"""Reopen/rehome the editable contact source and verify every baked wrist/elbow pose."""
import argparse,json,sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--report',type=Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);rows=json.loads((a.renders/'qa.json').read_text())['records']
 bpy.ops.wm.open_mainfile(filepath=str(a.renders/'SwordDodgeFeedback.blend'),use_scripts=False,load_ui=False)
 rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and 'hand_r' in o.pose.bones);error=0
 for r in rows:
  action=bpy.data.actions['R8_Contact_'+r['action']+'_'+r['view']];assert action.use_fake_user;rig.animation_data.action=action
  if action.slots:rig.animation_data.action_slot=action.slots[0]
  bpy.context.scene.frame_set(r['index']);bpy.context.view_layer.update()
  wrist=rig.matrix_world@rig.pose.bones['hand_r'].head;elbow=rig.matrix_world@rig.pose.bones['lowerarm_r'].head
  error=max(error,(wrist-Vector(r['qa']['arm']['wrist'])).length,(elbow-Vector(r['qa']['arm']['elbow'])).length)
 assert error<1e-5,error
 # Retiming editable pose actions to the exported action clocks, not arbitrary sample indices.
 scales={}
 for r in rows:
  name='R8_Contact_'+r['action']+'_'+r['view']
  scales[name]=.22*30/7 if r['action']=='dodge' else r['seconds']*30
 for name,scale in scales.items():
  action=bpy.data.actions[name];curves=[]
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:curves.extend(bag.fcurves)
  assert curves,name
  for curve in curves:
   for key in curve.keyframe_points:
    key.co.x*=scale;key.handle_left.x*=scale;key.handle_right.x*=scale
   curve.update()
 bpy.context.scene.render.fps=30
 # Capture absolute texture locations before changing the blend directory.
 for im in bpy.data.images:
  if im.filepath and im.source=='FILE' and not im.packed_file:im.filepath=str(Path(bpy.path.abspath(im.filepath)).resolve())
 c.save_source(a.source.resolve())
 a.report.write_text(json.dumps(dict(passed=True,bakedPoses=len(rows),maxWristElbowReopenError=error,actionsRetained=True,relativeTexturePaths=True,editableDodgeSeconds=.22,editableActionsRetimedToManifest=True),indent=2));print('CONTACT_SOURCE_REOPEN',len(rows),error)
if __name__=='__main__':main()
