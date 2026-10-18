"""Editable modular pixel architecture. Original project authorship, offline Aseprite."""
import argparse,json,math,random,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
import world_hydrology as common
ROOT=common.ROOT
ARCHETYPES={'A':{'id':'rural-stonewood','width':6.6,'depth':3.6,'wallHeight':5.6,'roofRise':2.1,'lift':0.0,'roof':'weathered-shingle'},'B':{'id':'merchant-gabled','width':8.0,'depth':4.4,'wallHeight':6.2,'roofRise':2.65,'lift':0.0,'roof':'slate-crossgable'},'C':{'id':'lakeside-raised','width':6.0,'depth':3.6,'wallHeight':5.5,'roofRise':1.95,'lift':.45,'roof':'reed-and-shingle'}}
LAYERS=['00 Ground shadow','01 Foundation and moisture protection','02 Stone and timber walls','03 Timber framing','04 Door modules','05 Window modules','06 Roof planes and eaves','07 Chimney masonry','08 Porch and posts','09 Dormer and trim']
CANVAS=(512,512);ANCHOR=(240,438)
def P(x,z,h=0):return (round(ANCHOR[0]+32*(x+.5*z)),round(ANCHOR[1]+16*z-32*h))
def polygon(image,points,fill,outline='#34372f',width=1):
 d=ImageDraw.Draw(image);d.polygon(points,fill=fill);d.line(points+[points[0]],fill=outline,width=width)
def quad(image,points,mode,seed,side=False):
 # Bilinear projection of editable masonry, planks, plaster or shingles onto a module plane.
 rng=random.Random(seed);mask=Image.new('L',CANVAS);ImageDraw.Draw(mask).polygon(points,fill=255);layer=Image.new('RGBA',CANVAS);d=ImageDraw.Draw(layer)
 palettes={'stone':['#69685a','#767463','#84806c','#616457','#8c846d'],'wood':['#78664c','#856e4e','#66583f','#927756'],'plaster':['#a49978','#ac9e7c','#a69876','#afa17d'],'shingle':['#615e4c','#726b53','#5a5949','#80745b'],'slate':['#565e5b','#64706b','#768078','#4a5553'],'thatch':['#79734e','#898059','#6b6948','#958860']}
 colors=palettes[mode];a,b,c,e=[tuple(q) for q in points]
 def uv(u,v):return (a[0]*(1-u)*(1-v)+b[0]*u*(1-v)+c[0]*u*v+e[0]*(1-u)*v,a[1]*(1-u)*(1-v)+b[1]*u*(1-v)+c[1]*u*v+e[1]*(1-u)*v)
 cols,rows={'stone':(9,5),'wood':(14,1),'plaster':(7,6),'shingle':(22,16),'slate':(20,15),'thatch':(32,13)}[mode]
 if mode=='stone':cols=max(3,round(math.dist(a,b)/17));rows=max(2,round(math.dist(a,e)/8))
 for r in range(rows):
  for col in range(-1,cols+1):
   shift=.5*(r%2) if mode not in ['wood','plaster','thatch'] else 0;u0=max(0,(col+shift)/cols);u1=min(1,(col+1+shift)/cols)
   if u1<=u0:continue
   v0=r/rows;v1=(r+1)/rows;pts=[uv(u0,v0),uv(u1,v0),uv(u1,v1),uv(u0,v1)];color=colors[rng.randrange(len(colors))];d.polygon(pts,fill=color)
   if mode=='plaster':
    for _ in range(12):
     q=uv(rng.uniform(u0,u1),rng.uniform(v0,v1));color=colors[rng.randrange(len(colors))];d.line((q[0],q[1],q[0]+rng.randrange(1,5),q[1]),fill=color)
   else:
    d.line([pts[3],pts[2],pts[1]],fill='#41483e' if mode in ['slate','shingle','thatch'] else '#514f40',width=1)
    d.line([pts[0],pts[1]],fill='#8c8b74' if mode=='slate' else '#a08c64',width=1)
    if mode=='wood':
     for _ in range(6):
      q=uv(rng.uniform(u0,u1),rng.uniform(.05,.95));d.line((q[0],q[1],q[0]+rng.choice([-1,0,1]),q[1]+rng.randrange(4,16)),fill='#5c533f')
    elif rng.random()<.28:
     q=uv((u0+u1)/2,(v0+v1)/2);d.line((q[0],q[1],q[0]+2,q[1]),fill=colors[-1])
 layer.putalpha(Image.composite(layer.getchannel('A'),Image.new('L',CANVAS),mask));image.alpha_composite(layer)
 if side:
  shade=Image.new('RGBA',CANVAS,(24,31,26,45));shade.putalpha(mask.point(lambda x:45 if x else 0));image.alpha_composite(shade)
 d=ImageDraw.Draw(image);d.line(points+[points[0]],fill='#383d34',width=2)
