using UnityEngine;
using UnityEngine.Rendering;
namespace Mmorpg.Runtime
{
 public sealed class PlantVisualDepth:MonoBehaviour
 {
  [SerializeField] SortingGroup group;
  public void Configure(SortingGroup value){group=value;Refresh();}
  void LateUpdate()=>Refresh();
  void Refresh(){if(group)group.sortingOrder=100-Mathf.RoundToInt(transform.position.y*16);}
 }
}
