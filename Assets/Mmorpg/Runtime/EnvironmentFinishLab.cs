using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 // Presentation-only comparison. Collider and navigation producers are shared.
 public sealed class EnvironmentFinishLab:MonoBehaviour
 {
  [Serializable] public sealed class Binding {public Renderer renderer;public Material before,after;}
  [Serializable] public sealed class Water {public WaterSurfaceAnimator animator;public MeshRenderer renderer;public Texture2D[] before,after;}
  [SerializeField] Binding[] materials;
  [SerializeField] Renderer[] oldPlants;
  [SerializeField] GameObject[] newGraphics;
  [SerializeField] Water[] waters;
  [SerializeField] bool refined=true;
  public bool Refined=>refined;
  public void Configure(Binding[] bindings,Renderer[] previousPlants,GameObject[] graphics,Water[] water){materials=bindings;oldPlants=previousPlants;newGraphics=graphics;waters=water;Select(true);}
  public void Select(bool value)
  {
   refined=value;foreach(var b in materials)if(b.renderer)b.renderer.sharedMaterial=value?b.after:b.before;
   foreach(var r in oldPlants)if(r)r.enabled=!value;
   foreach(var g in newGraphics)if(g)g.SetActive(value);
   foreach(var w in waters)if(w.animator)w.animator.Configure(w.renderer,value?w.after:w.before,.18f);
  }
  void Awake()=>Select(refined);
  void Update(){var k=Keyboard.current;if(k==null)return;if(k.digit1Key.wasPressedThisFrame)Select(false);if(k.digit2Key.wasPressedThisFrame)Select(true);}
 }
}
