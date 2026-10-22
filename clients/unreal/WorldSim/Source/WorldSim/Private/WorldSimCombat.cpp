#include "WorldSimCombat.h"
#include "WorldSimInteractable.h"
#include "WorldSimSettings.h"
#include "WorldSimSubsystem.h"
#include "Animation/AnimMontage.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/Character.h"
#include "GameFramework/PlayerController.h"
#include "HAL/IConsoleManager.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraSystem.h"
#include "TimerManager.h"

DEFINE_LOG_CATEGORY_STATIC(LogWorldSim, Log, All);

bool UWorldSimCombatSubsystem::ShouldCreateSubsystem(UObject* Outer) const
{
	const UWorld* W = Cast<UWorld>(Outer);
	return W && (W->WorldType == EWorldType::Game || W->WorldType == EWorldType::PIE) && !IsRunningCommandlet();
}

TStatId UWorldSimCombatSubsystem::GetStatId() const
{
	RETURN_QUICK_DECLARE_CYCLE_STAT(UWorldSimCombatSubsystem, STATGROUP_Tickables);
}

UWorldSimSubsystem* UWorldSimCombatSubsystem::Sim() const
{
	UGameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance() : nullptr;
	return GI ? GI->GetSubsystem<UWorldSimSubsystem>() : nullptr;
}

bool UWorldSimCombatSubsystem::HasSkill(const FString& Id) const
{
	const UWorldSimSubsystem* S = Sim();
	return Id.IsEmpty() || (S && S->GetSkills().ContainsByPredicate([&Id](const FWorldSimSkill& K) { return K.Id == Id; }));
}

TArray<FWorldSimMoveState> UWorldSimCombatSubsystem::GetHotbar() const
{
	TArray<FWorldSimMoveState> Out;
	const TArray<FWorldSimMove>& Moves = GetDefault<UWorldSimSettings>()->Moves;
	const double Now = FPlatformTime::Seconds();
	for (int32 i = 0; i < Moves.Num(); ++i)
	{
		FWorldSimMoveState M;
		M.Name = Moves[i].Name;
		M.Key = Moves[i].Key.GetDisplayName(false).ToString();
		const double Since = LastUse.IsValidIndex(i) ? Now - LastUse[i] : 1e9;
		M.CooldownLeft = FMath::Max(0.f, Moves[i].Cooldown - (float)Since);
		M.bLocked = !HasSkill(Moves[i].RequiresSkill);
		Out.Add(M);
	}
	return Out;
}

void UWorldSimCombatSubsystem::Tick(float DeltaTime)
{
	UWorldSimSubsystem* S = Sim();
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!S || !PC || !S->IsPlaying())
	{
		return;
	}
	const TArray<FWorldSimMove>& Moves = GetDefault<UWorldSimSettings>()->Moves;
	for (int32 i = 0; i < Moves.Num(); ++i)
	{
		if (Moves[i].Key.IsValid() && PC->WasInputKeyJustPressed(Moves[i].Key))
		{
			UseMove(i);
		}
	}
}

bool UWorldSimCombatSubsystem::UseMove(int32 Index)
{
	const TArray<FWorldSimMove>& Moves = GetDefault<UWorldSimSettings>()->Moves;
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	ACharacter* C = PC ? Cast<ACharacter>(PC->GetPawn()) : nullptr;
	UWorldSimSubsystem* S = Sim();
	if (!Moves.IsValidIndex(Index) || !C)
	{
		return false;
	}
	const FWorldSimMove& M = Moves[Index];
	LastUse.SetNumZeroed(Moves.Num());
	Combo.SetNumZeroed(Moves.Num());
	const double Now = FPlatformTime::Seconds();
	if (Now - LastUse[Index] < M.Cooldown)
	{
		return false;
	}
	if (!HasSkill(M.RequiresSkill))
	{
		if (S) { S->Notify(FString::Printf(TEXT("Voce ainda nao sabe usar %s. Viva o mundo para aprender."), *M.Name), FLinearColor(1.f, 0.7f, 0.3f)); }
		return false;
	}
	// Pressing again soon continues the combo; a pause starts it over.
	Combo[Index] = Now - LastUse[Index] < M.Cooldown + 1.2 ? Combo[Index] + 1 : 0;
	LastUse[Index] = Now;
	if (M.Montages.Num() > 0)
	{
		if (UAnimMontage* Montage = Cast<UAnimMontage>(M.Montages[Combo[Index] % M.Montages.Num()].TryLoad()))
		{
			C->PlayAnimMontage(Montage);
		}
	}
	if (UNiagaraSystem* FX = Cast<UNiagaraSystem>(M.CastFX.TryLoad()))
	{
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, FX, C->GetActorLocation(), C->GetActorRotation());
	}
	UE_LOG(LogWorldSim, Log, TEXT("WorldSim: MOVE %s (combo %d)"), *M.Name, Combo[Index]);
	FTimerHandle Handle;
	GetWorld()->GetTimerManager().SetTimer(Handle, FTimerDelegate::CreateWeakLambda(this, [this, Index]() { Hit(Index); }), FMath::Max(0.01f, M.HitDelay), false);
	return true;
}

void UWorldSimCombatSubsystem::Hit(int32 Index)
{
	const TArray<FWorldSimMove>& Moves = GetDefault<UWorldSimSettings>()->Moves;
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	APawn* P = PC ? PC->GetPawn() : nullptr;
	if (!Moves.IsValidIndex(Index) || !P)
	{
		return;
	}
	const FWorldSimMove& M = Moves[Index];
	if (M.Damage <= 0)
	{
		return; // a defensive move (block) hits nothing
	}
	const FVector At = P->GetActorLocation() + P->GetActorForwardVector() * M.Range;
	UNiagaraSystem* FX = Cast<UNiagaraSystem>(M.HitFX.TryLoad());
	bool bHitAny = false;
	for (TActorIterator<AWorldSimInteractable> It(GetWorld()); It; ++It)
	{
		AWorldSimInteractable* T = *It;
		if (!T->IsTarget() || FVector::Dist2D(At, T->GetActorLocation()) > M.Radius + 60.f)
		{
			continue;
		}
		bHitAny = true;
		if (FX) { UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, FX, T->GetActorLocation() + FVector(0, 0, 60)); }
		const FString Name = T->DisplayName;
		if (T->TakeHit(M.Damage))
		{
			UE_LOG(LogWorldSim, Log, TEXT("WorldSim: DEFEATED %s -> %s"), *Name, *T->ActionId);
			if (UWorldSimSubsystem* S = Sim()) { S->Notify(FString::Printf(TEXT("%s caiu!"), *Name), FLinearColor(1.f, 0.85f, 0.3f)); }
		}
		else
		{
			UE_LOG(LogWorldSim, Log, TEXT("WorldSim: HIT %s"), *Name);
		}
	}
	if (!bHitAny && FX)
	{
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, FX, At); // spells land even on empty ground
	}
}

// ws.attack <index>: use a combat move (headless tests and the console).
static FAutoConsoleCommandWithWorldAndArgs GAttackCmd(TEXT("ws.attack"), TEXT("ws.attack [index]: use combat move N (default 0)"),
	FConsoleCommandWithWorldAndArgsDelegate::CreateLambda([](const TArray<FString>& A, UWorld* W)
	{
		if (UWorldSimCombatSubsystem* C = W ? W->GetSubsystem<UWorldSimCombatSubsystem>() : nullptr)
		{
			C->UseMove(A.Num() > 0 ? FCString::Atoi(*A[0]) : 0);
		}
	}));
