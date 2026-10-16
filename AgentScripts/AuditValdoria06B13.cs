using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Mmorpg.Runtime;
using Mmorpg.Domain;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class AuditValdoria06B13
{
    private const string Evidence="Docs/Validation/Marco06B13/";
    private static string Hash(string p){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
    public static string Main()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/MmorpgWorld.unity")throw new Exception("Clean official scene outside Play required");
        Directory.CreateDirectory(Evidence);var story=UnityEngine.Object.FindAnyObjectByType<JourneySession>();
        var targets=story.Interactions.Where(i=>i.Kind==InteractionKind.Mira||i.Kind==InteractionKind.Orin).Select(i=>i.gameObject).Concat(UnityEngine.Object.FindObjectsByType<ExplorationNode>().Where(n=>n.name.StartsWith("Brann")||n.name.StartsWith("Soren")||n.name.StartsWith("Tessa")).Select(n=>n.gameObject)).Distinct().ToArray();
        var items=targets.Select(go=>new{name=go.name,position=go.transform.position.ToString("R"),scale=go.transform.localScale.ToString("R"),components=go.GetComponents<Component>().Select(c=>c.GetType().Name),
            collider=go.GetComponent<Collider2D>()==null?null:EditorJsonUtility.ToJson(go.GetComponent<Collider2D>()),
            interaction=go.GetComponent<JourneyInteractable>()==null?null:EditorJsonUtility.ToJson(go.GetComponent<JourneyInteractable>()),
            explorationNode=go.GetComponent<ExplorationNode>()==null?null:EditorJsonUtility.ToJson(go.GetComponent<ExplorationNode>()),
            renderers=go.GetComponentsInChildren<SpriteRenderer>().Select(r=>new{name=r.name,enabled=r.enabled,sprite=r.sprite==null?null:r.sprite.name,asset=AssetDatabase.GetAssetPath(r.sprite),rect=r.sprite==null?null:r.sprite.rect.ToString(),pivot=r.sprite==null?null:r.sprite.pivot.ToString(),ppu=r.sprite?.pixelsPerUnit,scale=r.transform.localScale.ToString("R"),position=r.transform.position.ToString("R"),sortingLayer=r.sortingLayerName,sortingOrder=r.sortingOrder,sortingComponent=r.GetComponent<WorldArtSorting>()==null?null:EditorJsonUtility.ToJson(r.GetComponent<WorldArtSorting>())})});
        var engine=new JourneyEngine();string json=JsonConvert.SerializeObject(new{npcs=items,identities=new{mira=ForestContent.Mira,orin=ForestContent.Orin},initialDialogue=new{mira=engine.Dialogue(ForestContent.Mira),orin=engine.Dialogue(ForestContent.Orin)},scene=SceneManager.GetActiveScene().path},Formatting.Indented);File.WriteAllText(Evidence+"existing-npcs.json",json);
        var files=new Dictionary<string,string>();foreach(string dir in new[]{"Assets/Mmorpg/Art/Production/IronKnight","ArtSource/Characters/IronKnight"})foreach(string p in Directory.GetFiles(dir,"*",SearchOption.AllDirectories))files[p.Replace('\\','/')]=Hash(p);
        foreach(string p in new[]{"Assets/Mmorpg/Scenes/MmorpgWorld.unity","Assets/Mmorpg/Scenes/MmorpgWorld.unity.meta","ProjectSettings/EditorBuildSettings.asset"})files[p]=Hash(p);if(!File.Exists(Evidence+"official-before.json"))File.WriteAllText(Evidence+"official-before.json",JsonConvert.SerializeObject(files,Formatting.Indented));
        var personal=new Dictionary<string,string>();foreach(string name in new[]{"profile.json","journey.json","journey.json.bak","marco06b1-exploration.json","marco06b1-exploration.json.bak"}){string p=Path.Combine(LocalJourneyProfile.Root,name);if(File.Exists(p))personal[p]=Hash(p);}if(!File.Exists("Temp/Marco06B13-personal-before.json"))File.WriteAllText("Temp/Marco06B13-personal-before.json",JsonConvert.SerializeObject(personal));
        return "Read-only audit: "+targets.Length+" NPCs; official scene/hero/build settings and "+personal.Count+" personal files hashed.";
    }
}
