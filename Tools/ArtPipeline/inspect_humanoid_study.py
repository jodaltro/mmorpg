"""Blender-only inspection of CC0 humanoids; no production scene or body edits.

Example: blender -b --python Tools/ArtPipeline/inspect_humanoid_study.py -- --output Temp/HumanoidResearch/Preview --frames 12
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'ArtSource/Labs/Humanoid2026'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--frames', type=int, default=0)
    parser.add_argument('--metadata-only', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {}
    for sex in ['Male', 'Female']:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.fps = 30
        bpy.ops.import_scene.gltf(filepath=str(LAB / f'Sources/BaseModels/Superhero_{sex}_FullBody.gltf'))
        targets = list(scene.objects)
        rig = next(o for o in targets if o.type == 'ARMATURE')
        meshes = [o for o in targets if o.type == 'MESH' and o.find_armature() == rig]
        rest = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
        height = max(v.z for v in rest) - min(v.z for v in rest)
        bpy.ops.import_scene.gltf(filepath=str(LAB / 'Sources/Animations/UAL1_Standard.glb'))
        imported = [o for o in scene.objects if o not in targets]
        source = next(o for o in imported if o.type == 'ARMATURE')
        for o in imported:
            if o.type == 'MESH':
                o.hide_render = True
        for track in source.animation_data.nla_tracks:
            track.mute = True
        matched = set(rig.pose.bones.keys()) & set(source.pose.bones.keys())
        assert len(matched) == 65
        for name in matched:
            constraint = rig.pose.bones[name].constraints.new('COPY_ROTATION')
            constraint.target = source
            constraint.subtarget = name
            constraint.target_space = 'WORLD'
            constraint.owner_space = 'WORLD'
        # Keep target bind lengths. Transfer the source pelvis motion as a delta, not its rest proportions.
        source_rest = source.data.bones['pelvis'].matrix_local.translation.copy()
        target_rest = rig.data.bones['pelvis'].matrix_local.translation.copy()
        actions = {a.name: a for a in bpy.data.actions}
        names = list(actions)
        find = lambda name: next(a for n, a in actions.items() if n == name or n.endswith('|'+name))
        idle, walk = find('Idle_Loop'), find('Walk_Loop')
        report[sex] = dict(bones=len(rig.pose.bones), mappedBones=len(matched), restHeightMeters=height,
                           meshNames=[o.name for o in meshes], availableActions=names,
                           idleFrames=list(idle.frame_range), walkFrames=list(walk.frame_range),
                           retarget='WORLD bone rotation constraints, target bind lengths retained; experimental preview')
        camera_data = bpy.data.cameras.new('Study Camera')
        camera = bpy.data.objects.new('Study Camera', camera_data)
        scene.collection.objects.link(camera)
        camera.location = (0, -8, 5.5)
        camera.rotation_euler = (Vector((0, 0, .9)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera_data.type = 'ORTHO'
        camera_data.ortho_scale = 2.4
        scene.camera = camera
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 32
        scene.cycles.use_denoising = False
        scene.render.resolution_x, scene.render.resolution_y = 128, 160
        scene.render.resolution_percentage = 100
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        scene.view_settings.view_transform = 'Standard'
        scene.world = bpy.data.worlds.new('Study World')
        scene.world.use_nodes = True
        scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.65, .7, .8, 1)
        scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .6
        light = bpy.data.lights.new('Upper left key', 'AREA')
        light.energy, light.shape, light.size = 450, 'DISK', 4
        lamp = bpy.data.objects.new('Upper left key', light)
        scene.collection.objects.link(lamp)
        lamp.location = (-3, -4, 6)
        lamp.rotation_euler = (Vector((0, 0, 1)) - lamp.location).to_track_quat('-Z', 'Y').to_euler()
        records = []
        views = [] if args.metadata_only else [('south', 0), ('west', -math.pi/2), ('north', math.pi), ('east', math.pi/2)]
        # Rotate the camera around the actor, keeping lighting fixed in camera space.
        for direction, angle in views:
            camera.location = (8*math.sin(angle), -8*math.cos(angle), 5.5)
            camera.rotation_euler = (Vector((0, 0, .9)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
            lamp.location = (-3*math.cos(angle)+4*math.sin(angle), -3*math.sin(angle)-4*math.cos(angle), 6)
            lamp.rotation_euler = (Vector((0, 0, 1)) - lamp.location).to_track_quat('-Z', 'Y').to_euler()
            for action, count in [(idle, 1), (walk, args.frames)]:
                if count == 0 and action == walk:
                    continue
                source.animation_data.action = action
                if action.slots:
                    source.animation_data.action_slot = action.slots[0]
                first, last = action.frame_range
                for index in range(count):
                    frame = first + (last-first) * index / count
                    scene.frame_set(int(frame), subframe=frame % 1)
                    # Root/pelvis displacement is retained without replacing target body dimensions.
                    delta = source.pose.bones['pelvis'].matrix.translation - source_rest
                    rig.pose.bones['pelvis'].location = rig.data.bones['pelvis'].matrix_local.to_3x3().inverted() @ delta
                    bpy.context.view_layer.update()
                    name = ('idle' if action == idle else 'walk') + '_' + direction
                    filename = f'{sex}/{name}_{index:03}.png'
                    (output / sex).mkdir(exist_ok=True)
                    scene.render.filepath = str(output / filename)
                    bpy.ops.render.render(write_still=True)
                    records.append(dict(clip=name, index=index, sourceAction=action.name,
                                        sourceFrame=frame, file=filename))
        report[sex]['frames'] = records
        report[sex]['sourcePelvisRest'] = list(source_rest)
        report[sex]['targetPelvisRest'] = list(target_rest)
    (output / 'inspection.json').write_text(json.dumps(report, indent=2) + '\n')
    print('HUMANOID_STUDY_COMPLETE', str(output))


if __name__ == '__main__':
    main()
