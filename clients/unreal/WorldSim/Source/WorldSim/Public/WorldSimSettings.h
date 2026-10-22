#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "InputCoreTypes.h"
#include "WorldSimSettings.generated.h"

/**
 * One combat move: a key plays a montage (cycling through a combo), spawns
 * effects and, after HitDelay, hits world targets in front of the player.
 * Content paths live in the project config, not in code.
 */
USTRUCT(BlueprintType)
struct FWorldSimMove
{
	GENERATED_BODY()

	/** Shown in the hotbar, e.g. "Golpe" or "Bola arcana". */
	UPROPERTY(Config, EditAnywhere, Category = "Move") FString Name;
	UPROPERTY(Config, EditAnywhere, Category = "Move") FKey Key;
	/** Montages played in turn when pressed again quickly (a combo). */
	UPROPERTY(Config, EditAnywhere, Category = "Move", meta = (AllowedClasses = "/Script/Engine.AnimMontage"))
	TArray<FSoftObjectPath> Montages;
	/** Niagara system at the player when the move starts (optional). */
	UPROPERTY(Config, EditAnywhere, Category = "Move", meta = (AllowedClasses = "/Script/Niagara.NiagaraSystem"))
	FSoftObjectPath CastFX;
	/** Niagara system where the move lands (optional). */
	UPROPERTY(Config, EditAnywhere, Category = "Move", meta = (AllowedClasses = "/Script/Niagara.NiagaraSystem"))
	FSoftObjectPath HitFX;
	/** Distance in front of the player where the move lands, and its radius (cm). */
	UPROPERTY(Config, EditAnywhere, Category = "Move") float Range = 150.f;
	UPROPERTY(Config, EditAnywhere, Category = "Move") float Radius = 150.f;
	/** Seconds from the key to the hit (matches the swing). */
	UPROPERTY(Config, EditAnywhere, Category = "Move") float HitDelay = 0.35f;
	UPROPERTY(Config, EditAnywhere, Category = "Move") float Cooldown = 0.6f;
	UPROPERTY(Config, EditAnywhere, Category = "Move") int32 Damage = 1;
	/** World skill id needed to use it (empty = always). Skills are learned by living the world. */
	UPROPERTY(Config, EditAnywhere, Category = "Move") FString RequiresSkill;
};

/** Project Settings > Plugins > WorldSim. Stored in DefaultGame.ini. */
UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "WorldSim"))
class WORLDSIM_API UWorldSimSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	/** World Simulation Engine host and port (worldsim serve). The URL is built in code: the ini parser treats // as a comment. */
	UPROPERTY(Config, EditAnywhere, Category = "Connection")
	FString ServerHost = TEXT("127.0.0.1");

	UPROPERTY(Config, EditAnywhere, Category = "Connection")
	int32 ServerPort = 8095;

	/** Character id in the simulated world. */
	UPROPERTY(Config, EditAnywhere, Category = "Player")
	FString PlayerId = TEXT("ana");

	UPROPERTY(Config, EditAnywhere, Category = "Player")
	FString PlayerName = TEXT("Ana");

	/** Join automatically when the game starts (headless tests, no start screen). */
	UPROPERTY(Config, EditAnywhere, Category = "Player")
	bool bAutoJoin = true;

	/**
	 * Show the start screen (continue a character, new character, new world)
	 * instead of joining automatically. Unattended runs (-unattended) always
	 * auto-join, so scripted tests keep working.
	 */
	UPROPERTY(Config, EditAnywhere, Category = "Presentation")
	bool bShowStartMenu = true;

	/** Seconds between view refreshes. */
	UPROPERTY(Config, EditAnywhere, Category = "Connection", meta = (ClampMin = "0.1"))
	float PollInterval = 0.5f;

	/** Print offers and events on screen (simple proof without UI). */
	UPROPERTY(Config, EditAnywhere, Category = "Presentation")
	bool bOnScreenMessages = true;

	/** Combat moves of the player (keys, montages, effects, required world skill). */
	UPROPERTY(Config, EditAnywhere, Category = "Combat")
	TArray<FWorldSimMove> Moves;
};

