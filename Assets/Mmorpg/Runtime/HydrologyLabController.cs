using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 public sealed class HydrologyLabController:MonoBehaviour
 {
  [SerializeField] GameObject water;
  [SerializeField] EnvironmentRegionData environment;
  [SerializeField] Transform actor;
  public bool WaterEnabled=>water.activeSelf;
  public void Configure(GameObject root,EnvironmentRegionData data,Transform player){water=root;environment=data;actor=player;SetWater(true);}
  public void SetWater(bool enabled){water.SetActive(enabled);environment.WaterEnabled=enabled;Physics2D.SyncTransforms();}
  public void ResetPose(){var p=new Vector2(11.5f,18.5f);actor.position=p;var body=actor.GetComponent<Rigidbody2D>();body.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
  void Update(){var k=Keyboard.current;if(k==null)return;if(k.digit0Key.wasPressedThisFrame)SetWater(false);if(k.digit1Key.wasPressedThisFrame)SetWater(true);if(k.rKey.wasPressedThisFrame)ResetPose();}
 }
}
