using System;
using System.Linq;
using System.Reflection;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using UnityEngine;

// Repeatable live validation. Uses isolated memory and real combat/interactions.
// Prepare -> Attack three times (>0.4 s apart) -> Deliver -> Inspect.
public static class ValidateJevPlay
{
    private static JourneySession Journey => UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    public static string ReloadIsolated()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Play required");
        JourneySession.PersistenceFactory=()=>new MemoryJourneyPersistence();
        UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/OfflineClearing.unity");
        return "Reloaded with isolated persistence; no disk save writes.";
    }
    public static string Prepare(string endpoint="http://127.0.0.1:8091/v1/decisions/evaluate")
    {
        if(!Application.isPlaying||!LocalDecisionClient.IsLocalEndpoint(endpoint)) throw new InvalidOperationException("Play and loopback endpoint required");
        var j=Journey; var memory=new MemoryJourneyPersistence();
        typeof(JourneySession).GetField("persistence",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(j,memory);
        j.Continue(); j.ConfigureDecisions(DecisionMode.OpenRouter,endpoint);
        j.Player.GetComponent<PlayerController>().enabled=false; j.Wolf.GetComponent<WolfBrain>().enabled=false;
        if(!j.Wolf.State.IsAlive||!j.Player.State.IsAlive) throw new InvalidOperationException("Fresh actors required");
        Interact(j,InteractionKind.Trace); Interact(j,InteractionKind.Orin);
        Place(j,Vector2.zero,new Vector2(0.8f,0)); return "Isolated memory; valid tracks and Orin; ready for combat.";
    }
    public static string Attack()
    {
        var j=Journey; var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        bool accepted=authority.RequestAttack(j.Player,Vector2.right);
        return $"accepted={accepted}, wolfHealth={j.Wolf.State.Health}, frame={Time.frameCount}";
    }
    public static string Deliver()
    {
        var j=Journey; if(j.Wolf.State.IsAlive) throw new InvalidOperationException("Defeat through combat first");
        Interact(j,InteractionKind.Sample); Interact(j,InteractionKind.Mira); Interact(j,InteractionKind.Mira);
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>(); if(!hud.JournalOpen)hud.ToggleJournal();
        return $"pending={j.DecisionPending}, A={j.Engine.Status(ForestContent.RouteA)}, B={j.Engine.Status(ForestContent.RouteB)}";
    }
    public static string Inspect()
    {
        var j=Journey;
        var saved=((IJourneyPersistence)typeof(JourneySession).GetField("persistence",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(j)).Load();
        var restored=JourneyEngine.Restore(saved);
        var d=restored.Snapshot().decisions.Single();
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>();
        string journal=((TMPro.TMP_Text)typeof(JourneyHud).GetField("journalText",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(hud)).text;
        if(!journal.Contains(MiraReactions.Text(d.selectedConsequence))||j.Message!=restored.Dialogue(ForestContent.Mira)) throw new InvalidOperationException("UI differs from persisted reaction");
        if(restored.Snapshot().abilities.Count!=1||restored.Status(ForestContent.RouteA)!=OpportunityStatus.Completed||restored.Status(ForestContent.RouteB)!=OpportunityStatus.Completed) throw new InvalidOperationException("Narrative regression");
        return $"decisionId={d.decisionId}, model={d.model}, choice={d.selectedConsequence}, fallback={d.fallback}, latencyMs={d.latencyMs}, persisted=True, dialogue=True, journal=True, A/B=Completed, abilities=1, frame={Time.frameCount}";
    }
    public static string DecisionMetrics()
    {
        var d=Journey.Engine.Snapshot().decisions.Single();
        if(d.fallback||d.provider!="TypeSafe"||!d.decisionId.StartsWith("gen-dec-",StringComparison.Ordinal))
            throw new InvalidOperationException("A real Jev decision is required; fallback is not a live API success.");
        return Newtonsoft.Json.JsonConvert.SerializeObject(new {decisionId=d.decisionId,model=d.model,choice=d.selectedConsequence,
            confidence=d.confidence,probabilities=d.probabilities,latencyMs=d.latencyMs,usage=d.usage});
    }
    public static string PersistAndReload()
    {
        DecisionMetrics(); // Fail rather than reporting a fallback as a real success.
        var j=Journey;var before=j.Engine.Snapshot();
        string path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"mmorpg-jev-real-validation",Guid.NewGuid().ToString("N"),"journey.json");
        var store=new JsonJourneyPersistence(path);store.Save(before);
        var restored=JourneyEngine.Restore(store.Load());
        if(restored.Dialogue(ForestContent.Mira)!=j.Engine.Dialogue(ForestContent.Mira)||restored.Snapshot().decisions.Single().decisionId!=before.decisions.Single().decisionId)
            throw new InvalidOperationException("Disk replay differs from applied decision");
        string unchangedDialogue=j.Message;
        var target=j.Interactions.Single(i=>i.Kind==InteractionKind.Mira);
        j.Player.transform.position=target.transform.position;j.Player.GetComponent<Rigidbody2D>().position=target.transform.position;Physics2D.SyncTransforms();
        j.RequestInteraction(target);
        if(j.Engine.Snapshot().decisions.Count!=1||j.Message!=unchangedDialogue||j.DecisionPending)throw new InvalidOperationException("Repeated dialogue changed or reselected the decision");
        JourneySession.PersistenceFactory=()=>store;
        UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/OfflineClearing.unity");
        return "Verified isolated disk persistence and repeated dialogue; reloaded scene from that same store.";
    }
    public static string InspectReload()
    {
        var j=Journey;j.Player.GetComponent<PlayerController>().enabled=false;j.Wolf.GetComponent<WolfBrain>().enabled=false;
        j.ConfigureDecisions(DecisionMode.OpenRouter,"http://127.0.0.1:8091/v1/decisions/evaluate");
        var target=j.Interactions.Single(i=>i.Kind==InteractionKind.Mira);
        j.Player.transform.position=target.transform.position;j.Player.GetComponent<Rigidbody2D>().position=target.transform.position;Physics2D.SyncTransforms();
        j.RequestInteraction(target);
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>();if(!hud.JournalOpen)hud.ToggleJournal();
        if(j.DecisionPending||j.Engine.PendingMiraDecision()!=null)throw new InvalidOperationException("Reload scheduled another decision");
        return "Reloaded persisted Jev reaction; repeated conversation scheduled no new decision.";
    }
    private static void Interact(JourneySession j,InteractionKind kind)
    {
        var target=j.Interactions.Single(i=>i.Kind==kind); j.Player.transform.position=target.transform.position; j.Player.GetComponent<Rigidbody2D>().position=target.transform.position; Physics2D.SyncTransforms();
        if(!j.RequestInteraction(target)) throw new InvalidOperationException("Interaction rejected: "+kind);
    }
    private static void Place(JourneySession j,Vector2 player,Vector2 wolf)
    { j.Player.transform.position=player;j.Player.GetComponent<Rigidbody2D>().position=player;j.Wolf.transform.position=wolf;j.Wolf.GetComponent<Rigidbody2D>().position=wolf;Physics2D.SyncTransforms(); }
}
