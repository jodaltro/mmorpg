using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 // References only. No generation, physics changes or shader tint in Play.
 public sealed class VisualUnificationLab:MonoBehaviour
 {
  [Serializable] public sealed class SpriteChoice
  {
   public SpriteRenderer renderer;public Sprite original,materialRevision,vegetationRevision,weathered;public int familyIndex=-1;
  }
  [Serializable] public sealed class MaterialChoice
  {
   public Renderer renderer;public Material[] original,materialRevision,vegetationRevision;
  }
  [SerializeField] SpriteChoice[] sprites=Array.Empty<SpriteChoice>();
  [SerializeField] MaterialChoice[] materials=Array.Empty<MaterialChoice>();
  [SerializeField] int stage=2;[SerializeField] bool weathered;
  [SerializeField] string[] linkedScenes=Array.Empty<string>();
  [SerializeField] TextAsset catalog;[SerializeField] TextAsset[] recipes=Array.Empty<TextAsset>(),selections=Array.Empty<TextAsset>();
  [Serializable] sealed class Selection{public string variant="";}
  public TextAsset Catalog=>catalog;public TextAsset[] Recipes=>recipes;public TextAsset[] Selections=>selections;
  public int Stage=>stage;public bool Weathered=>weathered;
  public void Configure(SpriteChoice[] s,MaterialChoice[] m,string[] scenes){sprites=s;materials=m;linkedScenes=scenes;Apply(2,false);}
  public void ConfigureCatalog(TextAsset c,TextAsset[] r,TextAsset[] s){catalog=c;recipes=r;selections=s;foreach(var item in sprites){var b=item.renderer.GetComponentInParent<ArchitectureBuilding>();item.familyIndex=b?(b.Id.Contains("castle")?2:b.Id.Contains("barn")?1:0):-1;}}
  public void ApplySelectedRecipe()
  {
   if(!catalog||selections.Length!=3)throw new InvalidOperationException("Missing validated recipe selection");
   Apply(2);weathered=false;
   foreach(var item in sprites)if(item.familyIndex>=0){bool aged=JsonUtility.FromJson<Selection>(selections[item.familyIndex].text).variant=="weathered";if(aged&&item.weathered){item.renderer.sprite=item.weathered;weathered=true;}}
  }
  public void Apply(int value,bool aged=false)
  {
   if(value<0||value>2)throw new ArgumentOutOfRangeException(nameof(value));stage=value;weathered=aged;
   foreach(var e in sprites)if(e.renderer)e.renderer.sprite=aged&&value>0&&e.weathered?e.weathered:value==0?e.original:value==1?e.materialRevision:e.vegetationRevision;
   foreach(var e in materials)if(e.renderer)e.renderer.sharedMaterials=value==0?e.original:value==1?e.materialRevision:e.vegetationRevision;
  }
  void Awake()=>Apply(stage,weathered);
  void Update()
  {
   var k=Keyboard.current;if(k==null)return;
   if(k.digit1Key.wasPressedThisFrame)Apply(0);if(k.digit2Key.wasPressedThisFrame)Apply(1);if(k.digit3Key.wasPressedThisFrame)Apply(2);
   if(k.vKey.wasPressedThisFrame)Apply(stage,!weathered);
   if(k.pKey.wasPressedThisFrame)ApplySelectedRecipe();
   int link=k.f1Key.wasPressedThisFrame?0:k.f2Key.wasPressedThisFrame?1:k.f3Key.wasPressedThisFrame?2:k.f4Key.wasPressedThisFrame?3:-1;
   if(link>=0&&link<linkedScenes.Length)
   {
    #if UNITY_EDITOR
    UnityEditor.SceneManagement.EditorSceneManager.LoadSceneInPlayMode(linkedScenes[link],new UnityEngine.SceneManagement.LoadSceneParameters(UnityEngine.SceneManagement.LoadSceneMode.Single));
    #endif
   }
  }
 }
}
