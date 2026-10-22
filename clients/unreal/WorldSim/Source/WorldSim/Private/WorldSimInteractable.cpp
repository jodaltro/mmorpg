#include "WorldSimInteractable.h"
#include "WorldSimSubsystem.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "TimerManager.h"

AWorldSimInteractable::AWorldSimInteractable()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	Body = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(RootComponent);
	Body->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	Label = CreateDefaultSubobject<UTextRenderComponent>(TEXT("Label"));
	Label->SetupAttachment(RootComponent);
	Label->SetRelativeLocation(FVector(0.f, 0.f, 230.f));
	Label->SetHorizontalAlignment(EHTA_Center);
	Label->SetWorldSize(28.f);
	Label->SetTextRenderColor(FColor(255, 225, 140));
}

void AWorldSimInteractable::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Label->SetText(FText::FromString(DisplayName));
}

void AWorldSimInteractable::BeginPlay()
{
	Super::BeginPlay();
	Health = HitPoints;
	Refresh();
}

void AWorldSimInteractable::Refresh()
{
	FString Text = DisplayName;
	if (HitPoints > 0)
	{
		Text += Health > 0 ? FString::Printf(TEXT("  %s"), *FString::ChrN(Health, TEXT('|'))) : TEXT("  (caido)");
	}
	Label->SetText(FText::FromString(Text));
}

bool AWorldSimInteractable::TakeHit(int32 Damage)
{
	if (!IsTarget())
	{
		return false;
	}
	Health = FMath::Max(0, Health - FMath::Max(1, Damage));
	Refresh();
	if (Health > 0)
	{
		return false;
	}
	LastUse = -1000.0; // going down always reports, whatever the cooldown
	Use();
	Body->SetVisibility(false, true);
	if (RespawnSeconds > 0.f)
	{
		FTimerHandle Handle;
		GetWorldTimerManager().SetTimer(Handle, FTimerDelegate::CreateWeakLambda(this, [this]()
		{
			Health = HitPoints;
			Body->SetVisibility(true, true);
			Refresh();
		}), RespawnSeconds, false);
	}
	return true;
}

FString AWorldSimInteractable::Prompt() const
{
	if (HitPoints > 0)
	{
		return IsTarget() ? FString::Printf(TEXT("[Clique] Atacar %s"), *DisplayName) : FString::Printf(TEXT("%s (caido)"), *DisplayName);
	}
	return FString::Printf(TEXT("[E] %s %s"), *Verb, *DisplayName);
}

bool AWorldSimInteractable::Ready() const
{
	return FPlatformTime::Seconds() - LastUse >= Cooldown;
}

void AWorldSimInteractable::Use()
{
	UGameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance() : nullptr;
	UWorldSimSubsystem* S = GI ? GI->GetSubsystem<UWorldSimSubsystem>() : nullptr;
	if (!S || !Ready())
	{
		return;
	}
	LastUse = FPlatformTime::Seconds();
	if (ActionId.IsEmpty())
	{
		return; // talking only: the HUD shows the NPC's offer
	}
	if (bConfirmedByGame)
	{
		S->ReportOccurrence(ActionId, {});
	}
	else
	{
		S->Act(ActionId, {});
	}
}
