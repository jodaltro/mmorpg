"""Vegetation Agent: deterministic ecological placement consuming immutable World Studio data."""
import argparse,copy,json,math,tempfile,time
from pathlib import Path
import numpy as np
from scipy.ndimage import distance_transform_edt,label
from scipy.spatial import cKDTree
from PIL import Image,ImageDraw
import world_hydrology as common
import environment_geometry as geo
import water_art
ROOT=common.ROOT;HYDRO=ROOT/'ArtSource/Labs/World2026/WorldStudio05/BuildR4';MATERIAL=ROOT/'ArtSource/Labs/World2026/WorldStudio04/BuildR6/A';LIB=ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5';VERSION='environment-vegetation/1.0.0'
SPECIES=['oak','elm','hazel','fern','wildflowers','reeds','drygrass','plantgroup']
PROFILES={
 'oak':{'radius':.30,'spacing':2.8,'road':2.2,'water':1.3,'slope':.14,'elevation':[.34,.70],'moisture':[.32,.82]},
 'elm':{'radius':.40,'spacing':3.4,'road':2.8,'water':1.5,'slope':.12,'elevation':[.34,.66],'moisture':[.45,.95]},
 'hazel':{'radius':0,'spacing':1.0,'road':.9,'water':.25,'slope':.16,'elevation':[.34,.78],'moisture':[.42,.95]},
 'fern':{'radius':0,'spacing':.55,'road':.55,'water':.12,'slope':.18,'elevation':[.34,.70],'moisture':[.43,1.]},
 'wildflowers':{'radius':0,'spacing':.65,'road':.6,'water':.35,'slope':.16,'elevation':[.34,.74],'moisture':[.34,.85]},
 'reeds':{'radius':0,'spacing':.42,'road':.6,'water':0,'slope':.12,'elevation':[.34,.60],'moisture':[.50,1.]},
 'drygrass':{'radius':0,'spacing':.7,'road':.65,'water':3.,'slope':.16,'elevation':[.34,.80],'moisture':[.30,.65]},
 'plantgroup':{'radius':0,'spacing':.8,'road':.65,'water':.22,'slope':.18,'elevation':[.34,.78],'moisture':[.35,.90]}}
COUNTS={'A':[18,7,26,35,45,24,30,32],'B':[38,20,55,65,32,24,20,42],'C':[15,9,40,65,35,70,14,42]}
def recipe(style):
 return {'schema':'valdoria-vegetation-recipe/v1','version':VERSION,'seed':710206,'composition':style,'speciesCounts':dict(zip(SPECIES,COUNTS[style])),'habitatFocus':{'center':[13.,25.],'radius':[12.,10.],'parentFraction':.5},'actorClearanceUnits':.45,'protectedAreas':[{'id':'ford-approach','rectUnits':[10.8,25.7,2.4,4.5]}],'profiles':copy.deepcopy(PROFILES),'patches':[],'notes':'Habitat suitability is authored ecology, not a calibrated climate/ecosystem simulation. Original terrain/hydrology/roads immutable.'}

def scalar(field,x,y,step=.25):
 H,W=field.shape;xx=np.clip(x/step,0,W-1);yy=np.clip(y/step,0,H-1);ix=min(W-2,int(xx));iy=min(H-2,int(yy));u=xx-ix;v=yy-iy;a,b,c,d=field[iy,ix],field[iy,ix+1],field[iy+1,ix+1],field[iy+1,ix]
 return float(a+(b-a)*u+(c-b)*v if v<=u else a+(c-d)*u+(d-a)*v)

def boundary_tree(loops):
 points=[]
 for loop in loops:
  for a,b in zip(loop,loop[1:]+loop[:1]):
   a,b=np.array(a),np.array(b);n=max(1,int(math.ceil(np.linalg.norm(b-a)*128)));points.extend(a[None,:]+(b-a)[None,:]*(np.arange(n)/n)[:,None])
 return cKDTree(np.array(points))

