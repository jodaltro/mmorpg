#include "WorldSimHUD.h"
#include "WorldSimCombat.h"
#include "WorldSimInteractable.h"
#include "WorldSimSubsystem.h"
#include "Camera/PlayerCameraManager.h"
#include "Components/TextRenderComponent.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/GameViewportClient.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "Framework/Application/SlateApplication.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "InputCoreTypes.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/App.h"
#include "Styling/CoreStyle.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Input/SEditableTextBox.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SSpacer.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/SOverlay.h"
#include "Widgets/SWeakWidget.h"
#include "Widgets/Text/STextBlock.h"

#define LOCTEXT_NAMESPACE "WorldSimHUD"

namespace
{
const FLinearColor Ink(0.92f, 0.94f, 1.f);
const FLinearColor Dim(0.62f, 0.68f, 0.8f);
const FLinearColor Gold(1.f, 0.82f, 0.35f);
const FLinearColor PanelBg(0.02f, 0.04f, 0.10f, 0.86f);
const FLinearColor PanelEdge(0.35f, 0.65f, 1.f, 0.9f);

FSlateFontInfo Font(int32 Size, bool bBold = false)
{
	return FCoreStyle::GetDefaultFontStyle(bBold ? "Bold" : "Regular", Size);
}

FText T(const FString& S) { return FText::FromString(S); }

// A system-window panel: thin bright edge, dark translucent body.
TSharedRef<SWidget> Panel(const TSharedRef<SWidget>& Content, const FLinearColor& Edge = PanelEdge, float Pad = 14.f)
{
	return SNew(SBorder)
		.BorderImage(FCoreStyle::Get().GetBrush("WhiteBrush"))
		.BorderBackgroundColor(Edge)
		.Padding(2.f)
		[
			SNew(SBorder)
			.BorderImage(FCoreStyle::Get().GetBrush("WhiteBrush"))
			.BorderBackgroundColor(PanelBg)
			.Padding(Pad)
			[
				Content
			]
		];
}

FLinearColor RankColor(const FString& Rank)
{
	if (Rank.StartsWith(TEXT("S"))) { return Gold; }
	if (Rank == TEXT("A")) { return FLinearColor(0.8f, 0.45f, 1.f); }
	if (Rank == TEXT("B")) { return FLinearColor(0.35f, 0.65f, 1.f); }
	if (Rank == TEXT("C")) { return FLinearColor(0.4f, 0.95f, 0.5f); }
	return Dim;
}

FLinearColor RarityColor(const FString& R)
{
	if (R == TEXT("lendaria")) { return FLinearColor(1.f, 0.55f, 0.1f); }
	if (R == TEXT("absurda")) { return FLinearColor(1.f, 0.35f, 0.85f); }
	if (R == TEXT("epica")) { return FLinearColor(0.75f, 0.45f, 1.f); }
	if (R == TEXT("rara")) { return FLinearColor(0.35f, 0.75f, 1.f); }
	if (R == TEXT("incomum")) { return FLinearColor(0.45f, 1.f, 0.55f); }
	return Ink;
}

FString StateName(const FString& S)
{
	if (S == TEXT("active")) { return TEXT("em andamento"); }
	if (S == TEXT("done")) { return TEXT("concluida"); }
	if (S == TEXT("offered")) { return TEXT("proposta"); }
	if (S == TEXT("declined")) { return TEXT("recusada"); }
	if (S == TEXT("failed")) { return TEXT("falhou"); }
	if (S == TEXT("expired")) { return TEXT("expirou"); }
	if (S == TEXT("withdrawn")) { return TEXT("retirada"); }
	return S;
}

// "Jodaltro Ricco" -> "jodaltro-ricco": a stable id from the typed name.
FString Slug(const FString& Name)
{
	FString Out;
	for (TCHAR C : Name.ToLower())
	{
		if (FChar::IsAlnum(C) && C < 128) { Out.AppendChar(C); }
		else if (!Out.IsEmpty() && !Out.EndsWith(TEXT("-"))) { Out.AppendChar(TEXT('-')); }
	}
	Out.RemoveFromEnd(TEXT("-"));
	return Out.IsEmpty() ? TEXT("jogador") : Out;
}
}

