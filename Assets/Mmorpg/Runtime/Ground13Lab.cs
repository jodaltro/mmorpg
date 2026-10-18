using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 public sealed class Ground13Lab:MonoBehaviour
 {
  [Serializable] public sealed class Surface{public Renderer renderer;public Material before,after;}
  [Serializable] public sealed class Water{public WaterSurfaceAnimator animator;public MeshRenderer renderer;public Texture2D[] before,after;}
  [SerializeField] Renderer[] originalPlants,originalRelief;
  [SerializeField] GameObject packedPlants,terraces;
  [SerializeField] Surface[] ground,relief;
  [SerializeField] Water[] waters;
  [SerializeField] Material clay;
  [SerializeField] int stage=3;
  public int Stage=>stage;
  public void Configure(Renderer[] plants,Renderer[] oldRelief,GameObject packed,GameObject newRelief,Surface[] surfaces,Surface[] reliefMaterials,Water[] water,Material clayMaterial){originalPlants=plants;originalRelief=oldRelief;packedPlants=packed;terraces=newRelief;ground=surfaces;relief=reliefMaterials;waters=water;clay=clayMaterial;Select(3);}
  public void Select(int value)
  {
   if(value<0||value>4)throw new ArgumentOutOfRangeException(nameof(value));stage=value;bool candidate=value>=2,optimized=value!=0&&value!=4;
   foreach(var r in originalPlants)if(r)r.enabled=!optimized;packedPlants.SetActive(optimized);
   foreach(var r in originalRelief)if(r)r.enabled=!candidate;terraces.SetActive(candidate);
   foreach(var s in ground)s.renderer.sharedMaterial=candidate?s.after:s.before;
   foreach(var s in relief)s.renderer.sharedMaterial=value==2?clay:s.after;
   foreach(var w in waters){w.animator.enabled=true;w.animator.Configure(w.renderer,candidate?w.after:w.before,.18f);}
  }
  public void EvidencePhase(int phase)
  {
   foreach(var w in waters){w.animator.enabled=phase<0;if(phase<0)continue;var frames=stage>=2?w.after:w.before;var block=new MaterialPropertyBlock();w.renderer.GetPropertyBlock(block);block.SetTexture("_MainTex",frames[phase%4]);w.renderer.SetPropertyBlock(block);}
  }
  void Awake()=>Select(stage);
  void Update(){var k=Keyboard.current;if(k==null)return;var keys=new[]{k.digit1Key,k.digit2Key,k.digit3Key,k.digit4Key,k.digit5Key};for(int i=0;i<keys.Length;i++)if(keys[i].wasPressedThisFrame)Select(i);}
 }
}
