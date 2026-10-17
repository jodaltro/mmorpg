"""Valdoria Material Agent: editable motifs and continuous world-space pixel synthesis.
No topology or road geometry writes. Python authors; Aseprite round-trips named layers.
"""
import argparse,hashlib,json,math,subprocess,tempfile
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,distance_transform_edt,gaussian_filter
from scipy.spatial import cKDTree
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'ArtSource/Labs/World2026/WorldStudio01/Regions/B/world-region.json'
ROAD=ROOT/'ArtSource/Labs/World2026/WorldStudio02/RoadsR3/A'
VERSION='terrain-materials/1.0.0'
KINDS=['grass','dirt','rock','mud','sand','road']
PALETTES={
 'grass':['#344a36','#425b3b','#506b40','#617d49','#78915c','#91a66e'],
 'dirt':['#66503d','#7c6347','#937854','#a88e64','#bba57a','#cdbb94'],
 'rock':['#394442','#4c5752','#637067','#7b867a','#949c8c','#adb49e'],
 'mud':['#3f4032','#50513a','#626244','#757550','#8b895e','#a19c70'],
 'sand':['#8c7952','#a08c5d','#b5a26e','#c9b780','#dac994','#e8d8a9'],
 'road':['#6d583f','#836b4b','#9a8159','#af966c','#c1aa7d','#d1be96']}
def canonical(x):return (json.dumps(x,sort_keys=True,separators=(',',':'),ensure_ascii=False)+'\n').encode()
def sha(x):return hashlib.sha256(x).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def refuse(p):
 p=Path(p)
 if p.exists():raise FileExistsError('Refuse existing output: '+str(p))
 return p
def recipe(style='A'):
 return {'schema':'valdoria-material-recipe/v1','version':VERSION,'seed':710202,'style':style,'ppu':32,'chunkPixels':512,'light':'upper-left','palette':PALETTES,'detailDensity':{'A':.62,'B':1.0,'C':.86}[style],'patches':[]}
def validate(r,region):
 if r.get('schema')!='valdoria-material-recipe/v1' or r.get('style') not in ['A','B','C']:raise ValueError('Material recipe/schema/style')
 if r.get('version')!=VERSION or r.get('ppu')!=32 or r.get('chunkPixels')!=512 or r.get('light')!='upper-left':raise ValueError('Unsupported material sampling contract')
 if not isinstance(r.get('seed'),int) or not 0<=r.get('detailDensity',-1)<=1.5:raise ValueError('Invalid seed/density')
 for kind in KINDS:
  if len(r.get('palette',{}).get(kind,[]))!=6:raise ValueError('Six palette values per material')
  for value in r['palette'][kind]:
   if len(value)!=7 or value[0]!='#':raise ValueError('Invalid palette')
   bytes.fromhex(value[1:])
 w,h=region['size']
 if region.get('schema')!='valdoria-world-region/v1' or region.get('cellSizeUnits')!=1:raise ValueError('Region contract')
 for kind in ['blocked','elevationMilli','moistureMilli','slopeMilli','material']:
  if len(region['layers'][kind])!=w*h:raise ValueError('Misaligned '+kind)
 for patch in r.get('patches',[]):
  if set(patch)!={'rectPixels','toneOffset'} or len(patch['rectPixels'])!=4 or patch['toneOffset'] not in [-1,0,1] or not all(isinstance(v,int) for v in patch['rectPixels']):raise ValueError('Invalid local patch')
  x,y,a,b=patch['rectPixels']
  if min(x,y)<0 or min(a,b)<=0 or x+a>w*32 or y+b>h*32:raise ValueError('Patch outside region')
def ihash(x,y,seed):
 x=np.asarray(x,dtype=np.int64);y=np.asarray(y,dtype=np.int64)
 n=(x*374761393+y*668265263+int(seed)*1442695041)&0xffffffff
 n=((n^(n>>13))*1274126177)&0xffffffff
 return ((n^(n>>16))&0xffffffff)/4294967296.
def field(x,y,scale,seed):
 a=x/scale;b=y/scale;ix=np.floor(a).astype(np.int64);iy=np.floor(b).astype(np.int64);u=a-ix;v=b-iy
 u=u*u*u*(u*(u*6-15)+10);v=v*v*v*(v*(v*6-15)+10)
 return ((ihash(ix,iy,seed)*(1-u)+ihash(ix+1,iy,seed)*u)*(1-v)+(ihash(ix,iy+1,seed)*(1-u)+ihash(ix+1,iy+1,seed)*u)*v)
