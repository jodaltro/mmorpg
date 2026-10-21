#include "WorldSimSubsystem.h"
#include "WorldSimSettings.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "HAL/IConsoleManager.h"
#include "Misc/App.h"
#include "HttpModule.h"
#include "Interfaces/IHttpResponse.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

DEFINE_LOG_CATEGORY_STATIC(LogWorldSim, Log, All);

void UWorldSimSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	const UWorldSimSettings* S = GetDefault<UWorldSimSettings>();
	ServerUrl = FString::Printf(TEXT("http://%s:%d"), *S->ServerHost, S->ServerPort);
	PlayerId = S->PlayerId;
	PlayerName = S->PlayerName;
	PollInterval = FMath::Max(0.1f, S->PollInterval);
	bOnScreen = S->bOnScreenMessages;
	TickHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UWorldSimSubsystem::Poll), PollInterval);
	bStartMenu = S->bShowStartMenu && !FApp::IsUnattended() && !IsRunningCommandlet();
	if (bStartMenu)
	{
		// The start screen picks the character; nothing is joined until then.
		PlayerId.Reset();
		PlayerName.Reset();
		UE_LOG(LogWorldSim, Log, TEXT("WorldSim: client for %s, waiting for the start screen"), *ServerUrl);
		RequestPlayers();
		return;
	}
	UE_LOG(LogWorldSim, Log, TEXT("WorldSim: client for %s as %s"), *ServerUrl, *PlayerId);
	if (S->bAutoJoin)
	{
		Join();
	}
}

void UWorldSimSubsystem::Deinitialize()
{
	FTSTicker::GetCoreTicker().RemoveTicker(TickHandle);
	Super::Deinitialize();
}

void UWorldSimSubsystem::SetPlayer(const FString& Id, const FString& Name)
{
	PlayerId = Id;
	PlayerName = Name.IsEmpty() ? Id : Name;
	Quests.Empty();
	Skills.Reset();
	Recent.Reset();
	Region.Reset();
	bConnected = false;
	LastSeq = 0;
}

void UWorldSimSubsystem::Send(const FString& Origin, const FString& Kind, TFunctionRef<void(TSharedRef<FJsonObject>)> Fill)
{
	TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("version"), 1);
	Body->SetStringField(TEXT("requestId"), FString::Printf(TEXT("ue-%s-%lld-%d"), *PlayerId, FDateTime::UtcNow().ToUnixTimestamp(), ++Counter));
	Body->SetStringField(TEXT("origin"), Origin);
	Body->SetStringField(TEXT("kind"), Kind);
	Body->SetStringField(TEXT("actor"), PlayerId);
	Fill(Body);
	FString Json;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Json);
	FJsonSerializer::Serialize(Body, Writer);

	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = FHttpModule::Get().CreateRequest();
	Req->SetURL(ServerUrl + TEXT("/v1/commands"));
	Req->SetVerb(TEXT("POST"));
	Req->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
	Req->SetContentAsString(Json);
	const FString What = Kind;
	Req->OnProcessRequestComplete().BindWeakLambda(this, [this, What](FHttpRequestPtr, FHttpResponsePtr Res, bool bOk)
	{
		const int32 Code = Res.IsValid() ? Res->GetResponseCode() : 0;
		if (!bOk || Code != 200)
		{
			// 409 = the world refused (rules); not an error of the client.
			UE_LOG(LogWorldSim, Warning, TEXT("WorldSim: %s -> %d %s"), *What, Code, Res.IsValid() ? *Res->GetContentAsString() : TEXT("no response"));
			if (Code == 409 && What != TEXT("join"))
			{
				Say(-1, FColor::Orange, FString::Printf(TEXT("O mundo recusou: %s"), *What), 4.f);
				Notify(What == TEXT("act") ? TEXT("Nada acontece... (nao e possivel fazer isso agora)") : TEXT("O mundo recusou."), FLinearColor(1.f, 0.6f, 0.2f));
			}
			else if (Code == 0)
			{
				Notify(TEXT("Sem conexao com o servidor do mundo."), FLinearColor(1.f, 0.3f, 0.3f));
			}
			return;
		}
		UE_LOG(LogWorldSim, Log, TEXT("WorldSim: %s accepted"), *What);
		if (What == TEXT("accept")) { Notify(TEXT("Missao aceita."), FLinearColor(0.4f, 1.f, 0.5f)); }
		else if (What == TEXT("decline")) { Notify(TEXT("Proposta recusada."), FLinearColor(0.8f, 0.8f, 0.8f)); }
	});
	Req->ProcessRequest();
}

