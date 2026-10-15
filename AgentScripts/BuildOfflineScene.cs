using System;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class BuildOfflineScene
{
    public const string ScenePath = "Assets/Mmorpg/Scenes/OfflineClearing.unity";
    private static Sprite square;
    private static Material spriteMaterial;

    public static string ImportHudResources()
    {
        TMP_PackageResourceImporter.ImportResources(true, false, false);
        return "TMP essentials imported non-interactively";
    }

    public static string Build()
    {
        if (File.Exists(ScenePath)) throw new InvalidOperationException("Scene exists; refusing overwrite.");
        for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++)
            if (UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).isDirty)
                throw new InvalidOperationException("Save existing dirty scenes first.");
        Directory.CreateDirectory("Assets/Mmorpg/Scenes");
        Directory.CreateDirectory("Assets/Mmorpg/Art");
        AssetDatabase.Refresh();
        SetLayer(8, "Obstacles"); SetLayer(9, "Actors");
        square = PixelSprite("Square", new[] { "w" }, new[] { Color.white }, "w", 1);
        var heroSprite = PixelSprite("Hero", new[] {
            ".....hhhh.......", "....hhhhhh......", "....hsssshh.....", ".....ssess......",
            "......ss........", "....bbbbbb......", "...abbbbbba.....", "...abbbbbba.....",
            "...abbbbbba.....", "....bbbbbb......", "....kkkkkk......", "....kk..kk......",
            "....kk..kk......", "...kkk..kkk.....", "................", "................"
        }, new Color[] { new Color32(54,35,37,255), new Color32(238,187,136,255), new Color32(29,40,49,255), new Color32(66,168,215,255), new Color32(236,186,133,255), new Color32(39,64,78,255) }, "hsebak", 16);
        var wolfSprite = PixelSprite("Wolf", new[] {
            "................", "...g......g.....", "...gg....gg.....", "..gggggggggg....",
            "..gweggggewg....", "..gggggggggg....", "...gggnnggg.....", "....ggnngg......",
            "...gggggggg.....", "..gggggggggg....", "..gggggggggg....", "...gggggggg.....",
            "...dd....dd.....", "...dd....dd.....", "................", "................"
        }, new Color[] { new Color32(159,171,173,255), Color.white, new Color32(240,107,77,255), new Color32(49,60,68,255), new Color32(79,96,103,255) }, "gwend", 16);
        var shader = Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default") ?? Shader.Find("Sprites/Default");
        spriteMaterial = new Material(shader);
        AssetDatabase.CreateAsset(spriteMaterial, "Assets/Mmorpg/Art/PlaceholderSprite.mat");
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        var server = new GameObject("OfflineAuthority").AddComponent<OfflineAuthority>();
        var world = new GameObject("Clearing");
        Block("Ground", Vector2.zero, new Vector2(26, 18), new Color32(37,65,53,255), false, world.transform, -500);
        // Deterministic sparse pixel grass, kept clear of the spawn and patrol path.
        var random = new System.Random(42);
        for (int i = 0; i < 160; i++)
            Block("Grass", new Vector2((float)random.NextDouble()*24-12, (float)random.NextDouble()*16-8), new Vector2(0.125f,0.25f), new Color32(54,89,64,255), false, world.transform, -499);
        var wallColor = new Color32(80,96,92,255);
        Block("NorthWall", new Vector2(0,8), new Vector2(25,0.75f), wallColor,true,world.transform);
        Block("SouthWall", new Vector2(0,-8), new Vector2(25,0.75f), wallColor,true,world.transform);
        Block("WestWall", new Vector2(-12,0), new Vector2(0.75f,16),wallColor,true,world.transform);
        Block("EastWall", new Vector2(12,0), new Vector2(0.75f,16),wallColor,true,world.transform);
        Block("RockWest", new Vector2(-4,2), new Vector2(1.5f,1.25f),wallColor,true,world.transform);
        Block("RockSouth", new Vector2(0,-3), new Vector2(2,1),wallColor,true,world.transform);
        Block("TreeEast", new Vector2(6,3), new Vector2(1.25f,2),new Color32(39,104,68,255),true,world.transform);
        Block("TreeWest", new Vector2(-6,-4), new Vector2(1.25f,2),new Color32(39,104,68,255),true,world.transform);
        var player = Actor("Player", new Vector2(-2,0),heroSprite,Faction.Player,server);
        player.gameObject.AddComponent<PlayerController>().Configure(server);
        var wolf = Actor("Wolf",new Vector2(3,0),wolfSprite,Faction.Wolf,server);
        wolf.gameObject.AddComponent<WolfBrain>().Configure(player,server,new[] { new Vector2(3,0),new Vector2(5,0),new Vector2(5,-2),new Vector2(3,-2) });
        var cameraObject = new GameObject("Main Camera"); cameraObject.tag = "MainCamera";
        var camera = cameraObject.AddComponent<Camera>(); camera.orthographic = true; camera.orthographicSize = 5;
        camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color32(22,36,34,255);
        cameraObject.transform.position = new Vector3(-2,0,-10);
        cameraObject.AddComponent<AudioListener>(); cameraObject.AddComponent<CameraFollow>().Configure(player.transform);
        var session = new GameObject("GameSession").AddComponent<GameSession>(); session.Configure(player,wolf);
        BuildHud(session);
        player.gameObject.SetActive(true); wolf.gameObject.SetActive(true);
        EditorSceneManager.SaveScene(scene,ScenePath);
        var entries = EditorBuildSettings.scenes.Where(x=>x.path!=ScenePath).ToList();
        entries.Insert(0,new EditorBuildSettingsScene(ScenePath,true)); EditorBuildSettings.scenes = entries.ToArray();
        AssetDatabase.SaveAssets();
        return $"Created {ScenePath}; {scene.rootCount} root objects; kept existing build scenes.";
    }

    private static void SetLayer(int index,string name)
    {
        var settings = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/TagManager.asset")[0]);
        var layer = settings.FindProperty("layers").GetArrayElementAtIndex(index);
        if (!string.IsNullOrEmpty(layer.stringValue) && layer.stringValue != name) throw new InvalidOperationException($"Layer {index} already occupied.");
        layer.stringValue = name; settings.ApplyModifiedProperties();
    }

    private static ActorHealth Actor(string name,Vector2 position,Sprite art,Faction faction,OfflineAuthority server)
    {
        var go = new GameObject(name); go.SetActive(false); go.layer = 9; go.transform.position = position;
        var renderer = go.AddComponent<SpriteRenderer>(); renderer.sprite = art; renderer.sharedMaterial = spriteMaterial;
        var body = go.AddComponent<Rigidbody2D>(); body.gravityScale = 0; body.constraints = RigidbodyConstraints2D.FreezeRotation;
        body.interpolation = RigidbodyInterpolation2D.Interpolate; body.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
        var collider = go.AddComponent<BoxCollider2D>(); collider.size = new Vector2(0.55f,0.65f); collider.offset = new Vector2(0,-0.1f);
        var health = go.AddComponent<ActorHealth>(); health.Configure(faction); go.AddComponent<ActorMotor>();
        var marker = Block("Attack",Vector2.zero,Vector2.one,new Color(1,0.85f,0.35f,0.7f),false,go.transform).GetComponent<SpriteRenderer>();
        marker.enabled = false; go.AddComponent<ActorVisual>().Configure(server,marker);
        return health;
    }

    private static GameObject Block(string name,Vector2 position,Vector2 size,Color color,bool collision,Transform parent,int order = 0)
    {
        var go = new GameObject(name); go.transform.SetParent(parent,false); go.transform.localPosition = position; go.transform.localScale = new Vector3(size.x,size.y,1);
        var sprite = go.AddComponent<SpriteRenderer>(); sprite.sprite = square; sprite.sharedMaterial = spriteMaterial; sprite.color = color; sprite.sortingOrder = order;
        if (collision) { go.layer = 8; go.AddComponent<BoxCollider2D>(); }
        return go;
    }

    private static Sprite PixelSprite(string name,string[] rows,Color[] colors,string keys,int ppu)
    {
        string path = $"Assets/Mmorpg/Art/{name}.png";
        if (File.Exists(path)) return AssetDatabase.LoadAssetAtPath<Sprite>(path);
        var texture = new Texture2D(rows[0].Length,rows.Length,TextureFormat.RGBA32,false);
        for(int y=0;y<rows.Length;y++) for(int x=0;x<rows[0].Length;x++)
        { int index=keys.IndexOf(rows[y][x]); texture.SetPixel(x,rows.Length-y-1,index<0?Color.clear:colors[index]); }
        texture.Apply(); File.WriteAllBytes(path,texture.EncodeToPNG()); UnityEngine.Object.DestroyImmediate(texture);
        AssetDatabase.ImportAsset(path);
        var importer = (TextureImporter)AssetImporter.GetAtPath(path); importer.textureType = TextureImporterType.Sprite;
        importer.spritePixelsPerUnit = ppu; importer.filterMode = FilterMode.Point; importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.mipmapEnabled = false; importer.SaveAndReimport(); return AssetDatabase.LoadAssetAtPath<Sprite>(path);
    }

    private static RectTransform Rect(string name,Transform parent,Vector2 anchor,Vector2 position,Vector2 size)
    {
        var go = new GameObject(name,typeof(RectTransform)); var rect = (RectTransform)go.transform; rect.SetParent(parent,false);
        rect.anchorMin = rect.anchorMax = anchor; rect.pivot = anchor; rect.anchoredPosition = position; rect.sizeDelta = size; return rect;
    }
    private static TMP_Text Label(string name,Transform parent,Vector2 anchor,Vector2 position,Vector2 size,string text,int fontSize)
    {
        var rect = Rect(name,parent,anchor,position,size); var label = rect.gameObject.AddComponent<TextMeshProUGUI>();
        label.font = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        label.text = text; label.fontSize = fontSize; label.color = new Color32(236,242,224,255); label.raycastTarget = false; return label;
    }
    private static void BuildHud(GameSession session)
    {
        var canvasObject = new GameObject("HUD",typeof(RectTransform),typeof(Canvas),typeof(UnityEngine.UI.CanvasScaler));
        canvasObject.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
        var scaler = canvasObject.GetComponent<UnityEngine.UI.CanvasScaler>(); scaler.uiScaleMode = UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(960,540); scaler.matchWidthOrHeight = 0.5f;
        var background = Rect("HealthBackground",canvasObject.transform,Vector2.up,new Vector2(24,-56),new Vector2(250,18));
        var bg = background.gameObject.AddComponent<UnityEngine.UI.Image>(); bg.color = new Color32(14,22,26,245); bg.raycastTarget = false;
        var fillRect = Rect("HealthFill",background,Vector2.up,Vector2.zero,new Vector2(250,18));
        var fill = fillRect.gameObject.AddComponent<UnityEngine.UI.Image>(); fill.sprite = square; fill.type = UnityEngine.UI.Image.Type.Filled;
        fill.fillMethod = UnityEngine.UI.Image.FillMethod.Horizontal; fill.color = new Color32(213,75,76,255); fill.raycastTarget = false;
        var health = Label("HealthText",canvasObject.transform,Vector2.up,new Vector2(24,-24),new Vector2(250,28),"VIDA",20);
        var status = Label("Status",canvasObject.transform,Vector2.one,new Vector2(-24,-24),new Vector2(320,90),"CLAREIRA OFFLINE",20);
        status.alignment = TextAlignmentOptions.TopRight;
        Label("Controls",canvasObject.transform,Vector2.zero,new Vector2(24,18),new Vector2(900,36),"WASD / Setas: mover     J / Clique: atacar     Espaco / Shift: esquivar     R: reiniciar",16);
        canvasObject.AddComponent<HealthHud>().Configure(session,fill,health,status);
    }
}
