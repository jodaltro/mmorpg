"""Render true diagonal views from the approved R5 .blend, without rebuilding the costume."""
import bpy,json,math,argparse,sys,hashlib
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2];R5=ROOT/'ArtSource/Labs/Humanoid2026/R5';R6=ROOT/'ArtSource/Labs/Humanoid2026/R6'
VIEWS=[('south',0,0),('west',1,90),('north',2,180),('east',3,-90),('southwest',4,45),('northwest',5,135),('northeast',6,-135),('southeast',7,-45)]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--audit-only',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bpy.ops.wm.open_mainfile(filepath=str(R5/'ValdoriaSwordsman.blend'));scene=bpy.context.scene
 rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and any(b.constraints for b in o.pose.bones));source=next(c.target for b in rig.pose.bones for c in b.constraints if c.type=='COPY_ROTATION');camera=scene.camera;lamp=bpy.data.objects.get('Upper left key')
 actions={name:next(x for x in bpy.data.actions if x.name==name or x.name.endswith('|'+name)) for name in ['Idle_Loop','Walk_Loop','Sword_Attack','Sword_Idle','Roll','Hit_Chest','Hit_Head','Death01']}
 audit={n:dict(action=x.name,frameRange=list(x.frame_range),seconds=(x.frame_range[1]-x.frame_range[0])/30) for n,x in actions.items()};(R6/'animation-audit.json').write_text(json.dumps(audit,indent=2));print('ACTION_AUDIT',json.dumps(audit))
 if a.audit_only:return
 records=[];source_rest=source.data.bones['pelvis'].matrix_local.translation.copy()
 for name,d,deg in VIEWS:
  angle=math.radians(deg)
  if d<4:continue
  camera.location=(8*math.sin(angle),-8*math.cos(angle),5.5);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();lamp.location=(-3*math.cos(angle)+4*math.sin(angle),-3*math.sin(angle)-4*math.cos(angle),6);lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
  for action,count in [('Idle_Loop',1),('Walk_Loop',12)]:
   clip=actions[action];source.animation_data.action=clip
   if clip.slots:source.animation_data.action_slot=clip.slots[0]
   first,last=clip.frame_range
   for i in range(count):
    frame=first+(last-first)*i/count;scene.frame_set(int(frame),subframe=frame%1);delta=source.pose.bones['pelvis'].matrix.translation-source_rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update()
    def project(v):
     q=world_to_camera_view(scene,camera,v);return [q.x*128,(1-q.y)*160,q.z]
    basename=('idle' if count==1 else 'walk')+'_'+name;file=out/(basename+'_'+str(i).zfill(3)+'.png');scene.render.filepath=str(file);bpy.ops.render.render(write_still=True)
    records.append(dict(clip=basename,direction=d,index=i,sourceAction=action,sourceFrame=frame,file=str(file),hand=project(rig.matrix_world@rig.pose.bones['hand_r'].head),handTip=project(rig.matrix_world@rig.pose.bones['hand_r'].tail),feet={n:project(rig.matrix_world@rig.pose.bones[n].head) for n in ['foot_l','foot_r','ball_l','ball_r']},skeleton={n:[list(row) for row in rig.matrix_world@b.matrix] for n,b in rig.pose.bones.items()},cameraDegrees=deg))
 (out/'diagonal-poses.json').write_text(json.dumps(records,indent=2));(R6/'views.json').write_text(json.dumps([dict(name=n,unityIndex=d,cameraDegrees=angle,observedOrientation=n) for n,d,angle in VIEWS],indent=2))
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(R6/'ValdoriaSwordsman8Dir.blend'),compress=True)
 print('R6_DIAGONALS_COMPLETE',len(records))
if __name__=='__main__':main()