void UWorldSimSubsystem::Join()
{
	Send(TEXT("adapter"), TEXT("join"), [this](TSharedRef<FJsonObject> B) { B->SetStringField(TEXT("name"), PlayerName); });
}

void UWorldSimSubsystem::Move(const FString& RegionId)
{
	Send(TEXT("adapter"), TEXT("move"), [&RegionId](TSharedRef<FJsonObject> B) { B->SetStringField(TEXT("region"), RegionId); });
}

void UWorldSimSubsystem::RequestPlayers()
{
	ServerStatus.Reset();
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = FHttpModule::Get().CreateRequest();
	Req->SetURL(ServerUrl + TEXT("/v1/players"));
	Req->SetVerb(TEXT("GET"));
	Req->OnProcessRequestComplete().BindWeakLambda(this, [this](FHttpRequestPtr, FHttpResponsePtr Res, bool bOk)
	{
		if (!bOk || !Res.IsValid() || Res->GetResponseCode() != 200)
		{
			ServerStatus = FString::Printf(TEXT("Servidor do mundo fora do ar (%s). Rode worldsim serve e tente de novo."), *ServerUrl);
			return;
		}
		TSharedPtr<FJsonObject> Root;
		TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Res->GetContentAsString());
		const TArray<TSharedPtr<FJsonValue>>* Arr = nullptr;
		KnownPlayers.Reset();
		if (FJsonSerializer::Deserialize(Reader, Root) && Root.IsValid() && Root->TryGetArrayField(TEXT("players"), Arr))
		{
			for (const TSharedPtr<FJsonValue>& V : *Arr)
			{
				const TSharedPtr<FJsonObject> O = V->AsObject();
				FWorldSimPlayer P;
				O->TryGetStringField(TEXT("id"), P.Id);
				O->TryGetStringField(TEXT("name"), P.Name);
				O->TryGetStringField(TEXT("regionName"), P.RegionName);
				KnownPlayers.Add(P);
			}
		}
		ServerStatus = TEXT("ok");
	});
	Req->ProcessRequest();
}

void UWorldSimSubsystem::NewWorld()
{
	ServerStatus.Reset();
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = FHttpModule::Get().CreateRequest();
	Req->SetURL(ServerUrl + TEXT("/v1/world/reset"));
	Req->SetVerb(TEXT("POST"));
	Req->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
	Req->SetContentAsString(TEXT("{\"version\":1,\"confirm\":\"new-world\"}"));
	Req->OnProcessRequestComplete().BindWeakLambda(this, [this](FHttpRequestPtr, FHttpResponsePtr Res, bool bOk)
	{
		const bool bDone = bOk && Res.IsValid() && Res->GetResponseCode() == 200;
		UE_LOG(LogWorldSim, Log, TEXT("WorldSim: new world -> %s"), Res.IsValid() ? *Res->GetContentAsString() : TEXT("no response"));
		Notify(bDone ? TEXT("Um novo mundo comecou. O anterior foi arquivado.") : TEXT("Nao foi possivel criar um novo mundo."),
			bDone ? FLinearColor(0.4f, 1.f, 0.5f) : FLinearColor(1.f, 0.3f, 0.3f));
		RequestPlayers();
	});
	Req->ProcessRequest();
}