class Context:
 def __init__(self,region=common.BASE,road=common.ROAD,hydro=HYDRO,material=MATERIAL,library=LIB):
  self.paths={'region':Path(region),'road':Path(road)/'road.json','roadCoverage':Path(road)/'coverage.png','roadNavigable':Path(road)/'navigable.png','hydrology':Path(hydro)/'hydrology.json','hydrologyManifest':Path(hydro)/'manifest.json','geometry':Path(hydro)/'geometry.json','material':Path(material)/'composition.json','materialManifest':Path(material)/'manifest.json','library':Path(library)/'library.json','sprites':Path(library)/'sprites.json'}
  for directory,key in [(Path(hydro),'files'),(Path(material),'files'),(Path(library),'files')]:
   m=geo.read(directory/('library.json' if directory==Path(library) else 'manifest.json'))
   for name,digest in m[key].items():
    if Path(name).name!=name or common.sha((directory/name).read_bytes())!=digest:raise ValueError('Consumed manifest mismatch '+name)
  common.verify_manifest(hydro)
  import terrain_materials
  terrain_materials.verify_manifest(material)
  self.region=geo.read(region);self.geometry=geo.read(Path(hydro)/'geometry.json');self.hydro=geo.read(Path(hydro)/'hydrology.json');self.sprites=geo.read(Path(library)/'sprites.json');self.w,self.h=self.region['size'];self.layers={k:np.array(v).reshape(self.h,self.w) for k,v in self.region['layers'].items()};self.road=geo.read(Path(road)/'road.json')
  terrain_hash=common.sha(Path(region).read_bytes())
  if self.road['region']['sha256']!=terrain_hash or self.hydro['inputs']['region']['sha256']!=terrain_hash or geo.read(Path(material)/'composition.json')['regionRef']['sha256']!=terrain_hash:raise ValueError('Consumers reference different WorldRegion')
  if self.hydro['inputs']['road']['sha256']!=common.sha((Path(road)/'road.json').read_bytes()):raise ValueError('Hydrology references different road')
  self.paths['relief']=ROOT/self.hydro['inputs']['relief']['path'];self.rock=np.array(geo.read(self.paths['relief'])['samples'])[:,:,0];self.water=np.array(self.geometry['waterFields']['surface']);self.depth=np.array(self.geometry['waterFields']['depth']);self.blocked=np.array(self.geometry['waterFields']['blocked']);self.rockTree=boundary_tree(self.geometry['rockLoops']);self.waterTree=boundary_tree(self.geometry['waterLoops']);self.roadDistance=distance_transform_edt(np.array(Image.open(Path(road)/'coverage.png'))==0)/32
  res=np.repeat(np.repeat(self.layers['reserved'].astype(bool),8,0),8,1);self.reserveDistance=distance_transform_edt(~res)/8
  self.baseNavigation=geo.read(Path(hydro)/'navigation.json');self.baseWalk=np.array(self.baseNavigation['walkable']).reshape(self.h*4,self.w*4);self.baseComponents=label(self.baseWalk)[1];self.navY,self.navX=np.mgrid[.125:self.h:.25,.125:self.w:.25]
 def sample(self,x,y):
  ix,iy=min(self.w-1,int(x)),min(self.h-1,int(y));water=scalar(self.water,x,y);distance=self.waterTree.query([x,y])[0];moist=float(self.layers['moistureMilli'][iy,ix])/1000;wet=np.clip(moist+.46*math.exp(-distance/3.8),0,1)
  return {'height':float(self.layers['elevationMilli'][iy,ix])/1000,'slope':float(self.layers['slopeMilli'][iy,ix])/1000,'moisture':float(wet),'soil':str(self.layers['material'][iy,ix]),'waterDistance':float(distance),'surfaceWater':water>=0,'depth':scalar(self.depth,x,y) if water>=0 else 0.,'solid':scalar(self.rock,x,y)>=0,'solidDistance':float(self.rockTree.query([x,y])[0]),'roadDistance':scalar(self.roadDistance,x,y,1/32),'reserveDistance':scalar(self.reserveDistance,x,y,1/8),'reserved':bool(self.layers['reserved'][iy,ix])}
 def permitted(self,r,kind,x,y):
  p=r['profiles'][kind];radius=p['radius'];margin=radius+r['actorClearanceUnits']+.05 if radius else .1
  if not margin<x<self.w-margin or not margin<y<self.h-margin:return None
  v=self.sample(x,y)
  if v['solid'] or v['solidDistance']<margin or v['reserved'] or v['reserveDistance']<margin+.1 or v['roadDistance']<p['road']+radius:return None
  for rect in r['protectedAreas']+r['patches']:
   ax,ay,w,h=rect['rectUnits'];extra=margin if radius else .35
   if ax-extra<=x<=ax+w+extra and ay-extra<=y<=ay+h+extra:return None
  for c in self.hydro['crossings']:
   if math.hypot(x-c['point'][0],y-c['point'][1])<c['radiusUnits']+.8+radius:return None
  if v['slope']>p['slope'] or not p['elevation'][0]<=v['height']<=p['elevation'][1] or not p['moisture'][0]<=v['moisture']<=p['moisture'][1]:return None
  if kind=='reeds':
   if v['depth']>.0025 or v['waterDistance']>.78:return None
  elif v['surfaceWater'] or v['waterDistance']<p['water']+radius:return None
  if v['soil'] not in ['grass','forest','dirt','mud','sand']:return None
  return v

