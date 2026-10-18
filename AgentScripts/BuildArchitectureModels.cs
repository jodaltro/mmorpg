using UnityEditor.SceneManagement;
public static class BuildArchitectureModels
{
 const string Root="ArtSource/Labs/World2026/WorldStudio08/";
 public static object Barn(){EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaVegetationLab.unity");return ArchitectureArt07RImporter.BuildReference(Root+"Barn/RegionV1/",Root+"Barn/ExportV1/","Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/Barn/","Assets/Mmorpg/Scenes/ValdoriaBarnLab.unity");}
 public static object Castle(){EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaVegetationLab.unity");return ArchitectureArt07RImporter.BuildReference(Root+"Castle/ReviewV1/",Root+"Castle/ExportV1/","Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/Castle/","Assets/Mmorpg/Scenes/ValdoriaCastleLab.unity",true);}
}
