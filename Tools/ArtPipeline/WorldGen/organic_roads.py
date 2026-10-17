"""Organic roads: offline, constrained curves and subcell masks. No terrain edits.
Coordinates are continuous world units, X right/Y down from region origin.
Centripetal Catmull-Rom: Yuksel/Schaefer/Keyser, CAD 43(7), 2011.
"""
from __future__ import annotations
import argparse, copy, heapq, json, math, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
import terrain_agent as terrain

VERSION='organic-roads/1.0.0'
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'ArtSource/Labs/World2026/WorldStudio01/Regions/B/world-region.json'
ATLAS=ROOT/'ArtSource/Labs/World2026/WorldStudio01/Materials/surfaces.png'
SOURCE=ROOT/'ArtSource/Labs/World2026/WorldStudio02'

class AuthoringError(ValueError):pass

def norm(v):return float(np.linalg.norm(v))
def unit(v):return v/max(norm(v),1e-10)
def canonical(v):return terrain.canonical(v)+b'\n'

def validate(region,recipe):
    if recipe.get('schema')!='valdoria-organic-road-recipe/v1':raise AuthoringError('Unsupported road recipe')
    if region.get('schema')!='valdoria-world-region/v1':raise AuthoringError('Unsupported source WorldRegion')
    if type(recipe.get('seed')) is not int:raise AuthoringError('Integer seed required')
    points=recipe.get('waypoints',[])
    if len(points)<2 or any(len(p)!=2 or not all(math.isfinite(v) for v in p) for p in points):raise AuthoringError('At least two finite waypoints required')
    if any(norm(np.array(a)-b)<.1 for a,b in zip(points,points[1:])):raise AuthoringError('Coincident waypoints')
    width=recipe['width']; edge=recipe['edges']
    if not 0.9<=width['min']<=width['nominal']<=width['max']<=8:raise AuthoringError('Invalid width bounds')
    if width['max']<width['min']+2*edge['amplitude']+.12:raise AuthoringError('Insufficient visual margin above physical minimum')
    if not 0<=edge['amplitude']<=.5 or not 0<=edge['shoulder']<=.6:raise AuthoringError('Invalid edge/shoulder')
    if not .04<=recipe['curve']['sampleSpacing']<=.25:raise AuthoringError('Sampling must resolve the corridor')
    w,h=region['size'];n=w*h
    for key in ('walkable','blocked','elevationMilli','slopeMilli','reserved','waterCandidate'):
        if len(region['layers'][key])!=n:raise AuthoringError('Misaligned '+key)
    if recipe.get('ppu',32)!=32:raise AuthoringError('This study exports at 32 PPU')
    if any(bool(b)==bool(w) for b,w in zip(region['layers']['blocked'],region['layers']['walkable'])):raise AuthoringError('Inconsistent blocked/walkable layers')
    if recipe['curve'].get('type')!='centripetal-catmull-rom':raise AuthoringError('Unsupported curve type')
    if not 0<recipe['width']['maxRate']<=1 or not 0<=recipe['width']['variation']<=.5:raise AuthoringError('Invalid width variation/rate')
    if not 0<=recipe['constraints']['maxSlope']<=1:raise AuthoringError('Invalid slope constraint')
    for area in recipe.get('protectedAreas',[]):
        x,y,rw,rh=area['rect']
        if not all(type(v) is int for v in (x,y,rw,rh)) or min(x,y)<0 or min(rw,rh)<=0 or x+rw>w or y+rh>h:raise AuthoringError('Protected area outside region')
    for key in ('authorizedCrossingCells','forbiddenCells'):
        if any(type(i) is not int or not 0<=i<n for i in recipe['constraints'].get(key,[])):raise AuthoringError('Invalid constrained cell')