void UWorldSimSubsystem::Play(const FString& Id, const FString& Name)
{
	SetPlayer(Id, Name);
	UE_LOG(LogWorldSim, Log, TEXT("WorldSim: playing as %s (%s)"), *PlayerId, *PlayerName);
	Join(); // a character that already exists answers 409, which is fine
}

void UWorldSimSubsystem::Notify(const FString& Text, const FLinearColor& Color)
{
	FWorldSimNotice N;
	N.Text = Text;
	N.Color = Color;
	N.At = FPlatformTime::Seconds();
	Notices.Add(N);
	if (Notices.Num() > 8) { Notices.RemoveAt(0); }
}

static void FillAct(TSharedRef<FJsonObject> B, const FString& Action, const TMap<FString, FString>& Args)
{
	B->SetStringField(TEXT("action"), Action);
	if (Args.Num() > 0)
	{
		TSharedRef<FJsonObject> A = MakeShared<FJsonObject>();
		for (const TPair<FString, FString>& P : Args)
		{
			A->SetStringField(P.Key, P.Value);
		}
		B->SetObjectField(TEXT("args"), A);
	}
}

void UWorldSimSubsystem::Act(const FString& Action, const TMap<FString, FString>& Args)
{
	Send(TEXT("player"), TEXT("act"), [&](TSharedRef<FJsonObject> B) { FillAct(B, Action, Args); });
}

void UWorldSimSubsystem::ReportOccurrence(const FString& Action, const TMap<FString, FString>& Args)
{
	Send(TEXT("adapter"), TEXT("act"), [&](TSharedRef<FJsonObject> B) { FillAct(B, Action, Args); });
}

bool UWorldSimSubsystem::GetOffer(FWorldSimQuest& Out) const
{
	for (const TPair<FString, FWorldSimQuest>& Q : Quests)
	{
		if (Q.Value.State == TEXT("offered")) { Out = Q.Value; return true; }
	}
	return false;
}

bool UWorldSimSubsystem::GetActiveQuest(FWorldSimQuest& Out) const
{
	for (const TPair<FString, FWorldSimQuest>& Q : Quests)
	{
		if (Q.Value.State == TEXT("active")) { Out = Q.Value; return true; }
	}
	return false;
}

void UWorldSimSubsystem::AcceptOffer()
{
	FWorldSimQuest Q;
	if (!GetOffer(Q)) { Say(-1, FColor::Silver, TEXT("Nenhuma proposta pendente."), 3.f); return; }
	Send(TEXT("player"), TEXT("accept"), [&Q](TSharedRef<FJsonObject> B) { B->SetStringField(TEXT("quest"), Q.Key); });
}

void UWorldSimSubsystem::DeclineOffer()
{
	FWorldSimQuest Q;
	if (!GetOffer(Q)) { return; }
	Send(TEXT("player"), TEXT("decline"), [&Q](TSharedRef<FJsonObject> B) { B->SetStringField(TEXT("quest"), Q.Key); });
}

bool UWorldSimSubsystem::Poll(float)
{
	if (bPollInFlight || PlayerId.IsEmpty())
	{
		return true;
	}
	bPollInFlight = true;
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = FHttpModule::Get().CreateRequest();
	Req->SetURL(FString::Printf(TEXT("%s/v1/views/%s?limit=50"), *ServerUrl, *PlayerId));
	Req->SetVerb(TEXT("GET"));
	Req->OnProcessRequestComplete().BindUObject(this, &UWorldSimSubsystem::OnView);
	Req->ProcessRequest();
	return true;
}

static FString Str(const TSharedPtr<FJsonObject>& O, const TCHAR* K)
{
	FString V;
	return O.IsValid() && O->TryGetStringField(K, V) ? V : FString();
}

