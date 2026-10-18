"""Architecture Agent: semantic sites, closed exterior shells and road-connected entries."""
import argparse,copy,json,math,heapq,tempfile
from pathlib import Path
import numpy as np
from scipy.ndimage import distance_transform_edt,label
from PIL import Image,ImageDraw
import environment_vegetation as veg
import world_hydrology as common
import environment_geometry as geo
ROOT=common.ROOT;VERSION='environment-architecture/1.0.0';LIB=ROOT/'ArtSource/Labs/World2026/WorldStudio07/LibraryR7'

def recipe():return {'schema':'valdoria-architecture-recipe/v1','version':VERSION,'seed':710207,'actorRadius':.45,'accessRadius':.7,'minimumBuildingGap':2.,'groveRect':[2.,12.,10.,8.],'sites':[{'id':'rural-01','archetype':'A','guide':[33.,34.],'searchRadius':[3.,1.2]},{'id':'medieval-01','archetype':'B','guide':[46.,14.],'searchRadius':[3.,1.5]},{'id':'lake-01','archetype':'C','guide':[24.,23.],'searchRadius':[2.,1.2]}]}

def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def ref(p):return {'path':Path(p).resolve().relative_to(ROOT).as_posix(),'sha256':common.sha(Path(p).read_bytes())}
def verify_files(directory):
 d=Path(directory);m=read(d/'manifest.json')
 for n,h in m['files'].items():
  if Path(n).name!=n or common.sha((d/n).read_bytes())!=h:raise ValueError('Architecture hash '+n)
 for v in m.get('inputs',{}).values():
  if common.sha((ROOT/v['path']).read_bytes())!=v['sha256']:raise ValueError('Architecture input hash '+v['path'])
 if (d/'vegetation.json').exists():
  for v in read(d/'vegetation.json').get('sourceBuilds',{}).values():
   if common.sha((ROOT/v['path']).read_bytes())!=v['sha256']:raise ValueError('Regenerated vegetation manifest hash')
 return m

def plan(style,spec):
 w=spec['width'];d=spec['depth'];pts=[[-w/2-d/4,-d/4],[w/2-d/4,-d/4],[w/2+d/4,d/4],[-w/2+d/4,d/4]]
 if style=='A':pts=[[-w/2-d/4,-d/4],[w/2-d/4,-d/4],[w/2+d/4,d/4],[-w/2+d/4,d/4],[-w/2-1.65+(d/2-.05)/2,(d/2-.05)/2],[-w/2-1.65-.325,-.325],[-w/2-.325,-.325]]
 return pts

def inside(points,x,y):
 result=np.zeros(np.broadcast(x,y).shape,dtype=bool)
 for a,b in zip(points,points[1:]+points[:1]):
  # Nonzero epsilon only avoids horizontal division; edge samples use centers.
  result^=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1]+1e-30)+a[0])
 # Closed-set occupancy: Physics2D includes points exactly on polygon edges.
 boundary=np.zeros_like(result)
 for a,b in zip(points,points[1:]+points[:1]):
  dx=b[0]-a[0];dy=b[1]-a[1];den=dx*dx+dy*dy
  if den<1e-20:continue
  t=np.clip(((x-a[0])*dx+(y-a[1])*dy)/den,0,1);boundary|=(x-a[0]-t*dx)**2+(y-a[1]-t*dy)**2<=1e-10
 return result|boundary

def mask_polygon(points,ctx):return inside(points,ctx.navX,ctx.navY)
def bbox(points,margin=0):
 p=np.array(points);a=p.min(axis=0)-margin;b=p.max(axis=0)+margin;return [float(a[0]),float(a[1]),float(b[0]-a[0]),float(b[1]-a[1])]
def rect_contains(rect,p):x,y,w,h=rect;return x<=p[0]<=x+w and y<=p[1]<=y+h

def validate(r):
 if r.get('schema')!='valdoria-architecture-recipe/v1' or r.get('version')!=VERSION or type(r.get('seed')) is not int or not .3<=r.get('actorRadius',0)<=.8 or not r['actorRadius']+.15<=r.get('accessRadius',0)<=1.5:raise ValueError('Architecture recipe/schema/clearance')
 if not 1<=len(r.get('sites',[]))<=3 or len({v['id'] for v in r['sites']})!=len(r['sites']):raise ValueError('One to three unique building IDs')
 if r['minimumBuildingGap']<1:raise ValueError('Building spacing')
 for v in r['sites']:
  if v['archetype'] not in ['A','B','C'] or len(v['guide'])!=2 or len(v['searchRadius'])!=2 or min(v['searchRadius'])<=0 or not all(math.isfinite(n) for n in v['guide']+v['searchRadius']):raise ValueError('Building site')
 return r

