#include "WorldSimInteractable.h"
#include "WorldSimSubsystem.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"

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

FString AWorldSimInteractable::Prompt() const
{
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
