#include "WorldSimActors.h"
#include "WorldSimSubsystem.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

static UWorldSimSubsystem* SimOf(const UObject* Ctx)
{
	const UWorld* W = Ctx ? Ctx->GetWorld() : nullptr;
	UGameInstance* GI = W ? W->GetGameInstance() : nullptr;
	return GI ? GI->GetSubsystem<UWorldSimSubsystem>() : nullptr;
}

static bool IsLocalPlayer(const UObject* Ctx, const AActor* Other)
{
	return Other && Other == UGameplayStatics::GetPlayerPawn(Ctx, 0);
}

AWorldSimRegionVolume::AWorldSimRegionVolume()
{
	SetActorHiddenInGame(true);
}

void AWorldSimRegionVolume::BeginPlay()
{
	Super::BeginPlay();
	OnActorBeginOverlap.AddDynamic(this, &AWorldSimRegionVolume::OnEnter);
	// A pawn that spawns inside the box overlaps before it is possessed, so
	// that overlap is dropped; check again once the player pawn exists.
	FTimerHandle Handle;
	GetWorldTimerManager().SetTimer(Handle, FTimerDelegate::CreateWeakLambda(this, [this]()
	{
		APawn* P = UGameplayStatics::GetPlayerPawn(this, 0);
		if (P && IsOverlappingActor(P)) { OnEnter(this, P); }
	}), 1.0f, false);
}

void AWorldSimRegionVolume::OnEnter(AActor*, AActor* Other)
{
	if (IsLocalPlayer(this, Other) && !RegionId.IsEmpty())
	{
		if (UWorldSimSubsystem* S = SimOf(this)) { S->Move(RegionId); }
	}
}

AWorldSimOccurrenceVolume::AWorldSimOccurrenceVolume()
{
	SetActorHiddenInGame(true);
}

void AWorldSimOccurrenceVolume::BeginPlay()
{
	Super::BeginPlay();
	OnActorBeginOverlap.AddDynamic(this, &AWorldSimOccurrenceVolume::OnEnter);
}

void AWorldSimOccurrenceVolume::OnEnter(AActor*, AActor* Other)
{
	if (!IsLocalPlayer(this, Other) || ActionId.IsEmpty() || bOnce && bFired)
	{
		return;
	}
	if (UWorldSimSubsystem* S = SimOf(this))
	{
		bFired = true;
		S->ReportOccurrence(ActionId, {});
	}
}

void UWorldSimDefeatReporter::BeginPlay()
{
	Super::BeginPlay();
	if (AActor* O = GetOwner())
	{
		O->OnDestroyed.AddDynamic(this, &UWorldSimDefeatReporter::OnOwnerDestroyed);
	}
}

void UWorldSimDefeatReporter::OnOwnerDestroyed(AActor*)
{
	ReportDefeat();
}

void UWorldSimDefeatReporter::ReportDefeat()
{
	const UWorld* W = GetWorld();
	if (bReported || ActionId.IsEmpty() || !W || W->bIsTearingDown)
	{
		return;
	}
	if (UWorldSimSubsystem* S = SimOf(this))
	{
		bReported = true;
		S->ReportOccurrence(ActionId, {});
	}
}
