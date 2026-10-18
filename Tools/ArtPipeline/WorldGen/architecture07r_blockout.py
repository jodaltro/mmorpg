"""One rural cottage, three CLAY design studies; never generates the final painted source."""
import bpy,math,json,sys
from mathutils import Vector
from pathlib import Path
from bpy_extras.object_utils import world_to_camera_view
if '--output' not in sys.argv:raise ValueError('Explicit new --output directory required')
root=Path(sys.argv[sys.argv.index('--output')+1])
if root.exists():raise FileExistsError('Refuse existing clay-study destination')
root.mkdir(parents=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True;scene.world.color=(.3,.3,.3);scene.view_settings.view_transform='Standard'
materials={}
for name,color in [('stone',(.42,.43,.39,1)),('wood',(.31,.27,.21,1)),('plaster',(.69,.65,.54,1)),('roof',(.31,.34,.32,1)),('dark',(.12,.15,.14,1))]:
 m=bpy.data.materials.new(name);m.diffuse_color=color;materials[name]=m

def box(name,loc,scale,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(materials[mat]);return o

def beam(name,a,b,width=.13):
 mid=(Vector(a)+Vector(b))/2;o=box(name,mid,(width,width,(Vector(b)-Vector(a)).length),'wood');o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler();return o

def roof(name,x0,x1,y0,y1,eave,rise,thickness=.20):
 verts=[(x0,y0,eave),(x1,y0,eave),(x1,(y0+y1)/2,eave+rise),(x0,(y0+y1)/2,eave+rise),(x0,y1,eave),(x1,y1,eave)];faces=[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)];mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);o.data.materials.append(materials['roof']);solid=o.modifiers.new('Structural roof thickness','SOLIDIFY');solid.thickness=thickness;solid.offset=-1;return o

bpy.ops.object.camera_add(location=(10,-14,11));camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=12.4
bpy.ops.object.light_add(type='AREA',location=(-5,-6,12));bpy.context.object.data.energy=1600;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
light=bpy.context.object
studies=[]
for idx,(name,yaw,depth,rise) in enumerate([('01-low-swept',28,4.6,1.5),('02-deep-gable',40,4.5,2.3),('03-tall-pitch',48,3.9,2.9)]):
 # Each study is a disposable clay arrangement of the SAME cottage program.
 if idx:
  for o in list(scene.objects):
   if o not in [camera,light]:bpy.data.objects.remove(o,do_unlink=True)
 w=6.;d=depth;eave=2.85
 box('Continuous stone footing',(0,0,.22),(w+.12,d+.12,.44),'stone');box('Main masonry volume',(0,0,1.6),(w,d,2.75),'plaster')
 for x in [-w/2,-.8,w/2]:beam('Front post',(x,-d/2,.35),(x,-d/2,eave),.16)
 for y in [-d/2,0,d/2]:beam('Side post',(w/2,y,.35),(w/2,y,eave),.16)
 beam('Front wallplate',(-w/2,-d/2,eave),(w/2,-d/2,eave),.2);beam('Side wallplate',(w/2,-d/2,eave),(w/2,d/2,eave),.2)
 roof('Thick gabled roof',-w/2-.45,w/2+.45,-d/2-.5,d/2+.5,eave,rise,.22)
 # Side gable closes the roof volume.
 for x in [-w/2,w/2]:
  mesh=bpy.data.meshes.new('Gable infill');mesh.from_pydata([(x,-d/2,eave),(x,d/2,eave),(x,0,eave+rise)],[],[(0,1,2)]);o=bpy.data.objects.new('Gable masonry',mesh);scene.collection.objects.link(o);o.data.materials.append(materials['plaster'])
 box('Recessed entry',(-.8,-d/2-.025,1.11),(.98,.07,2.12),'dark');box('Door leaf',(-.8,-d/2-.07,1.03),(.83,.08,1.98),'wood')
 for x in [-2.15,1.7]:box('Front window recess',(x,-d/2-.035,1.58),(.75,.08,.95),'dark')
 box('Side window recess',(w/2+.025,.65,1.62),(.08,.85,.95),'dark')
 # Small offset storage bay is subordinate, not another complete house.
 box('Low storage bay',(-3.55,.45,.95),(1.4,2.4,1.9),'stone');roof('Low bay roof',-4.4,-2.7,-.95,1.85,1.95,.6,.16)
 box('Masonry chimney',(1.6,.6,eave+rise-.1),(.56,.64,2.0),'stone');box('Chimney cap',(1.6,.6,eave+rise+.95),(.72,.80,.16),'stone')
 angle=math.radians(yaw);camera.location=(math.sin(angle)*16,-math.cos(angle)*16,11);target=Vector((-.2,0,2));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=12.4
 scene.render.filepath=str(root/(name+'.png'));bpy.ops.render.render(write_still=True)
 def pixel(point):
  v=world_to_camera_view(scene,camera,Vector(point));return [round(v.x*768,4),round((1-v.y)*768,4)]
 data={'id':name,'cameraYaw':yaw,'width':w,'depth':d,'wallHeight':eave,'roofRise':rise,'roofThickness':.22,'doorMeters':[.98,2.12],'groundCornersPixels':[pixel(p) for p in [(-w/2,-d/2,0),(w/2,-d/2,0),(w/2,d/2,0),(-w/2,d/2,0)]],'doorPixels':[pixel((-.8,-d/2,0)),pixel((-.8,-d/2,2.12))]};studies.append(data)
 if idx==1:bpy.ops.wm.save_as_mainfile(filepath=str(root/'chosen-volume-study.blend'))
(root/'studies.json').write_text(json.dumps({'kind':'clay studies, not final pixel art','studies':studies},indent=2))
