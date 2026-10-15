using System;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
public static class FinishExplorationWorld
{
    public static string Run()
    {
        if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/Marco06B1World.unity")throw new InvalidOperationException("New scene outside Play required");
        var world=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>().ConfigureExploration(world);UnityEngine.Object.FindAnyObjectByType<JourneyHud>().ConfigureExploration(world);UnityEngine.Object.FindAnyObjectByType<HealthHud>().ConfigureExploration(world);
        var debug=GameObject.Find("ActionDebug");if(debug!=null)debug.SetActive(false);
        var rock=UnityEngine.Object.FindObjectsByType<Transform>().FirstOrDefault(t=>t.name=="Formação rochosa"&&Vector2.Distance(t.position,new Vector2(1,23))<.1f);if(rock!=null)rock.position=new Vector2(2,21);
        var terrain=UnityEngine.Object.FindAnyObjectByType<MarshTerrain>();if(terrain!=null&&!PrefabUtility.IsPartOfPrefabInstance(terrain.gameObject))PrefabUtility.SaveAsPrefabAssetAndConnect(terrain.gameObject,"Assets/Mmorpg/Prefabs/Exploration/MarshTerrain.prefab",InteractionMode.AutomatedAction);
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();var children=canvas.GetComponentsInChildren<Transform>(true);var inventory=children.First(t=>t.name=="ActionSecondaryPanel");inventory.GetComponent<UnityEngine.UI.Image>().color=new Color(.03f,.06f,.06f,1);inventory.SetAsLastSibling();children.First(t=>t.name=="ExplorationDialogue").SetAsLastSibling();
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());return "Clear mine passage, hide debug, correct HUD and overlay order";
    }
}
