"""Render professional combat in-place on R6 without changing locomotion or physics."""
import bpy,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2];R6=ROOT/'ArtSource/Labs/Humanoid2026/R6'
# Attack source intervals are authored against existing preparation/cut/recovery clocks.
ACTIONS=[('attack-preparation','Sword_Attack',[0,3,6,9],.1),('attack-cut','Sword_Attack',[10,12,14,16],.035),('attack-recovery','Sword_Attack',[18,24,32,40,46],.032),('dodge','Roll',[44*i/11 for i in range(12)],.022),('hurt','Hit_Chest',[10*i/6 for i in range(7)],.05),('death','Death01',[3*i for i in range(25)],.1)]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--quick',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bpy.ops.wm.open_mainfile(filepath=str(R6/'ValdoriaSwordsman8Dir.blend'));scene=bpy.context.scene;rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and any(b.constraints for b in o.pose.bones));src=next(c.target for b in rig.pose.bones for c in b.constraints if c.type=='COPY_ROTATION');rest=src.data.bones['pelvis'].matrix_local.translation.copy();origin=rig.location.copy();camera=scene.camera;lamp=bpy.data.objects['Upper left key'];records=[]
 views=json.loads((R6/'views.json').read_text())
 if a.quick:views=[views[1]]
 for view in views:
  angle=math.radians(view['cameraDegrees']);camera.location=(8*math.sin(angle),-8*math.cos(angle),5.5);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();lamp.location=(-3*math.cos(angle)+4*math.sin(angle),-3*math.sin(angle)-4*math.cos(angle),6);lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
  for action,name,samples,seconds in ACTIONS:
   if not a.quick and action in ['dodge','death']:continue
   clip=next(c for c in bpy.data.actions if c.name==name or c.name.endswith('|'+name));src.animation_data.action=clip
   if clip.slots:src.animation_data.action_slot=clip.slots[0]
   if a.quick:
    if action not in ['death','dodge']:continue
    samples=samples[::max(1,len(samples)//4)]
   # Planar source displacement is removed only for Roll/Death. Original local joint motion remains.
   initial=None
   if name in ['Roll','Death01']:
    rig.location=origin;scene.frame_set(0);delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update();initial=(rig.matrix_world@rig.pose.bones['pelvis'].head).copy()
   for i,frame in enumerate(samples):
    rig.location=origin;scene.frame_set(int(frame),subframe=frame%1);delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update();removed=Vector()
    if initial is not None:
     now=rig.matrix_world@rig.pose.bones['pelvis'].head;removed=Vector((now.x-initial.x,now.y-initial.y,0));rig.location=origin-removed;bpy.context.view_layer.update()
    def project(v):
     q=world_to_camera_view(scene,camera,v);return [q.x*128,(1-q.y)*160,q.z]
    hand=rig.pose.bones['hand_r'];p=project(rig.matrix_world@hand.head);tip=project(rig.matrix_world@hand.tail);pelvis=project(rig.matrix_world@rig.pose.bones['pelvis'].head)
    file=out/(action+'_'+view['name']+'_'+str(i).zfill(3)+'.png');scene.render.filepath=str(file);bpy.ops.render.render(write_still=True)
    records.append(dict(action=action,direction=view['unityIndex'],view=view['name'],index=i,sourceAction=name,sourceFrame=frame,seconds=seconds,file=str(file),hand=p,handTip=tip,handAngle=math.degrees(math.atan2(-(tip[1]-p[1]),tip[0]-p[0])),depth=-1 if p[2]>pelvis[2]+.03 else 1,rootDisplacementRemoved=list(removed)))
 (out/'combat-frames.json').write_text(json.dumps(records,indent=2));print('R6_COMBAT_RENDERED',len(records))
if __name__=='__main__':main()
