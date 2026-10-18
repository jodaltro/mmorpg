using UnityEngine;
namespace Mmorpg.Runtime
{
 public sealed class VegetationRegionData:MonoBehaviour
 {
  [System.Serializable] sealed class Layer{public TextAsset source;public byte[] blocked;}
  [SerializeField] EnvironmentRegionData environment;
  [SerializeField] Layer[] layers;
  public int ActiveComposition {get;private set;}=0;
  public void Configure(EnvironmentRegionData data,TextAsset[] sources,byte[][] masks){environment=data;layers=new Layer[sources.Length];for(int i=0;i<layers.Length;i++)layers[i]=new Layer{source=sources[i],blocked=masks[i]};}
  public void Select(int index)=>ActiveComposition=Mathf.Clamp(index,-1,layers.Length-1);
  public bool CellWalkable(int x,int y){if(!environment.CellWalkable(x,y))return false;if(ActiveComposition<0)return true;return layers[ActiveComposition].blocked[y*environment.Width+x]==0;}
  public TextAsset Source=>ActiveComposition<0?null:layers[ActiveComposition].source;
 }
}
