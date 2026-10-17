import bpy, math, os, json, hashlib
from mathutils import Vector
base=os.path.dirname(os.path.abspath(__file__))
# deterministic orthographic 3/4 pixel-art source renders; refuse existing output
out=os.path.join(base,'rendered'); os.makedirs(out,exist_ok=True)
# Geometry uses a shared ground plane, camera, key light. Each module isolated by collection.
def mat(name,color,rough=1):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;return m
grass=mat('Moss olive',(0.22,.31,.14)); grassHi=mat('Meadow highlights',(.34,.43,.20)); earth=mat('Packed ochre',(.39,.30,.19)); stone=mat('Cold limestone',(.36,.39,.39)); stoneHi=mat('Limestone edges',(.52,.51,.44)); wood=mat('Walnut timber',(.20,.12,.08)); woodHi=mat('Timber light',(.40,.25,.13)); slate=mat('Aged slate',(.22,.27,.30)); slateHi=mat('Slate lit',(.34,.38,.38)); leaf=mat('Canopy deep',(.16,.29,.15)); leaf2=mat('Canopy mid',(.27,.40,.18)); leaf3=mat('Canopy light',(.39,.48,.23)); moss=mat('Moss',(.28,.36,.17)); rock=mat('Stone',( .40,.43,.42))
def cube(name,loc,scale,material,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('chipped pixel silhouette','BEVEL');mod.width=bevel;mod.segments=1;o.modifiers.new('weighted stone normals','WEIGHTED_NORMAL')
 return o
def ico(name,loc,scale,material,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);return o
def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def render(name,res,camz=14):
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=res[0];scene.render.resolution_y=res[1];scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
 scene.render.pixel_aspect_x=scene.render.pixel_aspect_y=1
 bpy.ops.object.camera_add(location=(0,-camz*.62,camz));cam=bpy.context.object;cam.rotation_euler=(math.radians(28),0,0);cam.data.type='ORTHO';cam.data.ortho_scale=camz;scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(-5,-6,12));lamp=bpy.context.object;lamp.data.energy=850;lamp.data.shape='DISK';lamp.data.size=5;lamp.rotation_euler=(math.radians(25),0,math.radians(-25))
 scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1;scene.view_settings.view_transform='Standard';scene.view_settings.look='Medium High Contrast'
 scene.render.image_settings.color_depth='8';scene.render.filepath=os.path.join(out,name+'.png');bpy.ops.render.render(write_still=True)
 # remove camera/light for next render
 for o in list(bpy.context.scene.objects):
  if o.type in {'CAMERA','LIGHT'}:bpy.data.objects.remove(o,do_unlink=True)
def floor(w,d): cube('shadow-catching meadow',(0,0,-.12),(w,d,.2),grass)
# terrain meadow 384x256 at 32px/m -> 12x8
clear();floor(12,8)
for x in range(-5,6,2):
 for y in range(-3,4,2):
  if (x*17+y*11)%5==0:ico('meadow tuft',(x+.2,y+.15,-.005),(.11,.08,.018),grassHi,1)
render('meadow',(384,256),8)
# packed path 96x256
clear();floor(3,8);cube('subtle path center',(0,0,0),(2.6,8,.025),earth)
for y in range(-3,4):
 for x in (-1,1):
  if (y*9+x*3)%4==0:ico('embedded pale gravel',(x*.66,y+.1,.022),(.07,.12,.022),stoneHi,1)
render('path',(96,256),8)
# tree canopy 96x128; trunk at lower center, modular split canopy independent
clear();
for x,y,z,s,m in [(-.35,.2,1.25,(.72,.62,.72),leaf),(.34,.27,1.40,(.68,.58,.8),leaf2),(0,-.35,1.57,(.68,.6,.75),leaf2),(-.08,.47,1.95,(.57,.5,.57),leaf3),(.48,-.15,1.9,(.42,.45,.48),leaf3)]:ico('faceted canopy cluster',(x,y,z),s,m,2)
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.location.z*=1.7;o.scale.z*=1.7
render('tree-canopy',(96,176),5.5)
clear();cube('bark trunk',(0,0,.5),(.4,.42,1.0),wood,.06);cube('bark lit plane',(-.09,-.22,.49),(.12,.025,.84),woodHi);cube('root east',(.18,-.12,.14),(.55,.22,.18),wood,.035);cube('root west',(-.18,-.12,.14),(.46,.2,.16),wood,.03)
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.location.z*=2.4;o.scale.z*=2.4
render('tree-trunk',(64,112),3.5)
# rock 64x48
clear();ico('mossy boulder',(0,0,.32),(.8,.52,.36),rock,2);ico('moss crown',(-.18,-.30,.55),(.38,.24,.12),moss,1);cube('stone lit facet',(-.32,-.32,.38),(.24,.02,.24),stoneHi)
render('rock',(64,48),1.5)
# Modular cottage split into wall/door and roof sheets for correct occlusion.
clear()
cube('stone foundation',(0,-.95,.18),(3.9,.42,.36),stone,.06)
cube('timber wall',(0,-.40,.84),(3.6,.72,1.3),woodHi)
for x in [-1.55,-.82,.82,1.55]:cube('stone facade masonry',(x,-.81,.72),(.34,.10,1.28),stone,.03)
for x in [-1.15,1.15]:cube('wall beam',(x,-.82,1.15),(.12,.09,.95),wood)
cube('lintel',(0,-.83,1.7),(1.25,.13,.16),wood)
cube('door frame left',(-.47,-.90,.84),(.14,.15,1.62),wood)
cube('door frame right',(.47,-.90,.84),(.14,.15,1.62),wood)
cube('proportional cottage door',(0,-.89,.78),(.82,.11,1.52),wood)
cube('door inset',(0,-.96,.84),(.58,.025,1.15),woodHi)
ico('bronze latch',(.25,-1,.72),(.06,.025,.06),stoneHi,1)
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.location.z*=4.6;o.scale.z*=4.6
render('house-wall',(288,288),9)
clear()
for i in range(5): cube('slate shingle row '+str(i),(0,-.48,1.75+i*.25),(4.3-i*.18,.14,.37),slate if i%2==0 else slateHi,.04)
cube('gable left',(-1.3,-.48,1.75),(.12,.15,.75),wood);cube('gable right',(1.3,-.48,1.75),(.12,.15,.75),wood)
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.location.z*=1.8;o.scale.z*=1.8
render('house-roof',(288,288),9)
print('R9 modules rendered:',sorted(os.listdir(out)))
