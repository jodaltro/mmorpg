// Console commands that let an agent play the game without a keyboard:
// real input goes through Enhanced Input injection (the same modifiers and
// triggers as a key press), and positions are logged so a headless run can be
// checked afterwards. They are test tools; the game logic never calls them.
#include "Containers/Ticker.h"
#include "Engine/Engine.h"
#include "Engine/LocalPlayer.h"
#include "Engine/World.h"
#include "EnhancedInputSubsystems.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "HAL/IConsoleManager.h"
#include "InputAction.h"
#include "Kismet/GameplayStatics.h"

DEFINE_LOG_CATEGORY_STATIC(LogWorldSim, Log, All);

static APlayerController* PlayerOf(UWorld* W)
{
	return W ? W->GetFirstPlayerController() : nullptr;
}

static UEnhancedInputLocalPlayerSubsystem* InputOf(UWorld* W)
{
	APlayerController* PC = PlayerOf(W);
	ULocalPlayer* LP = PC ? PC->GetLocalPlayer() : nullptr;
	return LP ? LP->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>() : nullptr;
}

// "IA_Move" means /Game/Input/IA_Move; a path starting with "/" is used as is.
static UInputAction* ActionOf(const FString& Name)
{
	FString Path = Name.StartsWith(TEXT("/")) ? Name : TEXT("/Game/Input/") + Name;
	if (!Path.Contains(TEXT(".")))
	{
		Path += TEXT(".") + FPaths::GetBaseFilename(Path);
	}
	UInputAction* A = LoadObject<UInputAction>(nullptr, *Path);
	if (!A)
	{
		UE_LOG(LogWorldSim, Warning, TEXT("WorldSim: no input action %s"), *Path);
	}
	return A;
}

static void LogPos(UWorld* W, const TCHAR* Tag)
{
	APawn* P = UGameplayStatics::GetPlayerPawn(W, 0);
	if (!P)
	{
		UE_LOG(LogWorldSim, Log, TEXT("WorldSim: %s no pawn"), Tag);
		return;
	}
	const FVector L = P->GetActorLocation();
	const FVector V = P->GetVelocity();
	UE_LOG(LogWorldSim, Log, TEXT("WorldSim: %s %s at %.0f %.0f %.0f speed %.0f yaw %.0f"), Tag, *P->GetClass()->GetName(),
		L.X, L.Y, L.Z, V.Size2D(), P->GetActorRotation().Yaw);
}

// ws.input <action> <x> [y] [z] [seconds=N]: hold the action for N seconds
// (continuous injection), or press it once when no seconds are given.
static FAutoConsoleCommandWithWorldAndArgs GInputCmd(TEXT("ws.input"), TEXT("ws.input <action> <x> [y] [z] [seconds=N]: inject input"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		UEnhancedInputLocalPlayerSubsystem* In = InputOf(W);
		UInputAction* Action = A.Num() > 0 ? ActionOf(A[0]) : nullptr;
		if (!In || !Action)
		{
			UE_LOG(LogWorldSim, Warning, TEXT("WorldSim: ws.input needs a player and an action"));
			return;
		}
		FVector V = FVector::ZeroVector;
		float Seconds = 0.f;
		int32 Axis = 0;
		for (int32 i = 1; i < A.Num(); ++i)
		{
			FString K, Val;
			if (A[i].Split(TEXT("="), &K, &Val)) { if (K == TEXT("seconds")) { Seconds = FCString::Atof(*Val); } }
			else if (Axis < 3) { V[Axis++] = FCString::Atof(*A[i]); }
		}
		const FInputActionValue Value(Action->ValueType, V);
		UE_LOG(LogWorldSim, Log, TEXT("WorldSim: INPUT %s %s for %.1fs"), *Action->GetName(), *Value.ToString(), Seconds);
		if (Seconds <= 0.f)
		{
			In->InjectInputForAction(Action, Value, {}, {});
			return;
		}
		In->StartContinuousInputInjectionForAction(Action, Value, {}, {});
		TWeakObjectPtr<UEnhancedInputLocalPlayerSubsystem> WeakIn(In);
		TWeakObjectPtr<UInputAction> WeakAction(Action);
		FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateLambda([WeakIn, WeakAction](float)
		{
			if (WeakIn.IsValid() && WeakAction.IsValid()) { WeakIn->StopContinuousInputInjectionForAction(WeakAction.Get()); }
			return false;
		}), Seconds);
	}));

