"""Verify editable baked source against rendered hand coordinates and fixed bone lengths."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
def main():
 bpy.ops.wm.open_mainfile(filepath=str(c.R8/'ValdoriaStatesR8.blend'),use_scripts=False,load_ui=False);s=bpy.context.scene;rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and 'upperarm_r' in o.pose.bones);rows=[]
 for action,action_name in [('dodge','R8_EvasiveStep'),('death','R8_Death01')]:
  clip=next(a for a in bpy.data.actions if a.name==action_name);rig.animation_data.action=clip
  if clip.slots:rig.animation_data.action_slot=clip.slots[0]
  manifest=json.loads((c.R8/action/'manifest.json').read_text());max_pixel=0;max_length=0;feet=[]
  for r in manifest['frames']:
   t=r['index']*.22*30/7 if action=='dodge' else r['sourceFrame'];s.frame_set(int(t),subframe=t%1);bpy.context.view_layer.update();c.camera_view(s,next(v for v in c.VIEWS if v['unityIndex']==r['direction']),*r['canvas']);p=world_to_camera_view(s,s.camera,rig.matrix_world@rig.pose.bones['hand_r'].head);max_pixel=max(max_pixel,math.dist([p.x*r['canvas'][0],(1-p.y)*r['canvas'][1]],r['hand'][:2]))
   max_length=max(max_length,max(abs((rig.matrix_world@b.tail-rig.matrix_world@b.head).length-b.bone.length) for b in rig.pose.bones));feet.extend([(rig.matrix_world@rig.pose.bones[n].head).z for n in ['foot_l','foot_r','ball_l','ball_r']]);assert rig.location.length<1e-6
  assert max_pixel<.001 and max_length<.00001,(action,max_pixel,max_length)
  rows.append(dict(action=action,samples=len(manifest['frames']),maxHandProjectionErrorPixels=max_pixel,maxBoneLengthError=max_length,footBoneHeightRange=[min(feet),max(feet)],fixedRigRoot=True,bakedActionRange=list(clip.frame_range)))
 (c.ROOT/'Docs/Validation/HumanoidStatesR8/editable-source-qa.json').write_text(json.dumps(dict(passed=True,rows=rows),indent=2));print('R8_EDITABLE_SOURCE',json.dumps(rows))
if __name__=='__main__':main()
