using UnityEngine;
namespace Mmorpg.Runtime
{
 // Authored subcell navigation samples; exact continuous boundaries live in the referenced contract.
 public sealed class EnvironmentRegionData:MonoBehaviour
 {
  [SerializeField] TextAsset hydrologyContract;
  [SerializeField] int width,height;
  [SerializeField] float stepUnits=.25f;
  [SerializeField] byte[] sampleFlags;
  public bool WaterEnabled {get;set;}=true;
  public TextAsset HydrologyContract=>hydrologyContract;
  public int Width=>width;
  public int Height=>height;
  public float StepUnits=>stepUnits;
  public void Configure(TextAsset contract,int w,int h,float step,byte[] flags){hydrologyContract=contract;width=w;height=h;stepUnits=step;sampleFlags=flags;}
  public byte SampleCell(int column,int row)=>column<0||row<0||column>=width||row>=height?(byte)3:sampleFlags[row*width+column];
  public bool CellWalkable(int column,int row){int flags=SampleCell(column,row);return (flags&1)==0&&(!WaterEnabled||(flags&2)==0);}
  // flags: solid=1, water blocked=2, surface water=4, wetland=8. Actor clearance is NOT included.
 }
}
