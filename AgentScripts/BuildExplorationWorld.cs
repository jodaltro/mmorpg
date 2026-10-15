using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Tilemaps;
public static class BuildExplorationWorld
{
    public const string ScenePath="Assets/Mmorpg/Scenes/Marco06B1World.unity";
    private const string Art="Assets/Mmorpg/Art/Exploration/";
    private static Sprite square;
    private static Material material;
    private static TMP_FontAsset font;
    private static JourneySession journey;
    private static OfflineAuthority authority;
    private static Transform root;
    private static readonly List<ExplorationNode> nodes=new List<ExplorationNode>();
    private static readonly List<ExplorationRegion> regions=new List<ExplorationRegion>();
    private static readonly Dictionary<Vector3Int,int> floor=new Dictionary<Vector3Int,int>();
    private static GameObject resourcePrefab;
    public static string Build()
    {
        if(EditorApplication.isPlaying||File.Exists(ScenePath))throw new InvalidOperationException("Refusing to overwrite scene; stop Play first.");
        for(int i=0;i<UnityEngine.SceneManagement.SceneManager.sceneCount;i++)if(UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).isDirty)throw new InvalidOperationException("Dirty scene: preserve user changes first.");
        var scene=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ActionVerticalSlice.unity");
        if(!EditorSceneManager.SaveScene(scene,ScenePath))throw new IOException("Cannot create new scene");
        nodes.Clear();regions.Clear();floor.Clear();
        square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        journey.ConfigureIsolatedSave("marco06b1-journey.json");journey.ConfigureDecisions(DecisionMode.Deterministic,"");journey.WorldEvents.ConfigureDecisions(DecisionMode.Deterministic,"");
        var game=UnityEngine.Object.FindAnyObjectByType<GameSession>();game.enabled=false;
        root=new GameObject("ExplorableWorld").transform;
        foreach(var name in new[]{"NorthWall","SouthWall","EastWall","WestWall"}){var wall=GameObject.Find(name);if(wall!=null)UnityEngine.Object.DestroyImmediate(wall);}
        foreach(var debug in UnityEngine.Object.FindObjectsByType<ActionDebugPanel>())debug.enabled=false;
        var debugWindow=GameObject.Find("ActionDebug");if(debugWindow!=null)debugWindow.SetActive(false);
        CreateArt();CreatePrefab();
        Room(-11,-1,-7,7,0);Room(1,11,-7,7,1);Room(-11,3,18,30,2);Room(23,39,-7,7,3);Room(23,39,18,30,4);
        Room(-8,-6,8,17,5);Room(12,22,-1,1,5);Room(4,22,23,25,5);Room(30,32,8,17,5);
        // Readable lanes; corridors are physical spaces, never teleport triggers.
        Room(-11,11,-1,1,5);Room(-8,-6,-6,7,5);Room(-8,-6,18,29,5);Room(-10,3,23,25,5);Room(23,38,-1,1,5);Room(30,32,2,30,5);Room(23,38,23,25,5);
        Tilemaps();
        Region("Valdoria",new Rect(-11,-7,11,15),new Vector2(-8,-1));
        Region("Floresta Cinzenta",new Rect(.5f,-7,11.5f,15),new Vector2(1.3f,0));
        Region("Minas de Kharum",new Rect(-11,18,15,13),new Vector2(-7,19));
        Region("Pântano dos Ecos",new Rect(23,-7,17,15),new Vector2(24,0));
        Region("Ruínas de Asterion",new Rect(23,18,17,13),new Vector2(31,19));
        Label("↑ MINAS DE KHARUM",new Vector2(-7,7),2.5f);Label("PÂNTANO DOS ECOS →",new Vector2(10,1.5f),2.2f);Label("ASTERION →",new Vector2(2,25.8f),2.5f);Label("↑ RUÍNAS DE ASTERION",new Vector2(31,7),2.4f);
        Label("MINAS DE KHARUM",new Vector2(-4,29.8f),3);Label("PÂNTANO DOS ECOS",new Vector2(32,6.6f),3);Label("RUÍNAS DE ASTERION",new Vector2(32,29.8f),3);
        // Preserve the approved wolf and its narrative encounter. Move existing spatial brains to appropriate regions.
        var spider=UnityEngine.Object.FindObjectsByType<SpatialCreatureBrain>().Single(b=>b.Kind==CreatureKind.Spider);spider.transform.position=new Vector2(34,-4);
        var golem=UnityEngine.Object.FindObjectsByType<SpatialCreatureBrain>().Single(b=>b.Kind==CreatureKind.Golem);golem.transform.position=new Vector2(-2,21);
        Drop(game.Wolf,"wolf-fang","Presas de lobo",2,"wolf-material");Drop(spider.GetComponent<ActorHealth>(),"spider-venom","Veneno de aranha",3,"spider-material");Drop(golem.GetComponent<ActorHealth>(),"stone-core","Núcleo de pedra",2,"sentinel-material");
        var guardian=UnityEngine.Object.Instantiate(golem.gameObject,root);guardian.name="Guardião de pedra ancestral";guardian.transform.position=new Vector2(36,27);
        var warning=Block("AncestralImpact",Vector2.zero,Vector2.one,Color.red,false,100).GetComponent<SpriteRenderer>();warning.enabled=false;
        guardian.GetComponent<SpatialCreatureBrain>().Configure(CreatureKind.Golem,game.Player,authority,warning);guardian.GetComponent<SpriteRenderer>().color=new Color(.45f,.6f,.63f);
        // This is a golem variant, not a claim that the catalogue guardian's directional protection exists.
        var clonedDrop=guardian.GetComponent<CreatureMaterialDrop>();if(clonedDrop!=null)UnityEngine.Object.DestroyImmediate(clonedDrop);
        Drop(guardian.GetComponent<ActorHealth>(),"guardian-fragment","Fragmento do guardião",2,"guardian-material");
        Resource("village-herbs",new Vector2(-9,-1.8f),"gray-herb","Erva cinzenta",2,"Herb");Resource("village-water",new Vector2(-9.5f,-5),"pure-water","Água pura",2,"Crystal");
        Resource("forest-herbs",new Vector2(3,2.8f),"gray-herb","Erva cinzenta",3,"Herb");Resource("forest-seeds",new Vector2(6,-5),"ember-seed","Semente de brasa",2,"Herb");Resource("forest-water",new Vector2(9,-1),"pure-water","Água pura",2,"Crystal");Resource("forest-moss",new Vector2(9,5.8f),"ancient-moss","Musgo antigo",2,"Herb");
        Resource("iron-vein",new Vector2(-9,21),"iron-ore","Minério de ferro",3,"Ore");Resource("coal-seam",new Vector2(-9,27),"coal","Carvão",2,"Ore");Resource("crystal-seam",new Vector2(1,27),"quartz","Quartzo",3,"Crystal");Resource("copper-vein",new Vector2(1,20),"copper-ore","Minério de cobre",2,"Ore");
        Resource("marsh-reeds",new Vector2(26,-3),"toxic-reed","Junco tóxico",3,"Herb");Resource("echo-lotus",new Vector2(37,3),"echo-lotus","Lótus dos ecos",2,"Herb");Resource("marsh-salt",new Vector2(26,5),"salt","Sal",2,"Crystal");
        Resource("ancient-fragments",new Vector2(27,21),"historical-fragment","Fragmento histórico",2,"Crystal");Resource("ancestral-glyph",new Vector2(37,21),"asterion-glyph","Glifo de Asterion",1,"Crystal");
        Npc("helena","Helena — acolhimento",new Vector2(-10,0),"Bem-vindo a Valdoria. A trilha norte chega às minas. A saída leste leva à floresta e à ponte do pântano.");
        Npc("brann","Brann — forja",new Vector2(-3,-5),"Minha forja é o ponto de equipamentos da vila. Guarde ferro, carvão e presas. Comércio e fabricação serão integrados depois; hoje não consumirei seus materiais.");
        Npc("selka","Selka — alquimia",new Vector2(-9,-6),"Juncos e veneno de aranha são ingredientes valiosos. O lodo desacelera seus passos; use as passarelas secas.");
        Npc("dorin","Dorin — minerador",new Vector2(-6,20),"Os veios brilham nas paredes. Aproxime-se e pressione E. A sentinela tem couraça: observe a preparação do impacto e ataque na recuperação.");
        Npc("tessa","Tessa — arquivo",new Vector2(-6,28),"As marcas de Kharum se repetem em Asterion. O túnel leste cruza a montanha até as ruínas.");
        Npc("nera","Nera — ervas",new Vector2(26,1.5f),"A aranha prepara o disparo antes de lançar veneno. Há juncos ao sul e lótus ao norte; a ponte norte chega a Asterion.");
        Npc("soren","Soren — historiador",new Vector2(29,25.8f),"O Farol de Asterion ocupa o altar ao norte. Seu acontecimento histórico pertence ao sistema existente; esta exploração não cria outra ativação mundial.");
        Node("asterion-inscription","Inscrição ancestral",new Vector2(27,27),ExplorationNodeKind.Inscription,"Os símbolos unem Kharum aos ecos do pântano. A pedra registra viajantes, não conquistadores.");
        Node("asterion-beacon-site","Farol de Asterion — local histórico",new Vector2(32,28),ExplorationNodeKind.Inscription,"Local reservado ao Farol de Asterion. Ativação compartilhada permanece no modo online experimental; nenhum evento online é produzido por este save offline.");
        Decorate();WireUi();
        game.Player.transform.position=new Vector2(-8,-1);Camera.main.transform.position=new Vector3(-8,-1,-10);
        var settings=EditorBuildSettings.scenes.ToList();if(!settings.Any(s=>s.path==ScenePath))settings.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.scenes=settings.ToArray();
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return "Five connected physical regions; "+nodes.Count+" nodes; isolated offline saves. Approved source scene preserved.";
    }
    private static void Room(int x0,int x1,int y0,int y1,int kind){for(int x=x0;x<=x1;x++)for(int y=y0;y<=y1;y++)floor[new Vector3Int(x,y)]=kind;}
    private static void Tilemaps()
    {
        var grid=new GameObject("RegionTilemaps",typeof(Grid));grid.transform.SetParent(root);
        var ground=new GameObject("Ground",typeof(Tilemap),typeof(TilemapRenderer));ground.transform.SetParent(grid.transform,false);ground.GetComponent<TilemapRenderer>().sortingOrder=-450;
        var edges=new GameObject("SolidBoundaries",typeof(Tilemap),typeof(TilemapRenderer),typeof(TilemapCollider2D));edges.transform.SetParent(grid.transform,false);edges.layer=8;edges.GetComponent<TilemapRenderer>().sortingOrder=-440;
        var tiles=new Tile[7];for(int i=0;i<7;i++){tiles[i]=ScriptableObject.CreateInstance<Tile>();tiles[i].sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Floor"+i+".png");tiles[i].colliderType=i==6?Tile.ColliderType.Grid:Tile.ColliderType.None;AssetDatabase.CreateAsset(tiles[i],Art+"Floor"+i+".asset");}
        var boundary=new HashSet<Vector3Int>();foreach(var pair in floor){ground.GetComponent<Tilemap>().SetTile(pair.Key,tiles[pair.Value]);foreach(var delta in new[]{Vector3Int.up,Vector3Int.down,Vector3Int.left,Vector3Int.right})if(!floor.ContainsKey(pair.Key+delta))boundary.Add(pair.Key+delta);}
        foreach(var cell in boundary)edges.GetComponent<Tilemap>().SetTile(cell,tiles[6]);
    }
    private static void Region(string title,Rect bounds,Vector2 entry)
    {var go=new GameObject(title,typeof(BoxCollider2D),typeof(ExplorationRegion));go.transform.SetParent(root);go.transform.position=bounds.center;var col=go.GetComponent<BoxCollider2D>();col.isTrigger=true;col.size=bounds.size;var area=go.GetComponent<ExplorationRegion>();area.Configure(title,entry);regions.Add(area);}
    private static GameObject Block(string name,Vector2 position,Vector2 scale,Color color,bool solid,int order=0,string art=null)
    {var go=new GameObject(name);go.transform.SetParent(root);go.transform.position=position;go.transform.localScale=new Vector3(scale.x,scale.y,1);var sr=go.AddComponent<SpriteRenderer>();sr.sprite=art==null?square:AssetDatabase.LoadAssetAtPath<Sprite>(Art+art+".png");sr.sharedMaterial=material;sr.color=color;sr.sortingOrder=order;if(solid){go.layer=8;go.AddComponent<BoxCollider2D>();}return go;}
    private static void Label(string words,Vector2 pos,float size)
    {var go=new GameObject(words,typeof(TextMeshPro));go.transform.SetParent(root);go.transform.position=pos;var text=go.GetComponent<TextMeshPro>();text.font=font;text.text=words;text.fontSize=size;text.alignment=TextAlignmentOptions.Center;text.rectTransform.sizeDelta=new Vector2(10,.8f);text.GetComponent<MeshRenderer>().sortingOrder=400;}
    private static ExplorationNode Resource(string id,Vector2 position,string item,string title,int count,string art)
    {var go=(GameObject)PrefabUtility.InstantiatePrefab(resourcePrefab);go.transform.SetParent(root);go.transform.position=position;go.name=title;var visual=go.GetComponent<SpriteRenderer>();visual.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+art+".png");var node=go.GetComponent<ExplorationNode>();node.Configure(id,item,title,count,ExplorationNodeKind.Resource,"",visual);PrefabUtility.RecordPrefabInstancePropertyModifications(node);PrefabUtility.RecordPrefabInstancePropertyModifications(visual);nodes.Add(node);return node;}
    private static void Drop(ActorHealth actor,string item,string title,int count,string id)
    {var node=Resource(id,actor.transform.position,item,title,count,"Crystal");actor.gameObject.AddComponent<CreatureMaterialDrop>().Configure(actor,node,authority);node.gameObject.SetActive(false);}
    private static void Npc(string id,string name,Vector2 position,string words)=>Node(id,name,position,ExplorationNodeKind.Npc,words);
    private static void Node(string id,string name,Vector2 position,ExplorationNodeKind kind,string words)
    {var go=Block(name,position,new Vector2(.8f,1),Color.white,true,0,kind==ExplorationNodeKind.Npc?"Npc":"Crystal");var node=go.AddComponent<ExplorationNode>();node.Configure(id,"","",0,kind,words,go.GetComponent<SpriteRenderer>());nodes.Add(node);Label(name,position+Vector2.up*.9f,1.5f);}
    private static void CreatePrefab()
    {Directory.CreateDirectory("Assets/Mmorpg/Prefabs/Exploration");var go=new GameObject("Resource",typeof(SpriteRenderer),typeof(ExplorationNode));go.GetComponent<SpriteRenderer>().sprite=AssetDatabase.LoadAssetAtPath<Sprite>(Art+"Herb.png");go.GetComponent<SpriteRenderer>().sharedMaterial=material;resourcePrefab=PrefabUtility.SaveAsPrefabAsset(go,"Assets/Mmorpg/Prefabs/Exploration/Resource.prefab");UnityEngine.Object.DestroyImmediate(go);}
    private static void Decorate()
    {
        foreach(var p in new[]{new Vector2(3,5),new Vector2(5,3.5f),new Vector2(6,-3),new Vector2(9,-6)})Block("Árvore cinzenta",p,new Vector2(1.3f,1.7f),Color.white,true,0,"Tree");
        foreach(var p in new[]{new Vector2(-4,19),new Vector2(-4,27),new Vector2(2,21),new Vector2(-10,25)})Block("Formação rochosa",p,new Vector2(1.3f,2),Color.white,true,0,"Rock");
        foreach(var p in new[]{new Vector2(27,-5),new Vector2(29,4),new Vector2(38,-4),new Vector2(38,5)})Block("Vegetação tóxica",p,new Vector2(1.3f,1.5f),new Color(.6f,.85f,.4f),true,0,"Tree");
        var mud=Block("Lodo — passos lentos",new Vector2(29,-3),new Vector2(3,3),new Color(.24f,.3f,.17f,.8f),false,-430);mud.AddComponent<BoxCollider2D>().isTrigger=true;mud.AddComponent<MarshTerrain>();PrefabUtility.SaveAsPrefabAssetAndConnect(mud,"Assets/Mmorpg/Prefabs/Exploration/MarshTerrain.prefab",InteractionMode.AutomatedAction);
        foreach(var p in new[]{new Vector2(25,20),new Vector2(25,28),new Vector2(38,20),new Vector2(34,25.5f)})Block("Pilar ancestral",p,new Vector2(.9f,1.8f),new Color(.65f,.68f,.59f),true,0,"Rock");
        Block("Altar do farol",new Vector2(32,28.5f),new Vector2(3,1),new Color(.4f,.6f,.65f),true,0,"Rock");
        Block("Bancada da forja",new Vector2(-3,-6.5f),new Vector2(2,.7f),new Color(.42f,.25f,.13f),true);Label("FORJA",new Vector2(-3,-6.8f),1.5f);
        Label("Ponte dos Ecos",new Vector2(18,1.7f),2);Label("Túnel de Kharum",new Vector2(15,26.5f),2);
    }
    private static TMP_Text UiText(string name,Transform parent,Vector2 anchor,Vector2 position,Vector2 size,int fontSize)
    {var go=new GameObject(name,typeof(RectTransform),typeof(TextMeshProUGUI));go.transform.SetParent(parent,false);var text=go.GetComponent<TextMeshProUGUI>();var rect=text.rectTransform;rect.anchorMin=rect.anchorMax=rect.pivot=anchor;rect.anchoredPosition=position;rect.sizeDelta=size;text.font=font;text.fontSize=fontSize;text.color=Color.white;text.raycastTarget=false;return text;}
    private static void WireUi()
    {
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();var all=canvas.GetComponentsInChildren<Transform>(true);
        var region=UiText("ExplorationRegion",canvas.transform,new Vector2(1,1),new Vector2(-20,-20),new Vector2(260,28),19);region.alignment=TextAlignmentOptions.Right;
        var hint=UiText("ExplorationContext",canvas.transform,new Vector2(.5f,0),new Vector2(0,125),new Vector2(600,48),17);hint.alignment=TextAlignmentOptions.Center;
        var panel=new GameObject("ExplorationDialogue",typeof(RectTransform),typeof(UnityEngine.UI.Image));panel.transform.SetParent(canvas.transform,false);var rect=(RectTransform)panel.transform;rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(.5f,.5f);rect.sizeDelta=new Vector2(650,245);panel.GetComponent<UnityEngine.UI.Image>().color=new Color(.03f,.06f,.06f,.98f);
        var words=UiText("Words",panel.transform,Vector2.up,new Vector2(22,-22),new Vector2(606,201),19);panel.SetActive(false);
        var world=new GameObject("ExplorationSession").AddComponent<ExplorationWorld>();world.Configure(journey,authority,journey.Player.GetComponent<PlayerController>(),region,hint,words,panel,nodes.ToArray(),regions.ToArray());
        authority.ConfigureExploration(world);canvas.GetComponent<ActionSliceHud>().ConfigureExploration(world);canvas.GetComponent<JourneyHud>().ConfigureExploration(world);UnityEngine.Object.FindAnyObjectByType<HealthHud>().ConfigureExploration(world);
        var text=all.FirstOrDefault(t=>t.name=="Controls")?.GetComponent<TMP_Text>();if(text!=null)text.text="WASD mover · Mouse atacar · Dir. pesado · Espaço esquiva · E interagir · I inventário · Tab diário · Esc pausa";
        var secondary=all.First(t=>t.name=="ActionSecondaryPanel");((RectTransform)secondary).sizeDelta=new Vector2(640,470);var inventory=all.First(t=>t.name=="ActionSecondaryText").GetComponent<TMP_Text>();inventory.rectTransform.sizeDelta=new Vector2(600,430);inventory.fontSize=17;secondary.GetComponent<UnityEngine.UI.Image>().color=new Color(.03f,.06f,.06f,1);secondary.SetAsLastSibling();panel.transform.SetAsLastSibling();
    }
    private static void CreateArt()
    {
        Directory.CreateDirectory(Art);
        var colors=new[]{new Color(.28f,.34f,.25f),new Color(.19f,.29f,.22f),new Color(.24f,.24f,.27f),new Color(.22f,.3f,.24f),new Color(.3f,.35f,.37f),new Color(.46f,.38f,.26f),new Color(.12f,.17f,.18f)};
        for(int i=0;i<colors.Length;i++){int index=i;Pixel("Floor"+i,(x,y)=>colors[index]*((x*7+y*3)%17==0?1.17f:((x+y)%13==0?.9f:1)));}
        Pixel("Herb",(x,y)=>((x==7||x==8)&&y<12||y>4&&y<10&&Math.Abs(x-8)<(y%3+3))?new Color(.45f,.72f,.32f):Color.clear);
        Pixel("Crystal",(x,y)=>y>1&&y<15&&Math.Abs(x-8)<(y<8?y/2: (16-y)/2)+1?new Color(x<8?.35f:.62f,.8f,.85f):Color.clear);
        Pixel("Ore",(x,y)=>y>1&&y<12&&Math.Abs(x-8)<6?((x+y)%5==0?new Color(.7f,.44f,.24f):new Color(.37f,.4f,.43f)):Color.clear);
        Pixel("Rock",(x,y)=>y>0&&y<14&&Math.Abs(x-8)<(y>10?4:7)?new Color(.4f+(x%3)*.03f,.45f,.47f):Color.clear);
        Pixel("Tree",(x,y)=>y<5&&x>6&&x<10?new Color(.38f,.24f,.15f):y>3&&y<16&&Math.Abs(x-8)<(y>12?3:7)?new Color(.16f+(x%3)*.025f,.34f+(y%4)*.025f,.24f):Color.clear);
        Pixel("Npc",(x,y)=>y>10&&y<15&&x>5&&x<11?new Color(.8f,.65f,.45f):y>2&&y<11&&x>3&&x<13?new Color(.42f,.52f,.64f):y<3&&(x==5||x==10)?new Color(.25f,.2f,.17f):Color.clear);
    }
    private static void Pixel(string name,Func<int,int,Color> color)
    {var texture=new Texture2D(16,16);for(int x=0;x<16;x++)for(int y=0;y<16;y++)texture.SetPixel(x,y,color(x,y));texture.Apply();string path=Art+name+".png";if(File.Exists(path))throw new IOException("Refusing existing art "+path);File.WriteAllBytes(path,texture.EncodeToPNG());UnityEngine.Object.DestroyImmediate(texture);AssetDatabase.ImportAsset(path);var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;importer.spritePixelsPerUnit=16;importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;importer.SaveAndReimport();}
}
