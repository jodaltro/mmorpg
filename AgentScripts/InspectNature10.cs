using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class InspectNature10
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play");var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(scene.path!=NatureReference10Importer.Scene||scene.isDirty)throw new IOException("Requires clean nature scene");
  foreach(var p in new[]{"ExportV3/","SurfaceFinal/","PlacementFinal/"})NatureReference10Importer.Verify(NatureReference10Importer.Source+p);
  var lab=UnityEngine.Object.FindAnyObjectByType<NatureReferenceLab>();var nav=UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>();int[] mismatch=new int[2];int initial=lab.Stage;
  for(int i=0;i<2;i++){lab.Select(i==0?0:3);Physics2D.SyncTransforms();for(int y=0;y<nav.Height;y++)for(int x=0;x<nav.Width;x++)if((Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,48-(y+.5f)*.25f),1<<8)!=null)==nav.CellWalkable(x,y))mismatch[i]++;}lab.Select(initial);
  var textures=AssetDatabase.FindAssets("t:Texture2D",new[]{NatureReference10Importer.Art.TrimEnd('/')}).Select(g=>AssetDatabase.GUIDToAssetPath(g)).Select(p=>new{path=p,importer=(TextureImporter)AssetImporter.GetAtPath(p)}).ToArray();
  var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();var rr=house.GetComponentsInChildren<SpriteRenderer>(true);var allTextures=EditorUtility.CollectDependencies(scene.GetRootGameObjects().Cast<UnityEngine.Object>().ToArray()).OfType<Texture2D>().Distinct().ToArray();
  var result=new{scene=scene.path,playing=false,clean=!scene.isDirty,stage=lab.Stage,navigationSamples=nav.Width*nav.Height,beforeMismatch=mismatch[0],afterMismatch=mismatch[1],onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,oneCamera=UnityEngine.Object.FindObjectsByType<Camera>().Length==1,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("Nature10QA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),timeScale=Time.timeScale,temporaryResolutionActive=SessionState.GetBool("Nature10.FixedView",false),comparisonResidentTextureBytes=allTextures.Sum(t=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)),houseTextures=rr.Where(r=>r.sprite).Select(r=>AssetDatabase.GetAssetPath(r.sprite.texture)).Distinct().ToArray(),houseColliderVertices=house.GetComponents<PolygonCollider2D>().Sum(p=>p.points.Length),houseDepths=house.GetComponentsInChildren<ReferenceHouseDepth>().Length,textures=textures.Select(t=>new{t.path,point=t.importer.filterMode==FilterMode.Point,mips=t.importer.mipmapEnabled,uncompressed=t.importer.textureCompression==TextureImporterCompression.Uncompressed,ppu=t.importer.spritePixelsPerUnit})};
  File.WriteAllText("Docs/Validation/ValdoriaNature10/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
