"""Save complete editable R8 actions, retaining inactive actions with fake users."""
import bpy,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import humanoid_r8_common as c
import render_humanoid_r8 as r
def main():
 target=c.R8/'ValdoriaStatesR8.blend'
 if target.exists():raise FileExistsError(target)
 s,rig,src=c.open_source();r.RIG=rig;idle=c.pose(s,rig,src,'Idle_Loop',0);dodge=[];death=[]
 for i in range(8):dodge.append((i*.22*30/7,r.blended(idle,c.pose(s,rig,src,'Sprint_Loop',10*i/7),.75*math.sin(math.pi*i/7))))
 for f in range(73):death.append((f,c.pose(s,rig,src,'Death01',f)))
 c.freeze(rig);rig.animation_data_create()
 for name,poses in [('R8_EvasiveStep',dodge),('R8_Death01',death)]:
  action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
  for frame,matrices in poses:
   s.frame_set(int(frame),subframe=frame%1)
   for n,m in matrices.items():rig.pose.bones[n].matrix=m;bpy.context.view_layer.update()
   for bone in rig.pose.bones:
    bone.keyframe_insert(data_path='location',frame=frame);bone.keyframe_insert(data_path='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler',frame=frame);bone.keyframe_insert(data_path='scale',frame=frame)
 s.render.fps=30;s.frame_start=0;s.frame_end=72;s.frame_set(0);c.camera_view(s,c.VIEWS[0],256,224);c.save_source(target);print('R8_EDITABLE_BAKED',len(dodge),len(death))
if __name__=='__main__':main()
