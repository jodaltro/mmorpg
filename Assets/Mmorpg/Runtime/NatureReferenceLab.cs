using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 public sealed class NatureReferenceLab:MonoBehaviour
 {
  [Serializable] public sealed class Surface{public Renderer renderer;public Material before,baseLayer,transitions,final;}
  [SerializeField] GameObject beforePlants,afterPlants,rocks;
  [SerializeField] Surface[] surfaces;
  [SerializeField] SpriteRenderer access;[SerializeField] Sprite beforeAccess,afterAccess;
  [SerializeField] ArchitectureRegionData navigation;[SerializeField] TextAsset beforeData,afterData;
  [SerializeField] byte[] beforeMask,afterMask;[SerializeField] int stage=3;
  public int Stage=>stage;public GameObject RefinedPlants=>afterPlants;public GameObject Rocks=>rocks;
  public void Configure(GameObject oldPlants,GameObject refinedPlants,GameObject stoneRoot,Surface[] surfaceBindings,SpriteRenderer path,Sprite pathAfter,ArchitectureRegionData nav,TextAsset oldNav,TextAsset newNav,byte[] oldMask,byte[] newMask)
  {beforePlants=oldPlants;afterPlants=refinedPlants;rocks=stoneRoot;surfaces=surfaceBindings;access=path;beforeAccess=path.sprite;afterAccess=pathAfter;navigation=nav;beforeData=oldNav;afterData=newNav;beforeMask=oldMask;afterMask=newMask;Select(3);}
  public void Select(int value)
  {
   if(value<0||value>3)throw new ArgumentOutOfRangeException(nameof(value));stage=value;bool refined=value>0;beforePlants.SetActive(!refined);afterPlants.SetActive(refined);rocks.SetActive(refined);
   foreach(var s in surfaces)if(s.renderer)s.renderer.sharedMaterial=value==0?s.before:value==1?s.baseLayer:value==2?s.transitions:s.final;
   access.sprite=refined?afterAccess:beforeAccess;navigation.Configure(refined?afterData:beforeData,256,192,refined?afterMask:beforeMask);Physics2D.SyncTransforms();
  }
  void Awake()=>Select(stage);
  void Update(){var k=Keyboard.current;if(k==null)return;if(k.digit1Key.wasPressedThisFrame)Select(0);if(k.digit2Key.wasPressedThisFrame)Select(1);if(k.digit3Key.wasPressedThisFrame)Select(2);if(k.digit4Key.wasPressedThisFrame)Select(3);}
 }
}
