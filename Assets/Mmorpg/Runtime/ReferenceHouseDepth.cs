using UnityEngine;
using UnityEngine.Rendering;
namespace Mmorpg.Runtime
{
 public sealed class ReferenceHouseDepth:MonoBehaviour
 {
  [SerializeField] Transform actor;[SerializeField] SpriteRenderer actorBody;[SerializeField] SortingGroup group;
  [SerializeField] Vector2[] groundOutline;[SerializeField] SpriteRenderer[] volumes;[SerializeField] byte[] roles;
  public bool CutawayActive {get;private set;} public float RoofAlpha {get;private set;}=1;public float DepthLineY {get;private set;}
  public void Configure(Transform target,SpriteRenderer body,SortingGroup sorting,Vector2[] outline,SpriteRenderer[] renderers,byte[] volumeRoles){actor=target;actorBody=body;group=sorting;groundOutline=outline;volumes=renderers;roles=volumeRoles;}
  public float FrontAt(float worldX){float result=float.PositiveInfinity;bool found=false;for(int i=0;i<groundOutline.Length;i++){var a=groundOutline[i];var b=groundOutline[(i+1)%groundOutline.Length];if(Mathf.Abs(a.x-b.x)<.00001f)continue;float t=(worldX-a.x)/(b.x-a.x);if(t<0||t>1)continue;float y=Mathf.Lerp(a.y,b.y,t);result=Mathf.Min(result,y);found=true;}return found?result:transform.position.y;}
  void LateUpdate(){DepthLineY=FrontAt(actor.position.x);group.sortingOrder=100-Mathf.RoundToInt(DepthLineY*16);bool behind=actor.position.y>DepthLineY+.08f;CutawayActive=false;RoofAlpha=1;for(int i=0;i<volumes.Length;i++){bool overlap=behind&&roles[i]!=0&&volumes[i].bounds.Intersects(actorBody.bounds);float target=overlap?(roles[i]==1?.18f:.28f):1;var c=volumes[i].color;c.a=Mathf.MoveTowards(c.a,target,Time.deltaTime*5);volumes[i].color=c;if(overlap)CutawayActive=true;if(roles[i]==1)RoofAlpha=Mathf.Min(RoofAlpha,c.a);}}
 }
}
