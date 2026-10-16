"""Audit professional combat poses on the approved costume before adopting them."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2];R6=ROOT/'ArtSource/Labs/Humanoid2026/R6'
def main():
 bpy.ops.wm.open_mainfile(filepath=str(R6/'ValdoriaSwordsman8Dir.blend'));s=bpy.context.scene;rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and any(b.constraints for b in o.pose.bones));src=next(c.target for b in rig.pose.bones for c in b.constraints if c.type=='COPY_ROTATION');rest=src.data.bones['pelvis'].matrix_local.translation.copy();camera=s.camera;out=ROOT/'Temp/HumanoidR6/CombatAudit';out.mkdir(exist_ok=False)
 actions=['Sword_Attack','Sword_Idle','Roll','Hit_Chest','Hit_Head','Death01'];report={}
 for action in actions:
  clip=next(a for a in bpy.data.actions if a.name==action or a.name.endswith('|'+action));src.animation_data.action=clip
  if clip.slots:src.animation_data.action_slot=clip.slots[0]
  first,last=clip.frame_range;records=[]
  for frame in range(int(first),int(last)+1):
   s.frame_set(frame);delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update()
   records.append(dict(frame=frame,hand=list(rig.matrix_world@rig.pose.bones['hand_r'].head),pelvis=list(rig.matrix_world@rig.pose.bones['pelvis'].head),footLeft=list(rig.matrix_world@rig.pose.bones['foot_l'].head)))
  report[action]=dict(seconds=(last-first)/30,frames=records)
  # Representative front/side sequences for honest artistic inspection, original camera contract.
  for angle,label in [(0,'south'),(math.pi/2,'west')]:
   camera.location=(8*math.sin(angle),-8*math.cos(angle),5.5);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();lamp=bpy.data.objects['Upper left key'];lamp.location=(-3*math.cos(angle)+4*math.sin(angle),-3*math.sin(angle)-4*math.cos(angle),6);lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
   for i in range(5):
    f=first+(last-first)*i/4;s.frame_set(int(f),subframe=f%1);delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update();s.render.filepath=str(out/(action+'_'+label+'_'+str(i)+'.png'));bpy.ops.render.render(write_still=True)
 (R6/'combat-source-audit.json').write_text(json.dumps(report,indent=2));print('COMBAT_AUDIT_COMPLETE')
if __name__=='__main__':main()