def beam(image,a,b,width=5):
 d=ImageDraw.Draw(image);d.line((a,b),fill='#3c4032',width=width+2);d.line((a,b),fill='#62543c',width=width);d.line(((a[0]-1,a[1]-1),(b[0]-1,b[1]-1)),fill='#978460',width=1)
def door(kind='arched'):
 im=Image.new('RGBA',(58,112));d=ImageDraw.Draw(im)
 if kind=='arched':d.rounded_rectangle((2,1,55,111),radius=23,fill='#514d3e',outline='#b1a17a',width=3);d.rectangle((2,35,55,111),fill='#514d3e')
 else:d.rectangle((2,3,55,111),fill='#564f3e',outline='#a18d65',width=3)
 for x in range(7,52,7):d.rectangle((x,30 if kind=='arched' else 9,x+5,108),fill=['#786344','#68583d','#8b704a'][x%3]);d.line((x,35,x,106),fill='#433f32')
 for y in [55,91]:d.rectangle((7,y,50,y+4),fill='#3e483e');d.point((10,y+2),fill='#b4ad85');d.point((47,y+2),fill='#b4ad85')
 d.ellipse((42,70,48,76),outline='#c5ac68',width=2)
 if kind=='arched':
  for angle in range(195,350,19):
   rad=math.radians(angle);x=29+24*math.cos(rad);y=25+23*math.sin(rad);d.line((x,y,x+2*math.cos(rad),y+2*math.sin(rad)),fill='#b9a780',width=2)
 for x,y in [(7,55),(47,55),(7,91),(47,91)]:d.point((x,y+1),fill='#b1ae87')
 return im

def window(seed,large=False):
 im=Image.new('RGBA',(44,59));d=ImageDraw.Draw(im);d.rectangle((4,4,39,53),fill='#393f37',outline='#8f7d56',width=3);d.rectangle((10,10,33,44),fill='#3c5150');d.polygon([(11,11),(32,11),(11,32)],fill='#63736b');d.line((22,10,22,45),fill='#aa9567',width=3);d.line((10,27,34,27),fill='#aa9567',width=2);d.rectangle((0,53,43,58),fill='#8c805d');d.line((1,53,42,53),fill='#c0ab78')
 for x in [0,40]:
  d.rectangle((x,12,x+3,47),fill='#70674b');d.line((x,14,x,45),fill='#9b885f');d.line((x,30,x+3,30),fill='#4b503e')
 return im