void UWorldSimSubsystem::OnView(FHttpRequestPtr, FHttpResponsePtr Res, bool bOk)
{
	bPollInFlight = false;
	if (!bOk || !Res.IsValid() || Res->GetResponseCode() != 200)
	{
		return; // not joined yet or engine offline: the game keeps running
	}
	TSharedPtr<FJsonObject> Root;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Res->GetContentAsString());
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		return;
	}
	WorldTick = (int64)Root->GetNumberField(TEXT("tick"));
	bConnected = true;
	const TSharedPtr<FJsonObject>* SelfObj = nullptr;
	if (Root->TryGetObjectField(TEXT("self"), SelfObj) && SelfObj)
	{
		Region = Str(*SelfObj, TEXT("region"));
	}
	const TArray<TSharedPtr<FJsonValue>>* SArr = nullptr;
	if (Root->TryGetArrayField(TEXT("skills"), SArr))
	{
		Skills.Reset();
		for (const TSharedPtr<FJsonValue>& V : *SArr)
		{
			const TSharedPtr<FJsonObject> O = V->AsObject();
			FWorldSimSkill K;
			K.Id = Str(O, TEXT("id"));
			K.Name = Str(O, TEXT("name"));
			K.Rarity = Str(O, TEXT("rarity"));
			K.Desc = Str(O, TEXT("desc"));
			Skills.Add(K);
		}
	}

	const TArray<TSharedPtr<FJsonValue>>* Others = nullptr;
	if (Root->TryGetArrayField(TEXT("others"), Others))
	{
		for (const TSharedPtr<FJsonValue>& V : *Others)
		{
			const TSharedPtr<FJsonObject> O = V->AsObject();
			Names.Add(Str(O, TEXT("id")), Str(O, TEXT("name")));
		}
	}

	const TArray<TSharedPtr<FJsonValue>>* QArr = nullptr;
	if (Root->TryGetArrayField(TEXT("quests"), QArr))
	{
		for (const TSharedPtr<FJsonValue>& V : *QArr)
		{
			const TSharedPtr<FJsonObject> O = V->AsObject();
			FWorldSimQuest Q;
			Q.Key = Str(O, TEXT("key"));
			Q.Title = Str(O, TEXT("title"));
			Q.Desc = Str(O, TEXT("desc"));
			Q.State = Str(O, TEXT("state"));
			Q.Giver = Str(O, TEXT("giver"));
			Q.GiverName = Names.FindRef(Q.Giver);
			Q.Rank = Str(O, TEXT("rank"));
			Q.Objective = Str(O, TEXT("objective"));
			Q.Reward = Str(O, TEXT("reward"));
			Q.Penalty = Str(O, TEXT("penalty"));
			Q.Stage = Str(O, TEXT("stage"));
			double Deadline = 0;
			O->TryGetNumberField(TEXT("deadline"), Deadline);
			Q.Deadline = (int64)Deadline;
			const FWorldSimQuest* Old = Quests.Find(Q.Key);
			const bool bStageChanged = Old && Old->State == Q.State && Old->Stage != Q.Stage;
			const bool bChanged = !Old || Old->State != Q.State || bStageChanged;
			Quests.Add(Q.Key, Q);
			if (!bChanged)
			{
				continue;
			}
			if (Q.State == TEXT("offered"))
			{
				const FString Who = Q.GiverName.IsEmpty() ? TEXT("Sistema") : Q.GiverName;
				UE_LOG(LogWorldSim, Log, TEXT("WorldSim: OFFER from %s: [%s] %s [%s]"), *Who, *Q.Rank, *Q.Title, *Q.Key);
				// A system window, Overgeared style: who, rank, text, objective, reward, penalty.
				FString Win = FString::Printf(TEXT("[%s] %s  (Rank %s)\n%s\nObjetivo: %s\nRecompensa: %s"),
					*Who, *Q.Title, Q.Rank.IsEmpty() ? TEXT("-") : *Q.Rank, *Q.Desc, *Q.Objective, *Q.Reward);
				if (!Q.Penalty.IsEmpty()) { Win += FString::Printf(TEXT("\nPenalidade: %s"), *Q.Penalty); }
				Win += TEXT("\n(ws.accept / ws.decline)");
				Say(1001, FColor::Yellow, Win, 25.f);
				OnQuestOffered.Broadcast(Q);
			}
			else if (bStageChanged)
			{
				const FString From = Old->Rank != Q.Rank ? FString::Printf(TEXT(" (Rank %s -> %s)"), *Old->Rank, *Q.Rank) : FString();
				UE_LOG(LogWorldSim, Log, TEXT("WorldSim: QUEST UPDATED %s stage %s%s"), *Q.Title, *Q.Stage, *From);
				Say(1003, FColor::Orange, FString::Printf(TEXT("Missao atualizada: %s%s\nObjetivo: %s"), *Q.Title, *From, *Q.Objective), 12.f);
				OnQuestChanged.Broadcast(Q);
			}
			else if (Old)
			{
				UE_LOG(LogWorldSim, Log, TEXT("WorldSim: QUEST %s -> %s"), *Q.Title, *Q.State);
				Say(1002, Q.State == TEXT("done") ? FColor::Green : FColor::Cyan, FString::Printf(TEXT("Missao %s: %s"), *Q.State, *Q.Title), 8.f);
				OnQuestChanged.Broadcast(Q);
			}
		}
	}

	const TArray<TSharedPtr<FJsonValue>>* EArr = nullptr;
	if (Root->TryGetArrayField(TEXT("events"), EArr))
	{
		for (const TSharedPtr<FJsonValue>& V : *EArr)
		{
			const TSharedPtr<FJsonObject> O = V->AsObject();
			FWorldSimEvent E;
			E.Seq = (int64)O->GetNumberField(TEXT("seq"));
			if (E.Seq <= LastSeq)
			{
				continue;
			}
			LastSeq = E.Seq;
			E.Tick = (int64)O->GetNumberField(TEXT("at"));
			E.Kind = Str(O, TEXT("kind"));
			E.Actor = Str(O, TEXT("actor"));
			E.Text = Str(O, TEXT("text"));
			O->TryGetBoolField(TEXT("public"), E.bPublic);
			const TSharedPtr<FJsonObject>* DataObj = nullptr;
			if (O->TryGetObjectField(TEXT("data"), DataObj) && DataObj)
			{
				for (const TPair<FString, TSharedPtr<FJsonValue>>& P : (*DataObj)->Values)
				{
					E.Data.Add(P.Key, P.Value->AsString());
				}
			}
			if (E.Kind == TEXT("skill-learned"))
			{
				// A system window, Overgeared/Shangri-La style.
				const FString Rarity = E.Data.FindRef(TEXT("rarity"));
				const FColor C = Rarity == TEXT("lendaria") ? FColor::Orange : Rarity == TEXT("absurda") ? FColor::Magenta
					: Rarity == TEXT("epica") || Rarity == TEXT("rara") ? FColor::Cyan : FColor::White;
				UE_LOG(LogWorldSim, Log, TEXT("WorldSim: SKILL %s (%s)"), *E.Text, *Rarity);
				Say(1004, C, FString::Printf(TEXT("Habilidade adquirida!\n%s  [%s]\n%s"), *E.Text, *Rarity, *E.Data.FindRef(TEXT("desc"))), 15.f);
			}
			if (!E.Text.IsEmpty() && !E.Kind.StartsWith(TEXT("quest-")) && E.Kind != TEXT("skill-learned"))
			{
				UE_LOG(LogWorldSim, Log, TEXT("WorldSim: EVENT [%lld] %s: %s"), E.Tick, *E.Kind, *E.Text);
				Say(-1, E.bPublic ? FColor::White : FColor(180, 220, 255), E.Text, 6.f);
			}
			if (!E.Text.IsEmpty() && !E.Kind.StartsWith(TEXT("quest-")))
			{
				Recent.Add(E);
				if (Recent.Num() > 30) { Recent.RemoveAt(0); }
			}
			OnWorldEvent.Broadcast(E);
		}
	}

	FWorldSimQuest Active;
	const FString Line = GetActiveQuest(Active)
		? FString::Printf(TEXT("[Mundo tick %lld] Missao ativa: %s"), WorldTick, *Active.Title)
		: FString::Printf(TEXT("[Mundo tick %lld] Sem missao ativa"), WorldTick);
	Say(1000, FColor::Emerald, Line, PollInterval * 3.f);
}