def validate(r):
 if r.get('schema')!='valdoria-vegetation-recipe/v1' or r.get('version')!=VERSION or r.get('composition') not in ['A','B','C'] or not isinstance(r['seed'],int) or isinstance(r['seed'],bool):raise ValueError('Vegetation recipe contract')
 if set(r['profiles'])!=set(SPECIES) or set(r['speciesCounts'])!=set(SPECIES) or not .3<=r['actorClearanceUnits']<=1:raise ValueError('Vegetation species/clearance')
 for kind,p in r['profiles'].items():
  if kind not in SPECIES or not 0<=p['radius']<=.8 or p['spacing']<(2*p['radius']+.8 if p['radius'] else .2) or any(not math.isfinite(x) for x in [p['radius'],p['spacing'],p['road'],p['water'],p['slope']]):raise ValueError('Physical/ecological profile')
 f=r['habitatFocus']
 if not 0<=f['parentFraction']<=1 or len(f['center'])!=2 or len(f['radius'])!=2 or min(f['radius'])<=0 or not all(math.isfinite(x) for x in f['center']+f['radius']):raise ValueError('Habitat focus')
 for kind in ['oak','elm']:
  if r['profiles'][kind]['radius']<.15:raise ValueError('Tree trunk footprint required')
 for count in r['speciesCounts'].values():
  if not isinstance(count,int) or count<0 or count>500:raise ValueError('Species density')
 for area in r['protectedAreas']+r['patches']:
  if len(area['rectUnits'])!=4 or not all(math.isfinite(x) for x in area['rectUnits']) or min(area['rectUnits'][2:])<=0:raise ValueError('Protected rectangle')
 return r

def solve(r,context):
 validate(r);ctx=context;accepted=[];physicalWalk=ctx.baseWalk.copy();rejects={};basecount=ctx.baseComponents
 for si,kind in enumerate(SPECIES):
  rng=np.random.default_rng(r['seed']+si*7919);target=r['speciesCounts'][kind];profile=r['profiles'][kind];made=0;parents=rng.uniform([1,1],[ctx.w-1,ctx.h-1],size=(30,2));radii=rng.uniform(2.2,6.3,(30,2));angles=rng.uniform(0,math.tau,30)
  focus=r['habitatFocus'];n=int(30*focus['parentFraction']);parents[:n]=np.array(focus['center'])+rng.uniform(-1,1,(n,2))*np.array(focus['radius'])
  budget=max(100,target*150)
  for candidate in range(budget):
   if made>=target:break
   parent=candidate%(12 if r['composition']=='B' and si<3 else 30)
   if kind=='reeds':
    shore_rng=np.random.default_rng(r['seed']+9001);shore_indices=shore_rng.integers(0,len(ctx.waterTree.data),18);center=ctx.waterTree.data[shore_indices[parent%18]];x,y=center+rng.normal(0,.70,2)
    if candidate%3==0:
     cx,cy=center;gradient=np.array([scalar(ctx.water,cx+.01,cy)-scalar(ctx.water,cx-.01,cy),scalar(ctx.water,cx,cy+.01)-scalar(ctx.water,cx,cy-.01)]);gradient/=max(np.linalg.norm(gradient),1e-8);x,y=center+gradient*.035+rng.normal(0,.04,2)
   else:
    dx,dy=rng.normal(0,1,2)*radii[parent]*(.72 if r['composition']=='B' and si<3 else 1);a=angles[parent];x,y=parents[parent]+[dx*math.cos(a)-dy*math.sin(a),dx*math.sin(a)+dy*math.cos(a)]
   x,y=round(float(x)*32)/32,round(float(y)*32)/32
   habitat=ctx.permitted(r,kind,x,y)
   if habitat is None:continue
   if kind=='reeds' and candidate%3==0 and not habitat['surfaceWater']:continue
   distances=[(math.hypot(x-v['point'][0],y-v['point'][1]),v) for v in accepted];trees=[d for d,v in distances if v['footprintRadius']>0];shade=max(0,1-min(trees,default=9)/4.5)
   if any(d<max(profile['spacing'],v['spacing'])*(.78 if v['species']!=kind and not profile['radius'] else 1) for d,v in distances if v['species']==kind or profile['radius'] and v['footprintRadius']>0):continue
   if not profile['radius'] and any(d<v['footprintRadius']+.26 for d,v in distances):continue
   suitability={'oak':.76,'elm':.28+habitat['moisture']*.65,'hazel':.32+shade*.45+habitat['moisture']*.2,'fern':.12+shade*.48+math.exp(-habitat['waterDistance']/4)*.38,'wildflowers':.78-shade*.45,'reeds':.95,'drygrass':.85-habitat['moisture']*.55,'plantgroup':.5+shade*.2}[kind]
   if rng.random()>suitability:continue
   radius=profile['radius'];newwalk=physicalWalk
   if radius:
    occupied=(ctx.navX-x)**2+(ctx.navY-y)**2<=radius**2;newwalk=physicalWalk&~occupied
    if label(newwalk)[1]>basecount:continue
   neighbor=[v for d,v in distances if v['species']==kind and d<5];variant=(candidate+parent)%3
   if neighbor and all(v['variant']==variant for v in neighbor):variant=(variant+1)%3
   accepted.append({'id':f'{kind}/{parent:02}/{candidate:05}','species':kind,'variant':variant,'point':[x,y],'groundAnchor':'authored foot origin, Unity=(x,regionHeight-y)','footprintRadius':radius,'spacing':profile['spacing'],'parentCluster':parent,'habitat':dict(habitat,shadeProxy=round(shade,4),suitability=round(suitability,4))});physicalWalk=newwalk;made+=1
  rejects[kind]={'requested':target,'placed':made,'exhaustedCandidates':made<target}
 # Shared .25-u navigation overlay. Preserve upstream data; mark new physical occupancy separately.
 nav={'schema':'valdoria-vegetation-navigation/v1','stepUnits':.25,'size':[ctx.w*4,ctx.h*4],'vegetationBlocked':(ctx.baseWalk&~physicalWalk).ravel().tolist(),'walkable':physicalWalk.ravel().tolist(),'componentCount':label(physicalWalk)[1],'baseComponentCount':basecount,'actorClearanceIncluded':False}
 return {'schema':'valdoria-vegetation/v1','generator':VERSION,'seed':r['seed'],'composition':r['composition'],'sizeUnits':[ctx.w,ctx.h],'instances':accepted,'densityResults':rejects,'navigation':nav,'ecologyModel':'authored habitat suitability with hierarchical spatial parents, exclusion/competition and shade proxy; no temporal ecosystem simulation'}

