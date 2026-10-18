using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 public sealed class VegetationLabController:MonoBehaviour
 {
  [SerializeField] GameObject[] compositions;
  [SerializeField] VegetationRegionData data;
  [SerializeField] Transform actor;
  public int Style {get;private set;}
  public bool Before {get;private set;}
  public void Configure(GameObject[] roots,VegetationRegionData region,Transform player){compositions=roots;data=region;actor=player;Select(0);}
  public void Select(int style,bool before=false){Style=Mathf.Clamp(style,0,2);Before=before;for(int i=0;i<compositions.Length;i++)compositions[i].SetActive(!before&&i==Style);data.Select(before?-1:Style);Physics2D.SyncTransforms();}
  public void ResetPose(){var p=new Vector2(11.5f,18.5f);actor.position=p;var b=actor.GetComponent<Rigidbody2D>();b.position=p;b.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
  void Update(){var k=Keyboard.current;if(k==null)return;if(k.digit0Key.wasPressedThisFrame)Select(Style,true);if(k.digit1Key.wasPressedThisFrame)Select(0);if(k.digit2Key.wasPressedThisFrame)Select(1);if(k.digit3Key.wasPressedThisFrame)Select(2);if(k.rKey.wasPressedThisFrame)ResetPose();}
 }
}