class TerrainCost:
    def __init__(self,region,recipe):
        self.region=region;self.recipe=recipe;self.w,self.h=region['size'];self.cell=region['cellSizeUnits'];self.origin=np.array(region.get('originUnits',[0.,0.]))
        self.extent=np.array([self.w,self.h])*self.cell
        l=region['layers'];self.heights=np.array(l['elevationMilli']).reshape(self.h,self.w)/1000
        self.slopes=np.array(l['slopeMilli']).reshape(self.h,self.w)/1000
        forbidden=np.array(l['blocked'],dtype=bool).reshape(self.h,self.w).copy()
        forbidden|=self.slopes>recipe['constraints']['maxSlope']
        # Water candidates are conservative exclusions here, not rendered water.
        if recipe['constraints'].get('avoidWaterCandidates',True):forbidden|=np.array(l['waterCandidate']).reshape(self.h,self.w)
        if 'waterOccupied' in l:forbidden|=np.array(l['waterOccupied']).reshape(self.h,self.w)
        for i in recipe['constraints'].get('authorizedCrossingCells',[]):
            if not l['blocked'][i] and self.slopes.flat[i]<=recipe['constraints']['maxSlope']:forbidden.flat[i]=False
        for area in recipe.get('protectedAreas',[]):
            if area.get('allowRoad',False):continue
            x,y,w,h=area['rect'];forbidden[y:y+h,x:x+w]=True
        for i in recipe['constraints'].get('forbiddenCells',[]):forbidden.flat[i]=True
        self.forbidden=forbidden;ys,xs=np.nonzero(forbidden)
        self.bad=np.column_stack((xs+.5,ys+.5))*self.cell+self.origin
        self.radius=recipe['width']['min']/2+2*recipe['edges']['amplitude']+recipe['edges']['shoulder']+.11
        self.clear=np.empty((self.h,self.w))
        for y in range(self.h):
            for x in range(self.w):self.clear[y,x]=self.clearance(self.center(x,y))
    def center(self,x,y):return self.origin+(np.array([x,y])+.5)*self.cell
    def index(self,p):return tuple(np.floor((p-self.origin)/self.cell).astype(int))
    def clearance(self,p):
        q=p-self.origin;limit=float(min(q[0],q[1],self.extent[0]-q[0],self.extent[1]-q[1]))
        if len(self.bad):
            delta=np.maximum(np.abs(self.bad-p)-self.cell*.5,0)
            limit=min(limit,float(np.sqrt((delta*delta).sum(axis=1)).min()))
        return limit
    def safe(self,a,b,radius=None):
        radius=self.radius if radius is None else radius
        n=max(1,math.ceil(norm(np.array(b)-a)/.18))
        return all(self.clearance(np.array(a)+(np.array(b)-a)*(i/n))>=radius for i in range(n+1))
    def cost(self,p):
        x,y=self.index(p)
        if not (0<=x<self.w and 0<=y<self.h):return 1e9
        return 1+self.slopes[y,x]*self.recipe['constraints']['slopeWeight']+self.heights[y,x]*self.recipe['constraints']['heightWeight']
    def path(self,start,end):
        start,end=np.array(start,dtype=float),np.array(end,dtype=float)
        if self.clearance(start)<self.radius or self.clearance(end)<self.radius:raise AuthoringError('Mandatory waypoint lacks minimum clearance; move the waypoint or revise constraints explicitly')
        a,b=self.index(start),self.index(end);queue=[(0.,a)];g={a:0.};came={};found=False
        while queue:
            _,current=heapq.heappop(queue)
            if current==b:found=True;break
            x,y=current
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
                nx,ny=x+dx,y+dy;nxt=(nx,ny)
                if not (0<=nx<self.w and 0<=ny<self.h) or self.clear[ny,nx]<self.radius:continue
                if dx and dy and (self.clear[y,nx]<self.radius or self.clear[ny,x]<self.radius):continue
                pa,pb=self.center(x,y),self.center(nx,ny)
                distance=math.hypot(dx,dy)*self.cell
                score=g[current]+distance*(self.cost(pa)+self.cost(pb))*.5
                if score<g.get(nxt,1e30):
                    g[nxt]=score;came[nxt]=current
                    heapq.heappush(queue,(score+norm(pb-end),nxt))
        if not found:raise AuthoringError('No traversable corridor connects mandatory waypoints; terrain left unchanged')
        chain=[b]
        while chain[-1]!=a:chain.append(came[chain[-1]])
        raw=[start]+[self.center(*p) for p in reversed(chain)][1:-1]+[end]
        # Greedy line of sight is constrained by both clearance and terrain cost.
        simplified=[raw[0]];i=0
        while i<len(raw)-1:
            j=len(raw)-1
            while j>i+1:
                reference=sum(norm(raw[k+1]-raw[k])*(self.cost(raw[k])+self.cost(raw[k+1]))*.5 for k in range(i,j))
                n=max(2,math.ceil(norm(raw[j]-raw[i])/.4));p=[raw[i]+(raw[j]-raw[i])*t/n for t in range(n+1)]
                cost=sum(norm(p[k+1]-p[k])*(self.cost(p[k])+self.cost(p[k+1]))*.5 for k in range(n))
                if cost<=reference*1.10 and self.safe(raw[i],raw[j]):break
                j-=1
            simplified.append(raw[j]);i=j
        return simplified

