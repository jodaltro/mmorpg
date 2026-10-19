#pragma once

#include "CoreMinimal.h"
#include "Engine/TriggerBox.h"
#include "Components/ActorComponent.h"
#include "WorldSimActors.generated.h"

/** Entering this box reports the region to the world (game server role). */
UCLASS(Blueprintable)
class WORLDSIM_API AWorldSimRegionVolume : public ATriggerBox
{
	GENERATED_BODY()

public:
	AWorldSimRegionVolume();

	/** Region entity id in the universe, e.g. "floresta". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString RegionId;

protected:
	virtual void BeginPlay() override;

private:
	UFUNCTION()
	void OnEnter(AActor* Self, AActor* Other);
};

/** Entering this box reports a confirmed occurrence (e.g. "seguir-rastro"). */
UCLASS(Blueprintable)
class WORLDSIM_API AWorldSimOccurrenceVolume : public ATriggerBox
{
	GENERATED_BODY()

public:
	AWorldSimOccurrenceVolume();

	/** Action id in the universe with "adapter" origin. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString ActionId;

	/** Report only the first time the player enters. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	bool bOnce = true;

protected:
	virtual void BeginPlay() override;

private:
	UFUNCTION()
	void OnEnter(AActor* Self, AActor* Other);

	bool bFired = false;
};

/** Add to an enemy: when it is destroyed, the player is reported as the victor. */
UCLASS(ClassGroup = (WorldSim), meta = (BlueprintSpawnableComponent))
class WORLDSIM_API UWorldSimDefeatReporter : public UActorComponent
{
	GENERATED_BODY()

public:
	/** Action id with "adapter" origin, e.g. "cacar-lobos". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString ActionId;

	/** Call from Blueprint when the enemy dies (if it is not destroyed). */
	UFUNCTION(BlueprintCallable, Category = "WorldSim")
	void ReportDefeat();

protected:
	virtual void BeginPlay() override;

private:
	UFUNCTION()
	void OnOwnerDestroyed(AActor* Owner);

	bool bReported = false;
};