def palette(r,kind):return np.array([list(bytes.fromhex(c[1:]))+[255] for c in r['palette'][kind]],dtype=np.uint8)
def library(output):
 output=refuse(output);output.mkdir(parents=True)
 layers={name:Image.new('RGBA',(384,192)) for name in ['Pigment clusters','Forms - upper left light','Edges and contact','Micro accents']}
 # Three functional motifs per material; transparent stamps, never a filled repeating tile.
 for row,kind in enumerate(KINDS):
  colors=PALETTES[kind]
  for variant in range(3):
   cx=variant*128+64;cy=row*32+16
   # each logical motif box is 128x32, occupied area only 7..27 pixels
   d=ImageDraw.Draw(layers['Pigment clusters']);f=ImageDraw.Draw(layers['Forms - upper left light']);e=ImageDraw.Draw(layers['Edges and contact']);m=ImageDraw.Draw(layers['Micro accents'])
   if kind=='grass':
    for dx,dy,height in [(-6,2,5),(0,0,7),(5,3,4)][:variant+1]:
     d.polygon([(cx+dx-3,cy+dy+2),(cx+dx,cy+dy-height),(cx+dx+2,cy+dy),(cx+dx+5,cy+dy+2)],fill=colors[1]);f.line([(cx+dx-1,cy+dy),(cx+dx,cy+dy-height+1)],fill=colors[3]);m.point((cx+dx,cy+dy-height),fill=colors[4])
   elif kind=='rock':
    shape=[(cx-9,cy+2),(cx-6,cy-5),(cx+3,cy-7),(cx+10,cy-2),(cx+7,cy+5),(cx-4,cy+6)]
    if variant==0:shape=[(cx+int((a-cx)*.65),cy+int((b-cy)*.65)) for a,b in shape]
    d.polygon(shape,fill=colors[2]);f.polygon([shape[i] for i in [0,1,2,3]]+[(cx,cy+1)],fill=colors[3]);e.line([shape[i] for i in [3,4,5,0]],fill=colors[1]);e.line([(cx-2,cy-4),(cx+1,cy),(cx-1,cy+3)],fill=colors[1]);m.line((cx-5,cy-5,cx+1,cy-6),fill=colors[4])
    if variant==1:e.line([(cx+4,cy-4),(cx+2,cy-1),(cx+5,cy+4)],fill=colors[0]);m.point((cx+4,cy-3),fill=colors[4])
    if variant==2:m.line((cx-6,cy+2,cx-2,cy+3),fill=PALETTES['grass'][2],width=2);m.line((cx-5,cy+1,cx-3,cy+1),fill=PALETTES['grass'][3])
   elif kind in ['dirt','road']:
    for n in range(variant+1):
     dx=n*6-variant*3;dy=n%2*3;d.ellipse((cx+dx-2,cy+dy-1,cx+dx+2,cy+dy+1),fill=colors[1]);f.line((cx+dx-1,cy+dy-1,cx+dx+1,cy+dy-1),fill=colors[3])
    if variant==2:e.line([(cx-10,cy+4),(cx-1,cy+2),(cx+9,cy+2)],fill=colors[1]);m.line((cx-6,cy+1,cx+4,cy),fill=colors[3])
   elif kind=='mud':
    d.polygon([(cx-11,cy),(cx-6,cy-4),(cx+4,cy-3),(cx+11,cy),(cx+3,cy+4),(cx-5,cy+3)],fill=colors[1]);f.line((cx-5,cy-2,cx+2,cy-2),fill=colors[3])
    if variant==0:m.line((cx-3,cy-3,cx,cy-3),fill=colors[4])
    elif variant==1:e.line([(cx-7,cy+1),(cx-2,cy),(cx+2,cy+3)],fill=colors[0]);e.line((cx-2,cy,cx-1,cy-2),fill=colors[0])
    else:f.polygon([(cx-5,cy),(cx-1,cy-2),(cx+5,cy-1),(cx+7,cy+1),(cx+1,cy+2)],fill=colors[2]);m.line((cx-1,cy-2,cx+3,cy-2),fill=colors[4])
   else:
    for n in range(2+variant):
     yy=cy-5+n*4;e.line([(cx-10+n,yy+1),(cx-2,yy),(cx+9-n,yy+1)],fill=colors[1]);f.line((cx-5,yy-1,cx+4,yy-1),fill=colors[3])
 for name,im in layers.items():im.save(output/(name.replace(' ','_')+'.png'))
 composite=Image.new('RGBA',(384,192))
 for im in layers.values():composite=Image.alpha_composite(composite,im)
 composite.save(output/'motifs-preview.png')
 lua='local root=app.params["root"]\nlocal s=Sprite(384,192,ColorMode.RGB)\ns.layers[1].name="Paint refinements"\n'
 for name in layers:
  lua+=f'local t=app.open(root.."/{name.replace(" ","_")}.png"); local l=s:newLayer(); l.name="{name}";s:newCel(l,1,t.cels[1].image,Point(0,0));t:close()\n'
 lua+='app.activeSprite=s\nlocal pal=Palette(36)\n'
 for i,color in enumerate(sum([PALETTES[k] for k in KINDS],[])):lua+=f'pal:setColor({i},Color{{r={int(color[1:3],16)},g={int(color[3:5],16)},b={int(color[5:7],16)},a=255}})\n'
 lua+='s:setPalette(pal)\ns:saveAs(root.."/terrain-motifs.aseprite")\ns:saveCopyAs(root.."/motifs.png")\ns:close()\n'
 (output/'assemble.lua').write_text(lua,encoding='utf8')
 subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+output.resolve().as_posix(),'--script',str(output/'assemble.lua')],check=True)
 assert np.array_equal(np.array(Image.open(output/'motifs.png')),np.array(composite)),'Aseprite roundtrip changed pixels'
 metadata={'schema':'valdoria-material-library/v1','canvas':[384,192],'module':[128,32],'kinds':KINDS,'variants':['sparse accent','cluster','wear or moss'],'palette':PALETTES,'light':'upper-left','allowedTransforms':['translation'],'source':'terrain-motifs.aseprite','author':'Original Valdoria algorithmic pixel art authored with Python + editable Aseprite layers','license':'Original project work; no downloaded or AI image assets','files':{p.name:sha(p.read_bytes()) for p in output.iterdir() if p.is_file()}}
 (output/'library.json').write_bytes(canonical(metadata));return metadata
