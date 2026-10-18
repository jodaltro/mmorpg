using UnityEngine;
namespace Mmorpg.Runtime
{
 public sealed class ArchitectureRegionData:MonoBehaviour
 {
  [SerializeField] TextAsset source;
  [SerializeField] int width,height;
  [SerializeField] byte[] walkable;
  public int Width=>width;public int Height=>height;public TextAsset Source=>source;
  public void Configure(TextAsset data,int w,int h,byte[] mask){source=data;width=w;height=h;walkable=mask;}
  public bool CellWalkable(int x,int y)=>x>=0&&y>=0&&x<width&&y<height&&walkable[y*width+x]!=0;
 }
}