bool UWorldSimHUDSubsystem::ShouldCreateSubsystem(UObject* Outer) const
{
	const UWorld* W = Cast<UWorld>(Outer);
	return W && (W->WorldType == EWorldType::Game || W->WorldType == EWorldType::PIE) && !IsRunningCommandlet();
}

TStatId UWorldSimHUDSubsystem::GetStatId() const
{
	RETURN_QUICK_DECLARE_CYCLE_STAT(UWorldSimHUDSubsystem, STATGROUP_Tickables);
}

UWorldSimSubsystem* UWorldSimHUDSubsystem::Sim() const
{
	UGameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance() : nullptr;
	return GI ? GI->GetSubsystem<UWorldSimSubsystem>() : nullptr;
}

void UWorldSimHUDSubsystem::Deinitialize()
{
	if (Root.IsValid() && GetWorld() && GetWorld()->GetGameViewport())
	{
		GetWorld()->GetGameViewport()->RemoveViewportWidgetContent(Root.ToSharedRef());
	}
	if (UWorldSimSubsystem* S = Sim()) { S->SetHudActive(false); }
	Root.Reset();
	Super::Deinitialize();
}

void UWorldSimHUDSubsystem::Build()
{
	UGameViewportClient* VP = GetWorld()->GetGameViewport();
	UWorldSimSubsystem* S = Sim();
	if (!VP || !S || FApp::IsUnattended())
	{
		return;
	}
	bBuilt = true;
	S->SetHudActive(true);
	Root = SNew(SOverlay)
		+ SOverlay::Slot()[BuildHud()]
		+ SOverlay::Slot()[BuildMenu()];
	VP->AddViewportWidgetContent(SNew(SWeakWidget).PossiblyNullContent(Root), 50);
}

