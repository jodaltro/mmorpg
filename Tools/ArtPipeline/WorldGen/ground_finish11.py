"""Authored ground + topology-aware road finishing, offline only.

Pixel authority: Aseprite. Geometry authority: immutable producer coverage / paths.
The grammar court is a separate noncanonical visual fixture, never world navigation.
"""
import argparse,json,math,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import distance_transform_edt,gaussian_filter,map_coordinates
from scipy.spatial import cKDTree
import nature_reference10 as n
import terrain_materials as m
import organic_roads as roads

ROOT=n.ROOT;BASE=ROOT/'ArtSource/Labs/World2026/Ground11';VERSION='valdoria-ground-finish/1.0.0'
SOURCE=BASE/'SourceV2';EXPORT=BASE/'ExportV2';SEED=910211
def read(p):return n.read(p)
def write(p,d):n.write(p,d)
def ref(p):return n.arch.ref(p)
def manifest(p,inputs):write(p/'manifest.json',{'schema':'valdoria-ground-finish-build/v1','version':VERSION,'inputs':inputs,'files':{f.name:n.common.sha(f.read_bytes()) for f in sorted(p.iterdir()) if f.is_file() and f.name!='manifest.json'}})
def lua(code,p):n.lua(code,p)
def refuse(p):return n.common.refuse(p)

def prepare():
 out=refuse(SOURCE);out.mkdir(parents=True);code=''
 for kind in ('meadow','earth'):
  code+=f'do local master=app.open({n.q(BASE/"Masters"/(kind+".png"))});local s=Sprite(512,512,ColorMode.RGB);local crop=Image(s.spec);crop:drawSprite(master,1,Point(-250,-300));s:newCel(s.layers[1],1,crop,Point(0,0));master:close();app.activeSprite=s;app.command.SpriteSize{{ui=false,width=384,height=384,method="nearest"}};app.command.ColorQuantization{{ui=false,maxColors=96,withAlpha=false,algorithm="octree"}};app.command.ChangePixelFormat{{ui=false,format="indexed",dithering="none"}};app.command.ChangePixelFormat{{ui=false,format="rgb"}};local canvas=Image(s.spec);canvas:drawSprite(s,1);s:deleteLayer(s.layers[1]);local images={{Image(s.spec),Image(s.spec),Image(s.spec),Image(s.spec)}};'
  # Exclusive ownership leaves the exact interpreted pixels unchanged.
  code+='for y=0,383 do for x=0,383 do local c=canvas:getPixel(x,y);local r,g,b=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c);local value=.2126*r+.7152*g+.0722*b;local part=value<70 and 1 or value<112 and 2 or value<158 and 3 or 4;images[part]:drawPixel(x,y,c) end end;'
  code+='local names={"Recesses and joints","Pigment body","Material planes","Small lit accents"};for i,name in ipairs(names) do local l=s:newLayer();l.name=name;s:newCel(l,1,images[i],Point(0,0)) end;'
  code+=f's:saveAs({n.q(out/(kind+".aseprite"))});s:close() end\n'
 lua(code,out/'initial-interpretation.lua')
 brushes(out)
 if not (BASE/'recipe.json').exists():write(BASE/'recipe.json',{'schema':'valdoria-ground-finish-recipe/v1','version':VERSION,'seed':SEED,'ppu':32,'nativeMaterialPixels':384,'worldSize':[64,48],'light':'upper-left','geometryChange':False,'grass':{'paintStrength':.88,'macroAmplitude':.055,'mesoAmplitude':.04,'quietAreaFraction':.3},'road':{'paintStrength':.95,'edgeVisualPixels':3,'brokenRimStrength':.08,'wearStrength':.10,'junctionWearSuppression':True},'contacts':{'maximumExtentUnits':1.15,'strength':.52},'courtOnly':True,'artisticStatus':'candidate-awaiting-user-review'})

