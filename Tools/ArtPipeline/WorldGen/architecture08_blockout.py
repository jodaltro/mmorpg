"""Two composition studies per new reference; Blender offline, never final pixels."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

root = Path(sys.argv[sys.argv.index('--output')+1]).resolve()
if root.exists(): raise FileExistsError('New study destination required')
root.mkdir(parents=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=960; scene.render.resolution_y=960
scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
materials={}
for name,color in [('stone',(.44,.43,.38,1)),('wood',(.30,.25,.19,1)),('roof',(.25,.28,.27,1)),('dark',(.08,.10,.10,1)),('floor',(.42,.38,.31,1))]:
    m=bpy.data.materials.new(name);m.diffuse_color=color;materials[name]=m

def box(name,center,size,mat='stone'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(materials[mat]);return o

def roof(name,x0,x1,y0,y1,eave,rise):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([(x0,y0,eave),(x1,y0,eave),(x1,(y0+y1)/2,eave+rise),(x0,(y0+y1)/2,eave+rise),(x0,y1,eave),(x1,y1,eave)],[],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)])
    o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);o.data.materials.append(materials['roof'])
    solid=o.modifiers.new('Built roof thickness','SOLIDIFY');solid.thickness=.24

def tower(x,y):
    box('Tower foundation',(x,y,.22),(1.95,1.95,.44))
    box('Tower masonry',(x,y,2.7),(1.7,1.7,5.1))
    box('Tower corbel cornice',(x,y,5.1),(2,2,.32))
    for a in [-.7,0,.7]:
        for b in [-.7,.7]:box('Merlon',(x+a,y+b,5.5),(.38,.38,.65))
    for b in [0]:
        for a in [-.7,.7]:box('Merlon',(x+a,y+b,5.5),(.38,.38,.65))
    box('Arrow slit',(x,y-.856,3.25),(.13,.03,.65),'dark')

bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-6,-8,14));light=bpy.context.object;light.data.energy=1900;light.data.size=6
results=[]
for kind in ['barn','castle']:
    for study in [1,2]:
        for o in list(scene.objects):
            if o not in [camera,light]:bpy.data.objects.remove(o,do_unlink=True)
        yaw=36 if study==1 else 43
        if kind=='barn':
            w=6.6;d=4.8 if study==1 else 5.6;eave=3.5;rise=2.5 if study==1 else 2.9
            box('Stone plinth',(0,0,.22),(w+.16,d+.16,.44));box('Timber hall',(0,0,1.9),(w,d,3.4),'wood')
            for x in [-3.15,-1.45,1.45,3.15]:box('Load bearing post',(x,-d/2-.04,1.9),(.18,.18,3.5),'stone')
            box('Large double loading doors',(0,-d/2-.055,1.6),(2.45,.08,2.85),'dark')
            box('Pedestrian door',(w/2+.03,.9,1.1),(.08,.95,2.12),'dark')
            roof('Main structural gable',-w/2-.4,w/2+.4,-d/2-.5,d/2+.5,eave,rise)
            box('Offset lean-to',(-4,.5,1.25),(1.5,3,2.5),'wood');roof('Lean-to cover',-4.9,-3.1,-1.2,2.2,2.6,.55)
            door=[(w/2,.9,0),(w/2,.9,2.12)];camera.data.ortho_scale=13
            description='Long timber hall; double loading door and separate human door; low offset lean-to'
        else:
            # Compact fortified manor, open central approach; not a full town-sized castle.
            box('Rear keep foundation',(0,2,.22),(5.4,3.2,.44))
            box('Rear keep masonry',(0,2,2.15),(5.1,3,4.1))
            roof('Keep slate roof',-2.9,2.9,.2,3.8,4.3,1.7 if study==1 else 2.3)
            for x in [-3.3,3.3]:tower(x,-1.75)
            for x in [-3.25,3.25]:box('Courtyard side wall',(x,.65,1.15),(.5,3.3,2.3))
            for x in [-1.95,1.95]:box('Gate flank wall',(x,-2.45,1.3),(1.9,.65,2.6))
            box('Open central gateway lintel',(0,-2.45,3.0),(2.15,.7,.7))
            box('Courtyard floor',(0,-.2,.03),(5.8,3.7,.06),'floor')
            box('Keep door',(0,.48,1.14),(.95,.04,2.12),'dark')
            door=[(0,.48,.08),(0,.48,2.2)];camera.data.ortho_scale=14.8
            description='Small fortified manor: two front towers, gate, open courtyard and rear keep'
        angle=math.radians(yaw);camera.location=(math.sin(angle)*18,-math.cos(angle)*18,13)
        camera.rotation_euler=(Vector((-.2,.4,2.2))-camera.location).to_track_quat('-Z','Y').to_euler()
        id=f'{kind}-study-{study}';scene.render.filepath=str(root/(id+'.png'));bpy.ops.render.render(write_still=True)
        def pixel(point):
            v=world_to_camera_view(scene,camera,Vector(point));return [v.x*960,(1-v.y)*960]
        results.append({'id':id,'description':description,'yaw':yaw,'doorPixels':[pixel(p) for p in door],'selected':study==1})
        if study==1:bpy.ops.wm.save_as_mainfile(filepath=str(root/(kind+'-selected.blend')))
(root/'studies.json').write_text(json.dumps(results,indent=2))
