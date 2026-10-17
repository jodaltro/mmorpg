"""R8: compare evasion candidates; render padded states with constant pixel density."""
import bpy,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c

def blended(idle,target,w):
 # Build hierarchical matrices, preserving local translations/scale and bone lengths.
 result={}
 for n,a in idle.items():
  b=RIG.pose.bones[n];p=b.parent.name if b.parent else None;la=idle[p].inverted()@a if p else a;lz=target[p].inverted()@target[n] if p else target[n];loc,rot,scale=la.decompose();tl,tr,ts=lz.decompose()
  if n=='pelvis':loc=loc.lerp(tl,w)
  local=Matrix.LocRotScale(loc,rot.slerp(tr,w),scale);result[n]=result[p]@local if p else local
 return result
def main():
 global RIG
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--candidates',action='store_true');p.add_argument('--only-death',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 s,RIG,src=c.open_source();idle=c.pose(s,RIG,src,'Idle_Loop',0);poses=[]
 if a.candidates:
  for i in range(8):
   t=i/7;poses.append(dict(action='A-roll-window',mats=c.pose(s,RIG,src,'Roll',8+10*t),sourceAction='Roll continuous 8..18 (rejected incomplete recovery)',sourceFrame=8+10*t,seconds=.0275,index=i))
 for i in range(8):
  t=i/7;target=c.pose(s,RIG,src,'Sprint_Loop',10*t);poses.append(dict(action='B-evasive-step' if a.candidates else 'dodge',mats=blended(idle,target,.75*math.sin(math.pi*t)),sourceAction='Sprint_Loop 0..10, local rotation blend from/to professional idle; no stretch',sourceFrame=10*t,seconds=.0275,index=i))
 if a.candidates:
  for i in range(8):
   t=i/7;target=c.pose(s,RIG,src,'Jump_Start' if t<.5 else 'Jump_Land',16 if t<.5 else 12);poses.append(dict(action='C-evasive-hop',mats=blended(idle,target,.7*math.sin(math.pi*t)),sourceAction='Jump_Start/Jump_Land representative poses blended; candidate only',sourceFrame=16 if t<.5 else 12,seconds=.0275,index=i))
 else:
  for i,f in enumerate(range(0,73,3)):poses.append(dict(action='death',mats=c.pose(s,RIG,src,'Death01',f),sourceAction='Death01 full interval 0..72 / 30fps, local pelvis translation retained',sourceFrame=f,seconds=.1 if f<72 else 1/30,index=i))
 c.freeze(RIG);records=[];views=[c.VIEWS[0],c.VIEWS[3]] if a.candidates else c.VIEWS
 for view in views:
  for pose in poses:
   if a.only_death and pose['action']!='death':continue
   large=pose['action']=='death';w,h=(256,224) if large else (192,192) if pose['action']=='A-roll-window' else (128,160);L=(w-128)//2;T=(h-160)//2
   c.camera_view(s,view,w,h)
   for n,m in pose['mats'].items():RIG.pose.bones[n].matrix=m;bpy.context.view_layer.update()
   def project(v):q=world_to_camera_view(s,s.camera,v);return [q.x*w,(1-q.y)*h,q.z]
   hand=RIG.pose.bones['hand_r'];hp=project(RIG.matrix_world@hand.head);tip=project(RIG.matrix_world@hand.tail);pelvis=project(RIG.matrix_world@RIG.pose.bones['pelvis'].head)
   file=out/f"{pose['action']}-{view['name']}-{pose['index']:03}.png";s.render.filepath=str(file);bpy.ops.render.render(write_still=True)
   records.append(dict(action=pose['action'],direction=view['unityIndex'],view=view['name'],sourceAction=pose['sourceAction'],sourceFrame=pose['sourceFrame'],index=pose['index'],seconds=pose['seconds'],file=str(file),canvas=[w,h],padding=[L,T,L,T],pivotTop=[64+L,126+T],pivotUnity=[64+L,34+T],hand=hp,handTip=tip,holdAngle=math.degrees(math.atan2(-(tip[1]-hp[1]),tip[0]-hp[0])),depth=-1 if hp[2]>pelvis[2]+.03 else 1,rigRoot=list(RIG.location),orthoScale=s.camera.data.ortho_scale,projectionPixelsPerMeter=max(w,h)/s.camera.data.ortho_scale))
 (out/'frames.json').write_text(json.dumps(records,indent=2))
 if not a.candidates:
  # Editable, baked actions share a 30fps source timeline; original professional actions remain.
  for name,items in [('R8_EvasiveStep',[x for x in poses if x['action']=='dodge'])]:
   action=bpy.data.actions.new(name);action.use_fake_user=True;RIG.animation_data_create();RIG.animation_data.action=action
   for pose in items:
    f=pose['index']*.22*30/7
    s.frame_set(int(f),subframe=f%1)
    for n,m in pose['mats'].items():RIG.pose.bones[n].matrix=m;bpy.context.view_layer.update()
    for bone in RIG.pose.bones:
     bone.keyframe_insert(data_path='location',frame=f);bone.keyframe_insert(data_path='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler',frame=f);bone.keyframe_insert(data_path='scale',frame=f)
  action=bpy.data.actions.new('R8_Death01');action.use_fake_user=True;RIG.animation_data.action=action
  for pose in [x for x in poses if x['action']=='death']:
   s.frame_set(int(pose['sourceFrame']))
   for n,m in pose['mats'].items():RIG.pose.bones[n].matrix=m;bpy.context.view_layer.update()
   for bone in RIG.pose.bones:
    bone.keyframe_insert(data_path='location',frame=pose['sourceFrame']);bone.keyframe_insert(data_path='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler',frame=pose['sourceFrame']);bone.keyframe_insert(data_path='scale',frame=pose['sourceFrame'])
  s.render.fps=30;s.frame_start=0;s.frame_end=72;s.frame_set(0);c.save_source(c.R8/'ValdoriaStatesR8.blend')
 print('R8_RENDERED',len(records),'candidate' if a.candidates else 'final')
if __name__=='__main__':main()