def brushes(out):
 # Intentional small authored shapes; these supplement the surface paintings.
 code='local s=Sprite(512,128,ColorMode.RGB);s.layers[1].name="Grass dark support";local names={"Grass illuminated planes","Earth fragments","Fallen leaves"};for _,name in ipairs(names) do local l=s:newLayer();l.name=name end;local images={Image(s.spec),Image(s.spec),Image(s.spec),Image(s.spec)};'
 for v in range(8):
  # Each variant has a distinct blade rhythm, negative space and low foot.
  forms=[[(5,26,3,20),(9,27,12,17),(13,27,19,21)],[(6,27,9,20),(11,27,11,16),(16,28,23,23)],[(4,26,1,22),(8,26,13,19),(16,27,20,19)],[(6,27,2,21),(12,28,15,17),(19,28,25,24)],[(7,27,6,18),(12,28,18,21)],[(3,28,7,22),(12,27,10,19),(17,28,24,20)],[(5,27,2,24),(10,28,13,19),(17,29,21,24)],[(5,27,9,21),(12,28,11,17),(18,28,26,24)]][v]
  for a,b,c,d in forms:
   code+=f'do local ax,ay,bx,by={v*64+a},{b},{v*64+c},{d};for k=0,9 do local t=k/9;local x=math.floor(ax+(bx-ax)*t);local y=math.floor(ay+(by-ay)*t);images[1]:drawPixel(x,y,app.pixelColor.rgba(51,69,31,255));images[1]:drawPixel(x+1,y,app.pixelColor.rgba(76,93,39,255));if k>4 then images[2]:drawPixel(x-1,y,app.pixelColor.rgba(130,143,67,255)) end end end;'
  # Broken earth chips with different upper-plane sizes; no decorative colliders.
  x=v*64+16;y=65;w=3+v%3
  code+=f'for dy=0,2 do for dx=-{w},{w} do if math.abs(dx)+dy<{w+1} then images[3]:drawPixel({x}+dx,{y}+dy,app.pixelColor.rgba(135,111,72,255));if dy==0 then images[3]:drawPixel({x}+dx,{y}-1,app.pixelColor.rgba(183,158,106,255)) end end end end;'
  x=v*64+16;y=100
  code+=f'for k=0,5 do local x={x}+k;local y={y}+math.floor(k*.35);images[4]:drawPixel(x,y,app.pixelColor.rgba(120,99,47,255));images[4]:drawPixel(x,y-1,app.pixelColor.rgba(158,131,64,255));if k>0 and k<4 then images[4]:drawPixel(x,y+1,app.pixelColor.rgba(83,77,37,255)) end end;'
 code+='for i,l in ipairs(s.layers) do s:newCel(l,1,images[i],Point(0,0)) end;'
 code+=f's:saveAs({n.q(out/"edge-grammar.aseprite")});s:close()'
 lua(code,out/'initial-edge-grammar.lua')

def export(out,source=SOURCE):
 out=refuse(out);out.mkdir(parents=True);code=''
 for name in ('meadow','earth','edge-grammar'):
  w,h=(512,128) if name=='edge-grammar' else (384,384)
  code+=f'do local s=app.open({n.q(Path(source)/(name+".aseprite"))});assert(#s.frames==1 and #s.layers==4 and s.width=={w} and s.height=={h},"Ground source contract");local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({n.q(out/(name+".png"))});s:close() end\n'
 lua(code,out/'export.lua')
 for kind in ('meadow','earth'):
  if Image.open(out/(kind+'.png')).convert('RGBA').getchannel('A').getextrema()!=(255,255):raise ValueError('Surface painting must be opaque: '+kind)
 manifest(out,{p.name:ref(p) for p in Path(source).glob('*.aseprite')})

def sample_paint(kind,x,y,seed,library=EXPORT):
 """Overlapping translated painted patches, continuous weighted support.

 Never rotate baked lighting. No per-32px reset and no hard quilting joins.
 Full patch footprints depend on global coordinates, including for cropped builds.
 """
 im=np.array(Image.open(Path(library)/(kind+'.png')).convert('RGB')).astype(float)
 step=128.;gx=np.floor(x/step).astype(int);gy=np.floor(y/step).astype(int);result=np.zeros(x.shape+(3,));weights=np.zeros(x.shape)
 for dy in (0,1):
  for dx in (0,1):
   px=gx+dx;py=gy+dy;u=x/step-px;v=y/step-py
   weight=(.5+.5*np.cos(np.pi*np.clip(u,-1,1)))*(.5+.5*np.cos(np.pi*np.clip(v,-1,1)))
   ox=np.floor(m.ihash(px,py,seed)*128);oy=np.floor(m.ihash(px,py,seed+1)*128)
   # Overlapping translated 256px windows stay INSIDE the 384px painting.
   # No modulo: source-edge discontinuities cannot enter the patch interior.
   xx=np.clip(x-px*step+128+ox,0,383).astype(int);yy=np.clip(y-py*step+128+oy,0,383).astype(int)
   result+=im[yy,xx]*weight[...,None];weights+=weight
 return result/np.maximum(weights[...,None],1e-9)

