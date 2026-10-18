"""Water Agent: offline depression/drainage authoring on immutable WorldRegion.
Priority-flood derives spill elevations/acyclic drainage; this is NOT a hydraulic solver.
"""
import argparse,copy,hashlib,heapq,json,math,tempfile
from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates,label,distance_transform_edt,binary_dilation
from scipy.spatial import cKDTree
from PIL import Image,ImageDraw
import environment_geometry as geo
import terrain_materials as materials
ROOT=materials.ROOT
BASE=materials.BASE
ROAD=materials.ROAD
RELIEF=ROOT/'ArtSource/Labs/World2026/WorldStudio04/BuildR6/A/relief-field.json'
VERSION='world-hydrology/1.0.0'
STEP=.25
NEIGHBORS=[(-1,0),(0,-1),(0,1),(1,0),(-1,-1),(-1,1),(1,-1),(1,1)]
def canonical(value):return (json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)+'\n').encode('utf8')
def sha(data):return hashlib.sha256(data).hexdigest()
def write(path,value):Path(path).write_bytes(canonical(value))
def refuse(path):
 p=Path(path)
 if p.exists():raise ValueError('Refuse existing destination '+str(p))
 return p

def priority_flood(height):
 """Stable min-heap flood from open domain edges. Returns filled surface + acyclic parents/rank."""
 z=np.asarray(height,float);H,W=z.shape;seen=np.zeros(z.shape,bool);fill=z.copy();parents=np.full(z.shape+(2,),-1,int);rank=np.full(z.shape,-1,int);queue=[];counter=0
 for y in range(H):
  for x in range(W):
   if y in (0,H-1) or x in (0,W-1):seen[y,x]=True;heapq.heappush(queue,(z[y,x],y,x))
 while queue:
  value,y,x=heapq.heappop(queue);rank[y,x]=counter;counter+=1
  for dy,dx in NEIGHBORS:
   yy,xx=y+dy,x+dx
   if 0<=yy<H and 0<=xx<W and not seen[yy,xx]:
    seen[yy,xx]=True;fill[yy,xx]=max(value,z[yy,xx]);parents[yy,xx]=[y,x];heapq.heappush(queue,(fill[yy,xx],yy,xx))
 # Steepest D8 on strict descents. On filled flats retain priority-flood parent: rank decreases.
 for y in range(1,H-1):
  for x in range(1,W-1):
   drops=[((fill[y,x]-fill[y+dy,x+dx])/math.hypot(dx,dy),dy,dx) for dy,dx in NEIGHBORS]
   drop,dy,dx=max(drops)
   if drop>1e-12:parents[y,x]=[y+dy,x+dx]
 return fill,parents,rank

def recipe():
 return {'schema':'valdoria-hydrology-recipe/v1','version':VERSION,'regionId':'valdoria-water-study','seed':710205,'stepUnits':STEP,'ppu':32,'lake':{'id':'lake-west','seedPoint':[7.5,23.5],'fillFraction':.93,'minimumDepression':.004},'rivers':[{'id':'brook-west','source':[17.5,23.5],'minWidth':1.05,'maxWidth':1.65,'relativeDepth':.0065}],'wetMarginUnits':.42,'blockedDepth':.0025,'protectedAreas':[],'crossings':[{'id':'ford-west','kind':'shallow-ford','riverId':'brook-west','point':[12.,27.5],'radiusUnits':1.05}],'patches':[],'notes':'Normalized environmental elevation/depth, not metres. Small inlet brook into natural depression; no terrain carving.'}

def validate_recipe(r):
 def finite(v):
  if isinstance(v,float) and not math.isfinite(v):raise ValueError('Non-finite recipe value')
  if isinstance(v,dict):
   for item in v.values():finite(item)
  if isinstance(v,list):
   for item in v:finite(item)
 finite(r)
 if r.get('schema')!='valdoria-hydrology-recipe/v1' or r.get('version')!=VERSION:raise ValueError('Hydrology schema/version')
 if not isinstance(r.get('seed'),int) or isinstance(r['seed'],bool):raise ValueError('Integer seed')
 if r.get('ppu')!=32 or r.get('stepUnits')!=STEP:raise ValueError('Unsupported spatial contract')
 if not .2<=r['lake']['fillFraction']<=1:raise ValueError('Lake fill fraction')
 if not 0<r['blockedDepth']<.02 or not 0<=r['wetMarginUnits']<=2:raise ValueError('Depth/margin')
 river_ids=[v['id'] for v in r['rivers']];ids=[r['lake']['id']]+river_ids
 if len(ids)!=len(set(ids)) or not r['rivers']:raise ValueError('Unique feature IDs required')
 for v in r['rivers']:
  if not .5<=v['minWidth']<=v['maxWidth']<=4 or not .001<=v['relativeDepth']<=.02:raise ValueError('River width/depth')
 for c in r.get('crossings',[]):
  if c.get('kind')!='shallow-ford' or c['riverId'] not in river_ids or c['radiusUnits']<=0:raise ValueError('Only authored shallow fords supported')
 for p in r.get('patches',[]):
  if p.get('kind')!='river-width' or p['riverId'] not in river_ids or not .65<=p['factor']<=1.3 or p['arcRange'][0]>=p['arcRange'][1]:raise ValueError('Invalid finite width patch')
 return r

