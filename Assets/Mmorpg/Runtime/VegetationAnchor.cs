using UnityEngine;
namespace Mmorpg.Runtime
{
 public sealed class VegetationAnchor:MonoBehaviour
 {
  [SerializeField] string instanceId,species;
  [SerializeField] int variant;
  [SerializeField] float footprintRadius;
  public string InstanceId=>instanceId;public string Species=>species;public int Variant=>variant;public float FootprintRadius=>footprintRadius;
  public void Configure(string id,string kind,int silhouette,float radius){instanceId=id;species=kind;variant=silhouette;footprintRadius=radius;}
 }
}