def coverage_world(ctx):
 cov=ctx.masks['coverage'].copy();source=n.ref.SOURCE.parent/'RegionV1';access=read(source/'access-render.json');a=np.array(Image.open(source/'access.png').convert('RGBA'))[:,:,3];x,y,x1,y1=access['rectPixels'];cov[y:y1,x:x1]=np.maximum(cov[y:y1,x:x1],a)
 main=[];arc=0
 for segment in ctx.road['segments']:
  s=np.array(segment['samples']);main.extend(s[:,:2].tolist())
 paths=[np.array(main)*32,np.array(read(source/'house.json')['access']['points'])*32]
 return cov,paths

def resample_path(points,spacing=3):
 p=np.array(points,float);diff=np.diff(p,axis=0);length=np.linalg.norm(diff,axis=1);good=length>1e-6;p=np.concatenate((p[:1],p[1:][good]));arc=np.concatenate(([0],np.cumsum(np.linalg.norm(np.diff(p,axis=0),axis=1))));s=np.linspace(0,arc[-1],max(2,math.ceil(arc[-1]/spacing)+1));q=np.column_stack([np.interp(s,arc,p[:,k]) for k in (0,1)]);t=np.gradient(q,axis=0);t/=np.maximum(np.linalg.norm(t,axis=1,keepdims=True),1e-9);return q,t,s

def road_flow(paths,x,y,suppress=True):
 total=np.zeros(x.shape);wear=np.zeros(x.shape);vx=np.zeros(x.shape);vy=np.zeros(x.shape)
 points=np.column_stack([x.ravel()+.5,y.ravel()+.5])
 for j,path in enumerate(paths):
  q,t,s=resample_path(path);d,k=cKDTree(q).query(points);delta=points-q[k];cross=delta[:,0]*t[k,1]-delta[:,1]*t[k,0];along=s[k]+(delta*t[k]).sum(axis=1)
  weight=np.exp(-(d/75)**2).reshape(x.shape);phase=(cross.reshape(x.shape)+8*np.sin(along.reshape(x.shape)/113))
  stroke=np.exp(-((phase-12)/7)**2)*(.25+.75*np.clip(np.sin(along.reshape(x.shape)/91+j*1.3)*1.5,0,1))
  stroke+=np.exp(-((phase+18)/9)**2)*(.25+.75*np.clip(np.cos(along.reshape(x.shape)/127+j)*1.5,0,1))
  end=np.clip(np.minimum(along,s[-1]-along)/38,0,1).reshape(x.shape)
  total+=weight;wear+=stroke*weight*end
  tx=t[k,0].reshape(x.shape);ty=t[k,1].reshape(x.shape);vx+=(tx*tx-ty*ty)*weight;vy+=2*tx*ty*weight
 coherence=np.hypot(vx,vy)/np.maximum(total,1e-9)
 return wear/np.maximum(total,1e-9)*(coherence**2 if suppress else 1),coherence

def reference_contact_sites():
 recipe=read(n.BASE/'recipe.json');source=read(n.BASE/'SourceV2/source.json');assets={a['id']:a for a in source['assets']}
 sites=[]
 for p in recipe['treeReplacements']:
  sites.append({'id':p['instance'],'kind':'tree','point':p['point'],'influenceRadii':[1.22,.72]})
 for p in recipe['rocks']:
  sites.append({'id':p['id'],'kind':'rock','footprint':(np.array(assets[p['asset']]['footprintPixels'])/32+np.array(p['point'])).tolist()})
 sites.append({'id':'approved-rural-house','kind':'foundation','footprint':read(n.ref.SOURCE.parent/'RegionV1/house.json')['footprint']});return sites

