using UnrealBuildTool;

public class WorldSim : ModuleRules
{
	public WorldSim(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "DeveloperSettings" });
		PrivateDependencyModuleNames.AddRange(new string[] { "HTTP", "Json", "JsonUtilities", "EnhancedInput", "InputCore" });
	}
}