def apply_patch(r,patch):
 if patch.get('schema')!='valdoria-hydrology-patch/v1':raise ValueError('Patch schema')
 result=copy.deepcopy(r);result['patches']+=patch['edits'];return validate_recipe(result)

def region_fields(region,relief):
 w,h=region['size'];step=STEP;y,x=np.mgrid[0:h+step:step,0:w+step:step]
 if region['cellSizeUnits']!=1 or relief['sizeUnits']!=[w,h]:raise ValueError('Unsupported region bounds')
 z=map_coordinates(np.array(region['layers']['elevationMilli'],float).reshape(h,w)/1000,[y-.5,x-.5],order=1,mode='nearest')
 reserved=np.array(region['layers']['reserved'],bool).reshape(h,w)[np.minimum(y.astype(int),h-1),np.minimum(x.astype(int),w-1)]
 rock=np.array(relief['samples'])[:,:,0]
 return x,y,z,reserved,rock

def solve(r,region_path=BASE,road_dir=ROAD,relief_path=RELIEF):
 validate_recipe(r);region=geo.read(region_path);relief=geo.read(relief_path);road_contract=geo.read(Path(road_dir)/'road.json');
 if road_contract['region']['sha256']!=sha(Path(region_path).read_bytes()):raise ValueError('Road belongs to different terrain')
 x,y,z,reserved,rock=region_fields(region,relief);H,W=z.shape;fill,parent,rank=priority_flood(z)
 # A lake is a connected depression below its spill elevation, not an ellipse stamped on a hill.
 px,py=r['lake']['seedPoint'];iy,ix=int(round(py/STEP)),int(round(px/STEP))
 if not 0<=iy<H or not 0<=ix<W:raise ValueError('Lake seed outside region')
 basin_labels,_=label(fill-z>1e-7);bid=int(basin_labels[iy,ix])
 if bid==0 or fill[iy,ix]-z[iy,ix]<r['lake']['minimumDepression']:raise ValueError('Lake seed is not a plausible depression')
 basin=basin_labels==bid;floor=float(z[basin].min());spill=float(fill[iy,ix]);level=floor+(spill-floor)*r['lake']['fillFraction']
 lake_labels,_=label((z<level)&basin);deepest=np.unravel_index(np.where(basin,z,np.inf).argmin(),z.shape);lid=int(lake_labels[deepest]);lake=(lake_labels==lid)&(lid>0)
 if lake.sum()<8:raise ValueError('Lake too small')
 lake_s=np.where(basin,(level-z)*180.,-1.)
 lake_s=np.where((lake_labels==lid)|(lake_s<0),lake_s,-1.)
 surface=lake_s.copy();depth=np.where(lake,np.maximum(0,level-z),0.);flow=np.zeros(z.shape+(2,),float);river_id=np.zeros(z.shape,int);river_features=[];width_fields=[]
 for rid,rv in enumerate(r['rivers'],1):
  sx,sy=rv['source'];p=(int(round(sy/STEP)),int(round(sx/STEP)));path=[];visited=set()
  while True:
   if min(p)<0 or p[0]>=H or p[1]>=W or p in visited:raise ValueError('River cannot reach lake on drainage graph')
   path.append(p);visited.add(p)
   if lake[p]:break
   p=tuple(parent[p])
  if len(path)<5:raise ValueError('River source too close to lake')
  points=np.array([[xx*STEP,yy*STEP] for yy,xx in path]);arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(points,axis=0),axis=1))]
  # Preserve the D8 route. Dense linear interpolation rounds raster corners only through envelope union.
  dense_arc=np.arange(0,arc[-1],.0625);dense_arc=np.r_[dense_arc,arc[-1]];samples=np.c_[np.interp(dense_arc,arc,points[:,0]),np.interp(dense_arc,arc,points[:,1])]
  widths=rv['minWidth']+(rv['maxWidth']-rv['minWidth'])*(.5+.30*np.sin(dense_arc*.71+r['seed']*.001)+.17*np.sin(dense_arc*1.43+rid))
  for patch in r['patches']:
   if patch['riverId']==rv['id']:
    lo,hi=patch['arcRange'];t=np.clip(np.minimum(dense_arc-lo,hi-dense_arc)/.6,0,1);widths*=1+(patch['factor']-1)*t
  widths=np.clip(widths,.5,4)
  tree=cKDTree(samples);dist,index=tree.query(np.c_[x.ravel(),y.ravel()]);dist=dist.reshape(z.shape);index=index.reshape(z.shape);half=widths[index]/2
  rs=half-dist;surface=np.maximum(surface,rs);profile=np.clip(rs/half,0,1);rd=rv['relativeDepth']*np.sqrt(profile)
  tangent=np.gradient(samples,axis=0);tangent/=np.maximum(1e-10,np.linalg.norm(tangent,axis=1,keepdims=True));used=rs>0
  depth=np.maximum(depth,rd);flow[used]=tangent[index[used]];river_id[used]=rid
  levels=fill[tuple(np.array(path).T)];heights=z[tuple(np.array(path).T)]
  river_features.append({'id':rv['id'],'toLake':r['lake']['id'],'source':rv['source'],'lengthUnits':round(float(arc[-1]),6),'sampleColumns':['x','y','arcUnits','widthUnits'],'samples':np.round(np.c_[samples,dense_arc,widths],6).tolist(),'drainageVertices':[[float(xx*STEP),float(yy*STEP),round(float(h),7),round(float(f),7)] for (yy,xx),h,f in zip(path,heights,levels)],'maxFilledUphill':round(float(np.diff(levels).max()),9),'maxOriginalUphill':round(float(np.diff(heights).max()),9)})
  width_fields.append(rs)
 # Explicit exclusions are checked before authoring; a disconnected/clipped stream is rejected.
 wet=surface>=0
 road_coverage=np.array(Image.open(Path(road_dir)/'coverage.png'))
 road=map_coordinates(road_coverage.astype(float),[y*32-.5,x*32-.5],order=0,mode='nearest')>0
 forbidden=reserved|road|(rock>=0)
 for area in r['protectedAreas']:
  ax,ay,aw,ah=area['rectUnits'];forbidden|=(x>=ax)&(x<=ax+aw)&(y>=ay)&(y<=ay+ah)
 for crossing in r['crossings']:
  cx,cy=crossing['point'];circle=np.hypot(x-cx,y-cy)<=crossing['radiusUnits'];river_index=next(i+1 for i,v in enumerate(r['rivers']) if v['id']==crossing['riverId']);zone=circle&(river_id==river_index)&wet
  if not zone.any() or np.any(zone&(rock>=0)):raise ValueError('Ford outside river or over solid terrain')
  depth[zone]=np.minimum(depth[zone],r['blockedDepth']*.65)
 # Shore protection includes a vertex halo: do not squeeze water between protected pixels.
 if np.any(wet&forbidden):raise ValueError('Hydrology intersects road, reserved/protected or solid terrain')
 deep=np.minimum(surface, (depth-r['blockedDepth'])*180.)
 water_loops=geo.contours(surface,STEP)
 if geo.positive_overlap(surface,rock,STEP):raise ValueError('Water intersects shared solid boundary between vertices')
 road_y,road_x=np.nonzero(road_coverage>0)
 if np.any(geo.sample_triangular(surface,(road_x+.5)/32,(road_y+.5)/32)>=0):raise ValueError('Water intersects road pixels between analysis nodes')
 for area in r['protectedAreas']:
  if geo.intersects_rect(water_loops,area['rectUnits']):raise ValueError('Water intersects subcell protected area')
 blocked_loops=geo.contours(deep,STEP);geometry=geo.rock_boundary(relief)
 geometry.update(waterLoops=water_loops,waterBlockedLoops=blocked_loops,waterFields={'surface':np.round(surface,7).tolist(),'depth':np.round(depth,7).tolist(),'blocked':np.round(deep,7).tolist(),'flow':np.round(flow,5).tolist()},depthUnits='normalized elevation scalar, not metres',blockedDepth=r['blockedDepth'])
 # Navigation samples the very same triangles at subcell centers. Actor radius remains a separate query.
 ny,nx=np.mgrid[STEP/2:y.max():STEP,STEP/2:x.max():STEP];solid=geo.sample_triangular(rock,nx,ny)>=0;water_blocked=geo.sample_triangular(deep,nx,ny)>=0;walk=~(solid|water_blocked);components,count=label(walk)
 water_present=geo.sample_triangular(surface,nx,ny)>=0
 from water_art import boundary_distance
 wetland=(~water_present)&(boundary_distance(water_loops,nx,ny)<=r['wetMarginUnits'])
 navigation={'schema':'valdoria-environment-navigation/v1','stepUnits':STEP,'size':[walk.shape[1],walk.shape[0]],'sampleOrigin':[STEP/2,STEP/2],'connectivity':4,'surfaceWater':water_present.ravel().tolist(),'wetland':wetland.ravel().tolist(),'solidBlocked':solid.ravel().tolist(),'waterBlocked':water_blocked.ravel().tolist(),'walkable':walk.ravel().tolist(),'componentIds':components.ravel().tolist(),'componentCount':int(count),'actorClearanceIncluded':False,'wetTraversableDepthMaximum':r['blockedDepth']}
 basin_points=np.argwhere(basin);lake_feature={'id':r['lake']['id'],'basinId':bid,'seedPoint':r['lake']['seedPoint'],'floorScalar':floor,'spillScalar':spill,'waterLevelScalar':level,'maxDepthScalar':float(depth[lake].max()),'areaVertexEstimateUnits2':round(float(lake.sum()*STEP*STEP),4),'basinBoundsUnits':[float(basin_points[:,1].min()*STEP),float(basin_points[:,0].min()*STEP),float(basin_points[:,1].max()*STEP),float(basin_points[:,0].max()*STEP)],'outlet':'inlet-only study, lake below natural spill; no forced outlet'}
 drainage={'schema':'valdoria-drainage/v1','stepUnits':STEP,'filledElevation':np.round(fill,7).tolist(),'parentYX':parent.tolist(),'rank':rank.tolist(),'model':'priority-flood spill surface and steepest D8; flat routing by acyclic parent; immutable ground'}
 return {'geometry':geometry,'navigation':navigation,'drainage':drainage,'lake':lake_feature,'rivers':river_features,'seed':r['seed'],'recipe':r}