def contacts(x,y,seed,sites=None):
 sites=reference_contact_sites() if sites is None else sites;xx=x/32;yy=y/32;root=np.zeros(x.shape);stone=np.zeros(x.shape);foundation=np.zeros(x.shape)
 for p in sites:
  if p['kind']=='tree':
   rx,ry=p['influenceRadii']
   if rx<=0 or ry<=0:raise ValueError('Positive contact influence radii required')
   dx=xx-p['point'][0];dy=yy-p['point'][1];shape=np.sqrt((dx/rx)**2+(dy/ry)**2);root=np.maximum(root,np.clip(1.1-shape+(m.field(x,y,14,seed+401)-.5)*.55,0,1))
  elif p['kind']=='rock':
   d=n.outside_distance(p['footprint'],xx,yy);stone=np.maximum(stone,np.clip((.60-d)/.60,0,1))
  elif p['kind']=='foundation':
   dist=n.outside_distance(p['footprint'],xx,yy);foundation=np.maximum(foundation,np.clip((.55-dist)/.55,0,1))
  else:raise ValueError('Unsupported contact kind')
 return root,stone,foundation

def render(bounds,coverage,paths,recipe,world=False,sites=None,library=EXPORT):
 H,W=coverage.shape
 if len(bounds)!=4 or any(type(v)!=int for v in bounds) or bounds[0]<0 or bounds[1]<0 or bounds[2]<=0 or bounds[3]<=0 or bounds[0]+bounds[2]>W or bounds[1]+bounds[3]>H:raise ValueError('Bounds must be positive integer pixels inside the complete coverage domain')
 x0,y0,w,h=bounds;y,x=np.mgrid[y0:y0+h,x0:x0+w];seed=recipe['seed']
 grass=sample_paint('meadow',x,y,seed,library);earth=sample_paint('earth',x,y,seed+29,library)
 # The painted source supplies material forms; fields only organize quiet/dense
 # areas and gentle context. They do not invent independent white-noise texture.
 macro=m.field(x,y,361,seed+91);meso=m.field(x,y,97,seed+97)
 quiet=np.clip((m.field(x,y,223,seed+101)-(1-recipe['grass']['quietAreaFraction']))*3.5,0,.70)
 grass_mean=np.array([91.,112.,48.]);strength=recipe['grass']['paintStrength']*(1-quiet*.80);grass=grass_mean+(grass-grass_mean)*strength[...,None]
 grass*=1+(macro[...,None]-.5)*recipe['grass']['macroAmplitude']*2+(meso[...,None]-.5)*recipe['grass']['mesoAmplitude']*2
 # Keep painterly material, but compress bright grain to support the protagonist.
 earth_mean=np.array([147.,119.,78.]);earth=earth_mean+(earth-earth_mean)*recipe['road']['paintStrength']
 base=grass.copy();cov=coverage[y0:y0+h,x0:x0+w]/255
 solid=coverage>127;inside=distance_transform_edt(solid);outside=distance_transform_edt(~solid);sd=(inside-outside)[y0:y0+h,x0:x0+w]
 fringe=recipe['road']['edgeVisualPixels'];edge_noise=((m.field(x,y,9,seed+109)-.5)*1.1+(m.field(x,y,23,seed+111)-.5))*fringe
 # Bank changes only the visual fringe, no producer coverage or navigability writes.
 visual=np.clip((sd+edge_noise+1.5)/3,0,1);core=inside[y0:y0+h,x0:x0+w]>=fringe+2;visual=np.where(core,1,visual)
 if world:visual=np.where(m.Context().masks['navigable'][y0:y0+h,x0:x0+w]>0,1,visual)
 bank=np.clip(1-np.abs(sd)/9,0,1)
 # Interrupted contact lips explain the grass/earth overlap without an outline.
 dy,dx=np.gradient((inside-outside).astype(float));normal=(dx[y0:y0+h,x0:x0+w]*-.65+dy[y0:y0+h,x0:x0+w]*-.76);normal/=np.maximum(np.hypot(dx[y0:y0+h,x0:x0+w],dy[y0:y0+h,x0:x0+w]),1)
 lip=bank*normal*(m.field(x,y,19,seed+113)>.51)
 soil=earth*(1+lip[...,None]*recipe['road']['brokenRimStrength'])
 shoulder=np.clip((7+sd)/7,0,1)*np.clip((m.field(x,y,29,seed+115)-.37)*2,0,.45)*(sd<0)
 grass=grass*(1-shoulder[...,None])+soil*shoulder[...,None]
 if world or sites is not None:
  root,stone,foundation=contacts(x,y,seed,sites);exposure=np.maximum.reduce([root*.92,stone*.73,foundation*.65])*recipe['contacts']['strength'];exposure*=np.clip((m.field(x,y,11,seed+117)-.16)*1.8,0,1)
  grass=grass*(1-exposure[...,None])+soil*exposure[...,None];grass*=1-np.maximum(stone,foundation)[...,None]*.06
 trans=grass*(1-visual[...,None])+soil*visual[...,None]
 wear,coherence=road_flow(paths,x,y,recipe['road']['junctionWearSuppression']);wear*=np.clip((sd-3)/9,0,1);wear*=.65+.35*m.field(x,y,27,seed+121)
 final=trans.copy();final*=1-wear[...,None]*recipe['road']['wearStrength']*visual[...,None]
 if world:
  # Preserve the old plateau pigment/interfaces; no redesign of background relief.
  ctx=m.Context();rock=ctx.sample(ctx.rock,x,y);old=np.array(Image.open(n.BASE/'SurfaceFinal/final.png').convert('RGB'))[y0:y0+h,x0:x0+w].astype(float);a=np.clip((rock+.20)/.28,0,1)[...,None]
  base=base*(1-a)+old*a;trans=trans*(1-a)+old*a;final=final*(1-a)+old*a
 output={name:Image.fromarray(np.clip(np.rint(v),0,255).astype('uint8')).convert('RGBA') for name,v in [('base',base),('transitions',trans),('final',final)]}
 stamps(output['final'],bounds,coverage,inside-outside,recipe,world,sites,library)
 return output,{'visualAlpha':(visual*255).astype('uint8'),'bankDistance':np.clip(sd+128,0,255).astype('uint8'),'flowCoherence':(np.clip(coherence,0,1)*255).astype('uint8')}