class Context:
 def __init__(self,region_path=BASE,road_dir=ROAD,library_dir=None):
  self.region_path=Path(region_path);self.road_dir=Path(road_dir);self.region=read(region_path);self.w,self.h=self.region['size'];self.library_dir=Path(library_dir) if library_dir else None
  self.layers={k:np.array(v).reshape(self.h,self.w) for k,v in self.region['layers'].items()}
  blocked=self.layers['blocked'];self.rock=gaussian_filter(distance_transform_edt(blocked)-distance_transform_edt(~blocked),.65)
  roadManifest=read(self.road_dir/'manifest.json')
  if roadManifest.get('inputRegionSha256')!=sha(self.region_path.read_bytes()):raise ValueError('Road references another topography')
  for name,digest in roadManifest['outputs'].items():
   if Path(name).name!=name or sha((self.road_dir/name).read_bytes())!=digest:raise ValueError('Road hash mismatch '+name)
  self.road=read(self.road_dir/'road.json')
  if self.road['schema']!='valdoria-organic-road/v1':raise ValueError('Road schema')
  self.masks={k:np.array(Image.open(self.road_dir/(k+'.png')).convert('L')) for k in ['coverage','shoulders','wear','navigable']}
  if any(v.shape!=(self.h*32,self.w*32) for v in self.masks.values()):raise ValueError('Misaligned road raster')
  samples=np.concatenate([np.array(s['samples']) for s in self.road['segments']]);self.tree=cKDTree(samples[:,:2]*32);self.samples=samples
  self.motifs=Image.open(self.library_dir/'motifs.png').convert('RGBA') if self.library_dir else None
  if self.library_dir:
   metadata=read(self.library_dir/'library.json')
   if metadata.get('schema')!='valdoria-material-library/v1':raise ValueError('Library schema')
   for name,digest in metadata['files'].items():
    if Path(name).name!=name or sha((self.library_dir/name).read_bytes())!=digest:raise ValueError('Library hash mismatch '+name)
   if self.motifs.size!=(384,192):raise ValueError('Library canvas')
 def sample(self,layer,x,y):
  shape=np.asarray(x).shape
  return map_coordinates(np.asarray(layer,dtype=float),[np.asarray((y+.5)/32-.5).ravel(),np.asarray((x+.5)/32-.5).ravel()],order=1,mode='nearest',prefilter=False).reshape(shape)
 def weights(self,r,x,y):
  seed=r['seed'];macro=field(x,y,193,seed+11);meso=field(x,y,57,seed+29);fine=field(x,y,17,seed+91)
  wet=self.sample(self.layers['moistureMilli'],x,y)/1000
  rock=self.sample(self.rock,x,y)+(meso-.5)*.30
  # Scalar interpolation happens in semantic space. Quantized pixels stay crisp.
  rock=np.clip((rock+.40)/.8,0,1)
  mud=np.clip((wet-.57)*15,0,.85)*(1-rock)*np.clip((meso-.48)*6,0,1)
  sand=np.clip((.40-wet)*15,0,.80)*(1-rock)*np.clip((macro-.38)*5,0,1)
  dirt=np.clip((.32-meso)*5,0,.85)*np.clip((.52-macro)*5,0,1)*(1-rock)
  weights=np.stack([np.maximum(0,1-rock-mud-sand-dirt),dirt,rock,mud,sand],axis=-1)
  weights/=np.maximum(weights.sum(axis=-1,keepdims=True),1e-6)
  # deterministic subpixel threshold ordered through world field, not a tile Bayer matrix.
  selector=field(x,y,37,seed+83)*.44+.28
  material=np.sum(np.cumsum(weights,axis=-1)<selector[...,None],axis=-1).clip(0,4)
  return material,macro,meso,fine,wet,rock
 def render(self,r,bounds,stage='final'):
  validate(r,self.region)
  if stage not in ['base','transitions','final']:raise ValueError('Invalid stage')
  x0,y0,width,height=map(int,bounds)
  if min(x0,y0)<0 or min(width,height)<=0 or x0+width>self.w*32 or y0+height>self.h*32:raise ValueError('Invalid raster bounds')
  y,x=np.mgrid[y0:y0+height,x0:x0+width];material,macro,meso,fine,wet,rock=self.weights(r,x,y)
  if stage=='base':material=np.zeros_like(material)
  tone=np.floor(2.55+(macro-.5)*1.05+(meso-.5)*.55+(fine-.5)*.25).astype(int).clip(1,3)
  if r['style']=='B':tone=np.floor(2.35+(macro-.5)*2.2+(meso-.5)*.95+(fine-.5)*.50).astype(int).clip(1,4)
  if r['style']=='C':tone=np.floor(2.4+(macro-.5)*2.1+(meso-.5)*.85+(fine-.5)*.42).astype(int).clip(1,4)
  for p in r.get('patches',[]):
   a,b,c,d=p['rectPixels'];tone=np.clip(tone+(((x>=a)&(x<a+c)&(y>=b)&(y<b+d))*p['toneOffset']),0,5)
  colors=np.stack([palette(r,k) for k in KINDS]);rgba=colors[material,tone]
  if r['style']=='C':
   grass=material==0;rgba[grass,:3]=np.clip(rgba[grass,:3].astype(int)+np.array([-2,3,5]),0,255)
  coverage=self.masks['coverage'][y0:y0+height,x0:x0+width]/255.
  wear=self.masks['wear'][y0:y0+height,x0:x0+width]/255.
  shoulder=self.masks['shoulders'][y0:y0+height,x0:x0+width]/255.
  dist,near=self.tree.query(np.column_stack([x.ravel()+.5,y.ravel()+.5]),workers=1);dist=dist.reshape(x.shape)/32
  widthmap=self.samples[near,3].reshape(x.shape)
  typeTone={'rural':.10,'worn':.35,'trail':-.10}.get(self.road.get('roadType'),0)
  roadtone=np.floor(2.4+typeTone+(macro-.5)*1.4+(meso-.5)*.80+wear*.50+np.clip(1-dist/np.maximum(widthmap*.5,.01),0,1)*.3).astype(int).clip(1,4)
  if stage!='base':
   edgeAlpha=(shoulder*(1-coverage)*.12)[...,None];rgba=np.rint(rgba*(1-edgeAlpha)+colors[1,2]*edgeAlpha).astype('uint8')
   roadcolor=colors[5,roadtone];alpha=coverage[...,None];rgba=np.rint(rgba*(1-alpha)+roadcolor*alpha).astype('uint8');rgba[:,:,3]=255
  image=Image.fromarray(rgba)
  if stage=='final' and self.motifs:
   # Global jittered candidates. Hard minimum spacing, no cell-locked decoration or mirrored light.
   candidates=[];spacing=23;halo=32;seed=r['seed']
   for gy in range(max(-1,(y0-halo)//spacing),min((self.h*32+halo)//spacing,(y0+height+halo)//spacing)+1):
    for gx in range(max(-1,(x0-halo)//spacing),min((self.w*32+halo)//spacing,(x0+width+halo)//spacing)+1):
     px=int((gx+.12+ihash(gx,gy,seed+109)*.76)*spacing);py=int((gy+.12+ihash(gx,gy,seed+223)*.76)*spacing)
     if not 0<=px<self.w*32 or not 0<=py<self.h*32:continue
     # all candidate decisions use coordinates, independent of chunk membership
     if ihash(gx,gy,seed+719)>r['detailDensity']*.62:continue
     priority=float(ihash(gx,gy,seed+997));excluded=False
     for oy in (-1,0,1):
      for ox in (-1,0,1):
       if ox==oy==0:continue
       nx=int((gx+ox+.12+ihash(gx+ox,gy+oy,seed+109)*.76)*spacing);ny=int((gy+oy+.12+ihash(gx+ox,gy+oy,seed+223)*.76)*spacing)
       if (nx-px)**2+(ny-py)**2<144 and float(ihash(gx+ox,gy+oy,seed+997))<priority:excluded=True
     if excluded:continue
     mat,ma,me,fi,we,ro=self.weights(r,np.array(px),np.array(py));kind=int(mat)
     slope=float(self.sample(self.layers['slopeMilli'],np.array(px),np.array(py)))/1000
     if slope>.13 and kind!=2:continue
     cv=self.masks['coverage'][py,px]/255
     if cv>.70:kind=5
     if 0<cv<.70:continue # preserve road coverage edge exactly, no stamp crosses margin
     variant=int(ihash(gx,gy,seed+457)*3)
     if kind==0 and float(we)>.58:variant=2
     if kind==5 and self.masks['wear'][py,px]>160:variant=2
     candidates.append((px,py,kind,variant))
   overlay=Image.new('RGBA',image.size)
   for px,py,kind,variant in candidates:
    stamp=self.motifs.crop((variant*128+48,kind*32,variant*128+80,kind*32+32))
    overlay.alpha_composite(stamp,(px-x0-16,py-y0-16))
   # Details cannot change material ownership; prevent grass tufts covering roads/cliff boundaries.
   a=np.array(overlay);yy,xx=np.indices((height,width));a[(coverage>.02)&(coverage<.98),3]=0
   image=Image.alpha_composite(image,Image.fromarray(a))
  return image

def seam_metrics(image):
 a=np.array(image.convert('RGB'),dtype=float);dx=np.abs(np.diff(a,axis=1)).mean(axis=2);dy=np.abs(np.diff(a,axis=0)).mean(axis=2)
 result={}
 for name,d,axis in [('vertical',dx,1),('horizontal',dy,0)]:
  values=np.array([np.take(d,np.arange(phase,d.shape[axis],32),axis=axis).mean() for phase in range(32)])
  result[name]={'cellBoundaryMean':float(values[31]),'phaseMean':float(values.mean()),'boundaryRatio':float(values[31]/max(values.mean(),1e-9)),'phaseCoefficientVariation':float(values.std()/max(values.mean(),1e-9))}
 return result

def cliff_texture(r,size):
 y,x=np.mgrid[0:size[1],0:size[0]];macro=field(x,y,211,r['seed']+47);meso=field(x,y,61,r['seed']+103)
 index=np.floor(2.6+(macro-.5)*1.3+(meso-.5)*1.2).astype(int).clip(1,4)
 im=Image.fromarray(palette(r,'rock')[index]);d=ImageDraw.Draw(im)
 # Unequal stratified fractures, global coordinates, no per-cell UV boundaries.
 for row in range(-1,size[1]//79+2):
  for col in range(-1,size[0]//117+2):
   px=int((col+float(ihash(col,row,r['seed']+7)))*117);py=int((row+float(ihash(col,row,r['seed']+19)))*79)
   length=16+int(ihash(col,row,r['seed']+29)*38)
   pts=[(px,py),(px+length//3,py-3),(px+length*2//3,py-2),(px+length,py-6)]
   d.line(pts,fill=r['palette']['rock'][1],width=1)
   d.line([(a,b-1) for a,b in pts[:3]],fill=r['palette']['rock'][3],width=1)
   if ihash(col,row,r['seed']+41)>.6:d.line([(px+length//3,py-3),(px+length//3-3,py+8),(px+length//3-1,py+16)],fill=r['palette']['rock'][1])
 return im

def generate(recipe_path,output,library_dir,region_path=BASE,road_dir=ROAD):
 r=read(recipe_path);context=Context(region_path,road_dir,library_dir);validate(r,context.region);output=refuse(output);output.mkdir(parents=True)
 manifests={};size=[context.w*32,context.h*32]
 for stage in ['base','transitions','final']:
  image=context.render(r,[0,0,*size],stage);image.save(output/(stage+'-atlas.png'));manifests[stage]=seam_metrics(image)
 cliff_texture(r,size).save(output/'cliff-atlas.png')
 # signed field + fine height mesh metadata; semantic physics remains immutable.
 blocked=context.layers['blocked'];scalar=[];step=.25;smoothedHeight=gaussian_filter(context.layers['elevationMilli'].astype(float),.85)
 for yy in np.arange(0,context.h+.001,step):
  row=[]
  for xx in np.arange(0,context.w+.001,step):
   rock=float(context.sample(context.rock,np.array(xx*32-.5),np.array(yy*32-.5)))
   elev=float(context.sample(smoothedHeight,np.array(xx*32-.5),np.array(yy*32-.5)))/1000
   row.append([round(rock,6),round(min(4.8,max(.65,(elev-.48)*9)),6)])
  scalar.append(row)
 (output/'relief-field.json').write_bytes(canonical({'schema':'valdoria-material-relief/v1','stepUnits':step,'samples':scalar,'sizeUnits':[context.w,context.h],'physicsChanged':False}))
 chunks=[{'id':f'{x//512}-{y//512}','rectPixels':[x,y,min(512,size[0]-x),min(512,size[1]-y)]} for y in range(0,size[1],512) for x in range(0,size[0],512)]
 contract={'schema':'valdoria-material-composition/v1','generator':VERSION,'regionRef':{'path':str(Path(region_path).relative_to(ROOT)).replace('\\','/'),'sha256':sha(Path(region_path).read_bytes())},'roadRef':{'path':str(Path(road_dir).relative_to(ROOT)).replace('\\','/'),'sha256':sha((Path(road_dir)/'road.json').read_bytes()),'masks':{k:sha((Path(road_dir)/(k+'.png')).read_bytes()) for k in context.masks}},'recipeSha256':sha(canonical(r)),'librarySha256':sha((Path(library_dir)/'library.json').read_bytes()),'seed':r['seed'],'style':r['style'],'ppu':32,'sizePixels':size,'chunks':chunks,'stages':['base','transitions','final'],'light':'upper-left','geometryInvariant':True,'artStatus':'candidate-awaiting-visual-review','metrics':manifests}
 (output/'composition.json').write_bytes(canonical(contract));(output/'manifest.json').write_bytes(canonical({'schema':'valdoria-material-build/v1','recipeSha256':contract['recipeSha256'],'regionSha256':contract['regionRef']['sha256'],'roadSha256':contract['roadRef']['sha256'],'librarySha256':contract['librarySha256'],'files':{p.name:sha(p.read_bytes()) for p in sorted(output.iterdir()) if p.is_file()}}))
 return contract

def verify_manifest(output):
 output=Path(output);manifest=read(output/'manifest.json')
 if manifest.get('schema')!='valdoria-material-build/v1':raise ValueError('Build schema')
 for name,digest in manifest['files'].items():
  if Path(name).name!=name or sha((output/name).read_bytes())!=digest:raise ValueError('Manifest mismatch '+name)
 c=read(output/'composition.json')
 if manifest['regionSha256']!=c['regionRef']['sha256'] or manifest['roadSha256']!=c['roadRef']['sha256']:raise ValueError('Composition mismatch')
 for ref in ['regionRef','roadRef']:
  path=ROOT/c[ref]['path'];path=path/'road.json' if path.is_dir() else path
  if sha(path.read_bytes())!=c[ref]['sha256']:raise ValueError('Input hash mismatch '+ref)
 return manifest

def verify(recipe_path,output,library_dir,region_path=BASE,road_dir=ROAD):
 manifest=verify_manifest(output)
 with tempfile.TemporaryDirectory() as tmp:
  # preserve relative input paths so composition provenance is byte-identical
  generate(recipe_path,Path(tmp)/'rebuilt',library_dir,region_path,road_dir)
  for p in Path(output).iterdir():
   if p.is_file() and p.read_bytes()!=(Path(tmp)/'rebuilt'/p.name).read_bytes():raise ValueError('Rebuild mismatch '+p.name)
 return True

def export_library(source,output):
 output=refuse(output);output.mkdir(parents=True)
 source=Path(source);target=output/'terrain-motifs.aseprite';target.write_bytes(source.read_bytes())
 subprocess.run([r'D:\Aseprite\Aseprite.exe','-b',str(target),'--save-as',str(output/'motifs.png')],check=True)
 image=Image.open(output/'motifs.png')
 if image.size!=(384,192) or image.mode!='RGBA':raise ValueError('Editable library must remain 384x192 RGBA')
 metadata={'schema':'valdoria-material-library/v1','canvas':[384,192],'module':[128,32],'kinds':KINDS,'variants':['sparse accent','cluster','wear or moss'],'palette':PALETTES,'light':'upper-left','allowedTransforms':['translation'],'source':'terrain-motifs.aseprite','author':'Edited original Valdoria material source, exported by Aseprite','license':'Original project work','files':{p.name:sha(p.read_bytes()) for p in output.iterdir()}}
 (output/'library.json').write_bytes(canonical(metadata));return metadata

def render_crop(recipe_path,output,library_dir,bounds,stage='final',region_path=BASE,road_dir=ROAD):
 r=read(recipe_path);ctx=Context(region_path,road_dir,library_dir);validate(r,ctx.region);out=refuse(output);out.mkdir(parents=True)
 image=ctx.render(r,bounds,stage);image.save(out/'patch.png')
 (out/'manifest.json').write_bytes(canonical({'schema':'valdoria-material-patch-build/v1','generator':VERSION,'boundsPixels':bounds,'stage':stage,'recipeSha256':sha(canonical(r)),'regionSha256':sha(Path(region_path).read_bytes()),'roadSha256':sha((Path(road_dir)/'road.json').read_bytes()),'files':{'patch.png':sha((out/'patch.png').read_bytes())}}))
 return image

def main():
 p=argparse.ArgumentParser();p.add_argument('command',choices=['library','export-library','generate','verify','recipes','render']);p.add_argument('--output',required=True);p.add_argument('--recipe');p.add_argument('--source');p.add_argument('--bounds',type=json.loads);p.add_argument('--stage',default='final');p.add_argument('--library');p.add_argument('--region',default=str(BASE));p.add_argument('--road',default=str(ROAD));a=p.parse_args()
 if a.command=='library':library(a.output)
 elif a.command=='export-library':export_library(a.source,a.output)
 elif a.command=='recipes':
  out=refuse(a.output);out.mkdir(parents=True)
  for style in 'ABC':(out/('recipe-'+style+'.json')).write_bytes(canonical(recipe(style)))
 elif a.command=='generate':generate(a.recipe,a.output,a.library,a.region,a.road)
 elif a.command=='render':render_crop(a.recipe,a.output,a.library,a.bounds,a.stage,a.region,a.road)
 else:print(json.dumps({'reproducible':verify(a.recipe,a.output,a.library,a.region,a.road)}))
if __name__=='__main__':main()
