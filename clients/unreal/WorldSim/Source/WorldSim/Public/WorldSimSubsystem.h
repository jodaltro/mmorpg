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
	void Move(const FString& Region);

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
	float PollInterval = 0.5f;
	bool bOnScreen = true;
	bool bPollInFlight = false;
	int64 LastSeq = 0;
	int64 WorldTick = 0;
	int32 Counter = 0;
	TMap<FString, FWorldSimQuest> Quests;
	TMap<FString, FString> Names;
	FTSTicker::FDelegateHandle TickHandle;
};
