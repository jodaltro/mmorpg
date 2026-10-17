"""R8 feedback study: weapon cylinder drives palm, two-bone arm and finger contact.

Works on a fresh copy of the R7 source. Death/Hurt and all historic sources stay intact.
Blender: --python this.py -- --output Temp/HumanoidR8/SwordFeedback --quick
"""
import argparse,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector,Matrix,Quaternion
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
import render_humanoid_r8 as baseline
import procedural_grip_r7 as arm
import procedural_hand_contact_r7 as contact
import bow_pose_constraints_r7 as anatomy

def set_pose(rig,mats):
 for name,matrix in mats.items():
  rig.pose.bones[name].matrix=matrix;bpy.context.view_layer.update()

def dodge_pose(rig,idle,target,t):
 baseline.RIG=rig
 # More decisive compression and torso anticipation, without changing bone lengths.
 weight=math.sin(math.pi*t)**.72
 mats=baseline.blended(idle,target,weight)
 set_pose(rig,mats)
 spine=rig.pose.bones['spine_01'];local=spine.parent.matrix.inverted()@spine.matrix
 spine.matrix=spine.parent.matrix@local@Matrix.Rotation(math.radians(13)*math.sin(math.pi*t),4,'X')
 bpy.context.view_layer.update()
 return {b.name:b.matrix.copy() for b in rig.pose.bones}