def catmull(p0,p1,p2,p3,t):
    points=[np.array(p,dtype=float) for p in (p0,p1,p2,p3)];knots=[0.]
    for a,b in zip(points,points[1:]):knots.append(knots[-1]+max(norm(b-a)**.5,1e-6))
    u=knots[1]+t*(knots[2]-knots[1])
    def mix(a,b,ta,tb):return (tb-u)/(tb-ta)*a+(u-ta)/(tb-ta)*b
    a1=mix(points[0],points[1],knots[0],knots[1]);a2=mix(points[1],points[2],knots[1],knots[2]);a3=mix(points[2],points[3],knots[2],knots[3])
    b1=mix(a1,a2,knots[0],knots[2]);b2=mix(a2,a3,knots[1],knots[3])
    return mix(b1,b2,knots[1],knots[2])

def resample(points,spacing):
    p=np.array(points);dist=np.r_[0,np.cumsum(np.linalg.norm(np.diff(p,axis=0),axis=1))]
    targets=np.linspace(0,dist[-1],max(2,math.ceil(dist[-1]/spacing)+1))
    return np.column_stack([np.interp(targets,dist,p[:,axis]) for axis in (0,1)]),targets

def curvature(points):
    delta=np.diff(points,axis=0);length=np.linalg.norm(delta,axis=1)
    if len(delta)<2:return 0.
    angles=np.arccos(np.clip((delta[:-1]*delta[1:]).sum(axis=1)/np.maximum(length[:-1]*length[1:],1e-10),-1,1))
    return float(np.max(angles/np.maximum((length[:-1]+length[1:])/2,1e-8)))

def wave(seed,s,period=9.):
    phase=terrain.lattice(seed,0,0)*math.tau
    return .65*np.sin(s/period*math.tau+phase)+.35*np.sin(s/(period*1.73)*math.tau+phase*.71)

