using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using Gamekit3D;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

// Directed Play QA with real queued Input System devices; never ships in the build.
public static class ProbeAction3DPlay
{
    [Serializable] public class Check { public string name; public bool passed; public string detail; }
    [Serializable] public class Report { public string scene; public int startFrame,endFrame; public List<Check> checks = new List<Check>(); public bool complete; }
    static Report report;
    static Keyboard keyboard;
    static Mouse mouse;
    static IEnumerator sequence;
    static int lastFrame;
    static InputSettings.BackgroundBehavior background;
    static PlayerController player;
    static GameObject enemy;
    static void CheckResult(string name, bool passed, string detail)
    {
        report.checks.Add(new Check { name=name, passed=passed, detail=detail });
        Save();
    }
    static void Save() { Directory.CreateDirectory("Temp/Action3D"); File.WriteAllText("Temp/Action3D/play-probe.json",Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented)); }
    public static string Start()
    {
        if (!EditorApplication.isPlaying) throw new InvalidOperationException("Play Mode required");
        if (sequence != null) throw new InvalidOperationException("Probe already running");
        report = new Report { scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,startFrame=Time.frameCount };
        background = InputSystem.settings.backgroundBehavior;
        InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
        keyboard=InputSystem.AddDevice<Keyboard>("Action3DQAKeyboard"); mouse=InputSystem.AddDevice<Mouse>("Action3DQAMouse");
        player=PlayerController.instance; enemy=UnityEngine.Object.FindFirstObjectByType<ChomperBehavior>().gameObject;
        sequence=Run(); lastFrame=-1; EditorApplication.update+=Tick;
        return "Input QA running; Temp/Action3D/play-probe.json";
    }
    static void Tick()
    {
        if (!EditorApplication.isPlaying) { Cleanup(); return; }
        if (lastFrame==Time.frameCount) return;
        lastFrame=Time.frameCount;
        try { if (!sequence.MoveNext()) { report.complete=true; report.endFrame=Time.frameCount; Save(); Cleanup(); } }
        catch(Exception ex) { CheckResult("probe-exception",false,ex.ToString()); Cleanup(); }
    }
    static void Cleanup()
    {
        EditorApplication.update-=Tick; sequence=null;
        if (keyboard!=null && keyboard.added) InputSystem.RemoveDevice(keyboard);
        if (mouse!=null && mouse.added) InputSystem.RemoveDevice(mouse);
        InputSystem.settings.backgroundBehavior=background;
        if (enemy!=null) { enemy.SetActive(true); var a=enemy.GetComponent<GamekitCombatAuthority>(); if(a!=null)a.enabled=true; var anim=enemy.GetComponent<Animator>();if(anim!=null)anim.enabled=true; }
        if (player!=null) player.GetComponent<Animator>().enabled=true;
    }
    static void Keys(params Key[] keys) { InputSystem.QueueStateEvent(keyboard,new KeyboardState(keys)); }
    static void Click(bool down) { InputSystem.QueueStateEvent(mouse,new MouseState().WithButton(MouseButton.Left,down)); }
    static IEnumerator Wait(float seconds) { float until=Time.time+seconds; while(Time.time<until) yield return null; }
    static void Warp(Vector3 position)
    {
        var character=player.GetComponent<CharacterController>(); character.enabled=false; player.transform.position=position; character.enabled=true; Physics.SyncTransforms();
    }
    static IEnumerator Run()
    {
        enemy.SetActive(false);
        yield return null;
        var wait=Wait(1); while(wait.MoveNext())yield return null;
        CheckResult("rendered-frames",Time.frameCount>report.startFrame+10,$"{report.startFrame} -> {Time.frameCount}");
        Vector3 start=player.transform.position;
        Keys(Key.W); wait=Wait(1.2f);while(wait.MoveNext())yield return null; Keys();
        float moved=Vector3.Distance(start,player.transform.position);
        CheckResult("input-movement",moved>1,$"distance={moved:F3}; from={start}; to={player.transform.position}");
        wait=Wait(0.4f);while(wait.MoveNext())yield return null;
        Quaternion cameraStart=Camera.main.transform.rotation;
        float until=Time.time+0.4f;
        while(Time.time<until) { InputSystem.QueueStateEvent(mouse,new MouseState { delta=new Vector2(8,0) }); yield return null; }
        InputSystem.QueueStateEvent(mouse,new MouseState());
        CheckResult("input-camera",Quaternion.Angle(cameraStart,Camera.main.transform.rotation)>3,$"angle={Quaternion.Angle(cameraStart,Camera.main.transform.rotation):F2}");
        float ground=player.transform.position.y, peak=ground;
        Keys(Key.Space);until=Time.time+0.35f;while(Time.time<until){peak=Mathf.Max(peak,player.transform.position.y);yield return null;} Keys();
        wait=Wait(1);while(wait.MoveNext()){peak=Mathf.Max(peak,player.transform.position.y);yield return null;}
        CheckResult("input-jump",peak>ground+0.5f,$"rise={peak-ground:F3}");
        // Independent collision query exercises the actual CharacterController and arena wall.
        Warp(new Vector3(14,0.1f,-10));
        var cc=player.GetComponent<CharacterController>();
        var collision=cc.Move(Vector3.right*5);
        CheckResult("wall-collision",player.transform.position.x<15.5f && (collision&CollisionFlags.Sides)!=0,$"x={player.transform.position.x:F3}; flags={collision}");
        Warp(new Vector3(5,0.1f,-5));wait=Wait(0.4f);while(wait.MoveNext())yield return null;
        var session=UnityEngine.Object.FindFirstObjectByType<Action3DSession>();int interactions=session.interactions;
        Keys(Key.E);yield return null;yield return null;Keys();wait=Wait(0.3f);while(wait.MoveNext())yield return null;
        CheckResult("input-interaction",session.interactions>interactions && !session.gate.activeSelf,$"interactions={session.interactions}; gate={session.gate.activeSelf}");
        Warp(new Vector3(0,0.1f,-6));player.transform.rotation=Quaternion.identity;
        enemy.transform.position=new Vector3(0,0.1f,5);enemy.SetActive(true);
        var enemyAuthority=enemy.GetComponent<GamekitCombatAuthority>();enemyAuthority.enabled=false;
        start=enemy.transform.position;wait=Wait(3);while(wait.MoveNext())yield return null;
        CheckResult("enemy-ai-pursuit",enemy.GetComponent<ChomperBehavior>().target==player && Vector3.Distance(start,enemy.transform.position)>0.5f,$"from={start}; to={enemy.transform.position}; target={enemy.GetComponent<ChomperBehavior>().target!=null}");
        // Freeze enemy presentation/motion only to measure authority rejects deterministically.
        enemy.GetComponent<Animator>().enabled=false;
        var agent=enemy.GetComponent<UnityEngine.AI.NavMeshAgent>();
        enemy.transform.position=player.transform.position+player.transform.forward*6;
        var health=enemy.GetComponent<Damageable>();int before=health.currentHitPoints;
        Click(true);yield return null;Click(false);wait=Wait(0.9f);while(wait.MoveNext())yield return null;
        CheckResult("out-of-range-rejected",health.currentHitPoints==before,$"before={before}; after={health.currentHitPoints}");
        enemy.transform.position=player.transform.position+player.transform.forward*1.8f;
        enemy.transform.rotation=Quaternion.LookRotation(-player.transform.forward);Physics.SyncTransforms();
        // Suppress the player's animation too: damage must remain independent from animation events.
        player.GetComponent<Animator>().enabled=false;
        before=health.currentHitPoints;Click(true);yield return null;yield return null;Click(false);wait=Wait(0.9f);while(wait.MoveNext())yield return null;
        CheckResult("damage-without-animation",health.currentHitPoints<before,$"before={before}; after={health.currentHitPoints}; hits={player.GetComponent<GamekitCombatAuthority>().confirmedHits}");
        player.GetComponent<Animator>().enabled=true;
        enemy.GetComponent<Animator>().enabled=true;enemyAuthority.enabled=true;
        agent.enabled=true; agent.Warp(enemy.transform.position);
        // Let the shipped enemy AI and authority kill and respawn the player naturally.
        var playerHealth=player.GetComponent<Damageable>();int originalMax=playerHealth.maxHitPoints;
        playerHealth.maxHitPoints=2;playerHealth.ResetDamage();
        Warp(new Vector3(0,0.1f,-6));enemy.transform.position=new Vector3(0,0.1f,-3);agent.Warp(enemy.transform.position);
        bool sawDead=false,sawRespawn=false;until=Time.time+24;
        while(Time.time<until)
        {
            sawDead|=playerHealth.currentHitPoints<=0 || player.respawning;
            if(sawDead && !player.respawning && playerHealth.currentHitPoints==playerHealth.maxHitPoints){sawRespawn=true;break;}
            yield return null;
        }
        CheckResult("enemy-damage-death-respawn",sawDead && sawRespawn,$"dead={sawDead}; respawn={sawRespawn}; hp={playerHealth.currentHitPoints}; enemyHits={enemyAuthority.confirmedHits}");
        playerHealth.maxHitPoints=originalMax;playerHealth.ResetDamage();
    }
}