def stamps(image,bounds,coverage,sd,recipe,world,sites=None,library=EXPORT):
 x0,y0,w,h=bounds;H,W=coverage.shape;sheet=Image.open(Path(library)/'edge-grammar.png').convert('RGBA');overlay=Image.new('RGBA',(w,h));seed=recipe['seed']
 # Boundary candidates use one global jitter lattice and variable rejection.
 for gy in range(H//13+1):
  for gx in range(W//13+1):
   xx=int((gx+float(m.ihash(gx,gy,seed+151)))*13);yy=int((gy+float(m.ihash(gx,gy,seed+157)))*13)
   if not 0<=xx<W or not 0<=yy<H or not x0-40<=xx<x0+w+40 or not y0-40<=yy<y0+h+40:continue
   v=int(m.ihash(gx,gy,seed+163)*8)%8
   if -5<sd[yy,xx]<2 and m.field(np.array(xx),np.array(yy),53,seed+167)>.48 and m.ihash(gx,gy,seed+169)>.50:
    stamp=sheet.crop((v*64,0,v*64+32,32));overlay.alpha_composite(stamp,(xx-x0-16,yy-y0-27))
   elif 2<sd[yy,xx]<13 and m.ihash(gx,gy,seed+173)>.65:
    stamp=sheet.crop((v*64,48,v*64+32,80));overlay.alpha_composite(stamp,(xx-x0-16,yy-y0-17))
 if world or sites is not None:
  sites=reference_contact_sites() if sites is None else sites
  for i,p in enumerate([s for s in sites if s['kind']=='tree']):
   cx,cy=np.array(p['point'])*32
   for k in range(17):
    angle=float(m.ihash(i,k,seed+179))*math.tau;r=18+float(m.ihash(i,k,seed+181))*28;xx=round(cx+math.cos(angle)*r);yy=round(cy+math.sin(angle)*r*.6);v=k%8
    if 0<=xx<W and 0<=yy<H and coverage[yy,xx]<10:overlay.alpha_composite(sheet.crop((v*64,80,v*64+32,112)),(xx-x0-16,yy-y0-20))
 image.alpha_composite(overlay)

def court_geometry():
 # Nine labelled-by-metadata cases, not tiles or canonical world roads.
 data=read(BASE/'court-network.json');W,H=data['sizePixels'];image=Image.new('L',(W,H));d=ImageDraw.Draw(image);paths=[];cases=[]
 if data['canonicalWorld'] is not False:raise ValueError('Court must remain noncanonical')
 for case in data['cases']:
  ox=case['slot'][0]*640;oy=case['slot'][1]*400;cases.append({'id':case['id'],'boundsPixels':[ox,oy,640,400],'centerUnits':[(ox+320)/32,(oy+200)/32]})
  for group in case['paths']:
   p=np.array(group,float)+[ox,oy]
   if case.get('curve')=='catmull-rom':
    padded=np.vstack([p[0]*2-p[1],p,p[-1]*2-p[-2]]);p=np.vstack([roads.catmull(*padded[j:j+4],float(t)) for j in range(len(p)-1) for t in np.linspace(0,1,24)])
   q,t,s=resample_path(p,1.5);paths.append(q)
   for j,point in enumerate(q):
    radius=(case['widthPixels'][0]+(case['widthPixels'][1]-case['widthPixels'][0])*j/max(1,len(q)-1))/2;x,y=point;d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=255)
 return np.array(image),paths,cases

def build(out,court=False,bounds=None,library=EXPORT,recipe_path=BASE/'recipe.json'):
 out=refuse(out);out.mkdir(parents=True);library=Path(library);n.arch.verify_files(library);recipe=read(recipe_path)
 validate(recipe)
 if court:cov,paths,cases=court_geometry()
 else:ctx=m.Context();cov,paths=coverage_world(ctx);cases=[]
 H,W=cov.shape;bounds=bounds or [0,0,W,H];images,masks=render(bounds,cov,paths,recipe,not court,library=library)
 for name,image in images.items():image.save(out/(name+'.png'))
 for name,a in masks.items():Image.fromarray(a).save(out/(name+'.png'))
 Image.fromarray(cov).save(out/'coverage-input.png')
 if court:
  y,x=np.mgrid[:H,:W];old=np.zeros((H,W,3))+[82,106,49];old[cov>0]=[156,128,80];Image.fromarray(old.astype('uint8')).convert('RGBA').save(out/'before.png')
 write(out/'composition.json',{'schema':'valdoria-ground-finish-composition/v1','version':VERSION,'seed':recipe['seed'],'boundsPixels':bounds,'sizePixels':[W,H],'ppu':32,'canonicalWorld':not court,'geometryChanged':False,'cases':cases,'pathsPixels':[p.tolist() for p in paths] if court else None,'stages':['base','transitions','final']})
 inputs={'recipe':ref(Path(recipe_path)),'library':ref(library/'manifest.json')}
 if not court:inputs.update(world=ref(m.BASE),road=ref(Path(m.ROAD)/'road.json'),house=ref(n.ref.SOURCE.parent/'RegionV1/house.json'),accessMask=ref(n.ref.SOURCE.parent/'RegionV1/access.png'),accessBounds=ref(n.ref.SOURCE.parent/'RegionV1/access-render.json'),naturePlacement=ref(n.BASE/'PlacementFinal/placement.json'),natureRecipe=ref(n.BASE/'recipe.json'),natureSourceMetadata=ref(n.BASE/'SourceV2/source.json'),retainedRockMaterial=ref(n.BASE/'SurfaceFinal/final.png'))
 else:inputs['network']=ref(BASE/'court-network.json')
 manifest(out,inputs)

def validate(recipe):
 if recipe['schema']!='valdoria-ground-finish-recipe/v1' or recipe['version']!=VERSION or recipe['ppu']!=32 or recipe['geometryChange'] is not False or recipe['nativeMaterialPixels']!=384 or recipe['light']!='upper-left':raise ValueError('Ground recipe invariants')
 if type(recipe['seed'])!=int or type(recipe['road']['junctionWearSuppression'])!=bool:raise ValueError('Seed/suppression types')
 for key,value,limit in [('grass paint',recipe['grass']['paintStrength'],1),('quiet area',recipe['grass']['quietAreaFraction'],1),('macro',recipe['grass']['macroAmplitude'],.2),('meso',recipe['grass']['mesoAmplitude'],.2),('road paint',recipe['road']['paintStrength'],1),('fringe',recipe['road']['edgeVisualPixels'],6),('lip',recipe['road']['brokenRimStrength'],.12),('wear',recipe['road']['wearStrength'],.2),('contact',recipe['contacts']['strength'],.7)]:
  if not isinstance(value,(float,int)) or not math.isfinite(value) or not 0<=value<=limit:raise ValueError('Unsupported '+key)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','export','build','court']);p.add_argument('--output');p.add_argument('--source',default=str(SOURCE));p.add_argument('--library',default=str(EXPORT));p.add_argument('--recipe',default=str(BASE/'recipe.json'));p.add_argument('--bounds',type=json.loads);a=p.parse_args()
 if a.command=='prepare':prepare()
 elif a.command=='export':export(a.output,a.source)
 else:build(a.output,a.command=='court',a.bounds,a.library,a.recipe)