TSharedRef<SWidget> UWorldSimHUDSubsystem::BuildMenu()
{
	TWeakObjectPtr<UWorldSimHUDSubsystem> Self(this);
	auto MenuVisible = [Self]()
	{
		const UWorldSimSubsystem* S = Self.IsValid() ? Self->Sim() : nullptr;
		return S && S->WantsStartMenu() && !S->IsPlaying() ? EVisibility::Visible : EVisibility::Collapsed;
	};
	auto Status = [Self]()
	{
		const UWorldSimSubsystem* S = Self.IsValid() ? Self->Sim() : nullptr;
		if (!S) { return FText(); }
		if (S->GetServerStatus().IsEmpty()) { return LOCTEXT("Loading", "Conectando ao mundo..."); }
		if (S->GetServerStatus() != TEXT("ok")) { return T(S->GetServerStatus()); }
		return S->GetKnownPlayers().Num() == 0
			? LOCTEXT("Empty", "Nenhum personagem neste mundo ainda. Crie o primeiro abaixo.")
			: LOCTEXT("Pick", "Escolha um personagem para continuar:");
	};
	auto Button = [](const FText& Label, const FLinearColor& Color, TFunction<void()> OnClick)
	{
		return SNew(SButton)
			.ButtonColorAndOpacity(Color)
			.ContentPadding(FMargin(16.f, 8.f))
			.OnClicked_Lambda([OnClick]() { OnClick(); return FReply::Handled(); })
			[
				SNew(STextBlock).Text(Label).Font(Font(13, true)).ColorAndOpacity(FLinearColor::White)
			];
	};

	return SNew(SBorder)
		.Visibility_Lambda(MenuVisible)
		.BorderImage(FCoreStyle::Get().GetBrush("WhiteBrush"))
		.BorderBackgroundColor(FLinearColor(0.f, 0.f, 0.02f, 0.78f))
		.HAlign(HAlign_Center)
		.VAlign(VAlign_Center)
		[
			SNew(SBox)
			.WidthOverride(620.f)
			[
				Panel(
					SNew(SVerticalBox)
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
					[
						SNew(STextBlock).Text(LOCTEXT("Title", "VALDORIA")).Font(Font(40, true)).ColorAndOpacity(Gold)
					]
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 0, 0, 18)
					[
						SNew(STextBlock).Text(LOCTEXT("Sub", "Um mundo vivo que continua sem voce")).Font(Font(13)).ColorAndOpacity(Dim)
					]
					+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 8)
					[
						SNew(STextBlock).Text_Lambda(Status).Font(Font(13)).ColorAndOpacity(Ink).AutoWrapText(true)
					]
					+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 16)
					[
						SAssignNew(PlayerList, SVerticalBox)
					]
					+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 6)
					[
						SNew(STextBlock).Text(LOCTEXT("NewChar", "Novo personagem (no mesmo mundo)")).Font(Font(14, true)).ColorAndOpacity(Ink)
					]
					+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 18)
					[
						SNew(SHorizontalBox)
						+ SHorizontalBox::Slot().FillWidth(1.f).Padding(0, 0, 8, 0)
						[
							SAssignNew(NameBox, SEditableTextBox)
							.HintText(LOCTEXT("NameHint", "Nome do personagem"))
							.Font(Font(14))
							.OnTextCommitted_Lambda([Self](const FText&, ETextCommit::Type How)
							{
								if (How == ETextCommit::OnEnter && Self.IsValid()) { Self->CreateCharacter(); }
							})
						]
						+ SHorizontalBox::Slot().AutoWidth()
						[
							Button(LOCTEXT("Create", "Criar e jogar"), FLinearColor(0.2f, 0.6f, 0.3f), [Self]() { if (Self.IsValid()) { Self->CreateCharacter(); } })
						]
					]
					+ SVerticalBox::Slot().AutoHeight()
					[
						SNew(SHorizontalBox)
						.Visibility_Lambda([Self]() { return Self.IsValid() && !Self->bConfirmNewWorld ? EVisibility::Visible : EVisibility::Collapsed; })
						+ SHorizontalBox::Slot().AutoWidth()
						[
							Button(LOCTEXT("NewWorld", "Novo mundo"), FLinearColor(0.7f, 0.18f, 0.15f), [Self]() { if (Self.IsValid()) { Self->bConfirmNewWorld = true; } })
						]
						+ SHorizontalBox::Slot().AutoWidth().Padding(12, 0, 0, 0)
						[
							Button(LOCTEXT("Refresh", "Atualizar"), FLinearColor(0.25f, 0.3f, 0.45f), [Self]() { if (Self.IsValid() && Self->Sim()) { Self->Sim()->RequestPlayers(); } })
						]
					]
					+ SVerticalBox::Slot().AutoHeight()
					[
						SNew(SVerticalBox)
						.Visibility_Lambda([Self]() { return Self.IsValid() && Self->bConfirmNewWorld ? EVisibility::Visible : EVisibility::Collapsed; })
						+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 8)
						[
							SNew(STextBlock)
							.Text(LOCTEXT("Confirm", "Comecar um mundo novo do zero? O mundo atual e todos os personagens ficam arquivados (nada e apagado)."))
							.Font(Font(13)).ColorAndOpacity(FLinearColor(1.f, 0.7f, 0.5f)).AutoWrapText(true)
						]
						+ SVerticalBox::Slot().AutoHeight()
						[
							SNew(SHorizontalBox)
							+ SHorizontalBox::Slot().AutoWidth()
							[
								Button(LOCTEXT("Yes", "Sim, novo mundo"), FLinearColor(0.75f, 0.15f, 0.12f), [Self]()
								{
									if (Self.IsValid() && Self->Sim()) { Self->bConfirmNewWorld = false; Self->Sim()->NewWorld(); }
								})
							]
							+ SHorizontalBox::Slot().AutoWidth().Padding(12, 0, 0, 0)
							[
								Button(LOCTEXT("Cancel", "Cancelar"), FLinearColor(0.25f, 0.3f, 0.45f), [Self]() { if (Self.IsValid()) { Self->bConfirmNewWorld = false; } })
							]
						]
					], Gold, 26.f)
			]
		];
}

