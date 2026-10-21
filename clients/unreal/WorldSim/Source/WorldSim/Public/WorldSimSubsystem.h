#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Containers/Ticker.h"
#include "Interfaces/IHttpRequest.h"
#include "WorldSimSubsystem.generated.h"

/** A quest as seen by this player (mirrors the engine view). */
USTRUCT(BlueprintType)
struct FWorldSimQuest
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Key;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Title;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Desc;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString State;
	/** NPC who calls the player. The client decides how they reach them. */
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Giver;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString GiverName;
	/** System window fields: rank (F..SSS), objective, reward, penalty. */
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Rank;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Objective;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Reward;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Penalty;
	/** Current stage: the quest changes as the world changes. */
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Stage;
	/** World tick when a timed quest fails (0 = no limit). */
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") int64 Deadline = 0;
};

/** An event visible to this player (public world event or private). */
USTRUCT(BlueprintType)
struct FWorldSimEvent
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") int64 Seq = 0;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") int64 Tick = 0;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Kind;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Actor;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Text;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") bool bPublic = false;
	/** Extra data, e.g. skill rarity and description for "skill-learned". */
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") TMap<FString, FString> Data;
};

/** A skill this player discovered. */
USTRUCT(BlueprintType)
struct FWorldSimSkill
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Id;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Name;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Rarity;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Desc;
};

/** A character that exists in the world (start screen). */
USTRUCT(BlueprintType)
struct FWorldSimPlayer
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Id;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString Name;
	UPROPERTY(BlueprintReadOnly, Category = "WorldSim") FString RegionName;
};

/** A short message for the player (refusals, confirmations). */
struct FWorldSimNotice
{
	FString Text;
	FLinearColor Color = FLinearColor::White;
	double At = 0;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FWorldSimEventSignature, const FWorldSimEvent&, Event);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FWorldSimQuestSignature, const FWorldSimQuest&, Quest);

/**
 * Client of the World Simulation Engine. The game never decides world
 * consequences: it sends intentions (player) and confirmed occurrences
 * (adapter), and presents what the engine says this player can see.
 * All calls are asynchronous; nothing here blocks the game thread.
 */
UCLASS()
class WORLDSIM_API UWorldSimSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void Join();

	/** The game (as authority of positions) reports the region the player entered. */
	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void Move(const FString& RegionId);

	/** A player intention (talk, inform, examine...). */
	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void Act(const FString& Action, const TMap<FString, FString>& Args);

	/** A confirmed occurrence (enemy defeated, trail reached...). */
	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void ReportOccurrence(const FString& Action, const TMap<FString, FString>& Args);

	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void AcceptOffer();

	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void DeclineOffer();

	UFUNCTION(BlueprintPure, Category = "WorldSim")
	bool GetOffer(FWorldSimQuest& Out) const;

	UFUNCTION(BlueprintPure, Category = "WorldSim")
	bool GetActiveQuest(FWorldSimQuest& Out) const;

	UFUNCTION(BlueprintPure, Category = "WorldSim")
	int64 GetWorldTick() const { return WorldTick; }

	UFUNCTION(BlueprintPure, Category = "WorldSim")
	FString GetPlayerId() const { return PlayerId; }

	UFUNCTION(BlueprintPure, Category = "WorldSim")
	FString GetPlayerName() const { return PlayerName; }

	/** Region id the engine has for this player, and its display name. */
	UFUNCTION(BlueprintPure, Category = "WorldSim")
	FString GetRegion() const { return Region; }

	UFUNCTION(BlueprintPure, Category = "WorldSim")
	FString NameOf(const FString& Id) const { const FString* N = Names.Find(Id); return N ? *N : Id; }

	/** True once the engine answered at least one view (server reachable, player joined). */
	UFUNCTION(BlueprintPure, Category = "WorldSim")
	bool IsConnected() const { return bConnected; }

	/** Start screen: ask the server which characters exist. */
	void RequestPlayers();
	/** Start screen: archive the current world and start a new one. */
	void NewWorld();
	/** Start screen: play as this character (joins if new). */
	void Play(const FString& Id, const FString& Name);
	/** True once a character was chosen (or auto-joined). */
	bool IsPlaying() const { return !PlayerId.IsEmpty(); }
	/** Whether this run waits for the start screen. */
	bool WantsStartMenu() const { return bStartMenu; }
	const TArray<FWorldSimPlayer>& GetKnownPlayers() const { return KnownPlayers; }
	/** "" while loading, "ok", or an error text for the start screen. */
	const FString& GetServerStatus() const { return ServerStatus; }

	const TMap<FString, FWorldSimQuest>& GetQuests() const { return Quests; }
	const TArray<FWorldSimSkill>& GetSkills() const { return Skills; }
	/** Last visible events with text, newest last. */
	const TArray<FWorldSimEvent>& GetRecentEvents() const { return Recent; }
	const TArray<FWorldSimNotice>& GetNotices() const { return Notices; }
	void Notify(const FString& Text, const FLinearColor& Color);

	/** A HUD that draws the world state turns the debug text off. */
	void SetHudActive(bool bActive) { bHudActive = bActive; }

	/** Fired once per new visible event. */
	UPROPERTY(BlueprintAssignable, Category = "WorldSim")
	FWorldSimEventSignature OnWorldEvent;

	/** Fired when an NPC calls the player with a new quest. */
	UPROPERTY(BlueprintAssignable, Category = "WorldSim")
	FWorldSimQuestSignature OnQuestOffered;

	/** Fired when a quest of this player changes state. */
	UPROPERTY(BlueprintAssignable, Category = "WorldSim")
	FWorldSimQuestSignature OnQuestChanged;

	void SetPlayer(const FString& Id, const FString& Name);
	FString Describe() const;

private:
	bool Poll(float DeltaTime);
	void Send(const FString& Origin, const FString& Kind, TFunctionRef<void(TSharedRef<class FJsonObject>)> Fill);
	void OnView(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bOk);
	void Say(int32 Key, const FColor& Color, const FString& Text, float Seconds = 8.f) const;

	FString ServerUrl;
	FString PlayerId;
	FString PlayerName;
	FString Region;
	float PollInterval = 0.5f;
	bool bOnScreen = true;
	bool bHudActive = false;
	bool bStartMenu = false;
	TArray<FWorldSimPlayer> KnownPlayers;
	FString ServerStatus;
	bool bConnected = false;
	bool bPollInFlight = false;
	int64 LastSeq = 0;
	int64 WorldTick = 0;
	int32 Counter = 0;
	TMap<FString, FWorldSimQuest> Quests;
	TMap<FString, FString> Names;
	TArray<FWorldSimSkill> Skills;
	TArray<FWorldSimEvent> Recent;
	TArray<FWorldSimNotice> Notices;
	FTSTicker::FDelegateHandle TickHandle;
};
