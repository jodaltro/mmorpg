using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 public sealed class TerrainMaterialLabController:MonoBehaviour
 {
  [SerializeField] GameObject[] previousVisuals;
  [SerializeField] GameObject generatedVisuals;
  [SerializeField] Material[] stageMaterials;
  [SerializeField] Material[] faceMaterials;
  [SerializeField] MeshRenderer[] surfaces;
  [SerializeField] MeshRenderer[] faces;
  [SerializeField] Transform actor;
  [SerializeField] TextAsset composition;
  public int Style {get;private set;}
  public int Stage {get;private set;}=2;
  public bool Before {get;private set;}
  public TextAsset Composition=>composition;
  public void Configure(GameObject[] previous,GameObject generated,Material[] materials,Material[] sides,MeshRenderer[] tops,MeshRenderer[] walls,Transform player,TextAsset data)
  {previousVisuals=previous;generatedVisuals=generated;stageMaterials=materials;faceMaterials=sides;surfaces=tops;faces=walls;actor=player;composition=data;Select(0,2);}
  public void Select(int style,int stage,bool before=false)
  {
   Style=Mathf.Clamp(style,0,2);Stage=Mathf.Clamp(stage,0,2);Before=before;
   foreach(var go in previousVisuals)go.SetActive(before);generatedVisuals.SetActive(!before);
   int i=Style*3+Stage;foreach(var r in surfaces)r.sharedMaterial=stageMaterials[i];foreach(var r in faces)r.sharedMaterial=faceMaterials[i];
  }
  public void ResetPose()
  {var p=new Vector3(33.5f,23.5f,0);actor.position=p;var b=actor.GetComponent<Rigidbody2D>();if(b!=null){b.position=p;b.linearVelocity=Vector2.zero;}Physics2D.SyncTransforms();}
  void Update()
  {
   var k=Keyboard.current;if(k==null)return;
   if(k.digit0Key.wasPressedThisFrame)Select(Style,Stage,true);
   if(k.digit1Key.wasPressedThisFrame)Select(0,Stage);
   if(k.digit2Key.wasPressedThisFrame)Select(1,Stage);
   if(k.digit3Key.wasPressedThisFrame)Select(2,Stage);
   if(k.bKey.wasPressedThisFrame)Select(Style,0);
   if(k.tKey.wasPressedThisFrame)Select(Style,1);
   if(k.fKey.wasPressedThisFrame)Select(Style,2);
  }
 }
}
