"""Art direction 1.1 for the existing Material Agent. Geometry is consumed, never rebuilt."""
import json,math,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageChops
from scipy.spatial import cKDTree
from scipy.ndimage import gaussian_filter
VERSION='terrain-materials/1.1.0'
# Palette anchors; intermediate pigment values are quantized RGB, not blurred texture.
PALETTES={
 'grass':['#3e5435','#4a603a','#566d40','#627b47','#758c52','#8e9f65'],
 'dirt':['#6e573e','#816746','#957b54','#aa9066','#bba47a','#ccb991'],
 'rock':['#414a44','#566052','#6b7564','#808a75','#96a08a','#aeb59e'],
 'mud':['#454335','#57503b','#6a6043','#80734f','#958660','#aa9b74'],
 'sand':['#8c7953','#9d8a5e','#b0a06e','#c4b580','#d7c894','#e5d7a9'],
 'road':['#745f43','#89724f','#9f865e','#b19a70','#c2ad84','#d1bf98']}
FUNCTIONS={
 'grass':['short used blades','swept blades','tall fan','broad leaf rosette','dry seedheads','creeping moss'],
 'dirt':['compacted grains','exposed soil edge','broken scuff','root fissure','loose fragments','soil deposit'],
 'rock':['shallow plate','joint fracture','scree group','mineral vein','moss seam','soil pocket'],
 'mud':['moist margin','shallow rut','small depression','dry crust','restrained sheen','wet soil edge'],
 'sand':['fine grains','short ripples','deposition fan','lee accumulation','gravel mix','soil transition'],
 'road':['fine gravel','scuff','compressed patch','short rut','margin rubble','worn soil']}
def recipe(style='A'):
 import terrain_materials as m
 r=m.recipe(style);r.update(version=VERSION,palette=PALETTES,detailDensity={'A':.60,'B':.78,'C':.70}[style],artDirection='contextual-hierarchy',pigmentContrast={'A':1.,'B':1.18,'C':1.10}[style],clusterSpacing=112)
 if style=='C':r['palette']=dict(PALETTES,grass=['#385238','#46633e','#527347','#618251','#77945e','#91a674'])
 return r