def rasterize(solution,bounds=None,ppu=32):
 g=solution['geometry'];w,h=g['sizeUnits'];bounds=bounds or [0,0,int(w*ppu),int(h*ppu)];ox,oy,W,H=bounds;y,x=np.mgrid[oy:oy+H,ox:ox+W];x=(x+.5)/ppu;y=(y+.5)/ppu
 f=g['waterFields'];surface=geo.sample_triangular(f['surface'],x,y);depth=geo.sample_triangular(f['depth'],x,y);blocked=geo.sample_triangular(f['blocked'],x,y)>=0;wet=surface>=0
 # Distance bands are sampled from the shared scalar, never another silhouette.
 from water_art import boundary_distance
 margin=(~wet)&(boundary_distance(g['waterLoops'],x,y)<=solution['recipe']['wetMarginUnits']);result={'surface':wet,'blocked':blocked,'shallow':wet&~blocked,'wetland':margin,'depth':np.where(wet,depth,0.)}
 flow=np.stack([geo.sample_triangular(np.array(f['flow'])[:,:,i],x,y) for i in range(2)],axis=-1);result['flow']=flow*wet[:,:,None]
 return result

def verify_manifest(output):
 p=Path(output);m=geo.read(p/'manifest.json')
 if m['schema']!='valdoria-hydrology-build/v1':raise ValueError('Build schema')
 for name,h in m['files'].items():
  if Path(name).name!=name or sha((p/name).read_bytes())!=h:raise ValueError('Artifact hash '+name)
 for ref in m['inputs'].values():
  if sha((ROOT/ref['path']).read_bytes())!=ref['sha256']:raise ValueError('Input hash '+ref['path'])
 return m

