using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using Newtonsoft.Json.Linq;
using UnityEngine.Tilemaps;

public static class IntegrateArt06B3
{
    private const string Art="Assets/Mmorpg/Art/";
    private const string ScenePath="Assets/Mmorpg/Scenes/Marco06B3Art.unity";
    [Serializable] private sealed class Entry {public string name,output,actor; public float[] pivot;}
    private static Dictionary<string,Sprite> sprites;
    private static Entry[] ReadManifest()=>JObject.Parse(File.ReadAllText(Art+"Processed/manifest.json"))["entries"].Select(e=>new Entry{name=(string)e["name"],output=(string)e["output"],actor=(string)e["actor"],pivot=e["pivot"].ToObject<float[]>()}).ToArray();
    private static void Load()=>sprites=ReadManifest().ToDictionary(e=>e.name,e=>AssetDatabase.LoadAssetAtPath<Sprite>(e.output));
    private static Sprite Get(string name)=>sprites.TryGetValue(name,out var sprite)?sprite:null;
    public static string Import()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play");
        AssetDatabase.Refresh();var entries=ReadManifest();
        AssetDatabase.StartAssetEditing();
        try {foreach(var e in entries)
        {
            var importer=AssetImporter.GetAtPath(e.output) as TextureImporter;
            if(importer==null)throw new InvalidDataException(e.output);
            importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Single;
            importer.spritePixelsPerUnit=32;importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;
            importer.mipmapEnabled=false;importer.wrapMode=TextureWrapMode.Clamp;importer.alphaIsTransparency=true;importer.maxTextureSize=512;
            var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteAlignment=(int)SpriteAlignment.Custom;settings.spritePivot=new Vector2(e.pivot[0],e.pivot[1]);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        }} finally {AssetDatabase.StopAssetEditing();}
        AssetDatabase.Refresh();Load();Directory.CreateDirectory(Art+"Animations");Directory.CreateDirectory(Art+"Prefabs");
        foreach(string kind in new[]{"Hero","Wolf","Spider","Golem"})
        {
            var path=Art+"Animations/"+kind+".asset";var set=AssetDatabase.LoadAssetAtPath<GameplaySpriteSet>(path);
            if(set==null){set=ScriptableObject.CreateInstance<GameplaySpriteSet>();AssetDatabase.CreateAsset(set,path);}
            Func<string,Sprite[]> poses=action=>new[]{"S","W","N","E"}.Select(d=>Get(kind+"_"+action+"_"+d+"_0")).ToArray();
            set.idle=poses("idle");set.walkA=poses("walk");set.walkB=kind=="Hero"?new[]{"S","W","N","E"}.Select(d=>Get("Hero_walk_"+d+"_1")).ToArray():set.idle;
            set.attackA=poses("attack");set.attackB=kind=="Hero"?new[]{"S","W","N","E"}.Select(d=>Get("Hero_attack_"+d+"_1")).ToArray():set.attackA;
            set.dodge=poses("dodge");set.hurt=poses("hurt");set.death=Array.Empty<Sprite>();set.walkFps=kind=="Golem"?4:8;EditorUtility.SetDirty(set);
            MakePrefab(kind=="Hero"?"PlayerVisual":"Enemy_"+kind+"_Visual",set.idle[0],set);
        }
        foreach(string kind in new[]{"Healer","Hunter","Smith","Scholar"})MakePrefab("NPC_"+kind+"_Visual",Get(kind+"_idle_S_0"));
        AssetDatabase.SaveAssets();return "Imported "+entries.Length+" individually normalized frames at 32 PPU; sprite sets and visual-only prefabs saved.";
    }
    private static void MakePrefab(string name,Sprite sprite,GameplaySpriteSet set=null)
    {
        var path=Art+"Prefabs/"+name+".prefab";
        // Existing generated prefab references stay stable when this authoring step repeats.
        var go=new GameObject(name);var sr=go.AddComponent<SpriteRenderer>();sr.sprite=sprite;
        sr.sharedMaterial=AssetDatabase.LoadAssetAtPath<Material>(Art+"PlaceholderSprite.mat");
        if(set!=null)go.AddComponent<SpriteVisualDefinition>().Configure(set,sr);
        foreach(string point in new[]{"Effects","GroundAnchor","EquipmentAnchor"})new GameObject(point).transform.SetParent(go.transform,false);
        if(name=="PlayerVisual")
        {
            var hand=go.transform.Find("EquipmentAnchor");hand.localPosition=new Vector3(-.35f,-.05f,0);hand.localRotation=Quaternion.Euler(0,0,-90);
            var blade=new GameObject("EquippedSword").AddComponent<SpriteRenderer>();blade.transform.SetParent(hand,false);blade.sprite=Get("Sword");blade.sharedMaterial=sr.sharedMaterial;blade.sortingOrder=1;blade.transform.localRotation=Quaternion.Euler(0,0,-Mathf.Atan2(41,51)*Mathf.Rad2Deg);blade.transform.localScale=Vector3.one*(64f/new Vector2(51,41).magnitude);
        }
        PrefabUtility.SaveAsPrefabAsset(go,path);UnityEngine.Object.DestroyImmediate(go);
    }
    public static string CreateScene()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play");
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(scene.path!="Assets/Mmorpg/Scenes/Marco06B2World.unity"||scene.isDirty)throw new InvalidOperationException("Clean saved B2 scene required");
        if(File.Exists(ScenePath))throw new IOException("Refusing to overwrite existing scene: "+ScenePath);
        EditorSceneManager.SaveScene(scene,ScenePath,true);EditorSceneManager.OpenScene(ScenePath);return "Created isolated B3 art scene; B2 preserved.";
    }
    private static void RequireScene(){if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=ScenePath)throw new InvalidOperationException("B3 outside Play required");Load();}
    private static void Save(){EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());AssetDatabase.SaveAssets();}
    public static string Player()
    {
        RequireScene();var p=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;Bind(p,"Hero");
        // Preserve the exact SwordSwing physics and sole equipped blade; only replace art.
        var blade=p.transform.Find("SwordHand/EquippedSword");var renderer=blade.GetComponent<SpriteRenderer>();
        var importer=(TextureImporter)AssetImporter.GetAtPath(Art+"Processed/VFX/Sword.png");var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteAlignment=(int)SpriteAlignment.Custom;settings.spritePivot=new Vector2(31/80f,35/80f);importer.SetTextureSettings(settings);importer.SaveAndReimport();
        renderer.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Processed/VFX/Sword.png");blade.localRotation=Quaternion.Euler(0,0,-Mathf.Atan2(41,51)*Mathf.Rad2Deg);blade.localScale=Vector3.one*(64f/new Vector2(51,41).magnitude);
        var camera=Camera.main;
        if(UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline==null||!UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline.GetType().FullName.Contains("Universal"))throw new InvalidOperationException("URP expected");
        var pp=camera.GetComponent<PixelPerfectCamera>()??camera.gameObject.AddComponent<PixelPerfectCamera>();pp.assetsPPU=32;pp.refResolutionX=640;pp.refResolutionY=360;pp.cropFrame=PixelPerfectCamera.CropFrame.Windowbox;pp.gridSnapping=PixelPerfectCamera.GridSnapping.PixelSnapping;
        camera.allowHDR=camera.allowMSAA=camera.allowDynamicResolution=false;camera.orthographicSize=5.625f;camera.GetComponent<CameraFollow>().ConfigurePixelGrid(32);
        var data=camera.GetUniversalAdditionalCameraData();data.antialiasing=AntialiasingMode.None;
        Save();return "Player 4 native headings, two-pose walk, attack stances, dodge; separate existing physical sword; URP 640x360 @32 PPU.";
    }
    private static void Bind(ActorHealth actor,string kind)
    {
        var old=actor.GetComponent<DirectionalSpriteAnimation>();if(old!=null)old.enabled=false;
        var sr=actor.GetComponent<SpriteRenderer>();var set=AssetDatabase.LoadAssetAtPath<GameplaySpriteSet>(Art+"Animations/"+kind+".asset");sr.sprite=set.idle[0];sr.color=Color.white;
        var anim=actor.GetComponent<GameplaySpriteAnimator>()??actor.gameObject.AddComponent<GameplaySpriteAnimator>();anim.Configure(set,actor.GetComponent<ActorMotor>(),actor,sr,actor.GetComponent<SwordSwing>());
        actor.GetComponent<ActorVisual>()?.ConfigurePreparedArt(kind=="Hero"?.5625f:.3125f);
    }
    public static string Wolf()
    {
        RequireScene();foreach(var wolf in UnityEngine.Object.FindObjectsByType<WolfBrain>())Bind(wolf.GetComponent<ActorHealth>(),"Wolf");
        foreach(var impact in UnityEngine.Object.FindObjectsByType<SheetImpactFeedback>())
        {
            var so=new SerializedObject(impact);so.FindProperty("frames").arraySize=4;for(int i=0;i<4;i++)so.FindProperty("frames").GetArrayElementAtIndex(i).objectReferenceValue=Get("Impact_"+i);so.ApplyModifiedPropertiesWithoutUndo();
        }
        Save();return "Wolf presentation observes existing windup/charge/damage/death; impact only on HitConfirmed. Native death unavailable, explicit fade fallback.";
    }
    public static string InspectWorld()
    {
        var s=new System.Text.StringBuilder();
        foreach(var sr in UnityEngine.Object.FindObjectsByType<SpriteRenderer>().Where(s=>s.name.StartsWith("Provided")||s.name.StartsWith("Mira")||s.name.StartsWith("Orin")))
        {var c=sr.GetComponentInParent<Collider2D>();s.AppendLine(sr.name+" parent="+sr.transform.parent?.name+" pos="+sr.transform.position+" scale="+sr.transform.lossyScale+" collider="+c?.bounds);}
        foreach(var image in UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Image>(FindObjectsInactive.Include))s.AppendLine("UI "+image.name+" sprite="+(image.sprite!=null?image.sprite.name:"none")+" color="+image.color);
        foreach(var text in UnityEngine.Object.FindObjectsByType<TMPro.TMP_Text>(FindObjectsInactive.Include))s.AppendLine("Text "+text.name+" world="+(text is TMPro.TextMeshPro)+" text="+text.text.Substring(0,Math.Min(50,text.text.Length)));
        return s.ToString();
    }
    private static void ImportSimple(string path,Vector4 border=default)
    {
        AssetDatabase.ImportAsset(path);var imp=(TextureImporter)AssetImporter.GetAtPath(path);
        imp.textureType=TextureImporterType.Sprite;imp.spriteImportMode=SpriteImportMode.Single;imp.spritePixelsPerUnit=32;imp.spriteBorder=border;
        imp.filterMode=FilterMode.Point;imp.textureCompression=TextureImporterCompression.Uncompressed;imp.mipmapEnabled=false;imp.alphaIsTransparency=true;imp.wrapMode=TextureWrapMode.Clamp;imp.maxTextureSize=512;imp.SaveAndReimport();
    }
    public static string Environment()
    {
        RequireScene();AssetDatabase.Refresh();
        foreach(string path in Directory.GetFiles(Art+"Tilesets","*.png"))ImportSimple(path.Replace('\\','/'));
        ImportSimple(Art+"Processed/VFX/GroundShadow.png");ImportSimple(Art+"Processed/UI/Panel.png",new Vector4(4,4,4,4));
        var map=UnityEngine.Object.FindObjectsByType<Tilemap>().Single(t=>t.name=="Ground");
        var kinds=new Dictionary<Vector3Int,string>();foreach(var p in map.cellBounds.allPositionsWithin)if(map.GetTile(p)!=null)kinds[p]=map.GetTile(p).name;
        var tiles=new Dictionary<string,Tile>();
        Func<string,Tile> tile=key=>{
            if(tiles.TryGetValue(key,out var found))return found;
            string path=Art+"Tilesets/"+key+".asset";found=AssetDatabase.LoadAssetAtPath<Tile>(path);
            if(found==null){found=ScriptableObject.CreateInstance<Tile>();AssetDatabase.CreateAsset(found,path);}
            found.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Tilesets/"+key+".png");found.transform=Matrix4x4.identity;found.colliderType=Tile.ColliderType.None;found.color=Color.white;EditorUtility.SetDirty(found);tiles[key]=found;return found;
        };
        Func<Vector3Int,bool> pathAt=p=>kinds.TryGetValue(p,out var n)&&(n.EndsWith("5")||n.StartsWith("Path_"));
        foreach(var pair in kinds)
        {
            var p=pair.Key;string name=pair.Value;int v=Math.Abs(p.x*73+p.y*127)%4;string key;
            if(pathAt(p))
            {
                int mask=(!pathAt(p+Vector3Int.left)?1:0)|(!pathAt(p+Vector3Int.right)?2:0)|(!pathAt(p+Vector3Int.down)?4:0)|(!pathAt(p+Vector3Int.up)?8:0);key="Path_"+mask;
            }
            else {string kind=name.StartsWith("Mine_")||name.EndsWith("2")&&!name.Contains("_")?"Mine":name.StartsWith("Marsh_")||name.EndsWith("3")&&!name.Contains("_")?"Marsh":name.StartsWith("Ruin_")||name.EndsWith("4")&&!name.Contains("_")?"Ruin":p.x>=0?"Forest":"Grass";key=kind+"_"+v;}
            map.SetTile(p,tile(key));map.SetTransformMatrix(p,Matrix4x4.identity);map.SetColor(p,Color.white);
        }
        map.RefreshAllTiles();
        var player=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
        foreach(var sr in UnityEngine.Object.FindObjectsByType<SpriteRenderer>())
        {
            string prop=sr.name=="ProvidedHouse"?"House":sr.name=="ProvidedTree"?"Tree":sr.name=="ProvidedRock"?"Rock":sr.name=="ProvidedBush"?"Bush":sr.name=="ProvidedPillar"?"Pillar":null;
            if(prop!=null)
            {
                var root=sr.transform.parent;var collider=root.GetComponent<Collider2D>();if(collider==null)continue;
                var footprint=collider.bounds;float foot=footprint.min.y;sr.sprite=Get(prop);sr.color=Color.white;
                var scale=root.lossyScale;sr.transform.localScale=new Vector3(1/scale.x,1/scale.y,1);sr.transform.position=new Vector3(root.position.x,foot,0);
                var propAnchor=root.Find("ArtGroundAnchor");if(propAnchor==null){propAnchor=new GameObject("ArtGroundAnchor").transform;propAnchor.SetParent(root,false);}propAnchor.position=new Vector3(root.position.x,foot,0);
                sr.GetComponent<WorldArtSorting>().Configure(sr,propAnchor);
                if(prop=="Tree"&&collider is BoxCollider2D box)
                {
                    // Preserve authored trunk ground position, remove canopy-sized blockage.
                    box.offset=new Vector2(0,(foot+.14f-root.position.y)/scale.y);box.size=new Vector2(.48f/scale.x,.28f/scale.y);
                }
                // Small rocks use their existing footprint scale uniformly; no stretching.
                if(prop=="Rock") {float k=Mathf.Clamp(footprint.size.x/(59*.6f/32),.8f,1.8f);sr.transform.localScale*=k;}
                continue;
            }
            if(sr.GetComponent<ActorHealth>()!=null)continue;
            string kind=sr.name.StartsWith("Mira")||sr.name.StartsWith("Helena")||sr.name.StartsWith("Selka")||sr.name.StartsWith("Nera")?"Healer":sr.name.StartsWith("Orin")&&!sr.name.Contains("House")?"Hunter":sr.name.StartsWith("Brann")||sr.name.StartsWith("Dorin")?"Smith":sr.name.StartsWith("Soren")||sr.name.StartsWith("Tessa")?"Scholar":null;
            if(kind==null)continue;sr.sprite=Get(kind+"_idle_S_0");sr.color=Color.white;
            var anchor=sr.transform.Find("ArtGroundAnchor");if(anchor==null){anchor=new GameObject("ArtGroundAnchor").transform;anchor.SetParent(sr.transform,false);}anchor.localPosition=Vector3.down*.5625f;
            (sr.GetComponent<WorldArtSorting>()??sr.gameObject.AddComponent<WorldArtSorting>()).Configure(sr,anchor);
        }
        foreach(var actor in UnityEngine.Object.FindObjectsByType<GameplaySpriteAnimator>())
        {
            var sr=actor.GetComponent<SpriteRenderer>();actor.GetComponent<ActorVisual>()?.ConfigurePreparedArt(actor.GetComponent<SwordSwing>()!=null?.5625f:.3125f);
            if(actor.transform.Find("GroundShadow")!=null)continue;
            var shadow=new GameObject("GroundShadow").AddComponent<SpriteRenderer>();shadow.transform.SetParent(actor.transform,false);shadow.transform.localPosition=Vector3.down*(actor.GetComponent<SwordSwing>()!=null?.53f:.28f);shadow.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Processed/VFX/GroundShadow.png");shadow.sharedMaterial=sr.sharedMaterial;shadow.gameObject.AddComponent<SpriteGroundShadow>().Configure(sr,shadow);
        }
        foreach(var text in UnityEngine.Object.FindObjectsByType<TMPro.TextMeshPro>(FindObjectsInactive.Include))
        {
            // Region/navigation copy is already available in the HUD. Keep contextual
            // NPC/object names near the player instead of painting debug text on terrain.
            if(text.name=="TrainingInstructions"||text.text==text.text.ToUpperInvariant()||text.text.Contains("Passagem")||text.text.Contains("→")||text.text.Contains("↑")){text.enabled=false;continue;}
            text.fontSize=2.4f;text.color=new Color(.91f,.88f,.72f);text.textWrappingMode=TMPro.TextWrappingModes.NoWrap;
            var proximity=text.GetComponent<WorldLabelProximity>()??text.gameObject.AddComponent<WorldLabelProximity>();proximity.Configure(text,player.transform);
        }
        // All serialized gameplay references and region cells remain in place.
        Save();return "Replaced "+kinds.Count+" floor cells, 40 tile library, prepared props/NPCs, foot sorting, trunk-only collisions and contextual world labels.";
    }
    public static string Interface()
    {
        RequireScene();var panel=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Processed/UI/Panel.png");
        foreach(var image in UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Image>(FindObjectsInactive.Include))
        {
            if(image.name.StartsWith("SkillSlot")||image.name.Contains("Backplate")||image.name=="JourneyJournal"||image.name=="ExplorationDialogue"||image.name=="ActionSecondaryPanel")
            {image.sprite=panel;image.type=UnityEngine.UI.Image.Type.Sliced;image.pixelsPerUnitMultiplier=3.125f;image.color=Color.white;}
            if(image.name=="Cooldown")image.color=new Color(.16f,.18f,.18f,.78f);
            if(image.name=="HealthBackground"){image.sprite=panel;image.type=UnityEngine.UI.Image.Type.Sliced;image.pixelsPerUnitMultiplier=3.125f;image.color=Color.white;}
            if(image.name=="HealthFill")image.color=new Color(.69f,.22f,.22f);
            if(image.name=="AbilityIcon")
            {string index=image.sprite.name.Substring(image.sprite.name.LastIndexOf('_')+1);image.sprite=Get("Icon_"+index);image.preserveAspect=true;}
        }
        foreach(var text in UnityEngine.Object.FindObjectsByType<TMPro.TextMeshProUGUI>(FindObjectsInactive.Include))
        {
            if(text.name=="Caption")continue;
            text.color=new Color(.94f,.91f,.8f);
            if(text.name=="JourneyDialogue")
            {var r=text.rectTransform;r.anchorMin=r.anchorMax=r.pivot=new Vector2(.5f,1);r.anchoredPosition=new Vector2(0,-65);r.sizeDelta=new Vector2(760,46);text.fontSize=14;text.alignment=TMPro.TextAlignmentOptions.Center;}
            if(text.name=="ExplorationContext")
            {var r=text.rectTransform;r.anchorMin=r.anchorMax=r.pivot=new Vector2(.5f,0);r.anchoredPosition=new Vector2(0,125);r.sizeDelta=new Vector2(700,50);text.fontSize=14;text.alignment=TMPro.TextAlignmentOptions.Center;}
            if(text.name=="CombatFeedback")
            {var r=text.rectTransform;r.anchorMin=r.anchorMax=r.pivot=new Vector2(.5f,0);r.anchoredPosition=new Vector2(0,100);r.sizeDelta=new Vector2(700,30);text.fontSize=14;text.alignment=TMPro.TextAlignmentOptions.Center;}
        }
        Save();return "Existing uGUI panels styled with bronze pixel borders, charcoal/ivory palette, normalized icons, messages moved clear of combat; no UI logic or scaler change.";
    }
    public static string Finishing()
    {
        RequireScene();var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var player=journey.Player;var body=player.GetComponent<SpriteRenderer>();
        player.GetComponent<PlayerCombatFeedback>().ConfigurePreparedVfx();
        player.GetComponent<SwordSwing>().ConfigureArtGrips(new[]{new Vector2(-.35f,-.05f),new Vector2(-.29f,0),new Vector2(.33f,-.04f),new Vector2(.31f,-.03f)});
        ImportSimple(Art+"Processed/Environment/TrainingDummy.png");
        var training=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();if(training!=null)
        {
            var sr=training.GetComponent<SpriteRenderer>();if(sr==null)sr=training.gameObject.AddComponent<SpriteRenderer>();sr.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Processed/Environment/TrainingDummy.png");sr.sharedMaterial=body.sharedMaterial;sr.color=Color.white;sr.sortingOrder=140;
            foreach(string part in new[]{"Post","StrawBody","Head","Arms"}){var child=training.transform.Find(part);if(child!=null)child.GetComponent<SpriteRenderer>().enabled=false;}
        }
        var root=GameObject.Find("Art06B3Effects")??new GameObject("Art06B3Effects");
        if(root.GetComponent<SwordPresentationEffects>()==null)
        {
            Func<string,SpriteRenderer> effect=name=>{var sr=new GameObject(name).AddComponent<SpriteRenderer>();sr.transform.SetParent(root.transform,false);sr.sharedMaterial=body.sharedMaterial;sr.enabled=false;return sr;};
            var slash=effect("SwordCut");slash.sprite=Get("Slash");slash.color=new Color(.8f,.9f,1,.65f);slash.transform.localScale=Vector3.one*.65f;
            var dust=effect("DodgeDust");root.AddComponent<SwordPresentationEffects>().Configure(player.GetComponent<SwordSwing>(),player,body,slash,dust,Enumerable.Range(0,3).Select(i=>Get("Dust_"+i)).ToArray());
            // Replace the old geometric slash, not an additional second trail.
            var feedback=player.GetComponent<PlayerCombatFeedback>();var serialized=new SerializedObject(feedback);var trail=serialized.FindProperty("trail").objectReferenceValue as LineRenderer;if(trail!=null)trail.forceRenderingOff=true;
        }
        foreach(var target in UnityEngine.Object.FindObjectsByType<ActionTargetVisual>())
        {
            target.ConfigureArt(Get("WeaknessReticle"),Get("HunterMark"));var so=new SerializedObject(target);var sr=so.FindProperty("indicator").objectReferenceValue as SpriteRenderer;sr.transform.localScale=Vector3.one;
        }
        // Legacy wolf/dummy weakness indicators share the same confirmed query.
        var js=new SerializedObject(journey);var legacy=js.FindProperty("markVisual").objectReferenceValue as SpriteRenderer;if(legacy!=null){legacy.sprite=null;}
        var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();if(dummy!=null){var ds=new SerializedObject(dummy);var mark=ds.FindProperty("mark").objectReferenceValue as SpriteRenderer;if(mark!=null)mark.sprite=null;}
        foreach(var node in UnityEngine.Object.FindObjectsByType<ExplorationNode>())
        {
            var so=new SerializedObject(node);var sr=so.FindProperty("visual").objectReferenceValue as SpriteRenderer;if(sr==null)continue;
            string id=node.SourceId;string key=id.Contains("herb")||id.Contains("moss")||id.Contains("seed")?"Herb":id.Contains("water")||id.Contains("crystal")?"Crystal":null;
            if(key!=null){sr.sprite=Get(key);sr.color=Color.white;var scale=sr.transform.parent!=null?sr.transform.parent.lossyScale:Vector3.one;sr.transform.localScale=new Vector3(1/scale.x,1/scale.y,1);}
        }
        foreach(var interaction in journey.Interactions)
        {
            var sr=interaction.GetComponent<SpriteRenderer>();if(sr==null)continue;
            if(interaction.Kind==Mmorpg.Runtime.InteractionKind.Trace){sr.sprite=Get("Corruption");sr.color=Color.white;sr.transform.localScale=Vector3.one;}
        }
        // A few non-blocking authored details in the initial village/forest pocket.
        if(GameObject.Find("Art06B3Details")==null)
        {
            var details=new GameObject("Art06B3Details");
            var names=new[]{"Flowers","Flowers","Bush","Stump","Barrel","Barrel","Flowers","Bush"};
            var positions=new[]{new Vector2(-11,2),new Vector2(-10,-3),new Vector2(-5,-6),new Vector2(2,-5),new Vector2(-11,4),new Vector2(-1,4),new Vector2(4,5.5f),new Vector2(7,5)};
            for(int i=0;i<names.Length;i++){var sr=new GameObject(names[i]).AddComponent<SpriteRenderer>();sr.transform.SetParent(details.transform,false);sr.transform.position=positions[i];sr.sprite=Get(names[i]);sr.sharedMaterial=body.sharedMaterial;sr.gameObject.AddComponent<WorldArtSorting>().Configure(sr,sr.transform);}
        }
        // Bat remains a visual prefab: this does not introduce or claim a bat AI.
        string batPath=Art+"Prefabs/Enemy_CrystalBat_Visual.prefab";
        var bat=new GameObject("Enemy_CrystalBat_Visual");var batRenderer=bat.AddComponent<SpriteRenderer>();batRenderer.sprite=Get("Bat_flight_S_0");bat.AddComponent<VisualSpriteLoop>().Configure(batRenderer,new[]{Get("Bat_flight_S_0"),Get("Bat_flight_S_1")});
        var projected=new GameObject("GroundShadow").AddComponent<SpriteRenderer>();projected.transform.SetParent(bat.transform,false);projected.transform.localPosition=Vector3.down*.8f;projected.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Processed/VFX/GroundShadow.png");projected.sortingOrder=-1;
        PrefabUtility.SaveAsPrefabAsset(bat,batPath);UnityEngine.Object.DestroyImmediate(bat);
        Save();return "Confirmed-state slash/dust and weakness/hunter art; eight small details; resource sprites; standalone two-pose bat flight visual prefab, no new gameplay.";
    }
    public static string FinalPolish()
    {
        RequireScene();var material=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player.GetComponent<SpriteRenderer>().sharedMaterial;
        foreach(var map in UnityEngine.Object.FindObjectsByType<Tilemap>())
        {
            if(map.name!="Ground"&&map.name!="SolidBoundaries"){map.GetComponent<TilemapRenderer>().enabled=false;continue;}
            if(map.name!="SolidBoundaries")continue;
            string path=Art+"Tilesets/Boundary.asset";var edge=AssetDatabase.LoadAssetAtPath<Tile>(path);
            if(edge==null){edge=ScriptableObject.CreateInstance<Tile>();AssetDatabase.CreateAsset(edge,path);}
            edge.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Tilesets/Mine_0.png");edge.colliderType=Tile.ColliderType.Grid;edge.transform=Matrix4x4.identity;edge.color=new Color(.6f,.7f,.64f);EditorUtility.SetDirty(edge);
            foreach(var p in map.cellBounds.allPositionsWithin)if(map.GetTile(p)!=null){map.SetTile(p,edge);map.SetTransformMatrix(p,Matrix4x4.identity);}map.RefreshAllTiles();
        }
        foreach(string name in new[]{"VillageGround","WalkingPath","VillageLane"}){var go=GameObject.Find(name);if(go!=null)go.GetComponent<SpriteRenderer>().enabled=false;}
        foreach(string name in new[]{"ForestHedgeNorth","ForestHedgeSouth"})
        {
            var go=GameObject.Find(name);if(go==null||go.transform.Find("PreparedHedge")!=null)continue;
            go.GetComponent<SpriteRenderer>().enabled=false;var bounds=go.GetComponent<Collider2D>().bounds;
            var group=new GameObject("PreparedHedge").transform;group.SetParent(go.transform,false);
            for(float y=bounds.min.y;y<bounds.max.y;y+=.8f)
            {var sr=new GameObject("HedgeBush").AddComponent<SpriteRenderer>();sr.transform.SetParent(group,false);sr.transform.localScale=new Vector3(1/go.transform.lossyScale.x,1/go.transform.lossyScale.y,1);sr.transform.position=new Vector3(bounds.center.x,y,0);sr.sprite=Get("Bush");sr.sharedMaterial=material;sr.gameObject.AddComponent<WorldArtSorting>().Configure(sr,sr.transform);}
        }
        // Correct source NPC aspect ratio in a child; authored root/collider untouched.
        foreach(var node in UnityEngine.Object.FindObjectsByType<ExplorationNode>())
        {
            var so=new SerializedObject(node);if(so.FindProperty("kind").enumValueIndex!=(int)ExplorationNodeKind.Npc)continue;
            if(node.transform.Find("PreparedNpcVisual")!=null)continue;
            var original=node.GetComponent<SpriteRenderer>();if(original==null)continue;
            var child=new GameObject("PreparedNpcVisual").AddComponent<SpriteRenderer>();child.transform.SetParent(node.transform,false);child.transform.localScale=new Vector3(1/node.transform.lossyScale.x,1/node.transform.lossyScale.y,1);child.sprite=original.sprite;child.sharedMaterial=original.sharedMaterial;child.color=Color.white;original.enabled=false;
            var anchor=new GameObject("PreparedNpcGround").transform;anchor.SetParent(node.transform,false);anchor.position=node.transform.position+Vector3.down*.5625f;child.gameObject.AddComponent<WorldArtSorting>().Configure(child,anchor);so.FindProperty("visual").objectReferenceValue=child;so.ApplyModifiedPropertiesWithoutUndo();
        }
        foreach(var i in UnityEngine.Object.FindAnyObjectByType<JourneySession>().Interactions)
        {
            var sr=i.GetComponent<SpriteRenderer>();if(sr==null)continue;
            if(i.Kind==InteractionKind.NoticeBoard)
            {
                sr.enabled=false;
                if(i.transform.Find("PreparedNoticeVisual")==null)
                {var sign=new GameObject("PreparedNoticeVisual").AddComponent<SpriteRenderer>();sign.transform.SetParent(i.transform,false);sign.transform.localScale=new Vector3(1/i.transform.lossyScale.x,1/i.transform.lossyScale.y,1);sign.sprite=Get("Sign");sign.sharedMaterial=sr.sharedMaterial;sign.gameObject.AddComponent<WorldArtSorting>().Configure(sign,i.transform);}
            }
            if(i.Kind==InteractionKind.Sample){sr.sprite=Get("Corruption");sr.color=Color.white;}
        }
        Camera.main.backgroundColor=new Color(.07f,.12f,.105f);
        Save();return "Legacy backplates hidden, boundary tile collision topology preserved, hedges use bushes, NPC aspect normalized in children, noticeboard/sample prepared.";
    }
    public static string AuditFinal()
    {
        RequireScene();var entries=ReadManifest();var errors=new List<string>();
        foreach(var e in entries)
        {var i=(TextureImporter)AssetImporter.GetAtPath(e.output);if(i.spritePixelsPerUnit!=32||i.filterMode!=FilterMode.Point||i.mipmapEnabled||i.textureCompression!=TextureImporterCompression.Uncompressed)errors.Add(e.name);}
        var camera=Camera.main.GetComponent<PixelPerfectCamera>();var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
        var prefabs=AssetDatabase.FindAssets("t:Prefab",new[]{Art+"Prefabs"});
        var bat=PrefabUtility.LoadPrefabContents(Art+"Prefabs/Enemy_CrystalBat_Visual.prefab");foreach(var sr in bat.GetComponentsInChildren<SpriteRenderer>())sr.sharedMaterial=actor.GetComponent<SpriteRenderer>().sharedMaterial;PrefabUtility.SaveAsPrefabAsset(bat,Art+"Prefabs/Enemy_CrystalBat_Visual.prefab");PrefabUtility.UnloadPrefabContents(bat);
        var result=new JObject{["scene"]=ScenePath,["frames"]=entries.Length,["importErrors"]=new JArray(errors),["visualPrefabs"]=prefabs.Length,["cameraPpu"]=camera.assetsPPU,["referenceWidth"]=camera.refResolutionX,["referenceHeight"]=camera.refResolutionY,["playerAnimator"]=actor.GetComponent<GameplaySpriteAnimator>()!=null,["legacyPlayerAnimationEnabled"]=actor.GetComponent<DirectionalSpriteAnimation>().enabled,["playerRootScale"]=actor.transform.localScale.ToString(),["saveDirectoryOverrideCleared"]=ExplorationWorld.ValidationDirectory==null,["persistenceFactoryCleared"]=JourneySession.PersistenceFactory==null};
        File.WriteAllText("Docs/Validation/Marco06B3/editor-art-audit.json",result.ToString());
        foreach(string path in new[]{"Assets/Docs/Validation/m06b3-before.png","Assets/Docs/Validation/Marco06B3/world-first.png"})
        {if(!File.Exists(path))continue;string target=path.Contains("before")?"Docs/Validation/Marco06B3/before.png":"Docs/Validation/Marco06B3/world-first.png";File.Copy(path,target,true);AssetDatabase.DeleteAsset(path);}
        AssetDatabase.SaveAssets();return result.ToString();
    }
}