def library(output,source):
 import terrain_materials as m
 output=m.refuse(output);output.mkdir(parents=True);source=Path(source)
 if not source.is_file():raise FileNotFoundError(source)
 size=(768,192);layers={n:Image.new('RGBA',size) for n in ['Pigment - contact masses','Forms - diverse silhouettes','Edges - upper left light','Accents - structured wear']}
 for row,kind in enumerate(m.KINDS):
  c=PALETTES[kind]
  for v in range(6):
   x=v*128+64;y=row*32+16
   d,f,e,a=[ImageDraw.Draw(im) for im in layers.values()]
   if kind=='grass':
    if v in (0,1,2,4):
     blades={0:[(-3,2,3),(1,2,4),(4,3,2)],1:[(-6,3,5),(-1,3,7),(3,4,4)],2:[(-6,4,9),(-2,4,13),(2,4,11),(6,5,7)],4:[(-4,4,8),(2,4,10)]}[v]
     for dx,dy,h in blades:
      lean={0:0,1:-3,2:2,4:-1}[v];tip=(x+dx+lean,y+dy-h)
      d.polygon([(x+dx-2,y+dy),tip,(x+dx+1,y+dy-1),(x+dx+3,y+dy+1)],fill=c[1]);f.line([(x+dx,y+dy-1),(tip[0],tip[1]+1)],fill=c[3]);e.point(tip,fill=c[4])
      if v==4:a.line((tip[0]-1,tip[1]-1,tip[0]+1,tip[1]-1),fill=PALETTES['sand'][2])
    elif v==3:
     for dx,dy in [(-5,-1),(2,-4),(5,1),(-2,3)]:
      d.polygon([(x,y+2),(x+dx-3,y+dy),(x+dx,y+dy-2),(x+dx+3,y+dy+1)],fill=c[1]);f.line((x+dx-1,y+dy-1,x+dx+1,y+dy),fill=c[3])
    else:
     d.polygon([(x-10,y+2),(x-7,y-1),(x-2,y),(x+1,y-3),(x+5,y-1),(x+11,y+2),(x+4,y+4),(x-5,y+4)],fill=c[1]);f.line([(x-7,y),(x-3,y+1),(x+1,y-1),(x+6,y+1)],fill=c[3]);a.point((x+1,y-2),fill=c[4])
   elif kind=='rock':
    if v in (0,2):
     for dx,dy,scale in ([(-5,1,.5),(4,3,.3),(0,-3,.25)] if v==2 else [(0,0,.85)]):
      pts=[(x+dx+int(xx*scale),y+dy+int(yy*scale)) for xx,yy in [(-10,2),(-6,-5),(2,-6),(10,-1),(6,5),(-3,6)]]
      d.polygon(pts,fill=c[1]);f.polygon(pts[:4]+[(x+dx,y+dy+1)],fill=c[3]);e.line(pts[:3],fill=c[4])
    elif v==1:
     d.line([(x-14,y+3),(x-5,y),(x+3,y+1),(x+14,y-4)],fill=c[0],width=2);e.line([(x-14,y+1),(x-5,y-2),(x+3,y-1),(x+13,y-6)],fill=c[3]);a.line([(x-5,y),(x-2,y+4),(x-3,y+9)],fill=c[1])
    elif v==3:
     d.line([(x-11,y+4),(x-4,y),(x+2,y+1),(x+10,y-3)],fill=c[2],width=3);e.line([(x-10,y+3),(x-3,y-1),(x+3,y),(x+10,y-4)],fill=c[4])
    elif v==4:
     d.polygon([(x-11,y+2),(x-4,y-2),(x+1,y),(x+9,y-3),(x+12,y),(x+5,y+3),(x-5,y+5)],fill=PALETTES['grass'][1]);e.line([(x-8,y+1),(x-3,y),(x+1,y+1)],fill=PALETTES['grass'][3])
    else:
     d.polygon([(x-10,y+1),(x-2,y-2),(x+8,y),(x+3,y+4),(x-6,y+5)],fill=PALETTES['dirt'][1]);a.line((x-3,y,x+2,y),fill=PALETTES['dirt'][2])
   elif kind in ['dirt','road']:
    if v in (0,4):
     for n,(dx,dy) in enumerate([(-5,0),(3,2),(0,-3)] if v==4 else [(-2,0),(2,1)]):
      d.polygon([(x+dx-2,y+dy),(x+dx,y+dy-2),(x+dx+2,y+dy),(x+dx+1,y+dy+1)],fill=c[1]);e.point((x+dx,y+dy-2),fill=c[3])
    elif v in (1,2,3):
     pts=[(x-9,y+2),(x-2,y),(x+2,y+1),(x+8,y-1)] if v!=3 else [(x-5,y-5),(x-2,y),(x-4,y+3),(x,y+6)]
     d.line(pts,fill=c[1],width=1);e.line([(a-1,b-1) for a,b in pts[:3]],fill=c[3]);
     if v==2:a.line((x+3,y+3,x+6,y+2),fill=c[2])
    else:
     d.polygon([(x-11,y),(x-5,y-3),(x+3,y-2),(x+10,y+1),(x+2,y+4),(x-7,y+2)],fill=c[2]);f.line([(x-7,y-1),(x-2,y-2),(x+4,y-1)],fill=c[3])
   elif kind=='mud':
    if v in (0,2,4,5):
     pts=[(x-10+v,y+1),(x-5,y-3),(x+3,y-2),(x+10-v,y+1),(x+2,y+3),(x-4,y+3)]
     d.polygon(pts,fill=c[1]);f.line((x-4,y-2,x+2,y-2),fill=c[2]);
     if v==4:e.line((x-2,y-2,x+2,y-2),fill=c[4])
     elif v==2:e.line((x-5,y+2,x+3,y+3),fill=c[0])
     elif v==5:a.line((x-8,y+1,x-4,y+2),fill=PALETTES['dirt'][2])
    elif v==1:d.line([(x-7,y-5),(x-4,y-1),(x-5,y+3),(x,y+6)],fill=c[0]);e.line([(x-8,y-5),(x-5,y-1),(x-6,y+3)],fill=c[2])
    else:
     d.line([(x-9,y+2),(x-3,y-1),(x+4,y+1),(x+9,y-2)],fill=c[0]);a.line((x-3,y-1,x-1,y-5),fill=c[1])
   else:
    if v in (1,2,3):
     for n in range(2+(v==2)):
      yy=y-4+n*4;d.line([(x-10+n*2,yy+1),(x-2,yy),(x+8-n*2,yy+2)],fill=c[1]);e.line((x-4,yy-1,x+3,yy),fill=c[3])
     if v==3:a.line((x+8,y,x+10,y+1),fill=c[0])
    else:
     for n in range(v+1):dx=(n*7)%17-8;dy=(n*3)%9-4;d.point((x+dx,y+dy),fill=c[1]);e.point((x+dx,y+dy-1),fill=c[3])
 for name,im in layers.items():im.save(output/(name.replace(' ','_')+'.png'))
 flat=Image.new('RGBA',size)
 for im in layers.values():flat=Image.alpha_composite(flat,im)
 flat.save(output/'motifs-preview.png')
 # Open and resize the actual previous source: keeps the editable provenance chain.
 lua='local root=app.params["root"]\nlocal s=app.open(app.params["source"])\ns:resize(768,192)\n'
 lua+='for i=#s.layers,1,-1 do s:deleteLayer(s.layers[i]) end\n'
 for name in layers:
  lua+=f'local t=app.open(root.."/{name.replace(" ","_")}.png");local l=s:newLayer();l.name="{name}";s:newCel(l,1,t.cels[1].image,Point(0,0));t:close()\n'
 lua+='local l=s:newLayer();l.name="Paint refinements"\napp.activeSprite=s\ns:saveAs(root.."/terrain-motifs.aseprite")\ns:saveCopyAs(root.."/motifs.png")\ns:close()\n'
 (output/'assemble.lua').write_text(lua,encoding='utf8')
 subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+output.resolve().as_posix(),'--script-param','source='+source.resolve().as_posix(),'--script',str(output/'assemble.lua')],check=True)
 if not np.array_equal(np.array(Image.open(output/'motifs.png')),np.array(flat)):raise ValueError('Aseprite roundtrip')
 meta={'schema':'valdoria-material-library/v2','canvas':list(size),'module':[128,32],'kinds':m.KINDS,'functions':FUNCTIONS,'variants':6,'palette':PALETTES,'light':'upper-left','allowedTransforms':['translation'],'source':'terrain-motifs.aseprite','parentSource':source.relative_to(m.ROOT).as_posix(),'parentSha256':m.sha(source.read_bytes()),'author':'Original Valdoria material refinement, Python plus Aseprite editable revision','license':'Original project work','files':{p.name:m.sha(p.read_bytes()) for p in output.iterdir() if p.is_file()}}
 (output/'library.json').write_bytes(m.canonical(meta));return meta