static FAutoConsoleCommandWithWorldAndArgs GInputStopCmd(TEXT("ws.inputstop"), TEXT("ws.inputstop <action>: stop a held action"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		UEnhancedInputLocalPlayerSubsystem* In = InputOf(W);
		UInputAction* Action = A.Num() > 0 ? ActionOf(A[0]) : nullptr;
		if (In && Action) { In->StopContinuousInputInjectionForAction(Action); }
	}));

// ws.face <yaw>: turn the controller (camera) to a world yaw, e.g. -90 = -Y.
static FAutoConsoleCommandWithWorldAndArgs GFaceCmd(TEXT("ws.face"), TEXT("ws.face <yaw>: set the control rotation yaw"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (APlayerController* PC = PlayerOf(W); PC && A.Num() > 0)
		{
			PC->SetControlRotation(FRotator(0.f, FCString::Atof(*A[0]), 0.f));
		}
	}));

static FAutoConsoleCommandWithWorldAndArgs GPosCmd(TEXT("ws.pos"), TEXT("ws.pos: log the player pawn position and speed"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>&, UWorld* W) { LogPos(W, TEXT("POS")); }));

// ws.track <interval> <count>: log the position every interval seconds.
static FAutoConsoleCommandWithWorldAndArgs GTrackCmd(TEXT("ws.track"), TEXT("ws.track <interval> <count>: log positions over time"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		const float Every = A.Num() > 0 ? FMath::Max(0.1f, FCString::Atof(*A[0])) : 1.f;
		int32 Left = A.Num() > 1 ? FCString::Atoi(*A[1]) : 10;
		TWeakObjectPtr<UWorld> Weak(W);
		FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateLambda([Weak, Left](float) mutable
		{
			if (!Weak.IsValid()) { return false; }
			LogPos(Weak.Get(), TEXT("TRACK"));
			return --Left > 0;
		}), Every);
	}));

// ws.sequence <seconds> <cmd> | <cmd> | ...: runs console commands spaced in
// time, so a headless test (-ExecCmds) can play a whole scenario. The clock
// starts once the player pawn exists; each step waits for the previous one,
// so a long first frame (shader or asset loading) cannot bunch them together.
static void RunStep(TWeakObjectPtr<UWorld> Weak, TSharedRef<TArray<FString>> Steps, int32 Index, float Gap)
{
	FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateLambda([Weak, Steps, Index, Gap](float)
	{
		UWorld* World = Weak.Get();
		if (!World || !GEngine) { return false; }
		const FString& Step = (*Steps)[Index];
		UE_LOG(LogWorldSim, Log, TEXT("WorldSim: STEP %s"), *Step);
		GEngine->Exec(World, *Step);
		if (Index + 1 < Steps->Num()) { RunStep(Weak, Steps, Index + 1, Gap); }
		return false;
	}), Gap);
}

static FAutoConsoleCommandWithWorldAndArgs GSequenceCmd(TEXT("ws.sequence"), TEXT("ws.sequence <seconds> <cmd> | <cmd> ...: run commands spaced in time"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (A.Num() < 2 || !W)
		{
			return;
		}
		const float Gap = FMath::Max(0.1f, FCString::Atof(*A[0]));
		TArray<FString> Rest;
		for (int32 i = 1; i < A.Num(); ++i) { Rest.Add(A[i]); }
		TArray<FString> Parsed;
		FString::Join(Rest, TEXT(" ")).ParseIntoArray(Parsed, TEXT("|"), true);
		TSharedRef<TArray<FString>> Steps = MakeShared<TArray<FString>>();
		for (const FString& S : Parsed) { Steps->Add(S.TrimStartAndEnd()); }
		TWeakObjectPtr<UWorld> Weak(W);
		// Wait (polling on the core ticker) until the player pawn exists.
		FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateLambda([Weak, Steps, Gap](float)
		{
			if (!Weak.IsValid()) { return false; }
			if (!UGameplayStatics::GetPlayerPawn(Weak.Get(), 0)) { return true; }
			UE_LOG(LogWorldSim, Log, TEXT("WorldSim: SEQUENCE start (%d steps)"), Steps->Num());
			RunStep(Weak, Steps, 0, Gap);
			return false;
		}), 0.25f);
	}));