class Context:
 def __init__(self,library=LIB):
  self.world=veg.Context();self.library=Path(library);verify_files(library);self.modules=read(self.library/'modules.json');self.paths={**self.world.paths,'architectureModules':self.library/'modules.json','architectureArt':self.library/'manifest.json'}
  self.north,self.south=self.world.h,self.world.w
  # Consume the previously published vegetation manifests, not just a label A/B/C.
  for s in 'ABC':
   d=ROOT/f'ArtSource/Labs/World2026/WorldStudio06/BuildR6/{s}';veg.verify_manifest(d);self.paths['vegetation'+s]=d/'manifest.json'

def sites(r,context):
 validate(r);ctx=context.world;outputs=[];occupied=np.zeros_like(ctx.baseWalk);rng=np.random.default_rng(r['seed'])
 for index,request in enumerate(r['sites']):
  style=request['archetype'];module=context.modules['archetypes'][style];spec=module['spec'];local=plan(style,spec);best=None
  candidates=[request['guide']]+[(np.array(request['guide'])+rng.uniform(-1,1,2)*request['searchRadius']).tolist() for _ in range(120)]
  for point in candidates:
   point=np.round(np.array(point)*32)/32;poly=(np.array(local)+point).tolist();bb=bbox(poly,.75)
   if min(bb[:2])<1 or bb[0]+bb[2]>ctx.w-1 or bb[1]+bb[3]>ctx.h-1:continue
   x,y,w,h=bb;samples=[ctx.sample(xx,yy) for yy in np.arange(y,y+h+.01,.5) for xx in np.arange(x,x+w+.01,.5)]
   if any(v['solid'] or v['surfaceWater'] or v['reserved'] or v['solidDistance']<.65 or v['roadDistance']<1.0 or v['waterDistance']<(.75 if style=='C' else 2.) or v['slope']>.065 for v in samples):continue
   heights=[v['height'] for v in samples]
   if max(heights)-min(heights)>.13:continue
   if style=='C' and min(v['waterDistance'] for v in samples)>3:continue
   if any(not (bb[0]>o['bounds'][0]+o['bounds'][2]+r['minimumBuildingGap'] or bb[0]+bb[2]<o['bounds'][0]-r['minimumBuildingGap'] or bb[1]>o['bounds'][1]+o['bounds'][3]+r['minimumBuildingGap'] or bb[1]+bb[3]<o['bounds'][1]-r['minimumBuildingGap']) for o in outputs):continue
   entry=(point+module['doorLocal']).tolist();approach=[entry[0],entry[1]+.85];mask=mask_polygon(poly,ctx)
   if np.any(mask&~ctx.baseWalk):continue
   score=np.linalg.norm(point-request['guide'])+max(v['slope'] for v in samples)*20
   if best is None or score<best[0]:best=(score,point,poly,bb,entry,approach,mask,heights,samples)
  if best is None:raise ValueError('No stable site without modifying producers: '+request['id'])
  _,point,poly,bb,entry,approach,mask,heights,samples=best;occupied|=mask
  # Porch posts use real small footprints rather than visual rectangles.
  posts=[]
  if style in 'BC':
   w=spec['width'];z=spec['depth']/2
   for x in ([-w/2,-w/2+1.65] if style=='B' else [-w/2-.25,-w/2+.95]):
    zz=z+(.78 if style=='B' else .85);posts.append([float(point[0]+x+.5*zz),float(point[1]+.5*zz)])
  outputs.append({'id':request['id'],'seed':r['seed']+index*7919,'archetype':style,'position':point.tolist(),'orientation':'south-east-authored-projection','groundAnchor':point.tolist(),'dimensions':spec,'footprint':poly,'porchPosts':[{'point':p,'radius':.10} for p in posts],'bounds':bb,'entry':entry,'approach':approach,'doorWidth':module['doorWidth'],'doorHeight':module['doorHeight'],'interior':'closed exterior shell, no door interaction or interior','siteQA':{'heightRange':[min(heights),max(heights)],'maxSlope':max(v['slope'] for v in samples),'minimumWaterDistance':min(v['waterDistance'] for v in samples)},'parts':[{'module':style+'-'+p,'sortAnchor':'building-ground','hideWithRoof':p in ['roof','trim','chimney']} for p in [v['part'] for v in context.modules['parts'] if v['archetype']==style]]})
 for b in outputs:
  for post in b['porchPosts']:occupied|=(ctx.navX-post['point'][0])**2+(ctx.navY-post['point'][1])**2<=post['radius']**2
 return outputs,occupied

