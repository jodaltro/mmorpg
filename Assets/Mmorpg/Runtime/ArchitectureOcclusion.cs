using UnityEngine;
namespace Mmorpg.Runtime
{
 public sealed class ArchitectureOcclusion:MonoBehaviour
 {
  [SerializeField] Transform actor;
  [SerializeField] SpriteRenderer[] roof,upperWalls;
  [SerializeField] Bounds visualBounds;
  public bool Occluding {get;private set;}
  public float RoofAlpha=>roof.Length==0?1:roof[0].color.a;
  public void Configure(Transform target,SpriteRenderer[] roofParts,SpriteRenderer[] walls,Bounds bounds){actor=target;roof=roofParts;upperWalls=walls;visualBounds=bounds;}
  void LateUpdate(){var feet=actor.position;var head=feet+Vector3.up*1.5f;Occluding=feet.y>transform.position.y+.15f&&visualBounds.Contains(head);Apply(roof,Occluding?.18f:1);Apply(upperWalls,Occluding?.28f:1);}
  static void Apply(SpriteRenderer[] renderers,float alpha){foreach(var r in renderers){var c=r.color;c.a=Mathf.MoveTowards(c.a,alpha,Time.deltaTime*5);r.color=c;}}
 }
}