def generate(recipe_path,output,library,region=BASE,road=ROAD,relief=RELIEF,patch=None):
 r=geo.read(recipe_path);patch_data=geo.read(patch) if patch else None
 if patch_data:r=apply_patch(r,patch_data)
 out=refuse(output);solution=solve(r,region,road,relief);out.mkdir(parents=True)
 inputs={k:{'path':str(Path(v).resolve().relative_to(ROOT)).replace('\\','/'),'sha256':sha(Path(v).read_bytes())} for k,v in {'region':region,'road':Path(road)/'road.json','relief':relief,'recipe':recipe_path,'library':Path(library)/'library.json'}.items()}
 for mask in ['coverage','navigable','shoulders','wear']:inputs['road-'+mask]={'path':str((Path(road)/(mask+'.png')).resolve().relative_to(ROOT)).replace('\\','/'),'sha256':sha((Path(road)/(mask+'.png')).read_bytes())}
 if patch:inputs['patch']={'path':str(Path(patch).resolve().relative_to(ROOT)).replace('\\','/'),'sha256':sha(Path(patch).read_bytes())}
 for name in ['geometry','navigation','drainage']:write(out/(name+'.json'),solution[name])
 write(out/'hydrology.json',{'schema':'valdoria-hydrology/v1','generator':VERSION,'seed':r['seed'],'inputs':inputs,'lake':solution['lake'],'rivers':solution['rivers'],'crossings':r['crossings'],'wetMarginUnits':r['wetMarginUnits'],'depthModel':'lake level minus original height; river authored cross-section depth proxy, no channel excavation or hydraulic integration','topographyChanged':False,'physicsRevision':'shared subcell rock boundary and depth-defined water blockage in new lab','artStatus':'candidate-awaiting-user-review'})
 masks=rasterize(solution)
 for name in ['surface','blocked','shallow','wetland']:Image.fromarray(masks[name].astype('uint8')*255).save(out/(name+'.png'))
 Image.fromarray(np.rint(np.clip(masks['depth'],0,1)*65535).astype('uint16')).save(out/'depth.png')
 flow=np.rint((masks['flow']*.5+.5)*255).astype('uint8');Image.fromarray(np.dstack([flow,np.zeros(flow.shape[:2],dtype='uint8'),masks['surface'].astype('uint8')*255])).save(out/'flow.png')
 import water_art
 water_art.compose(solution,library,out)
 write(out/'manifest.json',{'schema':'valdoria-hydrology-build/v1','generator':VERSION,'inputs':inputs,'files':{p.name:sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()}})
 return solution

