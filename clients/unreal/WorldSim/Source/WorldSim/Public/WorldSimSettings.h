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
	/** World Simulation Engine HTTP endpoint (worldsim serve). */
	UPROPERTY(Config, EditAnywhere, Category = "Connection")
	FString ServerUrl = TEXT("http://127.0.0.1:8095");

	/** Character id in the simulated world. */
	UPROPERTY(Config, EditAnywhere, Category = "Player")
	FString PlayerId = TEXT("ana");

	UPROPERTY(Config, EditAnywhere, Category = "Player")
	FString PlayerName = TEXT("Ana");

	/** Join automatically when the game starts. */
	UPROPERTY(Config, EditAnywhere, Category = "Player")
	bool bAutoJoin = true;

	/** Seconds between view refreshes. */
	UPROPERTY(Config, EditAnywhere, Category = "Connection", meta = (ClampMin = "0.1"))
	float PollInterval = 0.5f;

	/** Print offers and events on screen (simple proof without UI). */
	UPROPERTY(Config, EditAnywhere, Category = "Presentation")
	bool bOnScreenMessages = true;
};
