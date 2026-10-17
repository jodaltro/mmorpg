"""Audit every native Roll/Death sample and every view without rendering or recentering."""
import bpy,json,math,sys
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
def main():
 s,rig,src=c.open_source();out=c.ROOT/'Temp/HumanoidR8/Audit';out.mkdir(parents=True,exist_ok=False);meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render];records=[];catalog={}
 for name in ['Roll','Death01','Jump_Start','Jump_Loop','Jump_Land','Sprint_Loop']:
  clip=c.action(src,name);catalog[name]=dict(frames=list(clip.frame_range),seconds=(clip.frame_range[1]-clip.frame_range[0])/30)
 for name in ['Roll','Death01']:
  clip=c.action(src,name)
  for f in range(int(clip.frame_range[0]),int(clip.frame_range[1])+1):
   c.pose(s,rig,src,name,f);deps=bpy.context.evaluated_depsgraph_get();points=[];owners=[]
   for o in meshes:
    mesh=o.evaluated_get(deps).data;v=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',v);v=v.reshape(-1,3);m=np.array(o.matrix_world);points.append(v@m[:3,:3].T+m[:3,3]);owners.extend([o.name]*len(v))
   points=np.concatenate(points);owners=np.array(owners);pelvis=rig.matrix_world@rig.pose.bones['pelvis'].head
   for view in c.VIEWS:
    c.camera_view(s,view);cam=s.camera;q=world_to_camera_view(s,cam,Vector());rot=cam.matrix_world.to_quaternion();right=np.array(rot@Vector((1,0,0)));up=np.array(rot@Vector((0,1,0)));x=q.x*128+points@right*(160/2.4);y=(1-q.y)*160-points@up*(160/2.4);bad=(x<2)|(x>126)|(y<2)|(y>158)
    records.append(dict(action=name,view=view['name'],direction=view['unityIndex'],frame=f,bounds=[float(x.min()),float(y.min()),float(x.max()),float(y.max())],outsideMeshes=sorted(set(owners[bad])),pelvis=list(pelvis),rigRoot=list(rig.location)))
 rows=[]
 for name in ['Roll','Death01']:
  for view in c.VIEWS:
   rs=[r for r in records if r['action']==name and r['view']==view['name']];bounds=[min(r['bounds'][0] for r in rs),min(r['bounds'][1] for r in rs),max(r['bounds'][2] for r in rs),max(r['bounds'][3] for r in rs)]
   rows.append(dict(action=name,view=view['name'],direction=view['unityIndex'],samples=len(rs),bounds=bounds,requiredPadding=[max(0,math.ceil(4-bounds[0])),max(0,math.ceil(4-bounds[1])),max(0,math.ceil(bounds[2]-124)),max(0,math.ceil(bounds[3]-156))],outsideMeshes=sorted({n for r in rs for n in r['outsideMeshes']})))
 bounds=[min(r['bounds'][0] for r in rows),min(r['bounds'][1] for r in rows),max(r['bounds'][2] for r in rows),max(r['bounds'][3] for r in rows)]
 result=dict(source='R7 ProceduralGripStudy: original professional retarget restored, R7 weapon IK muted',catalog=catalog,rows=rows,frames=records,totalSamples=len(records),nativeCanvas=[128,160],projectionPixelsPerMeter=160/2.4,rootPolicy='rig transform constant; pelvis animation remains local visual motion; no physical root motion',unionBounds=bounds)
 (c.R8/'spatial-audit.json').write_text(json.dumps(result,indent=2));print('R8_AUDIT',json.dumps(dict(catalog=catalog,union=bounds,table=rows)))
if __name__=='__main__':main()
