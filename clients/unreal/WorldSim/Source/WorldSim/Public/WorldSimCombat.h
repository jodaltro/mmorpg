#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "WorldSimCombat.generated.h"

class UWorldSimSubsystem;
struct FWorldSimMove;

/** Hotbar state of one move, for the HUD. */
struct FWorldSimMoveState
{
	FString Name;
	FString Key;
	float CooldownLeft = 0.f;
	bool bLocked = false; // needs a world skill the player has not learned
};

/**
 * Player combat driven by UWorldSimSettings::Moves: a key plays a montage
 * (combos cycle), spawns Niagara effects and hits AWorldSimInteractable
 * targets in front of the player. A target going down is reported to the
 * world engine as a confirmed occurrence (the game is the combat authority;
 * the world never receives damage numbers). Moves may require a skill the
 * player learned by living the world.
 */
UCLASS()
class WORLDSIM_API UWorldSimCombatSubsystem : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual bool ShouldCreateSubsystem(UObject* Outer) const override;
	virtual void Tick(float DeltaTime) override;
	virtual TStatId GetStatId() const override;

	/** Uses a move by index (keys call this; tests use the ws.attack command). */
	bool UseMove(int32 Index);
	TArray<FWorldSimMoveState> GetHotbar() const;

private:
	UWorldSimSubsystem* Sim() const;
	bool HasSkill(const FString& Id) const;
	void Hit(int32 Index);

	TArray<double> LastUse;
	TArray<int32> Combo;
};