def verify(recipe_path,output,library,**kwargs):
 m=verify_manifest(output)
 with tempfile.TemporaryDirectory() as tmp:
  generate(recipe_path,Path(tmp)/'rebuild',library,**kwargs)
  for name,h in m['files'].items():
   if sha((Path(tmp)/'rebuild'/name).read_bytes())!=h:raise ValueError('Determinism failure '+name)
 return True

def main():
 p=argparse.ArgumentParser();p.add_argument('command',choices=['recipe','generate','verify','crop']);p.add_argument('--output',required=True);p.add_argument('--recipe');p.add_argument('--library');p.add_argument('--patch');p.add_argument('--bounds',type=json.loads);p.add_argument('--region',default=str(BASE));p.add_argument('--road',default=str(ROAD));p.add_argument('--relief',default=str(RELIEF));a=p.parse_args()
 if a.command=='recipe':out=refuse(a.output);out.mkdir(parents=True);write(out/'recipe.json',recipe())
 elif a.command=='generate':generate(a.recipe,a.output,a.library,region=a.region,road=a.road,relief=a.relief,patch=a.patch)
 elif a.command=='verify':print(verify(a.recipe,a.output,a.library,region=a.region,road=a.road,relief=a.relief,patch=a.patch))
 else:
  r=geo.read(a.recipe);r=apply_patch(r,geo.read(a.patch)) if a.patch else r;solution=solve(r,a.region,a.road,a.relief);masks=rasterize(solution,a.bounds);out=refuse(a.output);out.mkdir(parents=True)
  for name in ['surface','blocked','shallow','wetland']:Image.fromarray(masks[name].astype('uint8')*255).save(out/(name+'.png'))
  write(out/'manifest.json',{'schema':'valdoria-hydrology-crop/v1','boundsPixels':a.bounds,'recipeSha256':sha(canonical(r)),'regionSha256':sha(Path(a.region).read_bytes()),'roadSha256':sha((Path(a.road)/'road.json').read_bytes()),'reliefSha256':sha(Path(a.relief).read_bytes()),'generator':VERSION,'files':{p.name:sha(p.read_bytes()) for p in out.iterdir()}})
if __name__=='__main__':main()
