using System;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;
using Mmorpg.Runtime;

public static class InspectValdoriaR10
{
    public static string Scene()
    {
        var scene = SceneManager.GetActiveScene();
        var camera = Camera.main;
        var renderers = UnityEngine.Object.FindObjectsByType<SpriteRenderer>();
        var lines = renderers.Where(r => !r.name.StartsWith("Grass") && !r.name.StartsWith("Flower") && !r.name.StartsWith("Ground"))
            .OrderBy(r => r.sortingOrder).ThenBy(r => r.name).Take(100)
            .Select(r => $"{r.name}|{r.transform.position.x:F2},{r.transform.position.y:F2},{r.transform.position.z:F2}|order={r.sortingOrder}|sprite={(r.sprite ? r.sprite.name : "none")}");
        var player = GameObject.Find("Player");
        return $"scene={scene.path}; dirty={scene.isDirty}; camera={(camera ? camera.name + " size=" + camera.orthographicSize + " pos=" + camera.transform.position : "none")}; player={(player ? player.name + " pos=" + player.transform.position : "none")}; renderers={renderers.Length}\n" + string.Join("\n", lines);
    }

    public static string Character()
    {
        var player=GameObject.Find("Player");
        var anim=player?player.GetComponent<ProductionSpriteAnimator>():null;
        var set=anim?new SerializedObject(anim).FindProperty("art").objectReferenceValue as ProductionCharacterSet:null;
        var sword=player?player.GetComponentInChildren<SwordSwing>(true):null;
        var source=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/ValdoriaContactR8.asset");
        var paths=set==null?Array.Empty<string>():set.clips.SelectMany(c=>c.frames).Where(f=>f.sprite!=null).Select(f=>AssetDatabase.GetAssetPath(f.sprite.texture)).Distinct().OrderBy(p=>p).ToArray();
        var sample=source==null?"missing":$"{source.characterId} clips={source.clips.Length} frames={source.clips.Sum(c=>c.frames.Length)} dirs={source.clips.Select(c=>c.direction).Distinct().Count()}";
        var details=player==null?Array.Empty<string>():player.GetComponentsInChildren<SpriteRenderer>(true).Select(r=>$"renderer={r.name} enabled={r.enabled} active={r.gameObject.activeSelf} sprite={r.sprite?.name} order={r.sortingOrder} path={(r.sprite?AssetDatabase.GetAssetPath(r.sprite.texture):"")}").ToArray();
        var states=player?.GetComponent<ProductionCharacterStates>();var sync=player?.GetComponent<ProductionVisualSync>();
        return $"player={player}; animator={anim} enabled={anim?.enabled}; currentSet={(set==null?"none":set.characterId)} currentClips={set?.clips.Length}; sword={(sword==null?"none":sword.name)}; states={states?.enabled}; visualSync={sync?.enabled}; directionAnim={player?.GetComponent<DirectionalSpriteAnimation>()?.enabled}; gameplayAnim={player?.GetComponent<GameplaySpriteAnimator>()?.enabled}\nsource={sample}\nsourceTextureCount={(source==null?0:source.clips.SelectMany(c=>c.frames).Where(f=>f.sprite!=null).Select(f=>AssetDatabase.GetAssetPath(f.sprite.texture)).Distinct().Count())}\nsourceTextures={string.Join(";",source==null?Array.Empty<string>():source.clips.SelectMany(c=>c.frames).Where(f=>f.sprite!=null).Select(f=>AssetDatabase.GetAssetPath(f.sprite.texture)).Distinct().OrderBy(p=>p))}\ncurrentTextures={string.Join(";",paths)}\nrenderers={string.Join("\n",details)}";
    }

    public static string PlayState()
    {
        var player=GameObject.Find("Player");var cam=Camera.main;var animator=player?.GetComponent<ProductionSpriteAnimator>();var body=animator?.Body;
        return $"playing={EditorApplication.isPlaying} frame={Time.frameCount} player={player?.transform.position} camera={cam?.transform.position} screenPlayer={cam?.WorldToScreenPoint(player.transform.position)} bodyWorld={body?.transform.position} bodyLocal={body?.transform.localPosition} bodyScale={body?.transform.lossyScale} bodySprite={body?.sprite?.name} state={animator?.State} cameraTarget={cam?.GetComponent<CameraFollow>()?.name}";
    }

    public static string MapAudit()
    {
        var ti=AssetImporter.GetAtPath("Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png") as TextureImporter;
        var map=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png").OfType<Sprite>().ToArray();
        var follow=Camera.main?.GetComponent<CameraFollow>();var so=follow==null?null:new SerializedObject(follow);var bounds=so?.FindProperty("worldBounds").rectValue;
        return $"sceneDirty={SceneManager.GetActiveScene().isDirty} importMode={ti?.spriteImportMode} sprites={map.Length} map={string.Join(";",map.Select(s=>s.name+":"+s.rect+":ppu="+s.pixelsPerUnit+":bounds="+s.bounds.size))} cameraBounds={bounds}";
    }
}