void UWorldSimSubsystem::Say(int32 Key, const FColor& Color, const FString& Text, float Seconds) const
{
	if (bOnScreen && !bHudActive && GEngine)
	{
		GEngine->AddOnScreenDebugMessage(Key, Seconds, Color, Text);
	}
}

FString UWorldSimSubsystem::Describe() const
{
	FString Out = FString::Printf(TEXT("WorldSim %s as %s, tick %lld, %d quests"), *ServerUrl, *PlayerId, WorldTick, Quests.Num());
	for (const TPair<FString, FWorldSimQuest>& Q : Quests)
	{
		Out += FString::Printf(TEXT("\n  %-10s %s (giver %s)"), *Q.Value.State, *Q.Value.Title, *Q.Value.Giver);
	}
	return Out;
}

// ---------------------------------------------------------------------------
// Console commands: drive the client from the console, -ExecCmds or MCP.

static UWorldSimSubsystem* Sim(UWorld* World)
{
	UGameInstance* GI = World ? World->GetGameInstance() : nullptr;
	UWorldSimSubsystem* S = GI ? GI->GetSubsystem<UWorldSimSubsystem>() : nullptr;
	if (!S)
	{
		UE_LOG(LogWorldSim, Warning, TEXT("WorldSim: start Play first (no game instance)"));
	}
	return S;
}