def build_source(style,seed=710207,spec=None,opening_modules=None):
 spec=spec or ARCHETYPES[style];opening_modules=opening_modules or {};w=spec['width'];z=spec['depth']/2;h=spec['wallHeight'];rise=spec['roofRise'];lift=spec['lift'];layers=[Image.new('RGBA',CANVAS) for _ in LAYERS];shadow,base,walls,framing,doors,windows,roof,chimney,porch,trim=layers;d=ImageDraw.Draw(shadow)
 ground=[P(-w/2-.5,-z-.4),P(w/2+.8,-z-.4),P(w/2+1.4,z+.8),P(-w/2-.2,z+.8)];d.polygon(ground,fill=(26,33,24,76))
 # Ground-contact foundations share the projected semantic plan, including a raised plinth at the lake.
 for side,xx in [(False,(-w/2,w/2))]:
  pts=[P(-w/2,z,.0),P(w/2,z,.0),P(w/2,z,.65+lift),P(-w/2,z,.65+lift)];quad(base,pts,'stone',seed)
 pts=[P(w/2,z,0),P(w/2,-z,0),P(w/2,-z,.65+lift),P(w/2,z,.65+lift)];quad(base,pts,'stone',seed+1,True)
 if style=='C':
  # Piers, ventilation lattice and dry sill protect the cabin; stairs are presentation, no height locomotion.
  d=ImageDraw.Draw(base)
  for x in [-w/2,-w/6,w/6,w/2]:
   polygon(base,[P(x-.14,z,0),P(x+.14,z,0),P(x+.14,z,1.05),P(x-.14,z,1.05)],'#77745f')
  beam(base,P(-w/2,z,.85),P(w/2,z,.85),7)
  for x in [i*.35-w/2 for i in range(int(w/.35))]:beam(base,P(x,z,.12),P(x+.3,z,.65),1)
 front=[P(-w/2,z,.6+lift),P(w/2,z,.6+lift),P(w/2,z,h+lift),P(-w/2,z,h+lift)];quad(walls,front,'wood' if style=='C' else 'plaster',seed+2)
 side=[P(w/2,z,.6+lift),P(w/2,-z,.6+lift),P(w/2,-z,h+lift),P(w/2,z,h+lift)];quad(walls,side,'wood' if style!='A' else 'stone',seed+3,True)
 if style=='A':
  quad(walls,[P(-w/2,z,.65),P(w/2,z,.65),P(w/2,z,1.45),P(-w/2,z,1.45)],'stone',seed+40)
 # Timber frame and braces are structural modules, not a flat wall texture.
 for x in [-w/2,0,w/2]:beam(framing,P(x,z,.6+lift),P(x,z,h+lift),5)
 for hh in [.65+lift,h+lift]:beam(framing,P(-w/2,z,hh),P(w/2,z,hh),6)
 for x in [-w/2,0]:beam(framing,P(x,z,h-1+lift),P(x+w/2,z,h+lift),4)
 beam(framing,P(w/2,-z,.65+lift),P(w/2,-z,h+lift),5);beam(framing,P(w/2,z,h+lift),P(w/2,-z,h+lift),5)
 if style=='B':
  beam(framing,P(-w/2,z,h*.68),P(w/2,z,h*.68),4)
 for x in [-w/2,w/2]:
  q=P(x,z,h*.7+lift);dd=ImageDraw.Draw(framing);dd.rectangle((q[0]-1,q[1]-1,q[0]+1,q[1]+1),fill='#bab18a')
 # Right gable closes the end of the volume.
 polygon(walls,[P(w/2,z,h+lift),P(w/2,-z,h+lift),P(w/2,0,h+rise+lift)],'#746b50')
 for zz in [-z,-z*.5,0,z*.5,z]:beam(framing,P(w/2,zz,h+lift),P(w/2,0,h+rise+lift),2)
 # Front and rear roof planes, faceted shingles with staggered joints.
 rw=w/2+.35;rz=z+.42;roofmode={'A':'shingle','B':'slate','C':'thatch'}[style]
 quad(roof,[P(-rw,-rz,h+lift-.12),P(rw,-rz,h+lift-.12),P(rw,0,h+rise+lift),P(-rw,0,h+rise+lift)],roofmode,seed+5,True)
 quad(roof,[P(-rw,0,h+rise+lift),P(rw,0,h+rise+lift),P(rw,rz,h+lift-.12),P(-rw,rz,h+lift-.12)],roofmode,seed+6)
 for a,b in [(P(-rw,0,h+rise+lift),P(rw,0,h+rise+lift)),(P(-rw,rz,h+lift-.12),P(rw,rz,h+lift-.12)),(P(rw,rz,h+lift-.12),P(rw,0,h+rise+lift))]:beam(roof,a,b,4)
 # Door/window modules remain independent editable reusable PNG sources.
 doorim=opening_modules.get('door-arched' if style!='C' else 'door-square',door(style!='C' and 'arched' or 'square')).copy();doorwidth=2.2;doorheight=5.0;dx=-.65 if style!='B' else -.85;doorbase=P(dx,z,.03+lift);doorim=doorim.resize((round(doorwidth*32),round(doorheight*32)),Image.Resampling.NEAREST);doors.alpha_composite(doorim,(doorbase[0]-doorim.width//2,doorbase[1]-doorim.height))
 for xx in ([1.75] if style!='B' else [1.7,-2.7]):
  win=opening_modules.get('window-timber',window(seed)).copy();q=P(xx,z,2.4+lift);windows.alpha_composite(win,(q[0]-22,q[1]-59))
 # Landing/steps reach the closed exterior threshold, not a fabricated interior.
 for step in range(3 if style=='C' else 1):
  zz=z+.12+step*.20;hh=max(0,lift-step*.15);pts=[P(dx-.85,zz,hh),P(dx+.85,zz,hh),P(dx+.85,zz+.2,max(0,hh-.1)),P(dx-.85,zz+.2,max(0,hh-.1))];polygon(base,pts,'#8e8770',outline='#565e4a')
 # Chimney with two lit masonry planes, flashing and a capped top.
 if style!='C':
  x=w*.27;zz=-.55;bottom=h+rise*.5+lift;top=h+rise+1.0+lift
  quad(chimney,[P(x-.24,zz,bottom),P(x+.24,zz,bottom),P(x+.24,zz,top),P(x-.24,zz,top)],'stone',seed+8)
  polygon(chimney,[P(x+.24,zz,bottom),P(x+.24,zz-.6,bottom),P(x+.24,zz-.6,top),P(x+.24,zz,top)],'#525d53')
  polygon(chimney,[P(x-.34,zz+.1,top),P(x+.34,zz+.1,top),P(x+.34,zz-.7,top),P(x-.34,zz-.7,top)],'#9b9479')
 if style=='B':
  # Offset projecting dormer and front porch cross-gable create a genuinely different silhouette.
  x=.45;zz=z*.42;bottom=h+rise*.22;top=h+rise*.67
  polygon(trim,[P(x-1.05,zz,bottom),P(x+1.05,zz,bottom),P(x+1.05,zz,top),P(x,zz,top+1),P(x-1.05,zz,top)],'#a39a78')
  for xx in [x-1.05,x+1.05]:beam(trim,P(xx,zz,bottom),P(xx,zz,top),4)
  q=P(x,zz,bottom+.1);im=window(seed);trim.alpha_composite(im,(q[0]-22,q[1]-59))
  polygon(trim,[P(x-1.25,zz,top-.1),P(x,zz,top+1.2),P(x+.1,zz-1.1,top+1.2),P(x-1.15,zz-1.1,top-.1)],'#4d5b56')
  beam(trim,P(x-1.25,zz,top-.1),P(x,zz,top+1.2),4);beam(trim,P(x,zz,top+1.2),P(x+1.25,zz,top-.1),4)
  # Side lean-to with a low independent roof, integral to semantic silhouette but no extra collider outside main plan.
  awning=[P(-w/2-.2,z+.2,h*.58),P(-w/2+1.8,z+.2,h*.58),P(-w/2+1.8,z+.85,h*.48),P(-w/2-.2,z+.85,h*.48)];quad(porch,awning,'slate',seed+10)
  for xx in [-w/2,-w/2+1.65]:beam(porch,P(xx,z+.78,0),P(xx,z+.78,h*.5),3)
 if style=='C':
  # Asymmetric covered work porch and drainage overhang.
  pts=[P(-w/2-.45,z+.6,h*.62+lift),P(-w/2+1.1,z+.6,h*.62+lift),P(-w/2+1.1,z+1.0,h*.52+lift),P(-w/2-.45,z+1.0,h*.52+lift)];quad(porch,pts,'shingle',seed+12)
  for xx in [-w/2-.25,-w/2+.95]:beam(porch,P(xx,z+.85,0),P(xx,z+.85,h*.53+lift),3)
 if style=='A':
  # Lower masonry wing creates a stepped rural silhouette, with its own semantic footprint.
  xa=-w/2-1.65;xb=-w/2+.1;za=z-.05;zb=-.65;ah=2.15
  quad(walls,[P(xa,za,0),P(xb,za,0),P(xb,za,ah),P(xa,za,ah)],'stone',seed+21)
  quad(walls,[P(xb,za,0),P(xb,zb,0),P(xb,zb,ah+.3),P(xb,za,ah)],'stone',seed+22,True)
  quad(roof,[P(xa-.2,zb-.15,ah+.65),P(xb+.2,zb-.15,ah+.65),P(xb+.2,za+.25,ah),P(xa-.2,za+.25,ah)],'shingle',seed+23)
  beam(roof,P(xa-.2,za+.25,ah),P(xb+.2,za+.25,ah),4)
  hatch=door('square').resize((29,48),Image.Resampling.NEAREST);q=P((xa+xb)/2,za,.1);doors.alpha_composite(hatch,(q[0]-14,q[1]-48))
 # Eave shadow sits on upper wall while roof is its own hideable layer.
 d=ImageDraw.Draw(walls);d.line((P(-w/2,z,h+lift-.10),P(w/2,z,h+lift-.10)),fill='#4c513d',width=5)
 return layers,{'doorLocal':[dx+.5*z,.5*z],'doorWidth':doorwidth,'doorHeight':doorheight,'spec':spec}

def art_recipe():return {'schema':'valdoria-architecture-art-recipe/v1','seed':710207,'archetypes':ARCHETYPES}
def assemble(output,seed=710207,recipe_path=None,modules_source=None):
 out=common.refuse(output);specs=ARCHETYPES;opening_modules={}
 if recipe_path:
  r=json.loads(Path(recipe_path).read_text());assert r['schema']=='valdoria-architecture-art-recipe/v1';seed=r['seed'];specs=r['archetypes']
  if type(seed) is not int or set(specs)!=set('ABC'):raise ValueError('Architecture art seed/archetypes')
  for k,v in specs.items():
   if k not in 'ABC' or not 5<=v['width']<=10 or not 2.5<=v['depth']<=5 or not 5.2<=v['wallHeight']<=6.5 or not 1.5<=v['roofRise']<=3 or not 0<=v['lift']<=.8:raise ValueError('Architecture dimensions/door clearance')
 if modules_source:
  import tempfile
  with tempfile.TemporaryDirectory() as tmp:
   for name in ['door-arched','door-square','window-timber']:
    source=Path(modules_source)/('module-'+name+'.aseprite');target=Path(tmp)/(name+'.png');subprocess.run([r'D:\Aseprite\Aseprite.exe','-b',str(source),'--save-as',str(target)],check=True);opening_modules[name]=Image.open(target).convert('RGBA').copy()
 out.mkdir(parents=True);metadata={'schema':'valdoria-architecture-library/v1','seed':seed,'ppu':32,'canvas':list(CANVAS),'groundAnchor':list(ANCHOR),'layers':LAYERS,'archetypes':{},'license':'Original project work','light':'upper-left; no mirroring of prelit art'}
 lua='local root=app.params["root"]\n'
 # Reusable opening modules are consumed directly by the generator above and also exported for edit/recombination.
 for name,im in [('door-arched',door()),('door-square',door('square')),('window-timber',window(seed))]:
  opening_modules.setdefault(name,im);opening_modules[name].save(out/('module-'+name+'.png'));lua+='do local m=app.open(root.."/module-'+name+'.png");m:saveAs(root.."/module-'+name+'.aseprite");m:close() end\n'
 for style in 'ABC':
  layers,info=build_source(style,seed+ord(style)*71,specs[style],opening_modules);metadata['archetypes'][style]=info
  lua+='do local s=Sprite(512,512,ColorMode.RGB);s.layers[1].name="Temporary"\n'
  for i,(layer,name) in enumerate(zip(layers,LAYERS)):
   layer.save(out/f'{style}-layer{i}.png');lua+=f'local l=s:newLayer();l.name="{name}";local t=app.open(root.."/{style}-layer{i}.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();\n'
  lua+='s:deleteLayer(s.layers[1]);s:saveAs(root.."/'+style+'.aseprite");s:close() end\n'
 (out/'assemble.lua').write_text(lua);common.write(out/'source.json',metadata);subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'assemble.lua')],check=True);export_parts(out,out);return out

