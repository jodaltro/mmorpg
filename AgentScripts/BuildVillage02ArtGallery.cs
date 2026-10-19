using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

public static class BuildVillage02ArtGallery
{
    public const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02ArtGallery.unity";
    const string Source="ArtSource/World/PlayableVillage02/ArtProductionV1/ExportV1/";
    const string Art="Assets/Mmorpg/Art/Experimental/Village02ArtGallery/";
    const string QA="Docs/Validation/ValdoriaVillage02-ArtProduction/QA/";
    static string Hash(string p){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
    public static object Main()
    {
        var before=EditorSceneManager.GetActiveScene();
        if(EditorApplication.isPlaying||before.isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse dirty/playing/existing gallery destination");
        var catalog=JObject.Parse(File.ReadAllText(Source+"catalog.json"));
        foreach(var a in catalog["assets"])if(Hash((string)a["source"])!=(string)a["sourceSHA256"]||Hash((string)a["composite"])!=(string)a["compositeSHA256"])throw new IOException("Art export/source mismatch");
        Directory.CreateDirectory(Art);Directory.CreateDirectory(QA);
        File.WriteAllText(QA+"editor-before.json",JsonConvert.SerializeObject(new{scene=before.path,dirty=before.isDirty,firstBuildScene=EditorBuildSettings.scenes.First(s=>s.enabled).path},Formatting.Indented));
        var source=EditorSceneManager.OpenScene(PlayableVillage01Builder.Scene);EditorSceneManager.SaveScene(source,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);
        var actor=GameObject.Find("Player");var camera=Camera.main;var isolation=Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>();
        var keep=new[]{actor,camera.gameObject,GameObject.Find("OfflineAuthority"),isolation.gameObject};foreach(var g in scene.GetRootGameObjects().Where(g=>!keep.Contains(g)).ToArray())Object.DestroyImmediate(g);
        foreach(var c in actor.GetComponents<MonoBehaviour>().Where(c=>c.GetType().Name.Contains("Debug")).ToArray())Object.DestroyImmediate(c);
        int index=0;foreach(var a in catalog["assets"])
        {
            string id=(string)a["id"];string path=Art+id+".png";File.Copy((string)a["composite"],path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Single;importer.spritePixelsPerUnit=32;importer.npotScale=TextureImporterNPOTScale.None;importer.filterMode=FilterMode.Point;importer.mipmapEnabled=false;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.maxTextureSize=4096;importer.alphaIsTransparency=true;
            var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteAlignment=(int)SpriteAlignment.Custom;settings.spritePivot=new Vector2((float)a["groundAnchorPixels"][0]/(float)a["canvas"][0],1-(float)a["groundAnchorPixels"][1]/(float)a["canvas"][1]);importer.SetTextureSettings(settings);importer.SaveAndReimport();
            var go=new GameObject("Art E: "+id);go.transform.position=new Vector3(50,45+index*90);var rr=go.AddComponent<SpriteRenderer>();rr.sprite=AssetDatabase.LoadAssetAtPath<Sprite>(path);go.AddComponent<WorldArtSorting>().Configure(rr,go.transform);index++;
        }
        actor.transform.position=new Vector3(54,43);actor.GetComponent<Rigidbody2D>().position=actor.transform.position;isolation.ConfigureTemporaryProfile("Village02ArtGallery/IsolatedProfile");
        camera.backgroundColor=new Color(.31f,.33f,.30f);camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(50,51,-10);var follow=camera.GetComponent<CameraFollow>();follow.Configure(actor.transform);follow.ConfigureBounds(new Rect(-50,-50,250,1450));follow.ConfigurePixelGrid(32);follow.enabled=true;
        File.Copy(Source+"catalog.json",Art+"catalog.json",false);AssetDatabase.Refresh();EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();
        var receipt=new{scene=Scene,assets=index,players=Object.FindObjectsByType<PlayerController>().Length,cameras=Object.FindObjectsByType<Camera>().Count(c=>c.enabled),environmentColliders=0,artOnly=true,worldIntegrated=false,promoted=false};File.WriteAllText(QA+"gallery-build.json",JsonConvert.SerializeObject(receipt,Formatting.Indented));return receipt;
    }
    public static object Restore()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Stopped clean editor required");var before=JObject.Parse(File.ReadAllText(QA+"editor-before.json"));EditorSceneManager.OpenScene((string)before["scene"]);
        var result=new{scene=EditorSceneManager.GetActiveScene().path,playing=EditorApplication.isPlaying,dirty=EditorSceneManager.GetActiveScene().isDirty,timeScale=Time.timeScale,temporaryRecorder=Object.FindObjectsByType<Village02EvidenceCapture>().Length,promoted=EditorBuildSettings.scenes.Any(s=>s.path==Scene)};File.WriteAllText(QA+"editor-restored.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
    }
}
