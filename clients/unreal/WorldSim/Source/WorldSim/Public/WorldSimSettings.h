#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "WorldSimSettings.generated.h"

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
};