void UWorldSimHUDSubsystem::RebuildPlayerList()
{
	UWorldSimSubsystem* S = Sim();
	if (!S || !PlayerList.IsValid())
	{
		return;
	}
	uint32 Stamp = GetTypeHash(S->GetServerStatus());
	for (const FWorldSimPlayer& P : S->GetKnownPlayers()) { Stamp = HashCombine(Stamp, GetTypeHash(P.Id + P.RegionName)); }
	if (Stamp == ListStamp)
	{
		return;
	}
	ListStamp = Stamp;
	PlayerList->ClearChildren();
	TWeakObjectPtr<UWorldSimHUDSubsystem> Self(this);
	for (const FWorldSimPlayer& P : S->GetKnownPlayers())
	{
		const FString Id = P.Id, Name = P.Name.IsEmpty() ? P.Id : P.Name;
		const FString Where = P.RegionName.IsEmpty() ? FString() : FString::Printf(TEXT("   -   %s"), *P.RegionName);
		PlayerList->AddSlot().AutoHeight().Padding(0, 2)
		[
			SNew(SButton)
			.ButtonColorAndOpacity(FLinearColor(0.15f, 0.3f, 0.55f))
			.ContentPadding(FMargin(14.f, 7.f))
			.OnClicked_Lambda([Self, Id, Name]()
			{
				if (Self.IsValid() && Self->Sim()) { Self->Sim()->Play(Id, Name); Self->EnterGame(); }
				return FReply::Handled();
			})
			[
				SNew(STextBlock).Text(T(FString::Printf(TEXT("Continuar como %s%s"), *Name, *Where))).Font(Font(13, true)).ColorAndOpacity(FLinearColor::White)
			]
		];
	}
}

void UWorldSimHUDSubsystem::CreateCharacter()
{
	UWorldSimSubsystem* S = Sim();
	if (!S || !NameBox.IsValid())
	{
		return;
	}
	const FString Name = NameBox->GetText().ToString().TrimStartAndEnd();
	if (Name.IsEmpty())
	{
		S->Notify(TEXT("Digite um nome para o personagem."), Gold);
		return;
	}
	const FString Base = Slug(Name);
	FString Id = Base;
	for (int32 N = 2; S->GetKnownPlayers().ContainsByPredicate([&Id](const FWorldSimPlayer& P) { return P.Id == Id; }); ++N)
	{
		Id = FString::Printf(TEXT("%s-%d"), *Base, N); // a new character, never someone else's
	}
	S->Play(Id, Name);
	EnterGame();
}

void UWorldSimHUDSubsystem::EnterGame()
{
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetInputMode(FInputModeGameOnly());
		PC->bShowMouseCursor = false;
	}
	FSlateApplication::Get().SetAllUserFocusToGameViewport();
	bConfirmNewWorld = false;
}

