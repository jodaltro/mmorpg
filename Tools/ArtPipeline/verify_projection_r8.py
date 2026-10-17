"""Blender proof that padded canvases translate coordinates but never rescale the body."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
def main():
 s,rig,src=c.open_source();c.pose(s,rig,src,'Idle_Loop',0);points=[rig.matrix_world@b.head for b in rig.pose.bones];rows=[]
 for view in c.VIEWS:
  c.camera_view(s,view);old=[]
  for p in points:q=world_to_camera_view(s,s.camera,p);old.append((q.x*128,(1-q.y)*160))
  c.camera_view(s,view,256,224);error=0
  for p,a in zip(points,old):q=world_to_camera_view(s,s.camera,p);error=max(error,abs(q.x*256-a[0]-64),abs((1-q.y)*224-a[1]-32))
  assert error<.0001,error
  rows.append(dict(direction=view['unityIndex'],points=len(points),maximumPixelError=error,logicalPivotDifference=[64,32],bodyScaleChanged=False))
 result=dict(passed=True,rows=rows,ppu=32,projectionPixelsPerMeter=160/2.4,rootOrColliderChanged=False)
 (c.ROOT/'Docs/Validation/HumanoidStatesR8/projection-proof.json').write_text(json.dumps(result,indent=2));print('R8_PROJECTION',max(r['maximumPixelError'] for r in rows))
if __name__=='__main__':main()