def global_arcs(ctx):
 offset=0.;arcs=[]
 for segment in ctx.road['segments']:
  arcs.extend((np.array(segment['samples'])[:,2]+offset)*32);offset+=segment['length']
 return np.array(arcs)

def road_space(ctx,x,y):
 dist,idx=ctx.tree.query(np.column_stack([np.asarray(x).ravel()+.5,np.asarray(y).ravel()+.5]),workers=1)
 pts=ctx.samples[:,:2]*32;d=np.gradient(pts,axis=0);d/=np.maximum(np.linalg.norm(d,axis=1,keepdims=True),1e-9)
 delta=np.column_stack([np.asarray(x).ravel()+.5,np.asarray(y).ravel()+.5])-pts[idx]
 tangent=d[idx];signed=delta[:,0]*(-tangent[:,1])+delta[:,1]*tangent[:,0]
 return tuple(a.reshape(np.asarray(x).shape) for a in [dist,signed,global_arcs(ctx)[idx],ctx.samples[idx,3]*32]),tangent

def rock_structure(x,y,seed):
 import terrain_materials as m
 # Irregular connected joint network. Sites define mineral planes, not decorative stones.
 coords=np.column_stack([(np.asarray(x).ravel()*.88+np.asarray(y).ravel()*.19),np.asarray(y).ravel()*1.3])
 sx,sy=np.meshgrid(np.arange(int(np.floor(coords[:,0].min()/79))-3,int(np.floor(coords[:,0].max()/79))+4),np.arange(int(np.floor(coords[:,1].min()/73))-3,int(np.floor(coords[:,1].max()/73))+4));sx=sx.ravel();sy=sy.ravel()
 sites=np.column_stack([(sx+.15+.70*m.ihash(sx,sy,seed+41))*79,(sy+.15+.70*m.ihash(sx,sy,seed+47))*73])
 distances,near=cKDTree(sites).query(coords,k=2,workers=1)
 delta=distances[:,1]-distances[:,0];v=coords-sites[near[:,0]];normal=v/np.maximum(np.linalg.norm(v,axis=1,keepdims=True),1e-6)
 light=(-normal[:,0]*.7-normal[:,1]*.7)
 plate=m.ihash(sx[near[:,0]],sy[near[:,0]],seed+53)-.5
 worldId=sx+sy*100000;pairA=np.minimum(worldId[near[:,0]],worldId[near[:,1]]);pairB=np.maximum(worldId[near[:,0]],worldId[near[:,1]]);active=(m.ihash(pairA,pairB,seed+59)<.43)
 bevel=((delta>=1.2)&(delta<3.2))*np.where(light>.15,8,-3)*active;crack=(delta<1.2)*18*active
 return (plate*2+bevel-crack).reshape(np.asarray(x).shape),np.where(active,delta,999).reshape(np.asarray(x).shape)