def route(start,walk,road,ctx,radius):
 clearance=distance_transform_edt(walk)*.25;allowed=clearance>=radius;sy,sx=int(start[1]*4),int(start[0]*4)
 if not allowed[sy,sx]:raise ValueError('Entry approach has insufficient clearance')
 target=(road<.15)&allowed;H,W=walk.shape;dist={(sy,sx):0.};parents={};heap=[(0.,sy,sx)];end=None
 while heap:
  cost,y,x=heapq.heappop(heap)
  if cost>dist[(y,x)]+1e-9:continue
  if target[y,x]:end=(y,x);break
  for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
   yy,xx=y+dy,x+dx
   if not 0<=yy<H or not 0<=xx<W or not allowed[yy,xx] or not allowed[yy,x] or not allowed[y,xx]:continue
   new=cost+math.hypot(dx,dy)+.05/(clearance[yy,xx]+.1)
   if new<dist.get((yy,xx),1e30):dist[(yy,xx)]=new;parents[(yy,xx)]=(y,x);heapq.heappush(heap,(new,yy,xx))
 if end is None:raise ValueError('No road-connected entry')
 path=[end]
 while path[-1]!=(sy,sx):path.append(parents[path[-1]])
 path.reverse();points=np.array([[(x+.5)*.25,(y+.5)*.25] for y,x in path])
 for _ in range(24):
  smoothed=points.copy()
  for i in range(1,len(points)-1):
   q=(points[i-1]+2*points[i]+points[i+1])/4
   if clearance[int(q[1]*4),int(q[0]*4)]>=radius:smoothed[i]=q
  points=smoothed
 return np.round(points,5).tolist()

