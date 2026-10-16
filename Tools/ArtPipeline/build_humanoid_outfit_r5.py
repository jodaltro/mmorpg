"""R5: fitted professional CC0 wardrobe on the frozen Quaternius body/pose pipeline."""
import bpy, json, math, sys, argparse, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
LAB=ROOT/'ArtSource/Labs/Humanoid2026'
R5=LAB/'R5'

def collection(name):
 c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c);return c

def move(o,c):
 for old in list(o.users_collection):old.objects.unlink(o)
 c.objects.link(o)

def material(name,color,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.48 if metal else .8;p.inputs['Metallic'].default_value=metal;return m

def shell(body,rig,name,predicate,mat,offset,coll):
 # Duplicate selected garment surface, keeping every body vertex and all original animation intact.
 selected=[p for p in body.data.polygons if all(predicate(body.data.vertices[i]) for i in p.vertices)]
 ids=sorted({i for p in selected for i in p.vertices});mapping={v:i for i,v in enumerate(ids)}
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([body.data.vertices[i].co+body.data.vertices[i].normal*offset for i in ids],[],[[mapping[i] for i in p.vertices] for p in selected]);mesh.update()
 o=bpy.data.objects.new(name,mesh);coll.objects.link(o);o.matrix_world=body.matrix_world.copy();o.data.materials.append(mat)
 for g in body.vertex_groups:o.vertex_groups.new(name=g.name)
 for n,i in enumerate(ids):
  for g in body.data.vertices[i].groups:o.vertex_groups[g.group].add([n],g.weight,'REPLACE')
 mod=o.modifiers.new('Inherited body weights','ARMATURE');mod.object=rig
 for p in mesh.polygons:p.use_smooth=True
 return o

def build_outfit(rig,body,targets):
 cols={n:collection(n) for n in ['Body','Clothing','Armor','Accessories','Hair','Rig','Rendering']}
 for o in targets:move(o,cols['Rig'] if o.type=='ARMATURE' else cols['Body'])
 cloth=[];audit=[]
 # Rest-space fit: weighted source bind to target bind, then resolve body penetrations outward.
 verts=[body.matrix_world@v.co for v in body.data.vertices];polys=[list(p.vertices) for p in body.data.polygons];bvh=BVHTree.FromPolygons(verts,polys)
 for file in sorted((R5/'Sources/Outfits').glob('*.gltf'))+list((R5/'Sources/Hair').glob('*.gltf')):
  before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(file));objects=set(bpy.context.scene.objects)-before
  oldrig=next(o for o in objects if o.type=='ARMATURE')
  for o in [o for o in objects if o.type=='MESH' and o.find_armature()==oldrig]:
   # Ranger file includes a duplicate naked arm surface. Remove only those imported faces, never body arms.
   if 'Arms' in o.name:
    import bmesh
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index==1],context='FACES');bm.to_mesh(o.data);bm.free()
   oldworld=o.matrix_world.copy();inv=oldworld.inverted();push=0
   for v in o.data.vertices:
    point=oldworld@v.co;fitted=Vector();total=0
    for g in v.groups:
     n=o.vertex_groups[g.group].name
     if n in rig.data.bones and n in oldrig.data.bones:
      fitted+=(rig.matrix_world@rig.data.bones[n].matrix_local@(oldrig.matrix_world@oldrig.data.bones[n].matrix_local).inverted()@point)*g.weight;total+=g.weight
    if total:fitted/=total
    else:fitted=point
    if 'Hair' not in o.name:
     loc,normal,_,dist=bvh.find_nearest(fitted)
     signed=(fitted-loc).dot(normal)
     if signed<.013 and dist<.15:fitted+=normal*(.013-signed);push+=1
    v.co=inv@fitted
   o.parent=rig;o.matrix_world=oldworld
   for m in o.modifiers:
    if m.type=='ARMATURE':m.object=rig
   c='Hair' if 'Hair' in o.name else 'Armor' if 'Pauldron' in o.name else 'Accessories' if 'Belt' in o.name else 'Clothing'
   move(o,cols[c]);cloth.append(o)
   audit.append(dict(name=o.name,vertices=len(o.data.vertices),faces=len(o.data.polygons),weightedVertices=sum(bool(v.groups) for v in o.data.vertices),fittedOutwardVertices=push,armature=rig.name,materialSlots=[m.name for m in o.data.materials],source=file.name))
  for o in objects:
   if o not in cloth and o.name in bpy.data.objects:bpy.data.objects.remove(o,do_unlink=True)
 # Recolor only green cloth in the editable node graph; preserve original leather, seams and metal texture.
 for m in set(m for o in cloth for m in o.data.materials):
  if not m.use_nodes:continue
  nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF');base=p.inputs['Base Color']
  if 'Hair' in m.name:
   base.default_value=(.055,.025,.012,1)
   for l in list(base.links):links.remove(l)
   p.inputs['Roughness'].default_value=.78
   continue
  if not base.links:continue
  original=base.links[0].from_socket
  sep=nodes.new('ShaderNodeSeparateColor');sep.mode='RGB';links.new(original,sep.inputs[0])
  sub=nodes.new('ShaderNodeMath');sub.operation='SUBTRACT';links.new(sep.outputs[1],sub.inputs[0]);links.new(sep.outputs[0],sub.inputs[1])
  mask=nodes.new('ShaderNodeMath');mask.operation='GREATER_THAN';links.new(sub.outputs[0],mask.inputs[0]);mask.inputs[1].default_value=.005
  shade=nodes.new('ShaderNodeMixRGB');shade.blend_type='MULTIPLY';shade.inputs[0].default_value=1;shade.inputs[2].default_value=(.14,.39,.95,1);links.new(sep.outputs[1],shade.inputs[1])
  mix=nodes.new('ShaderNodeMixRGB');links.new(mask.outputs[0],mix.inputs[0]);links.new(original,mix.inputs[1]);links.new(shade.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],base)
  p.inputs['Roughness'].default_value=.68
 # Keep the sculpted layered pauldron shape, give it a cool metal finish.
 steel=material('Valdoria brushed blue steel',(.19,.29,.38),.65)
 brass=material('Aged brass edging',(.32,.18,.055),.5)
 leather=material('Oiled dark leather gloves',(.055,.025,.012))
 clothblue=material('Indigo woven sleeves',(.025,.06,.14))
 for o in cloth:
  if 'Pauldron' in o.name:o.data.materials.clear();o.data.materials.append(steel)
 # Structured sleeves and gloves are weighted surface shells, not primitives or replacement anatomy.
 def weight(v,keys):return sum(g.weight for g in v.groups if any(k in body.vertex_groups[g.group].name.lower() for k in keys))
 lining=shell(body,rig,'Indigo fitted under-armor lining',lambda v:1.18<(body.matrix_world@v.co).z<1.53 and abs((body.matrix_world@v.co).x)<.29,clothblue,.008,cols['Clothing']);cloth.append(lining)
 sleeves=shell(body,rig,'Indigo upper sleeves',lambda v:weight(v,['upperarm'])>.52,clothblue,.018,cols['Clothing']);cloth.append(sleeves)
 gloves=shell(body,rig,'Fitted articulated leather gloves',lambda v:weight(v,['hand','finger','thumb','index','middle','ring','pinky'])>.5,leather,.005,cols['Clothing']);cloth.append(gloves)
 # Slim metal cuffs over the professional bracers, based on their existing detailed geometry.
 for o in cloth:
  if 'Arms' in o.name:
   o.data.materials.append(steel)
   # Existing bracer plates retain texturing; selected distal decorative faces use steel.
   for p in o.data.polygons:
    center=sum((o.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
    if .47<abs((o.matrix_world@center).x)<.51:p.material_index=len(o.data.materials)-1
 for o in cloth:
  for p in o.data.polygons:p.use_smooth=True
 (R5/'parts-audit.json').write_text(json.dumps(audit,indent=2))
 (R5/'appearance.json').write_text(json.dumps(dict(identity='Valdoria adventuring swordsman',palette=['indigo cloth','oiled brown leather','blue steel','aged brass'],pieces=[o.name for o in cloth],cape=False,capeReason='Omitted: keep the first fitted outfit clear at hips and legs; no cloth solver',bodyGeometryRemoved=False,skinning='Original 65-bone weights; weighted rest-bind fitting onto approved rig; sleeves/gloves inherit original body weights',sourceSampling='unchanged approved 52 poses'),indent=2))
 return cloth,cols

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--quick',action='store_true');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.output.resolve();out.parent.mkdir(parents=True,exist_ok=True)
 if out.exists():raise FileExistsError(out)
 # Execute the original renderer with only explicit wardrobe hooks: camera, motion and sampling stay verbatim.
 source=(ROOT/'Tools/ArtPipeline/inspect_humanoid_study.py').read_text()
 source=source.replace("for sex in ['Male', 'Female']:","for sex in ['Male']:")
 source=source.replace("        camera_data = bpy.data.cameras.new('Study Camera')","        wardrobe, cols = build_outfit(rig, next(o for o in meshes if o.name.startswith('SuperHero')), targets)\n        camera_data = bpy.data.cameras.new('Study Camera')")
 source=source.replace('        records = []','        move(camera, cols["Rendering"]); move(lamp, cols["Rendering"]); move(source, cols["Rig"])\n        for o in scene.objects:\n            if o.type=="MESH" and o.find_armature() is None:o.hide_render=True\n        records = []; joints = []')
 hook='''                    if not args.metadata_only:
                        # Exact body reference render with every wardrobe object hidden, for motion proof.
                        for piece in wardrobe:piece.hide_render=True
                        reference = output / ('Reference/'+name+'_'+str(index).zfill(3)+'.png')
                        reference.parent.mkdir(exist_ok=True)
                        scene.render.filepath=str(reference)
                        bpy.ops.render.render(write_still=True)
                        for piece in wardrobe:piece.hide_render=False
                    scene.render.filepath = str(output / filename)
                    skeleton={n:[list(row) for row in (rig.matrix_world @ b.matrix)] for n,b in rig.pose.bones.items()}
                    def project(v):
                        p=world_to_camera_view(scene,camera,v);return [p.x*128,(1-p.y)*160,p.z]
                    anchors={n:project(rig.matrix_world @ rig.pose.bones[n].head) for n in rig.pose.bones.keys() if any(k in n.lower() for k in ['hand','foot','ball','calf','thigh','lowerarm','upperarm','pelvis','head'])}
                    grip=project(rig.matrix_world @ rig.pose.bones['hand_r'].head)
                    grip_tip=project(rig.matrix_world @ rig.pose.bones['hand_r'].tail)
                    center=project(rig.matrix_world @ rig.pose.bones['pelvis'].head)
                    hand_meta=dict(anatomical='right',bone='hand_r',pixel=grip[:2],boneAxisPixel=grip_tip[:2],angleDegrees=math.degrees(math.atan2(grip_tip[1]-grip[1],grip_tip[0]-grip[0])),cameraDepth=grip[2],relativeToPelvisDepth=grip[2]-center[2],occlusionHint='behind' if grip[2]>center[2] else 'front',certifiedGrip=False)
                    joints.append(dict(rightHand=hand_meta,bodyCenter=center,groundProjected=project(Vector((0,0,0))),clip=name,index=index,sourceFrame=frame,skeleton=skeleton,anchors=anchors,camera=[list(row) for row in camera.matrix_world],light=list(lamp.location),pivot=[64,126],ground=[64,144],gripStatus='projected hand bone, not a certified sword grip'))
                    bpy.ops.render.render(write_still=True)'''
 source=source.replace('                    bpy.ops.render.render(write_still=True)',hook)
 source=source.replace("    (output / 'inspection.json').write_text", "    (output / 'pose-metadata.json').write_text(json.dumps(joints,indent=2))\n    seen_images={}\n    for image in list(bpy.data.images):\n        key=bpy.path.abspath(image.filepath)\n        if image.source=='FILE' and key in seen_images:\n            image.user_remap(seen_images[key]);bpy.data.images.remove(image)\n        elif image.source=='FILE':seen_images[key]=image\n    for image in bpy.data.images:\n        if image.source=='FILE':\n            assert Path(bpy.path.abspath(image.filepath)).is_file(), image.filepath\n    bpy.context.preferences.filepaths.save_version=0\n    bpy.ops.wm.save_as_mainfile(filepath=str(R5/'ValdoriaSwordsman.blend'),compress=True)\n    (output / 'inspection.json').write_text")
 if args.quick:
  source=source.replace("for action, count in [(idle, 1), (walk, args.frames)]:","for action, count in [(idle, 1)]:")
 sys.argv=['blender','--','--output',str(out),'--frames','12']
 env=dict(__name__='r5_renderer',__file__=str(ROOT/'Tools/ArtPipeline/inspect_humanoid_study.py'),build_outfit=build_outfit,move=move,world_to_camera_view=world_to_camera_view,R5=R5)
 exec(compile(source,'frozen-renderer-r5','exec'),env);env['main']()

if __name__=='__main__':main()