def segments(region,recipe,patch=None):
    validate(region,recipe);recipe=copy.deepcopy(recipe)
    if patch:
        if patch.get('schema')!='valdoria-road-patch/v1':raise AuthoringError('Unsupported road patch')
        for edit in patch['waypointEdits']:
            index=edit['index']
            if not 0<index<len(recipe['waypoints'])-1:raise AuthoringError('Only interior waypoints can be locally edited')
            recipe['waypoints'][index]=edit['point']
    cost=TerrainCost(region,recipe);waypoints=recipe['waypoints']
    planned=[cost.path(a,b) for a,b in zip(waypoints,waypoints[1:])]
    # Keep span endpoints stable. A waypoint edit affects only neighbouring tangents.
    all_guides=[];owners=[]
    for i,path in enumerate(planned):
        for p in path[:-1]:all_guides.append(p);owners.append(i)
    all_guides.append(np.array(waypoints[-1]));owners.append(len(planned)-1)
    dense=[[] for _ in planned]
    tension=recipe['curve']['tension']
    for i in range(len(all_guides)-1):
        p1,p2=all_guides[i:i+2];p0=all_guides[i-1] if i else p1+(p1-p2);p3=all_guides[i+2] if i+2<len(all_guides) else p2+(p2-p1)
        n=max(16,math.ceil(norm(p2-p1)/.025))
        curve=[catmull(p0,p1,p2,p3,t/n)*tension+(p1+(p2-p1)*t/n)*(1-tension) for t in range(n+1)]
        if not all(cost.clearance(p)>=cost.radius for p in curve):raise AuthoringError('Curve overshoots a constraint; add a guide waypoint or reduce curvature. No terrain edits made')
        target=dense[owners[i]];target.extend(curve if not target else curve[1:])
    output=[]
    for i,points in enumerate(dense):
        p,s=resample(points,recipe['curve']['sampleSpacing']);curv=curvature(p)
        if curv>recipe['curve']['maxCurvature']:raise AuthoringError(f'Curvature {curv:.3f} exceeds configured limit in segment {i}')
        clearance=np.array([cost.clearance(v) for v in p]);width=recipe['width'];edge=recipe['edges']
        minimum=width['min']+2*edge['amplitude']+.12
        desired=np.clip(width['nominal']*(1+width['variation']*wave(recipe['seed']+i*4099,s)),minimum,width['max'])
        cap=2*(clearance-edge['amplitude']-edge['shoulder']-.04)
        desired=np.minimum(desired,cap)
        if desired.min()<minimum-1e-6:raise AuthoringError('Road width/shoulder cannot fit; increase clearance or reduce requested width')
        # Lipschitz-limited width, independent of global arc origin.
        for j in range(1,len(p)):desired[j]=min(desired[j],desired[j-1]+width['maxRate']*(s[j]-s[j-1]))
        for j in range(len(p)-2,-1,-1):desired[j]=min(desired[j],desired[j+1]+width['maxRate']*(s[j+1]-s[j]))
        physical=np.maximum(width['min'],desired-2*edge['amplitude']-.12)
        output.append({'id':f'road-main/{i:03d}','waypoints':[waypoints[i],waypoints[i+1]],'guides':[v.tolist() for v in planned[i]],
          'length':round(float(s[-1]),6),'maxCurvature':round(curv,6),
          'samples':[[round(float(x),6),round(float(y),6),round(float(d),6),round(float(v),6),round(float(n),6)] for (x,y),d,v,n in zip(p,s,desired,physical)]})
    # Per-span width variation may differ but must agree at each shared endpoint.
    # Blend width over a fixed support at each joint; distant segments stay unchanged.
    for left,right in zip(output,output[1:]):
        join=min(left['samples'][-1][3],right['samples'][0][3]);support=3.
        for segment,reverse in ((left,True),(right,False)):
            for sample in segment['samples']:
                d=segment['length']-sample[2] if reverse else sample[2]
                if d<support:
                    t=d/support;t=t*t*(3-2*t);sample[3]=round(join+(sample[3]-join)*t,6)
                    sample[4]=round(max(recipe['width']['min'],sample[3]-2*recipe['edges']['amplitude']-.12),6)
    # Reapply the configured width derivative bound after local joint blending.
    for segment in output:
        samples=segment['samples'];rate=recipe['width']['maxRate']
        for j in range(1,len(samples)):samples[j][3]=min(samples[j][3],samples[j-1][3]+rate*(samples[j][2]-samples[j-1][2]))
        for j in range(len(samples)-2,-1,-1):samples[j][3]=min(samples[j][3],samples[j+1][3]+rate*(samples[j+1][2]-samples[j][2]))
        for sample in samples:
            sample[3]=round(sample[3],6);sample[4]=round(max(recipe['width']['min'],sample[3]-2*recipe['edges']['amplitude']-.12),6)
    joint_points=np.array([p[:2] for i,segment in enumerate(output) for p in (segment['samples'] if i==0 else segment['samples'][1:])])
    if curvature(joint_points)>recipe['curve']['maxCurvature']:raise AuthoringError('Joined curve exceeds curvature constraint')
    return output,cost,recipe

def rasterize(road_segments,recipe,bounds,ppu=32):
    """Clip a shared global road into any chunk, sampling world pixel centres."""
    ox,oy,w,h=bounds;pw,ph=round(w*ppu),round(h*ppu)
    distance=np.full((ph,pw),np.inf,dtype=np.float32);width=np.zeros((ph,pw),np.float32);physical=width.copy();arc=width.copy()
    for segment in road_segments:
        samples=segment['samples']
        for a,b in zip(samples,samples[1:]):
            a,b=np.array(a),np.array(b);pad=max(a[3],b[3])/2+recipe['edges']['shoulder']+recipe['edges']['amplitude']+.1
            x0=max(0,math.floor((min(a[0],b[0])-pad-ox)*ppu));x1=min(pw,math.ceil((max(a[0],b[0])+pad-ox)*ppu))
            y0=max(0,math.floor((min(a[1],b[1])-pad-oy)*ppu));y1=min(ph,math.ceil((max(a[1],b[1])+pad-oy)*ppu))
            if x0>=x1 or y0>=y1:continue
            xx=ox+(np.arange(x0,x1)+.5)/ppu;yy=oy+(np.arange(y0,y1)+.5)/ppu
            dx,dy=b[:2]-a[:2];t=np.clip(((xx[None,:]-a[0])*dx+(yy[:,None]-a[1])*dy)/(dx*dx+dy*dy),0,1)
            dist=np.sqrt((xx[None,:]-a[0]-t*dx)**2+(yy[:,None]-a[1]-t*dy)**2)
            current=distance[y0:y1,x0:x1];update=dist<current
            current[update]=dist[update]
            for field,k in ((width,3),(physical,4),(arc,2)):
                interpolated=a[k]+(b[k]-a[k])*t;field[y0:y1,x0:x1][update]=interpolated[update]
    xx=ox+(np.arange(pw)+.5)/ppu;yy=oy+(np.arange(ph)+.5)/ppu
    phase=terrain.lattice(recipe['seed'],31,19)*math.tau
    broad=np.sin(xx[None,:]*2.1+np.sin(yy[:,None]*1.7)+phase)*.65
    fine=np.sin(xx[None,:]*17.1+yy[:,None]*13.3+phase)*.22+np.sin(xx[None,:]*31.7-yy[:,None]*19.1)*.13
    jitter=(broad+fine)*recipe['edges']['amplitude']
    radius=np.maximum(physical*.5+.045,width*.5+jitter)
    signed=distance-radius;pixel=1/ppu
    coverage=np.where(signed<=-pixel*.5,255,np.where(signed<=pixel*.5,128,0)).astype(np.uint8)
    nav=(distance<=physical*.5)&np.isfinite(distance);coverage[nav]=255
    shoulder=np.where((signed>0)&(signed<recipe['edges']['shoulder']),np.clip(1-signed/max(recipe['edges']['shoulder'],.001),0,1)*190,0).astype(np.uint8)
    wear=np.where(coverage>0,np.clip(.5+.5*wave(recipe['seed']+19,arc,5),0,1)*coverage,0).astype(np.uint8)
    return {'coverage':coverage,'shoulders':shoulder,'navigable':nav.astype(np.uint8)*255,'wear':wear}