TSharedRef<SWidget> UWorldSimHUDSubsystem::BuildHud()
{
	TWeakObjectPtr<UWorldSimHUDSubsystem> Self(this);
	auto S = [Self]() -> UWorldSimSubsystem* { return Self.IsValid() ? Self->Sim() : nullptr; };
	auto Playing = [S]() { const UWorldSimSubsystem* X = S(); return X && X->IsPlaying() ? EVisibility::HitTestInvisible : EVisibility::Collapsed; };
	auto Offer = [S](FWorldSimQuest& Q) { const UWorldSimSubsystem* X = S(); return X && X->GetOffer(Q); };
	auto Active = [S](FWorldSimQuest& Q) { const UWorldSimSubsystem* X = S(); return X && X->GetActiveQuest(Q); };

	return SNew(SOverlay)
		.Visibility_Lambda(Playing)
		// Who and where.
		+ SOverlay::Slot().HAlign(HAlign_Left).VAlign(VAlign_Top).Padding(24.f)
		[
			Panel(
				SNew(SVerticalBox)
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(STextBlock).Font(Font(16, true)).ColorAndOpacity(Gold).Text_Lambda([S]() { const UWorldSimSubsystem* X = S(); return X ? T(X->GetPlayerName()) : FText(); })
				]
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(STextBlock).Font(Font(12)).ColorAndOpacity(Dim).Text_Lambda([S]()
					{
						const UWorldSimSubsystem* X = S();
						if (!X) { return FText(); }
						if (!X->IsConnected()) { return LOCTEXT("Offline", "Conectando ao mundo..."); }
						return T(FString::Printf(TEXT("%s   -   dia do mundo %lld"), *X->NameOf(X->GetRegion()), X->GetWorldTick()));
					})
				], PanelEdge, 10.f)
		]
		// Active quest tracker.
		+ SOverlay::Slot().HAlign(HAlign_Right).VAlign(VAlign_Top).Padding(24.f)
		[
			SNew(SBox).WidthOverride(380.f)
			[
				Panel(
					SNew(SVerticalBox)
					+ SVerticalBox::Slot().AutoHeight()
					[
						SNew(STextBlock).Text(LOCTEXT("Mission", "MISSAO")).Font(Font(11, true)).ColorAndOpacity(Dim)
					]
					+ SVerticalBox::Slot().AutoHeight()
					[
						SNew(STextBlock).Font(Font(15, true)).AutoWrapText(true)
						.ColorAndOpacity_Lambda([Active]() { FWorldSimQuest Q; return FSlateColor(Active(Q) ? RankColor(Q.Rank) : Dim); })
						.Text_Lambda([Active]()
						{
							FWorldSimQuest Q;
							return Active(Q) ? T(FString::Printf(TEXT("[%s] %s"), *Q.Rank, *Q.Title)) : LOCTEXT("NoQuest", "Nenhuma missao ativa. O mundo vai te procurar.");
						})
					]
					+ SVerticalBox::Slot().AutoHeight().Padding(0, 4, 0, 0)
					[
						SNew(STextBlock).Font(Font(12)).ColorAndOpacity(Ink).AutoWrapText(true).Text_Lambda([Active, S]()
						{
							FWorldSimQuest Q;
							if (!Active(Q)) { return FText(); }
							FString Out = TEXT("> ") + Q.Objective;
							if (!Q.Stage.IsEmpty()) { Out += FString::Printf(TEXT("\nEtapa: %s"), *Q.Stage); }
							if (Q.Deadline > 0 && S()) { Out += FString::Printf(TEXT("\nPrazo: %lld"), FMath::Max<int64>(0, Q.Deadline - S()->GetWorldTick())); }
							return T(Out);
						})
					])
			]
		]
		// System window: an NPC calls the player.
		+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center).Padding(FMargin(0, 0, 0, 120))
		[
			SNew(SBox).WidthOverride(560.f)
			.Visibility_Lambda([Offer]() { FWorldSimQuest Q; return Offer(Q) ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
			[
				Panel(
					SNew(SVerticalBox)
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
					[
						SNew(STextBlock).Text(LOCTEXT("System", "[ SISTEMA ]")).Font(Font(12, true)).ColorAndOpacity(PanelEdge)
					]
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 2, 0, 8)
					[
						SNew(STextBlock).Font(Font(12)).ColorAndOpacity(Dim).Text_Lambda([Offer]()
						{
							FWorldSimQuest Q;
							return Offer(Q) ? T(FString::Printf(TEXT("%s chama voce"), Q.GiverName.IsEmpty() ? TEXT("Alguem") : *Q.GiverName)) : FText();
						})
					]
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
					[
						SNew(STextBlock).Font(Font(20, true)).Justification(ETextJustify::Center).AutoWrapText(true)
						.ColorAndOpacity_Lambda([Offer]() { FWorldSimQuest Q; return FSlateColor(Offer(Q) ? RankColor(Q.Rank) : Ink); })
						.Text_Lambda([Offer]() { FWorldSimQuest Q; return Offer(Q) ? T(Q.Title) : FText(); })
					]
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 2, 0, 10)
					[
						SNew(STextBlock).Font(Font(14, true)).ColorAndOpacity(Gold)
						.Text_Lambda([Offer]() { FWorldSimQuest Q; return Offer(Q) ? T(FString::Printf(TEXT("Rank %s"), Q.Rank.IsEmpty() ? TEXT("-") : *Q.Rank)) : FText(); })
					]
					+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 10)
					[
						SNew(STextBlock).Font(Font(13)).ColorAndOpacity(Ink).AutoWrapText(true)
						.Text_Lambda([Offer]() { FWorldSimQuest Q; return Offer(Q) ? T(Q.Desc) : FText(); })
					]
					+ SVerticalBox::Slot().AutoHeight()
					[
						SNew(STextBlock).Font(Font(13)).ColorAndOpacity(Ink).AutoWrapText(true).Text_Lambda([Offer]()
						{
							FWorldSimQuest Q;
							if (!Offer(Q)) { return FText(); }
							FString Out = FString::Printf(TEXT("Objetivo: %s\nRecompensa: %s"), *Q.Objective, *Q.Reward);
							if (!Q.Penalty.IsEmpty()) { Out += FString::Printf(TEXT("\nPenalidade: %s"), *Q.Penalty); }
							return T(Out);
						})
					]
					+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 14, 0, 0)
					[
						SNew(STextBlock).Text(LOCTEXT("YN", "[Y] Aceitar          [N] Recusar")).Font(Font(15, true)).ColorAndOpacity(Gold)
					], PanelEdge, 20.f)
			]
		]
		// Toast: notices, skills, the region banner.
		+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Top).Padding(FMargin(0, 90, 0, 0))
		[
			SNew(SVerticalBox)
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
			[
				SNew(STextBlock).Font(Font(26, true)).ColorAndOpacity(Gold)
				.Visibility_Lambda([Self]() { return Self.IsValid() && FPlatformTime::Seconds() - Self->RegionAt < 3.5 ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
				.Text_Lambda([S]() { const UWorldSimSubsystem* X = S(); return X ? T(X->NameOf(X->GetRegion())) : FText(); })
			]
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 8, 0, 0)
			[
				SNew(SBox)
				.Visibility_Lambda([Self]() { return Self.IsValid() && FPlatformTime::Seconds() - Self->ToastAt < 6.0 ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
				[
					Panel(
						SNew(STextBlock).Font(Font(15, true)).Justification(ETextJustify::Center)
						.ColorAndOpacity_Lambda([Self]() { return FSlateColor(Self.IsValid() ? Self->ToastColor : Ink); })
						.Text_Lambda([Self]() { return Self.IsValid() ? T(Self->Toast) : FText(); }),
						PanelEdge, 12.f)
				]
			]
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 8, 0, 0)
			[
				SNew(STextBlock).Font(Font(14, true)).ShadowOffset(FVector2D(1, 1))
				.Visibility_Lambda([S]()
				{
					const UWorldSimSubsystem* X = S();
					return X && X->GetNotices().Num() > 0 && FPlatformTime::Seconds() - X->GetNotices().Last().At < 4.0 ? EVisibility::HitTestInvisible : EVisibility::Collapsed;
				})
				.ColorAndOpacity_Lambda([S]() { const UWorldSimSubsystem* X = S(); return FSlateColor(X && X->GetNotices().Num() ? X->GetNotices().Last().Color : Ink); })
				.Text_Lambda([S]() { const UWorldSimSubsystem* X = S(); return X && X->GetNotices().Num() ? T(X->GetNotices().Last().Text) : FText(); })
			]
		]
		// World feed.
		+ SOverlay::Slot().HAlign(HAlign_Left).VAlign(VAlign_Bottom).Padding(24.f, 24.f, 24.f, 70.f)
		[
			SNew(SBox).WidthOverride(520.f)
			[
				SNew(STextBlock).Font(Font(12)).ColorAndOpacity(Ink).AutoWrapText(true).ShadowOffset(FVector2D(1, 1))
				.Text_Lambda([S]()
				{
					const UWorldSimSubsystem* X = S();
					if (!X) { return FText(); }
					const TArray<FWorldSimEvent>& R = X->GetRecentEvents();
					FString Out;
					for (int32 i = FMath::Max(0, R.Num() - 6); i < R.Num(); ++i) { Out += TEXT("- ") + R[i].Text + TEXT("\n"); }
					return T(Out);
				})
			]
		]
		// Combat hotbar: key, move, cooldown; locked until the world teaches the skill.
		+ SOverlay::Slot().HAlign(HAlign_Right).VAlign(VAlign_Bottom).Padding(24.f, 24.f, 24.f, 70.f)
		[
			SNew(STextBlock).Font(Font(13, true)).ColorAndOpacity(Ink).ShadowOffset(FVector2D(1, 1)).Justification(ETextJustify::Right)
			.Text_Lambda([Self]()
			{
				const UWorldSimCombatSubsystem* C = Self.IsValid() && Self->GetWorld() ? Self->GetWorld()->GetSubsystem<UWorldSimCombatSubsystem>() : nullptr;
				if (!C) { return FText(); }
				FString Out;
				for (const FWorldSimMoveState& M : C->GetHotbar())
				{
					Out += FString::Printf(TEXT("[%s] %s%s\n"), *M.Key, *M.Name,
						M.bLocked ? TEXT("  (bloqueado)") : M.CooldownLeft > 0.05f ? *FString::Printf(TEXT("  %.1fs"), M.CooldownLeft) : TEXT(""));
				}
				return T(Out);
			})
		]
		// Interaction prompt and key hints.
		+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Bottom).Padding(FMargin(0, 0, 0, 28))
		[
			SNew(SVerticalBox)
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0, 0, 0, 8)
			[
				SNew(SBox)
				.Visibility_Lambda([Self]() { return Self.IsValid() && Self->Nearest.IsValid() ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
				[
					Panel(SNew(STextBlock).Font(Font(16, true)).ColorAndOpacity(Gold)
						.Text_Lambda([Self]() { return Self.IsValid() && Self->Nearest.IsValid() ? T(Self->Nearest->Prompt()) : FText(); }), Gold, 10.f)
				]
			]
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
			[
				SNew(STextBlock).Text(LOCTEXT("Keys", "[E] Interagir     [Y]/[N] Proposta     [J] Diario")).Font(Font(11)).ColorAndOpacity(Dim).ShadowOffset(FVector2D(1, 1))
			]
		]
		// Journal.
		+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center)
		[
			SNew(SBox).WidthOverride(640.f)
			.Visibility_Lambda([Self]() { return Self.IsValid() && Self->bJournal ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
			[
				Panel(
					SNew(STextBlock).Font(Font(13)).ColorAndOpacity(Ink).AutoWrapText(true).Text_Lambda([S]()
					{
						const UWorldSimSubsystem* X = S();
						if (!X) { return FText(); }
						FString Out = TEXT("DIARIO\n\nMissoes\n");
						for (const TPair<FString, FWorldSimQuest>& Q : X->GetQuests())
						{
							Out += FString::Printf(TEXT("  [%s] %s  -  %s\n"), *Q.Value.Rank, *Q.Value.Title, *StateName(Q.Value.State));
						}
						Out += TEXT("\nHabilidades\n");
						for (const FWorldSimSkill& K : X->GetSkills())
						{
							Out += FString::Printf(TEXT("  %s  [%s]  -  %s\n"), *K.Name, *K.Rarity, *K.Desc);
						}
						if (X->GetSkills().Num() == 0) { Out += TEXT("  (nenhuma ainda: viva o mundo e elas aparecem)\n"); }
						Out += TEXT("\n[J] fechar");
						return T(Out);
					}), Gold, 22.f)
			]
		];
}

void UWorldSimHUDSubsystem::Interact()
{
	UWorldSimSubsystem* S = Sim();
	AWorldSimInteractable* I = Nearest.Get();
	if (!S || !I || !I->Ready() || I->HitPoints > 0)
	{
		return; // targets are defeated in combat, not with the interact key
	}
	if (!I->NpcId.IsEmpty() && I->ActionId.IsEmpty())
	{
		FWorldSimQuest Q;
		if (!(S->GetOffer(Q) && Q.Giver == I->NpcId))
		{
			S->Notify(FString::Printf(TEXT("%s: Agora nao tenho nada para voce."), *I->DisplayName), Dim);
		}
	}
	I->Use();
}

void UWorldSimHUDSubsystem::UpdateLabels()
{
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	APawn* P = PC ? PC->GetPawn() : nullptr;
	const FVector Cam = PC && PC->PlayerCameraManager ? PC->PlayerCameraManager->GetCameraLocation() : FVector::ZeroVector;
	AWorldSimInteractable* Best = nullptr;
	float BestDist = TNumericLimits<float>::Max();
	for (TActorIterator<AWorldSimInteractable> It(GetWorld()); It; ++It)
	{
		AWorldSimInteractable* I = *It;
		const FVector L = I->Label->GetComponentLocation();
		I->Label->SetWorldRotation(FRotator(0.f, (Cam - L).Rotation().Yaw, 0.f));
		if (P)
		{
			const float D = FVector::Dist2D(P->GetActorLocation(), I->GetActorLocation());
			if (D < I->Radius && D < BestDist) { Best = I; BestDist = D; }
		}
	}
	Nearest = Best;
}

void UWorldSimHUDSubsystem::Tick(float DeltaTime)
{
	if (!bBuilt)
	{
		Build();
		if (!bBuilt) { return; }
	}
	UWorldSimSubsystem* S = Sim();
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!S || !PC)
	{
		return;
	}
	if (S->WantsStartMenu() && !S->IsPlaying())
	{
		RebuildPlayerList();
		if (!bMenuInput)
		{
			bMenuInput = true;
			FInputModeUIOnly Mode;
			PC->SetInputMode(Mode);
			PC->bShowMouseCursor = true;
		}
		return;
	}
	UpdateLabels();
	if (!bPrimed && S->IsConnected())
	{
		// Continuing a character: what it learned before is not news.
		bPrimed = true;
		for (const FWorldSimEvent& E : S->GetRecentEvents()) { LastSkillSeq = FMath::Max(LastSkillSeq, E.Seq); }
	}
	// New region: a banner. New skill: a system toast.
	if (S->GetRegion() != LastRegion)
	{
		if (!LastRegion.IsEmpty() || !S->GetRegion().IsEmpty()) { RegionAt = FPlatformTime::Seconds(); }
		LastRegion = S->GetRegion();
	}
	for (const FWorldSimEvent& E : S->GetRecentEvents())
	{
		if (E.Kind == TEXT("skill-learned") && E.Seq > LastSkillSeq)
		{
			LastSkillSeq = E.Seq;
			const FString Rarity = E.Data.FindRef(TEXT("rarity"));
			Toast = FString::Printf(TEXT("Habilidade adquirida!\n%s  [%s]\n%s"), *E.Text, *Rarity, *E.Data.FindRef(TEXT("desc")));
			ToastColor = RarityColor(Rarity);
			ToastAt = FPlatformTime::Seconds();
		}
	}
	if (PC->WasInputKeyJustPressed(EKeys::E)) { Interact(); }
	if (PC->WasInputKeyJustPressed(EKeys::Y)) { S->AcceptOffer(); }
	if (PC->WasInputKeyJustPressed(EKeys::N)) { S->DeclineOffer(); }
	if (PC->WasInputKeyJustPressed(EKeys::J)) { bJournal = !bJournal; }
}

#undef LOCTEXT_NAMESPACE