def context_fields(ctx,r,x,y):
 import terrain_materials as m
 wet=ctx.sample(ctx.layers['moistureMilli'],x,y)/1000;rock=ctx.sample(ctx.rock,x,y);slope=ctx.sample(ctx.layers['slopeMilli'],x,y)/1000
 (distance,signed,arc,width),tangent=road_space(ctx,x,y)
 use=np.exp(-np.maximum(0,distance-width*.5)/25)
 # Density and exposure follow use, moisture and obstacle foot, not arbitrary pigment islands.
 foot=np.exp(-((rock+.65)/.85)**2)*(rock<0)
 growth=m.field(x,y,149,r['seed']+131)
 return wet,rock,slope,distance,signed,arc,width,tangent,use,foot,growth

def ramp(r,kind,tone):
 import terrain_materials as m
 p=m.palette(r,kind).astype(float);tone=np.clip(tone,0,5);lo=np.floor(tone).astype(int);hi=np.minimum(5,lo+1);a=(tone-lo)[...,None]
 return np.rint(p[lo]*(1-a)+p[hi]*a).astype('uint8')

def instances(ctx,r):
 import terrain_materials as m
 seed=r['seed'];items=[];spacing=r.get('clusterSpacing',112)
 for gy in range(-1,ctx.h*32//spacing+2):
  for gx in range(-1,ctx.w*32//spacing+2):
   px=(gx+.1+.8*float(m.ihash(gx,gy,seed+701)))*spacing;py=(gy+.1+.8*float(m.ihash(gx,gy,seed+709)))*spacing
   if not 0<=px<ctx.w*32 or not 0<=py<ctx.h*32:continue
   a=context_fields(ctx,r,np.array(px),np.array(py));wet,rock,slope,distance,signed,arc,width,tangent,use,foot,growth=a
   chance=float(growth)*.70+.15+float(foot)*.18
   if float(m.ihash(gx,gy,seed+719))>chance*r['detailDensity']:continue
   count=5+int(m.ihash(gx,gy,seed+727)*10)
   radius=18+float(m.ihash(gx,gy,seed+733))*27
   for child in range(count):
    u=float(m.ihash(gx*31+child,gy,seed+739));v=float(m.ihash(gx,gy*31+child,seed+743));angle=u*math.tau;rr=radius*math.sqrt(v)
    x=int(px+math.cos(angle)*rr);y=int(py+math.sin(angle)*rr*.62)
    if not 0<=x<ctx.w*32 or not 0<=y<ctx.h*32:continue
    wet,rock,slope,dist,sign,arc,width,tangent,use,foot,growth=context_fields(ctx,r,np.array(x),np.array(y))
    cov=ctx.masks['coverage'][y,x]/255
    if cov>.02:continue # Road marks are authored along the axis separately.
    v=int(m.ihash(x,y,seed+751)*6)
    if rock>.1:
     if rock>1.2 or float(m.ihash(x,y,seed+757))>.28:continue
     kind=2;v=4 if wet>.57 else 2
    elif wet>.61 and growth>.5:kind=3;v=4 if wet>.65 else v
    elif wet<.39 and growth<.3:kind=4
    elif use>.7:
     if float(m.ihash(x,y,seed+761))>.35:continue
     kind=0;v=0 # low grass, readable margins
    elif foot>.55:
     if wet<.52 and float(m.ihash(x,y,seed+763))<.22:kind=1;v=5
     else:kind=0;v=5 if wet>.52 else 4
    else:kind=0;v=[1,2,2,3,0,4][v] if growth>.55 and use<.2 else v
    items.append({'x':x,'y':y,'kind':kind,'variant':v,'parent':[gx,gy]})
 # Stable priority, minimum centre distance across parents.
 ordered=sorted(items,key=lambda p:float(m.ihash(p['x'],p['y'],seed+769)));accepted=[];bins={}
 for p in ordered:
  x,y=p['x'],p['y'];bx=x//9;by=y//9
  if any((x-q['x'])**2+(y-q['y'])**2<64 for oy in (-1,0,1) for ox in (-1,0,1) for q in bins.get((bx+ox,by+oy),[])):continue
  accepted.append(p);bins.setdefault((bx,by),[]).append(p)
 return sorted(accepted,key=lambda p:(p['y'],p['x']))

def wear_marks(ctx,r):
 import terrain_materials as m
 pts=ctx.samples;arcs=global_arcs(ctx);result=[];last=-100
 for i,p in enumerate(pts):
  arc=arcs[i]
  if arc<last+34:continue
  if float(m.ihash(i,0,r['seed']+811))>{'A':.66,'B':.86,'C':.72}[r['style']]:continue
  last=arc;d=pts[min(i+2,len(pts)-1),:2]-pts[max(0,i-2),:2];d=d/max(np.linalg.norm(d),1e-9);n=np.array([-d[1],d[0]])
  offset=(float(m.ihash(i,0,r['seed']+821))-.5)*p[3]*32*.60
  for child in range(2+int(m.ihash(i,0,r['seed']+823)*3)):
   length=3+int(m.ihash(i,child,r['seed']+827)*12);center=p[:2]*32+n*(offset+child*2)+d*(child*3)
   result.append({'x':float(center[0]),'y':float(center[1]),'dx':float(d[0]),'dy':float(d[1]),'length':length,'arcPixels':float(arc),'function':'directional compaction scuff'})
 return result

def render(ctx,r,bounds,stage):
 import terrain_materials as m
 x0,y0,w,h=map(int,bounds);y,x=np.mgrid[y0:y0+h,x0:x0+w];a=context_fields(ctx,r,x,y);wet,rock,slope,dist,signed,arc,width,tang,use,foot,growth=a
 pigment=(m.field(x,y,193,r['seed']+11)-.5)*.12+(m.field(x,y,57,r['seed']+29)-.5)*.055
 # Macro fields now modulate very low contrast; no floor() palette islands.
 pigment*=r.get('pigmentContrast',1)
 grassTone=2.30+pigment+(wet-.5)*.55-use*.15+foot*.06
 rgb=ramp(r,'grass',np.rint(grassTone*8)/8)
 # Controlled 3-9px sward clusters: bounded colour and directional forms, never independent pixel noise.
 sward=m.field(x*.92+y*.17,y*1.65,9,r['seed']+401)
 swardShade=np.where(sward>.68,5,np.where(sward<.25,-3,0))*(1-use*.6)
 rgb[:,:,:3]=np.clip(rgb[:,:,:3].astype(float)+swardShade[...,None],0,255).astype('uint8')
 if stage!='base':
  exposure=np.clip(use*.22+foot*.22+(0.42-wet)*.45,0,.34)
  # smooth context colour transitions, still point-filtered discrete pixels
  dirt=ramp(r,'dirt',1.95+pigment)
  rgb=np.rint(rgb*(1-exposure[...,None])+dirt*exposure[...,None]).astype('uint8')
  wetAlpha=(np.clip((wet-.60)*4,0,.24)*np.clip(foot+.2,0,1))[...,None];mud=ramp(r,'mud',2.3+pigment)
  rgb=np.rint(rgb*(1-wetAlpha)+mud*wetAlpha).astype('uint8')
  sandAlpha=(np.clip((.38-wet)*4,0,.20)*(1-use))[...,None];sand=ramp(r,'sand',2.1+pigment)
  rgb=np.rint(rgb*(1-sandAlpha)+sand*sandAlpha).astype('uint8')
  rockAlpha=np.rint(np.clip((rock+.10)/.20,0,1)*3)/3
  structure,joint=rock_structure(x,y,r['seed']);structure*=r.get('pigmentContrast',1)
  smoothed=gaussian_filter(ctx.layers['elevationMilli'].astype(float),.85)/1000;dy,dx=np.gradient(smoothed)
  light=np.rint((ctx.sample(dx,x,y)*190+ctx.sample(dy,x,y)*135)/5)*5
  mineral=m.field(x*.55+y*.22,y*1.25,8,r['seed']+409)
  mineralShade=np.where(mineral>.72,3,np.where(mineral<.22,-2,0))
  secondary,_=rock_structure(x*2.35+31,y*2.35-19,r['seed']+1009)
  fractureZone=np.clip(1-joint/20,0,1)
  structure+=mineralShade+secondary*fractureZone*.58
  stone=ramp(r,'rock',2.45+pigment);stone[:,:,:3]=np.clip(stone[:,:,:3].astype(float)+(structure+light)[...,None],0,255).astype('uint8')
  rgb=np.rint(rgb*(1-rockAlpha[...,None])+stone*rockAlpha[...,None]).astype('uint8')
  coverage=ctx.masks['coverage'][y0:y0+h,x0:x0+w]/255;wear=ctx.masks['wear'][y0:y0+h,x0:x0+w]/255;shoulder=ctx.masks['shoulders'][y0:y0+h,x0:x0+w]/255
  wandering=np.sin(arc/137)*.06+np.sin(arc/61)*.025
  compact=np.exp(-((signed/np.maximum(width*.43,1)+wandering)**2))
  interrupted=.82+.18*m.field(arc,np.zeros_like(arc),113,r['seed']+151)
  roadTone=2.05+compact*.29*interrupted+wear*.07+(m.field(arc,signed,53,r['seed']+157)-.5)*.035
  road=ramp(r,'road',np.rint(roadTone*10)/10)
  soilGrain=m.field(arc*.55,signed*1.65,9,r['seed']+419)
  grainShade=np.where(soilGrain>.70,2,np.where(soilGrain<.22,-3,0))*(.4+wear*.6)
  road[:,:,:3]=np.clip(road[:,:,:3].astype(float)+grainShade[...,None],0,255).astype('uint8')
  rgb=np.rint(rgb*(1-coverage[...,None])+road*coverage[...,None]).astype('uint8');rgb[:,:,3]=255
  # shoulders remain a supplied appearance signal, never alter coverage/navigation
  shoulderTint=(shoulder*(1-coverage)*.08)[...,None];rgb=np.rint(rgb*(1-shoulderTint)+dirt*shoulderTint).astype('uint8');rgb[:,:,3]=255
 for patch in r.get('patches',[]):
  px,py,pw,ph=patch['rectPixels'];mask=(x>=px)&(x<px+pw)&(y>=py)&(y<py+ph);rgb[mask,:3]=np.clip(rgb[mask,:3].astype(int)+patch['toneOffset']*4,0,255)
 image=Image.fromarray(rgb)
 if stage=='final':
  overlay=Image.new('RGBA',image.size)
  if not hasattr(ctx,'_refined_instances'):ctx._refined_instances={}
  key=m.sha(m.canonical(r))
  if key not in ctx._refined_instances:ctx._refined_instances[key]=instances(ctx,r)
  for p in ctx._refined_instances[key]:
   if not x0-32<=p['x']<x0+w+32 or not y0-32<=p['y']<y0+h+32:continue
   v=p['variant'];kind=p['kind'];stamp=ctx.motifs.crop((v*128+48,kind*32,v*128+80,kind*32+32));overlay.alpha_composite(stamp,(p['x']-x0-16,p['y']-y0-16))
  draw=ImageDraw.Draw(overlay);marks=wear_marks(ctx,r)
  for p in marks:
   px,py=p['x'],p['y'];l=p['length'];dx=p['dx'];dy=p['dy'];a=(round(px-l*.5*dx-x0),round(py-l*.5*dy-y0));b=(round(px+l*.5*dx-x0),round(py+l*.5*dy-y0))
   # Project only an editable source ALPHA silhouette, then recolour/relight in world space.
   # Never rotate a prelit stone/plant sprite or its baked highlights.
   variant=1+(int(p['arcPixels'])%2);brush=ctx.motifs.crop((variant*128+48,5*32,variant*128+80,6*32)).getchannel('A');bbox=brush.getbbox()
   if bbox:
    brush=brush.crop(bbox).resize((l,3),Image.Resampling.NEAREST).rotate(-math.degrees(math.atan2(dy,dx)),resample=Image.Resampling.NEAREST,expand=True)
    pos=(round(px-x0-brush.width*.5),round(py-y0-brush.height*.5))
    overlay.paste(r['palette']['road'][2],(pos[0]-1,pos[1]-1),brush);overlay.paste(r['palette']['road'][1],pos,brush)
   # Source gravel remains upright, with upper-left light; mainly off the compaction core.
   if int(p['arcPixels'])%3==0:
    nx=-dy*10;ny=dx*10;v=0 if int(p['arcPixels'])%2 else 4
    stone=ctx.motifs.crop((v*128+48,5*32,v*128+80,6*32));overlay.alpha_composite(stone,(round(px+nx-x0-16),round(py+ny-y0-16)))
  pixels=np.array(overlay);cov=ctx.masks['coverage'][y0:y0+h,x0:x0+w]/255
  # partial coverage boundary stays exactly as the original road's material blend
  pixels[(cov>.02)&(cov<.98),3]=0
  image=Image.alpha_composite(image,Image.fromarray(pixels))
 return image

def cliff_texture(r,size):
 import terrain_materials as m
 y,x=np.mgrid[0:size[1],0:size[0]];structure,joint=rock_structure(x,y,r['seed']);base=ramp(r,'rock',np.full(x.shape,2.5));mineral=m.field(x*.55+y*.22,y*1.25,8,r['seed']+409);mineralShade=np.where(mineral>.72,3,np.where(mineral<.22,-2,0))
 secondary,_=rock_structure(x*2.35+31,y*2.35-19,r['seed']+1009)
 base[:,:,:3]=np.clip(base[:,:,:3].astype(float)+(structure*1.10+mineralShade+secondary*np.clip(1-joint/20,0,1)*.58)[...,None],0,255).astype('uint8')
 # Stratification is broken by the joint network, not a repeated band or tile border.
 im=Image.fromarray(base);d=ImageDraw.Draw(im)
 for band in range(-1,size[1]//83+2):
  for segment in range(-1,size[0]//143+2):
   xx=int((segment+float(m.ihash(segment,band,r['seed']+907)))*143);yy=int((band+float(m.ihash(segment,band,r['seed']+911)))*83);length=24+int(m.ihash(segment,band,r['seed']+919)*34)
   pts=[(xx,yy),(xx+length//3,yy-3),(xx+length*2//3,yy-2),(xx+length,yy-6)]
   d.line(pts,fill=r['palette']['rock'][1]);d.line([(a,b-1) for a,b in pts],fill=r['palette']['rock'][3])
 return im

def main():
 import argparse,terrain_materials as m
 p=argparse.ArgumentParser();p.add_argument('command',choices=['library','recipes']);p.add_argument('--output',required=True);p.add_argument('--source',default=str(m.ROOT/'ArtSource/Labs/World2026/WorldStudio03/LibraryV2/terrain-motifs.aseprite'));a=p.parse_args()
 if a.command=='library':library(a.output,a.source)
 else:
  out=m.refuse(a.output);out.mkdir(parents=True)
  for style in 'ABC':(out/('recipe-'+style+'.json')).write_bytes(m.canonical(recipe(style)))
if __name__=='__main__':main()