static TMap<FString, FString> ParseArgs(const TArray<FString>& Args, int32 From)
{
	TMap<FString, FString> M;
	for (int32 i = From; i < Args.Num(); ++i)
	{
		FString K, V;
		if (Args[i].Split(TEXT("="), &K, &V))
		{
			M.Add(K, V);
		}
	}
	return M;
}

static FAutoConsoleCommandWithWorldAndArgs GJoinCmd(TEXT("ws.join"), TEXT("ws.join [id] [name]: join the simulated world"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W))
		{
			if (A.Num() > 0) { S->SetPlayer(A[0], A.Num() > 1 ? A[1] : A[0]); }
			S->Join();
		}
	}));

static FAutoConsoleCommandWithWorldAndArgs GMoveCmd(TEXT("ws.move"), TEXT("ws.move <region>: report the region the player entered"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W); S && A.Num() > 0) { S->Move(A[0]); }
	}));

static FAutoConsoleCommandWithWorldAndArgs GActCmd(TEXT("ws.act"), TEXT("ws.act <action> [k=v...]: player intention"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W); S && A.Num() > 0) { S->Act(A[0], ParseArgs(A, 1)); }
	}));

static FAutoConsoleCommandWithWorldAndArgs GOccurCmd(TEXT("ws.occur"), TEXT("ws.occur <action> [k=v...]: confirmed occurrence"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W); S && A.Num() > 0) { S->ReportOccurrence(A[0], ParseArgs(A, 1)); }
	}));

static FAutoConsoleCommandWithWorldAndArgs GAcceptCmd(TEXT("ws.accept"), TEXT("ws.accept: accept the pending offer"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>&, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W)) { S->AcceptOffer(); }
	}));

static FAutoConsoleCommandWithWorldAndArgs GDeclineCmd(TEXT("ws.decline"), TEXT("ws.decline: decline the pending offer"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>&, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W)) { S->DeclineOffer(); }
	}));

static FAutoConsoleCommandWithWorldAndArgs GStatusCmd(TEXT("ws.status"), TEXT("ws.status: print the client state"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>&, UWorld* W)
	{
		if (UWorldSimSubsystem* S = Sim(W)) { UE_LOG(LogWorldSim, Log, TEXT("%s"), *S->Describe()); }
	}));

// Test-only commands (ws.input, ws.face, ws.pos, ws.track, ws.sequence) live
// in WorldSimTestCommands.cpp.