def generate(recipe_path,output,context=None):
 out=common.refuse(output);r=geo.read(recipe_path);ctx=context or Context();solution=solve(r,ctx);out.mkdir(parents=True);inputs={k:{'path':str(p.resolve().relative_to(ROOT)).replace('\\','/'),'sha256':common.sha(p.read_bytes())} for k,p in ctx.paths.items()};inputs['recipe']={'path':str(Path(recipe_path).resolve().relative_to(ROOT)).replace('\\','/'),'sha256':common.sha(Path(recipe_path).read_bytes())}
 nav=solution.pop('navigation');common.write(out/'navigation.json',nav);solution['inputs']=inputs;common.write(out/'vegetation.json',solution)
 im=Image.new('RGB',(ctx.w*8,ctx.h*8),'#405637');d=ImageDraw.Draw(im)
 colors={'oak':'#a2ac67','elm':'#81a187','hazel':'#788750','fern':'#6c9c6e','wildflowers':'#ded3a3','reeds':'#80b7ae','drygrass':'#b9a778','plantgroup':'#9fa475'}
 for v in solution['instances']:
  x,y=np.array(v['point'])*8;radius=3 if v['footprintRadius'] else 1;d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=colors[v['species']])
 im.save(out/'distribution-diagnostic.png');common.write(out/'manifest.json',{'schema':'valdoria-vegetation-build/v1','generator':VERSION,'inputs':inputs,'files':{p.name:common.sha(p.read_bytes()) for p in sorted(out.iterdir())}});return solution

def verify_manifest(output):
 out=Path(output);m=geo.read(out/'manifest.json')
 if m['schema']!='valdoria-vegetation-build/v1':raise ValueError('Vegetation manifest schema')
 for name,h in m['files'].items():
  if Path(name).name!=name or common.sha((out/name).read_bytes())!=h:raise ValueError('Vegetation artifact hash')
 for ref in m['inputs'].values():
  if common.sha((ROOT/ref['path']).read_bytes())!=ref['sha256']:raise ValueError('Vegetation input hash '+ref['path'])
 return m

def verify(recipe_path,output,context=None):
 m=verify_manifest(output)
 with tempfile.TemporaryDirectory() as tmp:
  generate(recipe_path,Path(tmp)/'rebuilt',context)
  for name,h in m['files'].items():
   if common.sha((Path(tmp)/'rebuilt'/name).read_bytes())!=h:raise ValueError('Vegetation rebuild differs')
 return True

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['recipes','generate','verify']);p.add_argument('--output',required=True);p.add_argument('--recipe');p.add_argument('--library',default=str(LIB));a=p.parse_args()
 if a.command=='recipes':
  out=common.refuse(a.output);out.mkdir(parents=True)
  for style in 'ABC':common.write(out/f'recipe-{style}.json',recipe(style))
 elif a.command=='generate':print({k:v for k,v in generate(a.recipe,a.output,Context(library=a.library))['densityResults'].items()})
 else:print(verify(a.recipe,a.output,Context(library=a.library)))