def export_parts(source,out):
 import shutil
 source=Path(source);out=Path(out);meta=json.loads((source/'source.json').read_text());lua='local root=app.params["root"]\n';entries=[]
 if source!=out:
  (out/'source.json').write_bytes((source/'source.json').read_bytes())
  for p in list(source.glob('module-*.png'))+list(source.glob('module-*.aseprite')):shutil.copyfile(p,out/p.name)
 for style in 'ABC':
  if source!=out:shutil.copyfile(source/(style+'.aseprite'),out/(style+'.aseprite'))
  lua+=f'local s=app.open(root.."/{style}.aseprite");assert(s.width==512 and s.height==512 and #s.layers==10 and #s.frames==1,"Architecture source contract")\n'
  for part,indices in [('shadow',[1]),('foundation',[2]),('walls',[3]),('framing',[4]),('doors',[5]),('windows',[6]),('roof',[7]),('chimney',[8]),('porch',[9]),('trim',[10])]:
   lua+='for _,l in ipairs(s.layers) do l.isVisible=false end;'
   for index in indices:lua+=f's.layers[{index}].isVisible=true;'
   lua+=f'local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/{style}-{part}.png")\n'
   entries.append({'id':style+'-'+part,'archetype':style,'part':part,'file':f'{style}-{part}.png'})
  lua+='s:close()\n'
 (out/'export.lua').write_text(lua);subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'export.lua')],check=True)
 # Small per-part textures preserve editability and no single world panorama is created.
 for e in entries:
  im=Image.open(out/e['file']);rect=im.getbbox();
  if rect is None:continue
  e['sourceRect']=list(rect);e['offsetUnits']=[(rect[0]-ANCHOR[0])/32,(ANCHOR[1]-rect[3])/32];im.crop(rect).save(out/(e['id']+'-trimmed.png'));e['trimmedFile']=e['id']+'-trimmed.png'
 common.write(out/'modules.json',{'schema':'valdoria-architecture-modules/v1','ppu':32,'archetypes':meta['archetypes'],'parts':[e for e in entries if 'sourceRect' in e]});common.write(out/'manifest.json',{'schema':'valdoria-architecture-art-build/v1','files':{p.name:common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'}})
 return entries

def export_library(source,output):
 out=common.refuse(output);out.mkdir(parents=True);return export_parts(source,out)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['recipe','library','export-library']);p.add_argument('--output',required=True);p.add_argument('--source');p.add_argument('--recipe');p.add_argument('--modules-source');p.add_argument('--seed',type=int,default=710207);a=p.parse_args()
 if a.command=='recipe':common.refuse(a.output);Path(a.output).parent.mkdir(parents=True,exist_ok=True);common.write(a.output,art_recipe())
 elif a.command=='library':assemble(a.output,a.seed,a.recipe,a.modules_source)
 else:export_library(a.source,a.output)
