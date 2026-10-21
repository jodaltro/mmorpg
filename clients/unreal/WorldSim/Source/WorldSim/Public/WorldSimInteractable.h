#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "WorldSimInteractable.generated.h"

class UTextRenderComponent;
class USkeletalMeshComponent;

/**
 * Something the player can use with the interact key: a well, a forge, an
 * NPC, herbs, a trail. Pressing the key sends ActionId to the world engine,
 * as a player intention or, when the game itself is the judge (the player
 * really reached the trail, really gathered the herbs), as a confirmed
 * occurrence. The engine decides what it means; the game only shows it.
 */
UCLASS(Blueprintable)
class WORLDSIM_API AWorldSimInteractable : public AActor
{
	GENERATED_BODY()

public:
	AWorldSimInteractable();

	/** Name shown above it, e.g. "Poco Antigo" or "Velho Tomas". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString DisplayName;

	/** Verb in the prompt, e.g. "Examinar" -> "[E] Examinar Poco Antigo". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString Verb = TEXT("Interagir");

	/** Action id in the universe. Empty = only shows the NPC's pending offer. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString ActionId;

	/** Sent as a confirmed occurrence (adapter) instead of a player intention. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	bool bConfirmedByGame = false;

	/** NPC entity id: talking opens the offer this NPC has for the player. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	FString NpcId;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	float Radius = 350.f;

	/** Seconds before it can be used again. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "WorldSim")
	float Cooldown = 2.f;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "WorldSim")
	TObjectPtr<UTextRenderComponent> Label;

	/** Optional body for NPCs (mesh and animation set in the level). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "WorldSim")
	TObjectPtr<USkeletalMeshComponent> Body;

	FString Prompt() const;
	bool Ready() const;
	void Use();

protected:
	virtual void OnConstruction(const FTransform& Transform) override;

private:
	double LastUse = -1000.0;
};
