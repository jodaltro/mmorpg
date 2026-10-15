using System;
using System.Linq;
using System.Reflection;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine;

public static class ValidateWorldEventsPlay
{
    private static JourneySession Journey => UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    public static string PrepareIsolatedPlay()
    {
        if(Application.isPlaying) throw new InvalidOperationException("Outside Play required");
        SessionState.SetBool("m04-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);
        SessionState.SetInt("m04-options",(int)EditorSettings.enterPlayModeOptions);
        // Preserve the test persistence factory across the Play transition, before any Start/save.
        EditorSettings.enterPlayModeOptionsEnabled=true;
        EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        var store=new JsonJourneyPersistence(System.IO.Path.Combine(System.IO.Path.GetTempPath(),"m04-play-"+Guid.NewGuid().ToString("N"),"journey.json"));
        JourneySession.PersistenceFactory=()=>store;
        Application.runInBackground=true;
        return "Next Play uses isolated temporary JSON; original journey is never loaded or saved.";
    }
    public static string ReloadFresh()
    {
        if(!Application.isPlaying||JourneySession.PersistenceFactory==null) throw new InvalidOperationException("Isolated Play required");
        UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/OfflineClearing.unity");
        Journey.Player.GetComponent<PlayerController>().enabled=false; Journey.Wolf.GetComponent<WolfBrain>().enabled=false;
        return "Fresh actors loaded and AI disabled immediately; existing isolated store retained.";
    }
    public static string FreshRealHistory()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Play required");
        var store=new JsonJourneyPersistence(System.IO.Path.Combine(System.IO.Path.GetTempPath(),"m04-real-"+Guid.NewGuid().ToString("N"),"journey.json"));
        JourneySession.PersistenceFactory=()=>store;
        UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/OfflineClearing.unity");
        Journey.Player.GetComponent<PlayerController>().enabled=false; Journey.Wolf.GetComponent<WolfBrain>().enabled=false;
        return "Fresh independent history in isolated temporary JSON; no player save access.";
    }
    public static string PrepareRealSample()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Play required");
        var j=Journey; j.Player.GetComponent<PlayerController>().enabled=false; j.Wolf.GetComponent<WolfBrain>().enabled=false;
        if(!j.Player.State.IsAlive||!j.Wolf.State.IsAlive) throw new InvalidOperationException("Fresh living actors required");
        j.ConfigureDecisions(DecisionMode.Deterministic,"http://127.0.0.1:8092/v1/decisions/evaluate");
        j.WorldEvents.ConfigureDecisions(DecisionMode.OpenRouter,"http://127.0.0.1:8092/v1/decisions/evaluate");
        var saved=j.CaptureSnapshot(); j.WorldEvents.Initialize(saved,new SimulatedWorldClock{GameMilliseconds=saved.world?.gameTime??0,RealMilliseconds=saved.world?.realTime??0});
        Place(Vector2.zero,new Vector2(0.8f,0)); return "Real world decisions enabled; combat and sample interactions still required.";
    }
    public static async System.Threading.Tasks.Task<object> ConfirmRealDodgeAndReport()
    {
        PrepareRealSample(); var j=Journey; var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        if(!authority.PrepareWolfAttack(j.Wolf,Vector2.left)) throw new InvalidOperationException("Preparation rejected");
        double preparedAt=Time.timeAsDouble;
        while(Time.timeAsDouble<preparedAt+0.36) await System.Threading.Tasks.Task.Delay(10);
        if(!authority.RequestDodge(j.Player)||!authority.ReleasePreparedAttack(j.Wolf)) throw new InvalidOperationException("Prepared dodge rejected");
        Interact(InteractionKind.Orin);
        return new {health=j.Player.State.Health,verifiedActions=j.Engine.Snapshot().inputs.Count(e=>e.eventType==Mmorpg.Domain.EventType.CombatActionVerified),pending=j.WorldEvents.DecisionPending};
    }
    public static object RealMetrics()
    {
        if(Journey.WorldEvents.DecisionPending) throw new InvalidOperationException("Wait for real decision");
        var s=Journey.CaptureSnapshot(); var d=s.world.decisions.Last();
        if(d.fallback||d.provider!="TypeSafe"||!d.decisionId.StartsWith("gen-dec-",StringComparison.Ordinal)) throw new InvalidOperationException("Real Jev success required; fallback does not qualify");
        return new {d.decisionId,d.selectedConsequence,d.model,d.provider,d.confidence,d.probabilities,d.latencyMs,d.usage,opportunities=s.world.opportunities.Select(o=>new{o.id,o.status}),agenda=s.world.scheduled.Count,frame=Time.frameCount};
    }
    public static string AcceptAndCompleteTraining()
    {
        if(Journey.WorldEvents.World.Status(WorldEventContent.Training)!=WorldOpportunityStatus.Discovered) throw new InvalidOperationException("Training was not selected");
        Interact(InteractionKind.Orin); var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();
        Place((Vector2)dummy.transform.position+Vector2.left*0.8f,new Vector2(8,0));
        if(!UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>().RequestAttack(Journey.Player,Vector2.right)) throw new InvalidOperationException("Training hit rejected");
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>(); if(!hud.JournalOpen) hud.ToggleJournal(); Journey.Save();
        return Journey.WorldEvents.World.Journal();
    }
    public static object ReplayRealDecision()
    {
        var before=Journey.CaptureSnapshot(); var store=(IJourneyPersistence)typeof(JourneySession).GetField("persistence",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(Journey);
        Journey.Save(); var after=store.Load();
        if(after.world.decisions.Count!=before.world.decisions.Count||after.world.decisions.Last().decisionId!=before.world.decisions.Last().decisionId) throw new InvalidOperationException("Save replay changed decision");
        UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/OfflineClearing.unity");
        Journey.Player.GetComponent<PlayerController>().enabled=false; Journey.Wolf.GetComponent<WolfBrain>().enabled=false;
        return new {decisionId=after.world.decisions.Last().decisionId,choice=after.world.decisions.Last().selectedConsequence,persisted=true,reloaded=true,abilities=after.abilities.Count};
    }
    public static string PrepareTracking(string endpoint="http://127.0.0.1:8092/v1/decisions/evaluate")
    {
        if(!Application.isPlaying||!LocalDecisionClient.IsLocalEndpoint(endpoint)) throw new InvalidOperationException("Play and known deterministic loopback server required");
        var j=Journey; j.Player.GetComponent<PlayerController>().enabled=false; j.Wolf.GetComponent<WolfBrain>().enabled=false;
        j.ConfigureDecisions(DecisionMode.Deterministic,endpoint);
        j.WorldEvents.ConfigureDecisions(DecisionMode.OpenRouter,endpoint);
        j.WorldEvents.Initialize(j.CaptureSnapshot(),new SimulatedWorldClock{GameMilliseconds=j.CaptureSnapshot().world?.gameTime??0,RealMilliseconds=j.CaptureSnapshot().world?.realTime??0});
        Interact(InteractionKind.Trace); Interact(InteractionKind.Orin); Place(Vector2.zero,new Vector2(0.8f,0));
        return "Real scene interactions accepted; awaiting three authority attacks; provider mode must be chosen explicitly; real OpenRouter requires user authorization.";
    }
    public static object Attack()
    {
        var j=Journey; bool accepted=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>().RequestAttack(j.Player,Vector2.right);
        return new {accepted,wolfHealth=j.Wolf.State.Health,frame=Time.frameCount};
    }
    public static object InspectTransport()
    {
        var j=Journey; if(j.WorldEvents.DecisionPending) throw new InvalidOperationException("Wait for local decision");
        var d=j.WorldEvents.World.Snapshot().decisions.Single();
        if(d.fallback||d.provider!="deterministic"||!d.decisionId.StartsWith("det:",StringComparison.Ordinal)||!j.WorldEvents.World.ClueVisible) throw new InvalidOperationException("Real deterministic Go transport required");
        Place(new Vector2(0,1.7f),new Vector2(8,0));
        return new {d.decisionId,d.selectedConsequence,d.model,d.provider,d.fallback,d.latencyMs,clueVisible=j.WorldEvents.World.ClueVisible,frame=Time.frameCount};
    }
    public static string ExamineAndConclude()
    {
        Interact(InteractionKind.NewTracks); Interact(InteractionKind.Orin);
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>(); if(!hud.JournalOpen) hud.ToggleJournal();
        Journey.Save();
        return Journey.WorldEvents.World.Journal();
    }
    public static string PublishAlert()
    {
        Interact(InteractionKind.Sample); Interact(InteractionKind.Mira); Interact(InteractionKind.Mira);
        return "Mira received valid sample; wait for local Go selection before advancing clock.";
    }
    public static string AdvanceClockAndRead()
    {
        if(Journey.WorldEvents.DecisionPending) throw new InvalidOperationException("Decision still pending");
        var clock=(SimulatedWorldClock)typeof(WorldEventOrchestrator).GetField("clock",BindingFlags.NonPublic|BindingFlags.Instance).GetValue(Journey.WorldEvents.World);
        clock.GameMilliseconds=Math.Max(clock.GameMilliseconds,Journey.WorldEvents.World.Snapshot().gameTime)+15000; Journey.WorldEvents.OnJourneyChanged(); Interact(InteractionKind.NoticeBoard);
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>(); if(hud.JournalOpen) hud.ToggleJournal();
        return Journey.Message;
    }
    public static string Reload()
    {
        Journey.Save(); UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/OfflineClearing.unity"); return "Reloaded from same isolated JSON";
    }
    public static object InspectReload()
    {
        var j=Journey; j.Player.GetComponent<PlayerController>().enabled=false; j.Wolf.GetComponent<WolfBrain>().enabled=false;
        Interact(InteractionKind.NoticeBoard);
        var s=j.CaptureSnapshot();
        if(!s.world.noticePublished||s.world.scheduled.Count(x=>x.executed)!=1||s.world.opportunities.Single().status!=WorldOpportunityStatus.Completed||s.abilities.Count!=1) throw new InvalidOperationException("Unexpected persisted world");
        return new {s.version,notice=s.world.noticePublished,executed=s.world.scheduled.Count(x=>x.executed),decisions=s.world.decisions.Count,abilities=s.abilities.Count,dialogue=j.Message,frame=Time.frameCount};
    }
    public static string RestoreEditorSettings()
    {
        if(Application.isPlaying) throw new InvalidOperationException("Stop Play first");
        JourneySession.PersistenceFactory=null;
        EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("m04-options",0);
        EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("m04-options-enabled",false);
        return "Restored original Play options and cleared test persistence factory";
    }
    private static void Interact(InteractionKind kind)
    {
        var item=Journey.Interactions.Single(x=>x.Kind==kind); Place(item.transform.position,new Vector2(8,0));
        if(!Journey.RequestInteraction(item)&&!(kind==InteractionKind.NoticeBoard&&Journey.WorldEvents.World.NoticePublished)) throw new InvalidOperationException("Interaction rejected: "+kind);
    }
    private static void Place(Vector2 player,Vector2 wolf)
    {
        var j=Journey; j.Player.transform.position=player; j.Player.GetComponent<Rigidbody2D>().position=player;
        j.Wolf.transform.position=wolf; j.Wolf.GetComponent<Rigidbody2D>().position=wolf; Physics2D.SyncTransforms();
    }
}
