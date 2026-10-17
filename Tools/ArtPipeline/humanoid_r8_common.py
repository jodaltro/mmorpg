"""R8 source adapter: professional retarget, fixed rig root, unchanged outfit meshes."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
R8=ROOT/'ArtSource/Labs/Humanoid2026/R8'
VIEWS=json.loads((ROOT/'ArtSource/Labs/Humanoid2026/R6/views.json').read_text())
def open_source():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'ArtSource/Labs/Humanoid2026/R7/ProceduralGripStudy.blend'),use_scripts=False,load_ui=False)
 scene=bpy.context.scene;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=2;scene.render.use_persistent_data=False;scene.render.use_simplify=True;scene.cycles.texture_limit_render='1024'
 rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and 'upperarm_r' in o.pose.bones)
 src=next(c.target for b in rig.pose.bones for c in b.constraints if c.type=='COPY_ROTATION' and c.target and c.target.type=='ARMATURE')
 for b in rig.pose.bones:
  b.matrix_basis=Matrix.Identity(4)
  for c in b.constraints:c.mute=not(c.type=='COPY_ROTATION' and c.target==src)
 rig.animation_data_clear();rig.location=(0,0,0)
 return scene,rig,src
def action(src,name):
 clip=next(a for a in bpy.data.actions if a.name==name or a.name.endswith('|'+name));src.animation_data.action=clip
 if clip.slots:src.animation_data.action_slot=clip.slots[0]
 return clip
def pose(scene,rig,src,name,frame):
 action(src,name);scene.frame_set(int(frame),subframe=frame%1);delta=src.pose.bones['pelvis'].matrix.translation-src.data.bones['pelvis'].matrix_local.translation
 rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update()
 return {b.name:b.matrix.copy() for b in rig.pose.bones}
def camera_view(scene,view,width=128,height=160):
 a=math.radians(view['cameraDegrees']);camera=scene.camera;camera.location=(8*math.sin(a),-8*math.cos(a),5.5);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
 lamp=bpy.data.objects['Upper left key'];lamp.location=(-3*math.cos(a)+4*math.sin(a),-3*math.sin(a)-4*math.cos(a),6);lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
 scene.render.resolution_x=width;scene.render.resolution_y=height;scene.render.resolution_percentage=100;camera.data.ortho_scale=2.4*max(width,height)/160;bpy.context.view_layer.update()
def apply_blend(rig,idle,target,weight,pelvis_weight=1):
 for b in rig.pose.bones:
  parent=b.parent.name if b.parent else None
  a=idle[parent].inverted()@idle[b.name] if parent else idle[b.name]
  z=target[parent].inverted()@target[b.name] if parent else target[b.name]
  loc,rot,scale=a.decompose();tl,tr,ts=z.decompose()
  if b.name=='pelvis':loc=loc.lerp(tl,weight*pelvis_weight)
  local=Matrix.LocRotScale(loc,rot.slerp(tr,weight),scale);b.matrix=b.parent.matrix@local if parent else local;bpy.context.view_layer.update()
def freeze(rig):
 for b in rig.pose.bones:
  for c in b.constraints:c.mute=True
def save_source(path):
 if path.exists():raise FileExistsError(path)
 for im in bpy.data.images:
  if im.filepath and im.source=='FILE' and not im.packed_file:im.filepath=str(Path(bpy.path.abspath(im.filepath)).resolve())
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
 for im in bpy.data.images:
  if im.filepath and im.source=='FILE' and not im.packed_file:im.filepath=bpy.path.relpath(im.filepath)
 bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
