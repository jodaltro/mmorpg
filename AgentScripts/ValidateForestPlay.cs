using System;
using System.Linq;
using System.Reflection;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using UnityEngine;

// Run only in Play. Uses actual interaction/combat APIs and isolated persistence.
// Run Prepare, Attack three times at >0.4s intervals, then Finish. No fabricated facts.
public static class ValidateForestPlay
{
    private static JourneySession Journey => UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    public static string Prepare()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Play required");
        var j=Journey;
        if(!j.Player.State.IsAlive||!j.Wolf.State.IsAlive) throw new InvalidOperationException("Fresh live actors required");
        var memory=new MemoryJourneyPersistence();
        typeof(JourneySession).GetField("persistence",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(j,memory);
        j.Continue(); // empty isolated store; does not touch the user's disk save
        j.Player.GetComponent<PlayerController>().enabled=false; j.Wolf.GetComponent<WolfBrain>().enabled=false;
        Place(j,new Vector2(0,2),new Vector2(4,0));
        Interact(j,InteractionKind.Trace); Interact(j,InteractionKind.Orin);
        Place(j,Vector2.zero,new Vector2(0.8f,0));
        return "Verified tracks and Orin interaction; ready for authority attacks";
    }
    public static string Attack()
    {
        var j=Journey; var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        bool accepted=authority.RequestAttack(j.Player,Vector2.right);
        return $"Attack accepted={accepted}, wolf health={j.Wolf.State.Health}, unlocked={j.Engine.HasAbility(ForestContent.Technique)}";
    }
    public static string Finish()
    {
        var j=Journey; if(j.Wolf.State.IsAlive||!j.Engine.HasAbility(ForestContent.Technique)) throw new InvalidOperationException("Complete real combat first");
        Interact(j,InteractionKind.Sample); Interact(j,InteractionKind.Mira); Interact(j,InteractionKind.Mira);
        var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>(); if(!hud.JournalOpen) hud.ToggleJournal();
        Place(j,new Vector2(-2,1),j.Wolf.transform.position);
        var s=j.Engine.Snapshot();
        return $"facts={s.facts.Count}, abilities={s.abilities.Count}, A={j.Engine.Status(ForestContent.RouteA)}, B={j.Engine.Status(ForestContent.RouteB)}, trust={string.Join(",",s.relations.Select(r=>r.npcId+":"+r.trust))}, frame={Time.frameCount}";
    }
    private static void Interact(JourneySession j,InteractionKind kind)
    {
        var target=j.Interactions.Single(i=>i.Kind==kind); j.Player.transform.position=target.transform.position; j.Player.GetComponent<Rigidbody2D>().position=target.transform.position; Physics2D.SyncTransforms();
        if(!j.RequestInteraction(target)) throw new InvalidOperationException("Interaction rejected: "+kind);
    }
    private static void Place(JourneySession j,Vector2 player,Vector2 wolf)
    { j.Player.transform.position=player; j.Player.GetComponent<Rigidbody2D>().position=player; j.Wolf.transform.position=wolf; j.Wolf.GetComponent<Rigidbody2D>().position=wolf; Physics2D.SyncTransforms(); }
}
