using UnityEngine;
namespace Mmorpg.Runtime
{
 // Replays preauthored frames. Never changes shoreline, collision or hydrology in Play.
 public sealed class WaterSurfaceAnimator:MonoBehaviour
 {
  [SerializeField] MeshRenderer surface;
  [SerializeField] Texture2D[] frames;
  [SerializeField] float frameSeconds=.18f;
  MaterialPropertyBlock properties;
  int last=-1;
  public int FrameIndex=>last;
  public void Configure(MeshRenderer renderer,Texture2D[] images,float duration){surface=renderer;frames=images;frameSeconds=duration;}
  void OnEnable(){last=-1;}
  void Update()
  {
   if(surface==null||frames==null||frames.Length==0)return;
   int frame=Mathf.FloorToInt(Time.time/frameSeconds)%frames.Length;if(frame==last)return;
   if(properties==null)properties=new MaterialPropertyBlock();surface.GetPropertyBlock(properties);properties.SetTexture("_MainTex",frames[frame]);surface.SetPropertyBlock(properties);last=frame;
  }
 }
}