def grip(rig,mats,camera,blade_angle=None):
 hand=mats['hand_r'];local=contact.local_socket(rig,mats,'r','cylinder')
 socket=rig.matrix_world@(hand@local)
 index=mats['index_01_r'].translation;pinky=mats['pinky_01_r'].translation
 old_axis=(rig.matrix_world.to_3x3()@(index-pinky)).normalized()
 if blade_angle is None:
  # Ready guard: upright weapon; fingers curl across its real handle axis.
  desired=Vector((0,-.18,1)).normalized()
 else:
  q=camera.matrix_world.to_quaternion();a=math.radians(blade_angle)
  desired=(q@Vector((1,0,0))*math.cos(a)+q@Vector((0,1,0))*math.sin(a)).normalized()
 rotation=old_axis.rotation_difference(desired)@(rig.matrix_world@hand).to_quaternion()
 # Adapt the weapon trajectory to anatomical reach, never stretch the arm.
 shoulder=rig.matrix_world@mats['upperarm_r'].translation
 wrist=socket-rotation@local;delta=wrist-shoulder
 reach=sum(rig.data.bones[n].length for n in ['upperarm_r','lowerarm_r'])*rig.matrix_world.to_scale().x
 correction=delta.normalized()*max(reach*.38,min(reach*.94,delta.length))-delta
 socket+=correction
 pole=rig.matrix_world@mats['lowerarm_r'].translation
 metrics=arm.pose_arm(rig,mats,socket,rotation,rig.data.bones['hand_r'].length*.45,.014,'r',local,pole)
 wrap=contact.conform_hand(rig,'r',socket,desired,.014,'cylinder')
 flexion=anatomy.elbow_angle(rig.matrix_world@mats['upperarm_r'].translation,metrics['elbow'],metrics['wrist'])
 assert metrics['socketError']<1e-4 and abs(metrics['upperLength']-metrics['expectedUpper'])<1e-5 and abs(metrics['lowerLength']-metrics['expectedLower'])<1e-5,metrics
 return socket,desired,dict(arm=metrics,fingers=wrap,elbowFlexionDegrees=flexion,handleRadius=.014,weaponReachCorrection=list(correction))

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--quick',action='store_true');p.add_argument('--no-render',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 scene,rig,src=c.open_source();baseline.RIG=rig;idle=c.pose(scene,rig,src,'Idle_Loop',0);poses=[]
 for i in range(8):
  t=i/7;target=c.pose(scene,rig,src,'Sprint_Loop',10*t);c.freeze(rig)
  mats=dodge_pose(rig,idle,target,t);poses.append(dict(action='dodge',index=i,seconds=.0275,mats=mats))
  # Restore professional retarget for the next source evaluation.
  for b in rig.pose.bones:
   for constraint in b.constraints:constraint.mute=not(constraint.type=='COPY_ROTATION' and constraint.target==src)
 if args.quick:
  for i,f in enumerate([0,6,12,24]):poses.append(dict(action='sword-study',index=i,sourceFrame=f,seconds=.15,mats=c.pose(scene,rig,src,'Sword_Attack',f)))
  poses.insert(0,dict(action='idle',index=0,seconds=.25,mats=idle))
 else:
  # Reuse exact approved world-space skeletons for locomotion, changing only the weapon arm.
  locomotion=json.loads((c.ROOT/'ArtSource/Labs/Humanoid2026/R6/Locomotion/pose-metadata.json').read_text())
  for r in locomotion:
   poses.append(dict(action=r['action'],index=r['index'],sourceFrame=r['sourceFrame'],direction=r['direction'],seconds=.125 if r['action']=='idle' else .111,mats={n:rig.matrix_world.inverted()@Matrix(m) for n,m in r['skeleton'].items()}))
  combat=json.loads((c.ROOT/'ArtSource/Labs/Humanoid2026/R6/CombatCandidate/manifest.json').read_text())
  for r in combat['frames']:
   if r['action']=='hurt':continue
   poses.append(dict(action=r['action'],index=r['index'],sourceFrame=r['sourceFrame'],direction=r['direction'],seconds=r['seconds'],mats=c.pose(scene,rig,src,r['sourceAction'],r['sourceFrame'])))
 c.freeze(rig);records=[];baked={};master=bpy.data.objects.new('R8_SwordWeaponMaster',None);scene.collection.objects.link(master)
 for view in [c.VIEWS[0],c.VIEWS[3]] if args.quick else c.VIEWS:
  c.camera_view(scene,view)
  # Blender camera-dependent wrist is intentional: runtime blade sweeps in the 2D plane.
  facing={0:-90,1:180,2:90,3:0,4:-135,5:135,6:45,7:-45}[view['unityIndex']]
  for pose in poses:
   if 'direction' in pose and pose['direction']!=view['unityIndex']:continue
   set_pose(rig,pose['mats'])
   angle=None if pose['action']!='sword-study' else facing+[-55,-25,25,55][pose['index']]
   if pose['action'].startswith('attack-'):
    phase=pose['action'][7:];u=(pose['index']+.5)/(5 if phase=='recovery' else 4)
    def lerp_angle(start,end,t):return start+((end-start+180)%360-180)*t
    angle=lerp_angle(90,facing-55,u) if phase=='preparation' else facing-55+110*u if phase=='cut' else lerp_angle(facing+55,90,u*u*(3-2*u))
   socket,axis,qa=grip(rig,pose['mats'],scene.camera,angle)
   unchanged=[n for n in pose['mats'] if not(n in ['upperarm_r','lowerarm_r','hand_r'] or n.endswith('_r') and any(n.startswith(f) for f in ['index','middle','ring','pinky','thumb']))]
   qa['maxUnaffectedBoneMatrixError']=max(abs(rig.pose.bones[n].matrix[i][j]-pose['mats'][n][i][j]) for n in unchanged for i in range(4) for j in range(4))
   qa['headClearance']=anatomy.HeadClearance().measure()
   assert qa['maxUnaffectedBoneMatrixError']<1e-5,qa
   master.location=socket;master.rotation_euler=axis.to_track_quat('Y','Z').to_euler()
   def project(point):
    q=world_to_camera_view(scene,scene.camera,point);return [q.x*128,(1-q.y)*160,q.z]
   center=project(socket);tip=project(socket+axis*.3);pelvis=project(rig.matrix_world@rig.pose.bones['pelvis'].head)
   glove=bpy.data.objects['Fitted articulated leather gloves']
   indices=anatomy.weighted_indices(glove,lambda n:n.endswith('_r') and any(n.startswith(f) for f in ['hand','index','middle','ring','pinky','thumb']))
   mesh=glove.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
   projected=[project(glove.matrix_world@v.co) for v in mesh.vertices]
   polygons=[[projected[i][:2] for i in face.vertices] for face in mesh.polygons if all(i in indices for i in face.vertices) and sum(projected[i][2] for i in face.vertices)/len(face.vertices)<center[2]-.001]
   path=out/f"{pose['action']}-{view['name']}-{pose['index']:03}.png"
   if not args.no_render:scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
   records.append(dict(action=pose['action'],index=pose['index'],view=view['name'],direction=view['unityIndex'],seconds=pose['seconds'],file=str(path),canvas=[128,160],pivotTop=[64,126],pivotUnity=[64,34],hand=center,handTip=tip,holdAngle=math.degrees(math.atan2(-(tip[1]-center[1]),tip[0]-center[0])),depth=-1 if center[2]>pelvis[2]+.03 else 1,handForegroundPolygons=polygons,qa=qa))
   baked.setdefault(pose['action']+'_'+view['name'],[]).append((pose['index'],{b.name:b.matrix.copy() for b in rig.pose.bones}))
   if len(records)%8==0:print('R8_SWORD_PROGRESS',len(records),flush=True)
 (out/'qa.json').write_text(json.dumps(dict(method='Same bow analytic arm + geometric palm socket + CCD cylindrical fingers; weapon master independent of hand',records=records,historicSourcesUntouched=True,deathAndHurtUntouched=True,artisticApproval=False),indent=2))
 rig.animation_data_create()
 for name,keys in baked.items():
  action=bpy.data.actions.new('R8_Contact_'+name);action.use_fake_user=True;rig.animation_data.action=action
  for frame,mats in keys:
   scene.frame_set(frame);set_pose(rig,mats)
   for bone in rig.pose.bones:
    bone.keyframe_insert(data_path='location',frame=frame);bone.keyframe_insert(data_path='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler',frame=frame);bone.keyframe_insert(data_path='scale',frame=frame)
 c.save_source(out/'SwordDodgeFeedback.blend');print('R8_SWORD_FEEDBACK',len(records))
if __name__=='__main__':main()
