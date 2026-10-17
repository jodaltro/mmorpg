"""Augment the full spatial audit with the actual projected bone extremities."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
def main():
 p=c.R8/'spatial-audit.json';data=json.loads(p.read_text());s,rig,src=c.open_source();groups={}
 for r in data['frames']:groups.setdefault((r['action'],r['frame']),[]).append(r)
 for (action,f),rows in groups.items():
  c.pose(s,rig,src,action,f)
  for r in rows:
   view=next(v for v in c.VIEWS if v['unityIndex']==r['direction']);c.camera_view(s,view);outside=[];extremities={}
   for b in rig.pose.bones:
    if not any(n in b.name.lower() for n in ['hand','foot','ball','head','lowerarm','calf']):continue
    q=world_to_camera_view(s,s.camera,rig.matrix_world@b.tail);point=[q.x*128,(1-q.y)*160];extremities[b.name]=point
    if point[0]<2 or point[0]>126 or point[1]<2 or point[1]>158:outside.append(b.name)
   r['outsideBoneExtremities']=outside;r['projectedExtremities']=extremities
 for row in data['rows']:row['outsideBoneExtremities']=sorted({b for r in data['frames'] if r['action']==row['action'] and r['direction']==row['direction'] for b in r['outsideBoneExtremities']})
 p.write_text(json.dumps(data,indent=2));print('R8_EXTREMITIES_AUDITED',len(data['frames']))
if __name__=='__main__':main()
