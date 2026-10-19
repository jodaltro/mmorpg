using System;
using System.IO;
using System.Linq;
using Gamekit3D;
using Cinemachine;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.Rendering;

public static class BuildAction3DFoundation
{
    const string ScenePath = "Assets/Mmorpg/Scenes/ValdoriaAction3D.unity";
    const string Kit = "Assets/3DGamekit/Prefabs/";
    static GameObject Prefab(string path, Vector3 position)
    {
        var asset = AssetDatabase.LoadAssetAtPath<GameObject>(Kit + path + ".prefab");
        if (asset == null) throw new InvalidOperationException("Missing licensed Game Kit prefab: " + path);
        var result = (GameObject)PrefabUtility.InstantiatePrefab(asset);
        result.transform.position = position;
        return result;
    }
    static void Layer(GameObject root, int layer)
    {
        foreach (var t in root.GetComponentsInChildren<Transform>(true)) t.gameObject.layer = layer;
    }
    static GameObject Block(string name, Vector3 position, Vector3 scale, Material material)
    {
        var result = GameObject.CreatePrimitive(PrimitiveType.Cube);
        result.name = name; result.transform.position = position; result.transform.localScale = scale;
        result.GetComponent<Renderer>().sharedMaterial = material; result.layer = 16;
        return result;
    }
    public static string Build()
    {
        if (File.Exists(ScenePath)) throw new InvalidOperationException("Refusing to overwrite " + ScenePath);
        if (EditorSceneManager.GetActiveScene().isDirty) throw new InvalidOperationException("Save the current scene first.");
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        // Preserve existing 2D layer names; use only vacant indices for this kit.
        var tags = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/TagManager.asset")[0]);
        var layers = tags.FindProperty("layers");
        foreach (var pair in new[] { (16, "Environment"), (23, "Enemy"), (29, "Checkpoint") })
        {
            var layer = layers.GetArrayElementAtIndex(pair.Item1);
            if (layer.stringValue != "" && layer.stringValue != pair.Item2) throw new InvalidOperationException("Layer conflict");
            layer.stringValue = pair.Item2;
        }
        tags.ApplyModifiedPropertiesWithoutUndo();
        // The accessible official checkout uses Built-in shaders. Old setup is in the Git checkpoint.
        GraphicsSettings.defaultRenderPipeline = null;
        var quality = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/QualitySettings.asset")[0]);
        var entries = quality.FindProperty("m_QualitySettings");
        for (int i = 0; i < entries.arraySize; i++) entries.GetArrayElementAtIndex(i).FindPropertyRelative("customRenderPipeline").objectReferenceValue = null;
        quality.ApplyModifiedPropertiesWithoutUndo();
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.48f, 0.53f, 0.59f);
        RenderSettings.fog = true; RenderSettings.fogColor = new Color(0.32f, 0.45f, 0.5f);
        RenderSettings.fogMode = FogMode.Linear; RenderSettings.fogStartDistance = 35; RenderSettings.fogEndDistance = 95;
        var light = new GameObject("Sun").AddComponent<Light>(); light.type = LightType.Directional;
        light.transform.rotation = Quaternion.Euler(48, -35, 0); light.intensity = 1.2f; light.shadows = LightShadows.Soft;
        var material = new Material(Shader.Find("Standard")) { color = new Color(0.36f, 0.42f, 0.34f) };
        const string matPath = "Assets/Mmorpg/Scenes/Action3DGround.mat";
        if (File.Exists(matPath)) throw new InvalidOperationException("Refusing to overwrite " + matPath);
        AssetDatabase.CreateAsset(material, matPath);
        Block("ArenaGround", new Vector3(0,-0.5f,4), new Vector3(32,1,40), material);
        foreach (float side in new[] {-16f,16f}) Block("ArenaBoundary",new Vector3(side,1,4),new Vector3(1,3,40),material);
        Block("ArenaBoundary",new Vector3(0,1,-16),new Vector3(32,3,1),material);
        Block("ArenaBoundary",new Vector3(0,1,24),new Vector3(32,3,1),material);
        Block("NavigationObstacle",new Vector3(-5,1,6),new Vector3(3,2,6),material);
        Prefab("Environment/Skybox", Vector3.zero);
        var player = Prefab("Characters/Ellen/Ellen", new Vector3(0,0.15f,-6));
        var controller = player.GetComponent<PlayerController>(); controller.canAttack = true;
        player.AddComponent<GamekitCombatAuthority>().player = true;
        var cameraRig = Prefab("Utilities/CameraRig", Vector3.zero);
        var settings = cameraRig.GetComponent<CameraSettings>();
        settings.follow = player.transform; settings.lookAt = player.transform.Find("HeadTarget");
        settings.keyboardAndMouseInvertSettings.invertY = false;
        controller.cameraSettings = settings;
        foreach (var cam in cameraRig.GetComponentsInChildren<Camera>()) { cam.farClipPlane = 200; cam.backgroundColor = RenderSettings.fogColor; }
        UnityEngine.Object.FindAnyObjectByType<Gamekit3D.SkyboxVolume.Skybox3D>().camera = Camera.main;
        var checkpoint = Prefab("Utilities/Checkpoint", new Vector3(0,0.2f,-6)).GetComponent<Checkpoint>();
        var session = new GameObject("Action3DSession").AddComponent<Action3DSession>();
        session.gameObject.AddComponent<Mmorpg.Runtime.ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("Action3D/IsolatedProfile");
        session.gate = Block("PassageGate",new Vector3(7,1.5f,12),new Vector3(4,3,0.6f),material);
        var pedestal = Prefab("Interactables/WeaponPedestal",new Vector3(5,0,-5));
        // Keep the kit pedestal art; a separate kit trigger owns the local interaction.
        foreach(var component in pedestal.GetComponentsInChildren<MonoBehaviour>(true)) component.enabled = false;
        var interact = new GameObject("RecoveryInteraction"); interact.transform.position = new Vector3(5,1,-5);
        interact.AddComponent<BoxCollider>().isTrigger = true; interact.GetComponent<BoxCollider>().size = new Vector3(4,3,4);
        var button = interact.AddComponent<InteractOnButton>(); button.layers = 1 << player.layer;
        button.OnButtonPress = new UnityEngine.Events.UnityEvent();
        UnityEventTools.AddPersistentListener(button.OnButtonPress, session.Interact);
        Prefab("SceneControl/ScreenFader",Vector3.zero);
        var hud = new GameObject("EvaluationHUD",typeof(Canvas),typeof(UnityEngine.UI.CanvasScaler),typeof(UnityEngine.UI.GraphicRaycaster));
        hud.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
        var scaler = hud.GetComponent<UnityEngine.UI.CanvasScaler>(); scaler.uiScaleMode = UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize; scaler.referenceResolution = new Vector2(1280,720);
        var textGo = new GameObject("Controls",typeof(RectTransform),typeof(UnityEngine.UI.Text)); textGo.transform.SetParent(hud.transform,false);
        var rect = textGo.GetComponent<RectTransform>(); rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0,1); rect.anchoredPosition = new Vector2(18,-18); rect.sizeDelta = new Vector2(800,170);
        var text = textGo.GetComponent<UnityEngine.UI.Text>(); text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); text.fontSize = 19; text.color = Color.white; text.raycastTarget = false; session.status = text;
        var outline = textGo.AddComponent<UnityEngine.UI.Outline>(); outline.effectColor = Color.black;
        var rock = Prefab("Environment/Rock/RockChunk01",new Vector3(-10,0,12)); rock.transform.localScale = Vector3.one*0.6f; Layer(rock,16);
        var wall = Prefab("Environment/Stonework/WallLong01",new Vector3(10,0,14)); Layer(wall,16);
        var surface = new GameObject("ArenaNavigation").AddComponent<NavMeshSurface>(); surface.layerMask = 1 << 16; surface.useGeometry = NavMeshCollectGeometry.PhysicsColliders; surface.BuildNavMesh();
        AssetDatabase.CreateAsset(surface.navMeshData,"Assets/Mmorpg/Scenes/Action3DNavigation.asset");
        var enemy = Prefab("Characters/Enemies/Chomper/Chomper",new Vector3(0,0.1f,5));
        enemy.GetComponent<NavMeshAgent>().agentTypeID = surface.agentTypeID;
        enemy.transform.rotation = Quaternion.Euler(0,180,0);
        enemy.AddComponent<GamekitCombatAuthority>().cooldown = 1.5f;
        var chomper = enemy.GetComponent<ChomperBehavior>(); chomper.playerScanner.viewBlockerLayerMask = 1 << 16; chomper.playerScanner.detectionRadius = 12;
        enemy.GetComponent<Damageable>().maxHitPoints = 4;
        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene,ScenePath);
        var previous = EditorBuildSettings.scenes.Where(s=>s.path!=ScenePath).ToArray();
        EditorBuildSettings.scenes = new[] {new EditorBuildSettingsScene(ScenePath,true)}.Concat(previous.Select(s=>new EditorBuildSettingsScene(s.path,false))).ToArray();
        AssetDatabase.SaveAssets();
        return ScenePath;
    }
}
