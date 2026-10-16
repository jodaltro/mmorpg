"""Two-hand weapon-driven bow study using an inspected CC0 animated bow; no archery gameplay."""
import bpy,json,math,sys,argparse,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
PROFILE=json.loads((ROOT/'ArtSource/Labs/Humanoid2026/R7/bow-anatomical-profile-v4.json').read_text())
spec=importlib.util.spec_from_file_location('grip_solver',ROOT/'Tools/ArtPipeline/procedural_grip_r7.py');solver=importlib.util.module_from_spec(spec);spec.loader.exec_module(solver)
contact_spec=importlib.util.spec_from_file_location('hand_contact',ROOT/'Tools/ArtPipeline/procedural_hand_contact_r7.py');contact=importlib.util.module_from_spec(contact_spec);contact_spec.loader.exec_module(contact)
qa_spec=importlib.util.spec_from_file_location('bow_constraints',ROOT/'Tools/ArtPipeline/bow_pose_constraints_r7.py');constraints=importlib.util.module_from_spec(qa_spec);qa_spec.loader.exec_module(constraints)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--study',type=Path,default=ROOT/'ArtSource/Labs/Humanoid2026/R7/BowGripStudyV4.blend');p.add_argument('--quick',action='store_true');p.add_argument('--no-render',action='store_true');p.add_argument('--composite-only',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 if a.study.exists():raise FileExistsError(a.study)
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'ArtSource/Labs/Humanoid2026/R6/ValdoriaSwordsman8Dir.blend'),use_scripts=False,load_ui=False);scene=bpy.context.scene;scene.cycles.device='CPU';scene.render.use_simplify=True;scene.cycles.texture_limit_render='1024';scene.render.threads_mode='FIXED';scene.render.threads=2;scene.render.use_persistent_data=False;rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and any(b.constraints for b in o.pose.bones));src=next(c.target for b in rig.pose.bones for c in b.constraints if c.type=='COPY_ROTATION');clip=next(c for c in bpy.data.actions if c.name=='Idle_Loop' or c.name.endswith('|Idle_Loop'));src.animation_data.action=clip
 if clip.slots:src.animation_data.action_slot=clip.slots[0]
 scene.frame_set(0);rest=src.data.bones['pelvis'].matrix_local.translation;delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update();mats={b.name:b.matrix.copy() for b in rig.pose.bones}
 # A fixed professional idle body isolates the experiment; the weapon animation drives both arms.
 for b in rig.pose.bones:
  for c in b.constraints:c.mute=True
 rig.animation_data_clear()
 for name,m in mats.items():rig.pose.bones[name].matrix=m;bpy.context.view_layer.update()
 with bpy.data.libraries.load(str(ROOT/'ArtSource/Labs/Humanoid2026/R7/Sources/Bow/bow.blend'),link=False) as (data,loaded):loaded.objects=['Cube','Armature'];loaded.images=['Bow','Bow_NRM.png','Bow_SPEC.png']
 bow=next(o for o in loaded.objects if o.type=='MESH');bowrig=next(o for o in loaded.objects if o.type=='ARMATURE')
 for o in loaded.objects:scene.collection.objects.link(o)
 dx,dy,_=Vector(PROFILE['drawAxis']).normalized();bs=PROFILE['bowScale']
 master=bpy.data.objects.new('BowWeaponMaster',None);scene.collection.objects.link(master);master.matrix_world=Matrix(((dx,0,dy,0),(dy,0,-dx,0),(0,1,0,0),(0,0,0,1)))@Matrix.Diagonal((bs,bs,bs,1));master.location=PROFILE['bowPosition'];bowrig.parent=master;bowrig.matrix_parent_inverse=Matrix.Identity(4)
 # Retarget draw depth to this body without changing bow size or stretching human bones.
 bow_locations={}
 for f in range(1,38):
  scene.frame_set(f);bow_locations[f]={b.name:b.location.copy() for b in bowrig.pose.bones}
 bowrig.animation_data_clear()
 for f,locations in bow_locations.items():
  scene.frame_set(f)
  for name,location in locations.items():bowrig.pose.bones[name].location=location*PROFILE['drawTranslationScale'];bowrig.pose.bones[name].keyframe_insert(data_path='location',frame=f)
 # Migrate the legacy diffuse map to a current shader while preserving packed source images.
 material=bow.data.materials[0];texture=next(im for im in loaded.images if im.name=='Bow');assert texture.size[0]>0;material.use_nodes=True;nodes=material.node_tree.nodes;nodes.clear();output=nodes.new('ShaderNodeOutputMaterial');shader=nodes.new('ShaderNodeBsdfPrincipled');image=nodes.new('ShaderNodeTexImage');image.image=texture;material.node_tree.links.new(image.outputs['Color'],shader.inputs['Base Color']);material.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface']);shader.inputs['Roughness'].default_value=.75
 human=[o for o in scene.objects if o.type=='MESH' and o!=bow and not o.hide_render];camera=scene.camera;lamp=bpy.data.objects['Upper left key'];records=[];rotation=Vector((-dx,-dy,0)).to_track_quat('Y','Z')
 pull_samples=[]
 for sample_frame in range(1,38):
  scene.frame_set(sample_frame);bpy.context.view_layer.update();evaluated=bow.evaluated_get(bpy.context.evaluated_depsgraph_get());pull_samples.append(sum((bow.matrix_world@evaluated.data.vertices[i].co for i in range(68,76)),Vector())/8)
 draw_axis=(master.matrix_world.to_3x3()@Vector((1,0,0))).normalized();release_frame=max(range(37),key=lambda i:pull_samples[i].dot(draw_axis))+1
 head_clearance=constraints.HeadClearance()
 for view,deg in [('south',0),('east',-90)]:
  previous_elbow=None
  angle=math.radians(deg);camera.location=(8*math.sin(angle),-8*math.cos(angle),5.5);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();lamp.location=(-3*math.cos(angle)+4*math.sin(angle),-3*math.sin(angle)-4*math.cos(angle),6);lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
  for frame in ([1,18,30,34] if a.quick else range(1,38)):
   scene.frame_set(frame);bpy.context.view_layer.update();mesh=bow.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[bow.matrix_world@v.co for v in mesh.data.vertices]
   grip=sum((points[i] for i in [84,85,86,87]),Vector())/4;string=sum((points[i] for i in range(68,76)),Vector())/8
   hand_target=string.copy()
   if frame>release_frame:
    u=(frame-release_frame)/(37-release_frame);u=u*u*(3-2*u);hand_target=pull_samples[release_frame-1].lerp(pull_samples[0],u)
   left_local=contact.local_socket(rig,mats,'l','cylinder');right_local=contact.local_socket(rig,mats,'r','pinch');left=solver.pose_arm(rig,mats,grip,rotation,rig.data.bones['hand_l'].length*.45,.018,'l',left_local,(rig.matrix_world@mats['upperarm_l']).translation+Vector(PROFILE['leftElbowPoleOffset']));right=solver.pose_arm(rig,mats,hand_target,rotation,rig.data.bones['hand_r'].length*.45,.006,'r',right_local,(rig.matrix_world@mats['upperarm_r']).translation+Vector(PROFILE['rightElbowPoleOffset']))
   gap=.003 if frame<=release_frame else .003+.008*min(1,(frame-release_frame)/3)
   wrap=contact.conform_hand(rig,'l',grip,Vector((0,0,1)),.02,'cylinder');pinch=contact.conform_hand(rig,'r',hand_target,Vector((0,0,1)),gap,'pinch')
   clearance=head_clearance.measure();flexion=constraints.elbow_angle((rig.matrix_world@mats['upperarm_r']).translation,right['elbow'],right['wrist'])
   assert clearance['minSignedHeadSurfaceDistance']>=PROFILE['minimumSampledHeadClearance'],(frame,clearance)
   assert flexion<=PROFILE['maximumRightElbowFlexionDegrees'],(frame,flexion)
   if previous_elbow is not None and not a.quick:assert (Vector(right['elbow'])-previous_elbow).length<=PROFILE['maximumAdjacentElbowStep'],frame
   previous_elbow=Vector(right['elbow'])
   if view=='south':
    for bone in rig.pose.bones:
     bone.keyframe_insert(data_path='location',frame=frame);bone.keyframe_insert(data_path='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler',frame=frame);bone.keyframe_insert(data_path='scale',frame=frame)
   assert max(left['socketError'],right['socketError'])<1e-4,(left,right)
   composite_file=out/f'composite-{view}-{frame:03}.png';body_file=out/f'body-{view}-{frame:03}.png';weapon_file=out/f'bow-{view}-{frame:03}.png'
   if not a.no_render:
    scene.render.filepath=str(composite_file);bpy.ops.render.render(write_still=True)
    if not a.quick and not a.composite_only:
     bow.hide_render=True;scene.render.filepath=str(body_file);bpy.ops.render.render(write_still=True);bow.hide_render=False
     for o in human:o.hide_render=True
     scene.render.filepath=str(weapon_file);bpy.ops.render.render(write_still=True)
     for o in human:o.hide_render=False
   def project(v):q=world_to_camera_view(scene,camera,v);return [q.x*128,(1-q.y)*160,q.z]
   records.append(dict(view=view,direction=0 if view=='south' else 3,sourceFrame=frame,releaseFrame=release_frame,stringContact=frame<=release_frame,handTarget=list(hand_target),headClearance=clearance,rightElbowFlexionDegrees=flexion,composite=str(composite_file),wrap=wrap,pinch=pinch,leftGripLocal=list(left_local),rightGripLocal=list(right_local),body=str(body_file) if body_file.exists() else None,weapon=str(weapon_file) if weapon_file.exists() else None,grip=list(grip),string=list(string),gripPixel=project(grip),stringPixel=project(string),left=left,right=right))
 scene.render.fps=24;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=37;scene.frame_set(1)
 study=a.study.resolve()
 if study.exists():raise FileExistsError(study)
 for im in bpy.data.images:
  if im.filepath and im.source=='FILE' and not im.packed_file:im.filepath=str(Path(bpy.path.abspath(im.filepath)).resolve())
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(study),compress=True)
 for im in bpy.data.images:
  if im.filepath and im.source=='FILE' and not im.packed_file:im.filepath=bpy.path.relpath(im.filepath)
 bpy.ops.wm.save_as_mainfile(filepath=str(study),compress=True)
 (out/'qa.json').write_text(json.dumps(dict(records=records,profile=PROFILE,model='Animated Longbow / djonvincent / CC0-1.0',method='Bow mesh drives grip and draw; hand releases at peak draw and recovers independently',gripVertices=[84,85,86,87],stringVertices=list(range(68,76)),bodyScaleUnchanged=True,bowScale=bs,separateBodyAndWeaponImages=not(a.quick or a.composite_only or a.no_render),archeryGameplay=False,fullArcherAnimation=False),indent=2));print('BOW_TWO_HAND_IK',len(records),'poses')
if __name__=='__main__':main()
