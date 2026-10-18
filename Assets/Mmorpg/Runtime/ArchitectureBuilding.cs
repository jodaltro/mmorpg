using UnityEngine;
namespace Mmorpg.Runtime
{
 public sealed class ArchitectureBuilding:MonoBehaviour
 {
  [SerializeField] string buildingId,archetype;
  [SerializeField] Vector2 entrance,approach;
  public string Id=>buildingId;public string Archetype=>archetype;public Vector2 Entrance=>entrance;public Vector2 Approach=>approach;
  public void Configure(string id,string kind,Vector2 door,Vector2 access){buildingId=id;archetype=kind;entrance=door;approach=access;}
 }
}