def generate(recipe_path,output,context=None):
 out=common.refuse(output);r=validate(read(recipe_path));c=context or Context();ctx=c.world;buildings,architectureBlocked=sites(r,c);road=np.array([[veg.scalar(ctx.roadDistance,x,y,1/32) for x in ctx.navX[0]] for y in ctx.navY[:,0]])
 base=ctx.baseWalk&~architectureBlocked;exclusions=[]
 for b in buildings:
  b['access']={'radius':r['accessRadius'],'points':route(b['approach'],base,road,ctx,r['accessRadius']),'kind':'pedestrian-approach-not-road-replacement'}
  exclusions.append({'id':b['id']+'-canopy-clearance','rectUnits':bbox(b['footprint'],2.4)})
  # Axis-aligned envelopes are conservative reservations for the ecological consumer.
  for i,p in enumerate(b['access']['points']):exclusions.append({'id':b['id']+'-access-'+str(i),'rectUnits':[p[0]-1.05,p[1]-1.05,2.1,2.1]})
 # Regenerate only the affected vegetation consumers, leaving all producer inputs untouched.
 out.mkdir(parents=True);(out/'Vegetation').mkdir();vegetationSets={};deltas={};inputs={k:ref(p) for k,p in c.paths.items()};inputs['recipe']=ref(recipe_path)
 for s in 'ABC':
  vr=veg.recipe(s);vr['protectedAreas']+=exclusions;rp=out/'Vegetation'/('recipe-'+s+'.json');common.write(rp,vr);new=veg.generate(rp,out/'Vegetation'/s,ctx);vegetationSets[s]=new['instances'];old=read(ROOT/f'ArtSource/Labs/World2026/WorldStudio06/BuildR6/{s}/vegetation.json')['instances'];oldMap={v['id']:v for v in old};newMap={v['id']:v for v in new['instances']};deltas[s]={'oldCount':len(old),'newCount':len(newMap),'unchangedIDs':sum(1 for k,v in newMap.items() if k in oldMap and oldMap[k]==v),'removedOrRepositionedIDs':sorted(k for k,v in oldMap.items() if k not in newMap or newMap[k]!=v),'note':'competition may propagate changes outside exclusions; entire vegetation consumer rebuilt'}
 selected=[]
 for s in 'ABC':
  for item in vegetationSets[s]:
   if not ((s=='C' and item['species']=='reeds') or (item['species']!='reeds' and ((s=='B')==rect_contains(r['groveRect'],item['point'])) and s!='C')):continue
   if any(math.dist(v['point'],item['point'])<max(v['footprintRadius']+item['footprintRadius']+.8 if v['footprintRadius'] and item['footprintRadius'] else .2,min(v['spacing'],item['spacing'])*.4) for v in selected):continue
   v=copy.deepcopy(item);v['id']=s+'/'+v['id'];v['sourceComposition']=s;selected.append(v)
 combined=base.copy()
 for v in selected:
  rr=v['footprintRadius'];x,y=v['point']
  if rr:combined&=~((ctx.navX-x)**2+(ctx.navY-y)**2<=rr**2)
 clear=distance_transform_edt(combined)*.25
 for b in buildings:
  for x,y in b['access']['points']:
   if clear[int(y*4),int(x*4)]<r['actorRadius']+.12:raise ValueError('Vegetation competition compromised access')
 nav={'schema':'valdoria-architecture-navigation/v1','size':[ctx.w*4,ctx.h*4],'stepUnits':.25,'architectureBlocked':architectureBlocked.ravel().tolist(),'walkable':combined.ravel().tolist(),'actorClearanceIncluded':False,'componentCount':label(combined)[1]}
 common.write(out/'navigation.json',nav);common.write(out/'vegetation-exclusions.json',{'schema':'valdoria-architecture-vegetation-exclusions/v1','seed':r['seed'],'rectangles':exclusions,'consumerEffects':deltas});common.write(out/'vegetation.json',{'schema':'valdoria-vegetation/v1','generator':'architecture-ecotone-composition/1.0.0','seed':710206,'composition':'A-field+B-defined-grove+C-reeds','sizeUnits':[ctx.w,ctx.h],'instances':selected,'sourceBuilds':{s:ref(out/'Vegetation'/s/'manifest.json') for s in 'ABC'}})
 solution={'schema':'valdoria-architecture/v1','generator':VERSION,'seed':r['seed'],'sizeUnits':[ctx.w,ctx.h],'buildings':buildings,'inputs':inputs,'ecotone':{'base':'A','banks':'C reeds','grove':'B inside explicit groveRect','groveRect':r['groveRect']},'limitations':['closed non-enterable buildings','no terrain flattening','no calibrated flood simulation','no interiors or 3D actor elevation']};common.write(out/'architecture.json',solution)
 # Only the subsidiary access surface is authored; main road remains immutable.
 accessRenders=[]
 for b in buildings:
  im=Image.new('RGBA',(ctx.w*32,ctx.h*32));d=ImageDraw.Draw(im);pts=[tuple(round(n*32) for n in p) for p in b['access']['points']];d.line(pts,fill='#99876aff',width=34,joint='curve')
  for p in pts:d.ellipse((p[0]-17,p[1]-17,p[0]+17,p[1]+17),fill='#99876aff')
  arr=np.array(im);yy,xx=np.mgrid[0:arr.shape[0],0:arr.shape[1]];tone=np.sin(xx*.031+yy*.019)*.8+np.sin(xx*.17-yy*.13)*.35+np.sin(xx*.83+yy*.67)*.16;idx=np.clip(np.round(2+tone),0,4).astype(int);pal=np.array([[143,126,97],[151,133,102],[158,140,108],[165,147,115],[172,153,120]],dtype=np.uint8);arr[:,:,:3]=pal[idx];im=Image.fromarray(arr);rect=im.getbbox();filename='access-'+b['id']+'.png';im.crop(rect).save(out/filename);accessRenders.append({'id':b['id'],'file':filename,'rectPixels':list(rect),'originUnity':[rect[0]/32,ctx.h-rect[3]/32]})
 common.write(out/'access-render.json',{'schema':'valdoria-architecture-access-render/v1','ppu':32,'surfaces':accessRenders});common.write(out/'manifest.json',{'schema':'valdoria-architecture-build/v1','inputs':inputs,'files':{p.name:common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()}});return solution

def verify(recipe_path,output,context=None):
 m=verify_files(output)
 for s in 'ABC':veg.verify_manifest(Path(output)/'Vegetation'/s)
 # Build records internal paths, so compare semantic outputs after normalizing rebuild-root references.
 with tempfile.TemporaryDirectory(dir=ROOT/'Temp') as tmp:
  rebuilt=Path(tmp)/'rebuilt';generate(recipe_path,rebuilt,context)
  for n in m['files']:
   if n=='vegetation.json':
    a=read(Path(output)/n);b=read(rebuilt/n);a.pop('sourceBuilds');b.pop('sourceBuilds');assert a==b
   else:
    if common.sha((rebuilt/n).read_bytes())!=m['files'][n]:raise ValueError('Architecture rebuild '+n)
 return True
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['recipe','generate','verify']);p.add_argument('--output',required=True);p.add_argument('--recipe');p.add_argument('--library',default=str(LIB));a=p.parse_args()
 if a.command=='recipe':common.refuse(a.output);Path(a.output).parent.mkdir(parents=True,exist_ok=True);common.write(Path(a.output),recipe())
 elif a.command=='generate':print([(b['id'],b['position']) for b in generate(a.recipe,a.output,Context(a.library))['buildings']])
 else:print(verify(a.recipe,a.output,Context(a.library)))
