using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.U2D.Sprites;
using UnityEngine;
using UnityEngine.Tilemaps;
public static class IntegrateProvidedArt
{
    private const string Root="Assets/Mmorpg/Art/Provided06B2/";
    private static readonly List<SpriteRect> rects=new List<SpriteRect>();
    private static readonly Dictionary<string,Vector2[]> outlines=new Dictionary<string,Vector2[]>();
    private static readonly Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>();
    private static void Rect(string name,int x,int top,int width,int height,Vector2? pivot=null)
    {rects.Add(new SpriteRect{name=name,rect=new Rect(x,1086-top-height,width,height),alignment=SpriteAlignment.Custom,pivot=pivot??new Vector2(.5f,.5f),spriteID=GUID.Generate()});}
    private static void Sheet(string file,float ppu,Action layout)
    {
        string source="assets_para_usar/"+file+".png",path=Root+file+".png";
        if(File.Exists(path))throw new IOException("Refusing existing imported art: "+path);
        File.Copy(source,path);AssetDatabase.ImportAsset(path);
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;
        importer.spritePixelsPerUnit=ppu;importer.filterMode=FilterMode.Point;importer.mipmapEnabled=false;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.maxTextureSize=2048;importer.alphaIsTransparency=true;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.Tight;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        var factory=new SpriteDataProviderFactories();factory.Init();var provider=factory.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        var capability=provider.GetDataProvider<ISpriteFrameEditCapability>();
        if(capability==null||!capability.GetEditCapability().HasCapability(EEditCapability.CreateAndDeleteSprite)||!capability.GetEditCapability().HasCapability(EEditCapability.EditPivot))throw new InvalidOperationException("Importer cannot safely slice / edit pivots");
        rects.Clear();outlines.Clear();layout();provider.SetSpriteRects(rects.ToArray());
        var names=provider.GetDataProvider<ISpriteNameFileIdDataProvider>();if(names==null)throw new InvalidOperationException("Stable sprite identity provider absent");
        names.SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));
        if(outlines.Count>0)
        {
            var shapes=provider.GetDataProvider<ISpriteOutlineDataProvider>();if(shapes==null)throw new InvalidOperationException("Sprite outline provider absent");
            foreach(var r in rects)if(outlines.TryGetValue(r.name,out var polygon))shapes.SetOutlines(r.spriteID,new List<Vector2[]>{polygon});
        }
        provider.Apply();importer.SaveAndReimport();
        foreach(var sprite in AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>())sprites.Add(sprite.name,sprite);
    }
    public static string Apply()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play before integrating art");
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(scene.path!="Assets/Mmorpg/Scenes/Marco06B2World.unity"||scene.isDirty)throw new InvalidOperationException("Saved B2 scene required; preserve other changes");
        if(GameObject.Find("ProvidedArt06B2")!=null)throw new InvalidOperationException("Art integration already applied");
        Directory.CreateDirectory(Root);sprites.Clear();
        Sheet("personagem",128,()=>
        {
            for(int row=0;row<3;row++)for(int dir=0;dir<8;dir++)
            {
                string name="Hero_"+row+"_"+dir;Rect(name,dir*181+35,row*172,136,172,new Vector2(60/136f,82/172f));
                // Render-mesh outline excludes the sword already drawn in the locomotion
                // frame. PNG pixels stay intact; the separate blade owns the visible sweep.
                if(dir<4)outlines[name]=Polygon(136,172,new[]{new Vector2(20,172),new Vector2(136,172),new Vector2(136,0),new Vector2(43,0),new Vector2(43,68),new Vector2(22,82),new Vector2(12,109)});
                else if(dir>4)outlines[name]=Polygon(136,172,new[]{new Vector2(0,172),new Vector2(116,172),new Vector2(125,110),new Vector2(107,83),new Vector2(89,68),new Vector2(89,0),new Vector2(0,0)});
            }
        });
        Sheet("monstros",128,()=>
        {
            int[] columns={0,1,3,4,5,6,8,9};
            for(int row=0;row<3;row++)for(int dir=0;dir<8;dir++)
            {Rect("Wolf_"+row+"_"+dir,columns[dir]*144,row==0?0:128,144,128);Rect("Spider_"+row+"_"+dir,columns[dir]*144,row==0?518:648,144,130);}
        });
        Sheet("monstros_2",128,()=>{for(int row=0;row<3;row++)for(int dir=0;dir<8;dir++)Rect("Golem_"+row+"_"+dir,dir*181,row==0?0:130,181,130);});
        Sheet("npcs",128,()=>{Rect("Healer",0,40,112,192);Rect("Hunter",395,40,116,190);Rect("Smith",719,40,153,192);Rect("Scholar",1090,40,108,190);});
        Sheet("efeitos_habilidades_e_icones",128,()=>
        {
            Rect("Sword",16,42,96,96,new Vector2(27/96f,36/96f));
            for(int i=0;i<12;i++)Rect("Icon_"+i,12+i*118,985,108,100);
            Rect("Impact_0",48,150,115,103);Rect("Impact_1",170,143,136,110);Rect("Impact_2",308,138,141,115);Rect("Impact_3",444,138,150,115);
        });
        Sheet("cenarios",128,()=>
        {
            Rect("House",884,16,152,212);Rect("Tree",1031,0,126,159,new Vector2(.5f,.08f));Rect("Pine",1006,233,102,160,new Vector2(.5f,.08f));
            Rect("Rock",1070,536,59,69);Rect("Pillar",572,875,92,185,new Vector2(.5f,.12f));Rect("Bush",1190,159,109,65);
            Rect("GrassTile",26,36,64,64);Rect("PathTile",124,36,64,64);Rect("MineTile",22,472,64,64);Rect("RuinTile",21,882,64,64);Rect("MarshTile",128,693,64,64);
        });
        var story=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var player=story.Player;var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        foreach(var actor in UnityEngine.Object.FindObjectsByType<ActorHealth>())
        {
            string kind=actor==player?"Hero":actor.GetComponent<WolfBrain>()!=null?"Wolf":actor.GetComponent<SpatialCreatureBrain>()?.Kind==CreatureKind.Spider?"Spider":actor.GetComponent<SpatialCreatureBrain>()?.Kind==CreatureKind.Golem?"Golem":null;
            if(kind==null)continue;var sr=actor.GetComponent<SpriteRenderer>();sr.sprite=sprites[kind+"_0_0"];sr.color=Color.white;
            actor.gameObject.AddComponent<DirectionalSpriteAnimation>().Configure(actor.GetComponent<ActorMotor>(),actor,sr,Frames(kind),actor==player?player.GetComponent<SwordSwing>():null);
        }
        player.GetComponent<PlayerCombatFeedback>().ConfigureSheetArt();
        var sword=player.transform.Find("SwordHand/EquippedSword").GetComponent<SpriteRenderer>();sword.sprite=sprites["Sword"];
        sword.transform.localRotation=Quaternion.Euler(0,0,-Mathf.Atan2(41,51)*Mathf.Rad2Deg);sword.transform.localScale=Vector3.one*(128f/new Vector2(51,41).magnitude);
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();var all=canvas.GetComponentsInChildren<Transform>(true);
        int[] iconIndices={1,1,3,9,8,2};
        for(int index=0;index<6;index++)
        {
            var slot=all.First(t=>t.name=="SkillSlot"+index) as RectTransform;slot.sizeDelta=new Vector2(68,74);
            var cooldown=slot.Find("Cooldown") as RectTransform;cooldown.sizeDelta=slot.sizeDelta;
            var caption=slot.Find("Caption").GetComponent<TMP_Text>();caption.rectTransform.sizeDelta=new Vector2(64,26);caption.fontSize=10;
            var go=new GameObject("AbilityIcon",typeof(RectTransform),typeof(UnityEngine.UI.Image));var r=go.GetComponent<RectTransform>();r.SetParent(slot,false);r.anchorMin=r.anchorMax=r.pivot=Vector2.zero;r.anchoredPosition=new Vector2(15,32);r.sizeDelta=new Vector2(38,36);
            var icon=go.GetComponent<UnityEngine.UI.Image>();icon.sprite=sprites["Icon_"+iconIndices[index]];icon.preserveAspect=true;icon.raycastTarget=false;go.transform.SetSiblingIndex(1);
        }
        ((RectTransform)all.First(t=>t.name=="RpgSkillSlots")).sizeDelta=new Vector2(440,74);
        foreach(var sr in UnityEngine.Object.FindObjectsByType<SpriteRenderer>())
        {
            string name=sr.name;
            if(sr.GetComponent<ActorHealth>()!=null)continue;
            string npc=name.StartsWith("Mira")||name.StartsWith("Helena")||name.StartsWith("Selka")||name.StartsWith("Nera")?"Healer":name.StartsWith("Orin")?"Hunter":name.StartsWith("Brann")||name.StartsWith("Dorin")?"Smith":name.StartsWith("Soren")||name.StartsWith("Tessa")?"Scholar":null;
            if(npc!=null&&!name.Contains("House")){sr.sprite=sprites[npc];sr.color=Color.white;continue;}
            string prop=name.Contains("House")?"House":name.StartsWith("Tree")||name.StartsWith("Árvore")?"Tree":name.StartsWith("Rock")||name.StartsWith("Formação")?"Rock":name.StartsWith("Pilar")?"Pillar":name.StartsWith("Vegetação")?"Bush":null;
            if(prop!=null)ReplaceProp(sr,prop);
        }
        ReplaceGround();
        var marker=new GameObject("ProvidedArt06B2");var effect=new GameObject("SheetSwordImpact").AddComponent<SpriteRenderer>();effect.transform.SetParent(marker.transform,false);effect.sharedMaterial=player.GetComponent<SpriteRenderer>().sharedMaterial;effect.enabled=false;
        marker.AddComponent<SheetImpactFeedback>().Configure(authority,player,effect,Enumerable.Range(0,4).Select(i=>sprites["Impact_"+i]).ToArray());
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return "Provided sheets imported intact; directional actors, sword, impact, NPCs, props, floor and skill icons integrated. Physics and region topology preserved.";
    }
    private static Vector2[] Polygon(int width,int height,Vector2[] points)=>points.Select(p=>p-new Vector2(width/2f,height/2f)).ToArray();
    private static Sprite[] Frames(string prefix)=>Enumerable.Range(0,24).Select(i=>sprites[prefix+"_"+(i/8)+"_"+(i%8)]).ToArray();
    private static void ReplaceProp(SpriteRenderer original,string kind)
    {
        var collider=original.GetComponent<Collider2D>();if(collider==null)return;
        Vector2 footprint=collider.bounds.size;float width=footprint.x;var sprite=sprites[kind];float height=width*sprite.rect.height/sprite.rect.width;
        var visual=new GameObject("Provided"+kind).AddComponent<SpriteRenderer>();visual.transform.SetParent(original.transform,false);visual.sprite=sprite;visual.sharedMaterial=original.sharedMaterial;visual.color=Color.white;
        var scale=original.transform.lossyScale;visual.transform.localScale=new Vector3(width/sprite.bounds.size.x/scale.x,height/sprite.bounds.size.y/scale.y,1);
        float pivotY=sprite.pivot.y/sprite.rect.height;
        visual.transform.localPosition=new Vector3(0,(-footprint.y*.5f+height*pivotY)/scale.y,0);
        original.enabled=false;visual.gameObject.AddComponent<WorldArtSorting>().Configure(visual,original.transform);
    }
    private static void ReplaceGround()
    {
        var ground=UnityEngine.Object.FindObjectsByType<Tilemap>().Single(t=>t.name=="Ground");var replacements=new Dictionary<TileBase,Tile>();
        foreach(var pos in ground.cellBounds.allPositionsWithin)
        {
            var source=ground.GetTile(pos);if(source==null)continue;
            if(!replacements.TryGetValue(source,out var tile))
            {
                int kind=int.Parse(source.name.Substring(5));string art=kind==5?"PathTile":kind==2?"MineTile":kind==4?"RuinTile":kind==3?"MarshTile":"GrassTile";
                tile=ScriptableObject.CreateInstance<Tile>();tile.sprite=sprites[art];tile.transform=Matrix4x4.Scale(new Vector3(2,2,1));tile.colliderType=Tile.ColliderType.None;
                AssetDatabase.CreateAsset(tile,Root+"Ground"+kind+".asset");replacements.Add(source,tile);
            }
            ground.SetTile(pos,tile);ground.SetTransformMatrix(pos,Matrix4x4.Scale(new Vector3(2,2,1)));
        }
    }
    public static string Finish()
    {
        if(EditorApplication.isPlaying || UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/Marco06B2World.unity")throw new InvalidOperationException("B2 outside Play required");
        sprites.Clear();foreach(var file in Directory.GetFiles(Root,"*.png"))foreach(var sprite in AssetDatabase.LoadAllAssetsAtPath(file.Replace('\\','/')).OfType<Sprite>())sprites.Add(sprite.name,sprite);
        ReplaceGround();var player=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var marker=new GameObject("ProvidedArt06B2");var effect=new GameObject("SheetSwordImpact").AddComponent<SpriteRenderer>();effect.transform.SetParent(marker.transform,false);effect.sharedMaterial=player.GetComponent<SpriteRenderer>().sharedMaterial;effect.enabled=false;
        marker.AddComponent<SheetImpactFeedback>().Configure(UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>(),player,effect,Enumerable.Range(0,4).Select(i=>sprites["Impact_"+i]).ToArray());
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return "Finished imported art integration after correcting ambiguous Ground object selection.";
    }
    public static string Inspect()
    {var ground=UnityEngine.Object.FindObjectsByType<Tilemap>().Single(t=>t.name=="Ground");var tile=ground.GetTile<Tile>(new Vector3Int(-8,0,0));return "sprite="+tile.sprite.rect+" bounds="+tile.sprite.bounds+" ppu="+tile.sprite.pixelsPerUnit+" asset="+tile.transform+" cell="+ground.GetTransformMatrix(new Vector3Int(-8,0,0))+" grid="+ground.layoutGrid.cellSize+" scale="+ground.transform.lossyScale;}
    public static string FixGroundScale()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var ground=UnityEngine.Object.FindObjectsByType<Tilemap>().Single(t=>t.name=="Ground");foreach(var pos in ground.cellBounds.allPositionsWithin)if(ground.GetTile(pos)!=null)ground.SetTransformMatrix(pos,Matrix4x4.Scale(new Vector3(2,2,1)));
        ground.RefreshAllTiles();var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);return Inspect();
    }
    public static string CalibrateSword()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Outside Play required");
        var importer=(TextureImporter)AssetImporter.GetAtPath(Root+"efeitos_habilidades_e_icones.png");var factory=new SpriteDataProviderFactories();factory.Init();var provider=factory.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();var capability=provider.GetDataProvider<ISpriteFrameEditCapability>();if(capability==null || !capability.GetEditCapability().HasCapability(EEditCapability.EditPivot))throw new InvalidOperationException("Pivot edit capability absent");var rects=provider.GetSpriteRects();rects.Single(r=>r.name=="Sword").pivot=new Vector2(27/96f,36/96f);provider.SetSpriteRects(rects);provider.Apply();importer.SaveAndReimport();
        var blade=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player.transform.Find("SwordHand/EquippedSword");blade.localRotation=Quaternion.Euler(0,0,-Mathf.Atan2(41,51)*Mathf.Rad2Deg);blade.localScale=Vector3.one*(128f/new Vector2(51,41).magnitude);
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);return "Provided sword calibrated: pivot at grip, tip vector (51,41), rendered blade length 1 world unit.";
    }
}

