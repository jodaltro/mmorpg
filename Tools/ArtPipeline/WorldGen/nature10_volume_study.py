"""Offline clay analysis of branch support, canopy overlap and stone planes.
This is an auxiliary study, not automatically pixelized production art.
"""
import bpy,math,sys,json
from pathlib import Path
from mathutils import Vector
out=Path(sys.argv[sys.argv.index('--output')+1]).resolve()
if out.exists():raise FileExistsError('Refuse existing volume study')
out.mkdir(parents=True);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True;scene.view_settings.view_transform='Standard';scene.world.color=(.22,.22,.22)
def material(name,c):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);return m
leaf=material('Canopy clay - masses not leaves',(.44,.49,.39));wood=material('Branch support clay',(.39,.32,.24));stone=material('Stone plane clay',(.48,.46,.39))
def branch(a,b,r1,r2):
 d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r1,radius2=r2,depth=d.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name='Tapered supporting branch';o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(wood)
branch((0,0,0),(-.3,0,3.5),.35,.24);branch((-.3,0,3.5),(-1.3,.1,6.1),.25,.13);branch((-.3,0,3.5),(1.9,.3,5.5),.22,.08);branch((-1.3,.1,6.1),(-2.3,-.3,7.5),.13,.04)
lobes=[((-2.0,-.1,7.1),(2.,1.25,1.4)),((-.7,.4,8.2),(1.55,1.2,1.4)),((1.0,.5,7.0),(1.65,1.3,1.5)),((2.0,.2,5.8),(1.55,1.25,1.3)),((-.5,-.65,5.9),(1.65,1.05,1.15)),((-2.25,-.5,5.7),(1.3,.95,1.)),((.4,-.85,7.0),(1.2,.85,1.15))]
for i,(center,scale) in enumerate(lobes):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=center);o=bpy.context.object;o.name='Overlapping canopy mass '+str(i);o.scale=scale;o.rotation_euler=(.1*i,.12*(i%3),i*.21);o.data.materials.append(leaf)
# Offset irregular top, front and right faces, not a symmetric gem.
verts=[(-1.8,-.9,0),(1.6,-1.,0),(2.,.8,0),(-1.5,1.,0),(-1.5,-.65,1.15),(.7,-.8,1.55),(1.55,.65,1.10),(-.8,.7,1.8),(-.3,-.2,1.85)]
faces=[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(5,6,8),(6,7,8),(7,4,8),(3,2,1,0)]
mesh=bpy.data.meshes.new('Major stone fracture planes');mesh.from_pydata(verts,[],faces);obj=bpy.data.objects.new('Boulder major planes',mesh);scene.collection.objects.link(obj);obj.location=(5,0,0);obj.data.materials.append(stone)
bpy.ops.object.camera_add(location=(15,-23,16));camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=13.5;camera.rotation_euler=(Vector((1.5,0,4))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(-5,-8,15));light=bpy.context.object;light.data.energy=1500;light.data.size=4
scene.render.filepath=str(out/'clay-support-and-planes.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(out/'nature-volume-study.blend'))
(out/'study.json').write_text(json.dumps({'purpose':'Auxiliary analysis; not Unity and not direct pixel conversion','light':'upper-left warm reference','canopyMasses':[{'center':c,'scale':s} for c,s in lobes],'stoneVertices':verts,'stoneFaces':faces,'paintRelationship':'Independent painted references were evaluated against these structural principles; no claim of exact projection identity.'},indent=2))
