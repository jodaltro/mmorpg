"""Weapon-driven two-bone IK authoring study. Never edits R5/R6 or gameplay assets.
Blender entry: blender -b --python this.py -- --output Temp/HumanoidR7/ProceduralGrip
"""
import argparse,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector,Matrix,Quaternion
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]

def solve_two_bone(shoulder,target,pole,a,b):
    delta=target-shoulder;distance=delta.length
    if distance<1e-7:raise ValueError('Target coincides with shoulder')
    axis=delta.normalized();minimum=abs(a-b)+1e-5;maximum=a+b-1e-5
    if not minimum<=distance<=maximum:raise ValueError(f'Weapon socket outside arm reach: distance={distance} lengths={a},{b} shoulder={tuple(shoulder)} wrist={tuple(target)}; never stretch anatomy')
    bend=pole-shoulder-axis*(pole-shoulder).dot(axis)
    if bend.length<1e-6:raise ValueError('Degenerate elbow pole')
    along=(a*a-b*b+distance*distance)/(2*distance)
    elbow=shoulder+axis*along+bend.normalized()*math.sqrt(max(0,a*a-along*along))
    return elbow

def pose_arm(rig,matrices,socket,rotation,palm_distance,radius,side="r",grip_local=None,elbow_pole=None):
    # World-space weapon transform is supplied independently, never parented to this chain.
    upper,lower,hand=[rig.pose.bones[n] for n in [f'upperarm_{side}',f'lowerarm_{side}',f'hand_{side}']]
    original={n:rig.matrix_world@m for n,m in matrices.items()}
    shoulder=original[upper.name].translation;pole=original[lower.name].translation if elbow_pole is None else Vector(elbow_pole)
    grip_local=Vector((0,palm_distance,0)) if grip_local is None else Vector(grip_local)
    wrist=socket-rotation@grip_local
    a=rig.data.bones[upper.name].length*rig.matrix_world.to_scale().x
    b=rig.data.bones[lower.name].length*rig.matrix_world.to_scale().x
    elbow=solve_two_bone(shoulder,wrist,pole,a,b)
    for bone,start,end in [(upper,shoulder,elbow),(lower,elbow,wrist)]:
        old=original[bone.name];old_axis=old.to_quaternion()@Vector((0,1,0));q=old_axis.rotation_difference((end-start).normalized())@old.to_quaternion()
        world=q.to_matrix().to_4x4();world.translation=start;bone.matrix=rig.matrix_world.inverted()@world;bpy.context.view_layer.update()
    world=rotation.to_matrix().to_4x4();world.translation=wrist;hand.matrix=rig.matrix_world.inverted()@world;bpy.context.view_layer.update()
    # Inherit the new wrist transform; professional local finger poses are the starting pose.
    # Radius-dependent curl is a bounded preparation, not a universal contact/collision solver.
    for name,old in matrices.items():
        bone=rig.pose.bones[name]
        if name in [upper.name,lower.name,hand.name] or not name.endswith('_'+side):continue
        if not any(name.startswith(f) for f in ['index_','middle_','ring_','pinky_','thumb_']):continue
        local=matrices[bone.parent.name].inverted()@old
        curl=math.radians(max(-12,min(12,(.02-radius)*900)))
        if 'leaf' not in name:local=local@Matrix.Rotation(curl,4,'X')
        bone.matrix=bone.parent.matrix@local;bpy.context.view_layer.update()
    actual=rig.matrix_world@(hand.matrix@grip_local)
    return dict(socketError=(actual-socket).length,upperLength=(rig.matrix_world@upper.tail-rig.matrix_world@upper.head).length,lowerLength=(rig.matrix_world@lower.tail-rig.matrix_world@lower.head).length,expectedUpper=a,expectedLower=b,handRotationErrorDegrees=math.degrees((rig.matrix_world.to_quaternion()@hand.matrix.to_quaternion()).rotation_difference(rotation).angle),elbow=list(elbow),wrist=list(wrist))

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--study',type=Path,default=ROOT/'ArtSource/Labs/Humanoid2026/R7/ProceduralGripStudy.blend');args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.output.resolve();study=args.study.resolve();
    if study.exists():raise FileExistsError(study)
    out.mkdir(parents=True,exist_ok=False)
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'ArtSource/Labs/Humanoid2026/R6/ValdoriaSwordsman8Dir.blend'))
    scene=bpy.context.scene;rig=next(o for o in bpy.data.collections['Rig'].objects if o.type=='ARMATURE' and any(b.constraints for b in o.pose.bones));src=next(c.target for b in rig.pose.bones for c in b.constraints if c.type=='COPY_ROTATION');rest=src.data.bones['pelvis'].matrix_local.translation.copy();clip=next(a for a in bpy.data.actions if a.name=='Sword_Attack' or a.name.endswith('|Sword_Attack'));src.animation_data.action=clip
    if clip.slots:src.animation_data.action_slot=clip.slots[0]
    # Capture the professional seed trajectory first. Subsequent solving reads only these matrices.
    poses={}
    for f in [6,12,24]:
        scene.frame_set(f);delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta;bpy.context.view_layer.update();poses[f]={b.name:b.matrix.copy() for b in rig.pose.bones}
    affected=['upperarm_r','lowerarm_r','hand_r']+[b.name for b in rig.pose.bones if b.name.endswith('_r') and any(b.name.startswith(t) for t in ['index_','middle_','ring_','pinky_','thumb_'])]
    for n in affected:
        for c in rig.pose.bones[n].constraints:c.mute=True
    # Pure calibration controls, not a new sword/equipment model. Marker remains hidden in renders.
    weapon=bpy.data.objects.new('ProceduralWeaponMaster',None);scene.collection.objects.link(weapon);weapon.empty_display_type='ARROWS';weapon.empty_display_size=.12
    profiles=json.loads((ROOT/'ArtSource/Labs/Humanoid2026/R7/grip-profiles.json').read_text())
    records=[];camera=scene.camera;lamp=bpy.data.objects['Upper left key']
    for label,angle in [('south',0),('east',-90)]:
        ang=math.radians(angle);camera.location=(8*math.sin(ang),-8*math.cos(ang),5.5);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler();lamp.location=(-3*math.cos(ang)+4*math.sin(ang),-3*math.sin(ang)-4*math.cos(ang),6);lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
        for profile in profiles:
            for frame,mats in poses.items():
                scene.frame_set(frame);delta=src.pose.bones['pelvis'].matrix.translation-rest;rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@delta
                for n in affected:rig.pose.bones[n].matrix=mats[n];bpy.context.view_layer.update()
                hand_world=rig.matrix_world@mats['hand_r'];palm_distance=rig.data.bones['hand_r'].length*.45
                seed_socket=hand_world@Vector((0,palm_distance,0));rotation=hand_world.to_quaternion()@Quaternion(Vector((1,0,0)),math.radians(profile['wristDegrees']))
                socket=seed_socket+hand_world.to_quaternion()@Vector(profile['socketOffsetLocal'])
                weapon.matrix_world=rotation.to_matrix().to_4x4();weapon.location=socket;bpy.context.view_layer.update()
                before={n:(rig.matrix_world@rig.pose.bones[n].matrix).copy() for n in ['pelvis','thigh_r','calf_r','spine_03']}
                metrics=pose_arm(rig,mats,weapon.matrix_world.translation,weapon.matrix_world.to_quaternion(),palm_distance,profile['handleRadius'])
                metrics['bodyUnaffected']=all(max(abs((rig.matrix_world@rig.pose.bones[n].matrix)[i][j]-m[i][j]) for i in range(4) for j in range(4))<1e-5 for n,m in before.items())
                assert metrics['socketError']<1e-4 and abs(metrics['upperLength']-metrics['expectedUpper'])<1e-4 and abs(metrics['lowerLength']-metrics['expectedLower'])<1e-4 and metrics['bodyUnaffected'],metrics
                def project(v):q=world_to_camera_view(scene,camera,v);return [q.x*128,(1-q.y)*160]
                image=out/f"{profile['id']}-{label}-{frame}.png";scene.render.filepath=str(image);bpy.ops.render.render(write_still=True)
                records.append(dict(profile=profile['id'],view=label,sourceFrame=frame,file=str(image),socket=list(socket),socketPixel=project(socket),**metrics))
    unreachableRejected=False
    try:solve_two_bone(Vector((0,0,0)),Vector((3,0,0)),Vector((0,1,0)),.25,.24)
    except ValueError:unreachableRejected=True
    # Keep a live, editable weapon-driven IK constraint in the saved study as well.
    wrist_target=bpy.data.objects.new('WeaponWristSocket',None);scene.collection.objects.link(wrist_target);wrist_target.parent=weapon;wrist_target.location=(0,-palm_distance,0)
    pole=bpy.data.objects.new('ElbowPole',None);scene.collection.objects.link(pole);pole.location=Vector(metrics['elbow'])
    lower=rig.pose.bones['lowerarm_r'];constraint=lower.constraints.new('IK');constraint.name='WeaponDrivenArm';constraint.target=wrist_target;constraint.pole_target=pole;constraint.chain_count=2;constraint.use_tail=True;constraint.use_stretch=False;constraint.iterations=128
    hand=rig.pose.bones['hand_r'];orient=hand.constraints.new('COPY_ROTATION');orient.name='WeaponDrivenWrist';orient.target=weapon;orient.owner_space='WORLD';orient.target_space='WORLD'
    desired=Vector(metrics['elbow']);best=(float('inf'),0)
    for i in range(72):
        angle=-math.pi+i*math.tau/72;constraint.pole_angle=angle;bpy.context.view_layer.update();error=(rig.matrix_world@lower.head-desired).length
        if error<best[0]:best=(error,angle)
    constraint.pole_angle=best[1];bpy.context.view_layer.update()
    live=[];saved_weapon=weapon.location.copy()
    for shift in [(0,0,0),(.006,0,0),(0,.006,0)]:
        weapon.location=saved_weapon+Vector(shift);bpy.context.view_layer.update();actual=rig.matrix_world@(hand.matrix@grip_local);error=(actual-weapon.matrix_world.translation).length;live.append(dict(weaponShift=shift,socketError=error));assert error<.002,live
    weapon.location=saved_weapon;bpy.context.view_layer.update()
    audit=dict(method='Analytic two-bone IK, weapon master -> palm/wrist -> arm; no cyclic parenting',profiles=profiles,records=records,unreachableTargetRejected=unreachableRejected,sourceAnimation='Sword_Attack',liveWeaponFollowing=live,gameplayIntegrated=False,fingerContactSolver=False,artisticApproval=False)
    (out/'qa.json').write_text(json.dumps(audit,indent=2));bpy.context.preferences.filepaths.save_version=0
    # Save only this new study. Existing approved blend is never overwritten.
    blend=study
    if blend.exists():raise FileExistsError(blend)
    for im in bpy.data.images:
        if im.filepath and im.source=='FILE':im.filepath=str(Path(bpy.path.abspath(im.filepath)).resolve())
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    for im in bpy.data.images:
        if im.filepath and im.source=='FILE':im.filepath=bpy.path.relpath(im.filepath)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    print('PROCEDURAL_GRIP_QA',len(records),'poses',unreachableRejected)
if __name__=='__main__':main()