def logical_masks(road_segments,region,cost):
    occupancy=[];centre=[];w,h=region['size']
    samples=np.array([p for seg in road_segments for p in seg['samples']])
    for y in range(h):
        for x in range(w):
            d=np.linalg.norm(samples[:,:2]-cost.center(x,y),axis=1);j=int(d.argmin())
            occupied=float(d[j])<=float(samples[j,4])*.5
            # Conservative logical occupancy: flagged cells are traversable; it is not a collider mask.
            occupancy.append(bool(occupied and not cost.forbidden[y,x]));centre.append(bool(float(d[j])<=region['cellSizeUnits']*.6))
    return {'navigable':occupancy,'centreline':centre}

def overlay(masks,recipe,bounds):
    # Existing study atlas only. No new material library in Marco 02.
    with Image.open(ATLAS) as atlas:tile=np.array(atlas.convert('RGBA').crop((4*32,0,5*32,32)))
    ph,pw=masks['coverage'].shape;ox,oy,_,_=bounds
    x=(np.arange(pw)+round(ox*32))%32;y=(np.arange(ph)+round(oy*32))%32
    rgba=tile[y[:,None],x[None,:]].copy()
    rgba[:,:,3]=np.maximum(masks['coverage'],masks['shoulders']//2)
    return Image.fromarray(rgba)

def build(region,recipe,output,patch=None,input_sha=None):
    output=Path(output)
    if output.exists():raise FileExistsError(f'Refuse existing road output {output}')
    seg,cost,effective=segments(region,recipe,patch);w,h=region['size'];bounds=[*cost.origin.tolist(),w*cost.cell,h*cost.cell]
    masks=rasterize(seg,effective,bounds);logical=logical_masks(seg,region,cost)
    minwidth=min(p[4] for s in seg for p in s['samples'])
    road={'schema':'valdoria-organic-road/v1','generator':VERSION,'seed':recipe['seed'],'roadType':recipe['roadType'],
      'region':{'id':region['regionId'],'sha256':input_sha or terrain.digest(canonical(region)),'schema':region['schema']},
      'coordinates':'world units X right Y down; pixel centres; Unity=(x,regionHeight-y)',
      'bounds':bounds,'ppu':32,'sampleColumns':['x','y','localArcUnits','visualWidthUnits','navigableWidthUnits'],
      'waypoints':effective['waypoints'],'segments':seg,'logicalMasks':logical,'constraints':effective['constraints'],
      'masks':{k:{'file':k+'.png','size':[masks[k].shape[1],masks[k].shape[0]]} for k in masks},
      'qa':{'mandatoryWaypointsConnected':True,'minNavigableWidth':minwidth,'minimumRequested':recipe['width']['min'],
        'length':round(sum(s['length'] for s in seg),6),'maxCurvature':max(s['maxCurvature'] for s in seg),
        'terrainModified':False,'physicalMaskCreatesColliders':False,'visualCoreContinuous':bool(np.all(masks['coverage'][masks['navigable']>0]==255))}}
    output.mkdir(parents=True)
    for key,value in masks.items():Image.fromarray(value).save(output/(key+'.png'))
    overlay(masks,effective,bounds).save(output/'road-overlay.png')
    (output/'road.json').write_bytes(canonical(road))
    link={'schema':'valdoria-world-region/v2','terrainRef':road['region'],'roadRefs':[{'file':'road.json','sha256':terrain.digest((output/'road.json').read_bytes())}]}
    (output/'world-region-linked.json').write_bytes(canonical(link))
    manifest={'schema':'valdoria-road-build/v1','generator':VERSION,'recipeSha256':terrain.digest(terrain.canonical(recipe)),
      'patchSha256':terrain.digest(terrain.canonical(patch)) if patch else None,'inputRegionSha256':road['region']['sha256'],
      'studyAtlasSha256':terrain.digest(ATLAS.read_bytes()),'status':'candidate-not-art-approved',
      'outputs':{p.name:terrain.digest(p.read_bytes()) for p in sorted(output.iterdir())}}
    (output/'manifest.json').write_bytes(canonical(manifest));return road

def study_recipe(style):
    configs={'A':('rural',3.,2.,3.8,.10,.08,.22,7.),'B':('medieval-worn',3.4,2.2,4.4,.22,.19,.27,7.),'C':('natural-trail',2.0,1.4,2.8,.17,.14,.19,14.)}
    kind,nominal,minimum,maximum,variation,amplitude,shoulder,slope_weight=configs[style]
    waypoints=[[2.5,34.5],[14.5,33.5],[25.5,29.5],[33.5,24.5],[44.5,21.0],[60.5,18.5]]
    if style=='C':
        # Additional authored valley guides, both inside the existing low-gradient corridor.
        waypoints.insert(2,[20.5,32.7]);waypoints.insert(5,[39.5,22.9])
    return {'schema':'valdoria-organic-road-recipe/v1','seed':710202,'roadType':kind,'ppu':32,
      'waypoints':waypoints,
      'width':{'nominal':nominal,'min':minimum,'max':maximum,'variation':variation,'maxRate':.23},
      'curve':{'type':'centripetal-catmull-rom','tension':1.,'sampleSpacing':.125,'maxCurvature':1.1},
      'edges':{'amplitude':amplitude,'shoulder':shoulder},
      'constraints':{'maxSlope':.16,'slopeWeight':slope_weight,'heightWeight':1.4,'avoidWaterCandidates':True,'authorizedCrossingCells':[]},
      'protectedAreas':[{'id':'settlement-access','rect':[6,29,10,9],'allowRoad':True}]}

def study(output):
    output=Path(output)
    if output.exists():raise FileExistsError(output)
    # Validate all geometry before creating the destination.
    region=terrain.read_json(BASE)
    for style in 'ABC':segments(region,study_recipe(style))
    output.mkdir(parents=True)
    for style in 'ABC':
        r=study_recipe(style);(output/('recipe-'+style+'.json')).write_bytes(canonical(r))
        build(region,r,output/style,input_sha=terrain.digest(BASE.read_bytes()))

def verify(region,recipe,output,patch=None,input_sha=None):
    output=Path(output);published=terrain.read_json(output/'manifest.json')
    with tempfile.TemporaryDirectory(prefix='valdoria-road-verify-') as tmp:
        candidate=Path(tmp)/'candidate';build(region,recipe,candidate,patch,input_sha)
        expected=terrain.read_json(candidate/'manifest.json')
    if published!=expected:raise AuthoringError('Manifest differs from deterministic rebuild')
    for name,sha in published['outputs'].items():
        if Path(name).name!=name or terrain.digest((output/name).read_bytes())!=sha:raise AuthoringError('Artifact hash mismatch: '+name)
    return True

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['generate','verify','study']);p.add_argument('--region',type=Path,default=BASE);p.add_argument('--recipe',type=Path);p.add_argument('--patch',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if a.command=='study':study(a.output)
    else:
        if not a.recipe:p.error('--recipe required')
        args=(terrain.read_json(a.region),terrain.read_json(a.recipe),a.output,terrain.read_json(a.patch) if a.patch else None,terrain.digest(a.region.read_bytes()))
        if a.command=='generate':print(json.dumps(build(*args)['qa'],indent=2))
        else:print(json.dumps({'valid':verify(*args)}))
