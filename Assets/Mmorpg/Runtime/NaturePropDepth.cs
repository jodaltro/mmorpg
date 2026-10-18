using UnityEngine;
using UnityEngine.Rendering;
namespace Mmorpg.Runtime
{
 // Opaque natural volumes sort by their authored ground envelope, not PNG bounds.
 public sealed class NaturePropDepth:MonoBehaviour
 {
  [SerializeField] Transform actor;[SerializeField] SortingGroup group;[SerializeField] Vector2[] localFootprint;
  public void Configure(Transform target,SortingGroup sorting,Vector2[] outline){actor=target;group=sorting;localFootprint=outline;}
  void Awake(){if(!actor){var p=GameObject.Find("Player");if(p)actor=p.transform;}}
  public float FrontAt(float x)
  {
   float result=float.PositiveInfinity;bool found=false;
   for(int i=0;i<localFootprint.Length;i++){Vector2 a=transform.TransformPoint(localFootprint[i]),b=transform.TransformPoint(localFootprint[(i+1)%localFootprint.Length]);if(Mathf.Abs(a.x-b.x)<.00001f)continue;float t=(x-a.x)/(b.x-a.x);if(t<0||t>1)continue;result=Mathf.Min(result,Mathf.Lerp(a.y,b.y,t));found=true;}
   return found?result:transform.position.y;
  }
  void LateUpdate(){if(actor&&group)group.sortingOrder=100-Mathf.RoundToInt(FrontAt(actor.position.x)*16);}
 }
}
