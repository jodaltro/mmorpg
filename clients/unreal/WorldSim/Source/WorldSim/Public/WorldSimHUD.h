#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "WorldSimHUD.generated.h"

class SWidget;
class SVerticalBox;
class SEditableTextBox;
class UWorldSimSubsystem;
class AWorldSimInteractable;

/**
 * The player-facing interface of the WorldSim client, drawn with Slate so it
 * needs no assets: a start screen (continue a character, new character, new
 * world) and the in-game HUD (system window for offers with [Y]/[N], active
 * quest, world feed, notices, region banner, [E] prompts, [J] journal).
 * It only presents what UWorldSimSubsystem knows and sends what the player
 * chooses; it never decides anything about the world.
 */
UCLASS()
class WORLDSIM_API UWorldSimHUDSubsystem : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual bool ShouldCreateSubsystem(UObject* Outer) const override;
	virtual void Deinitialize() override;
	virtual void Tick(float DeltaTime) override;
	virtual TStatId GetStatId() const override;

private:
	UWorldSimSubsystem* Sim() const;
	void Build();
	TSharedRef<SWidget> BuildMenu();
	TSharedRef<SWidget> BuildHud();
	void RebuildPlayerList();
	void EnterGame();
	void CreateCharacter();
	void Interact();
	void UpdateLabels();

	TSharedPtr<SWidget> Root;
	TSharedPtr<SVerticalBox> PlayerList;
	TSharedPtr<SEditableTextBox> NameBox;
	TWeakObjectPtr<AWorldSimInteractable> Nearest;
	uint32 ListStamp = 0;
	bool bBuilt = false;
	bool bMenuInput = false;
	bool bConfirmNewWorld = false;
	bool bJournal = false;
	bool bPrimed = false;
	FString LastRegion;
	double RegionAt = -100.0;
	int64 LastSkillSeq = 0;
	FString Toast;
	FLinearColor ToastColor = FLinearColor::White;
	double ToastAt = -100.0;
};
