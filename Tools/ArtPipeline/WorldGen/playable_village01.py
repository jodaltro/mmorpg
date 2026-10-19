"""Offline village composition. Existing paintings remain the pixel authority.

No runtime generation. Semantic footprints precede presentation and are shared
with Unity's polygon import and the clearance-aware connectivity proof.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, math
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, label
import ground_finish11 as ground

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'ArtSource/World/PlayableVillage01'
W,H,PPU=112,144,32
SEED=1202601
if (BASE/'recipe.json').is_file():SEED=int(json.loads((BASE/'recipe.json').read_text(encoding='utf-8'))['seed'])

def read(p): return json.loads(Path(p).read_text(encoding='utf-8'))
def write(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rect(x0,y0,x1,y1): return [[x0,y0],[x1,y0],[x1,y1],[x0,y1]]
def bank(x):
    # Deliberately authored low-frequency bends; full-width river, no ford.
    center=24+1.1*np.sin(x/13)+.45*np.sin(x/5.7)
    return center-4.2,center+4.2

def layout():
    recipe=read(BASE/'recipe.json')
    if recipe['schema']!='valdoria-village-recipe/v1' or recipe['worldSize']!=[W,H] or recipe['ppu']!=32:raise ValueError('Village v1 domain contract')
    data={'schema':'valdoria-playable-village/v1','seed':SEED,'worldSize':[W,H],
          'ppu':PPU,'navigationStep':.25,'spawn':[56,8],'bridgeClearance':[53,18,59,35],
          'physical':[],'buildings':[],'props':[], 'paths':[],
          'physicalHeight':0,'waterModel':'Authored defensive surface channel; no hydraulic simulation',
          'artisticStatus':'candidate-awaiting-user-review'}
    def physical(id,p,kind): data['physical'].append({'id':id,'kind':kind,'polygon':p})
    # Water is partitioned at the bridge: these are physical water polygons,
    # never an attempt to derive collisions by inspecting rendered blue pixels.
    for a,b in [(0,53),(59,W)]:
        xs=np.linspace(a,b,int((b-a)*4)+1)
        physical('river-'+str(a),[[float(x),float(bank(x)[0])] for x in xs]+[[float(x),float(bank(x)[1])] for x in xs[::-1]],'water')
    for id,p in [('west',rect(11,34,13,118)),('east',rect(99,34,101,118)),('north',rect(11,116,101,118)),('south-west',rect(11,33,53.5,35)),('south-east',rect(59,33,101,35))]: physical('wall-'+id,p,'wall')
    for x in (52,58): physical('bridge-rail-'+str(x),rect(x,18,x+2,34),'rail')
    gate=read(ROOT/'ArtSource/Labs/World2026/WorldStudio08/Castle/ReviewV1/house.json')
    for i in (3,4):physical('gate-pier-'+str(i),[[p[0]+24,66-p[1]] for p in gate['footprints'][i]],'wall')
    for id,p in [('left',rect(-2,-2,0,H+2)),('right',rect(W,-2,W+2,H+2)),('bottom',rect(-2,-2,W+2,0)),('top',rect(-2,H,W+2,H+2))]:physical('world-'+id,p,'boundary')
    for spec in recipe['buildings']:
        id,family,position=spec['id'],spec['family'],spec['position']
        stem={'house':'WorldStudio07R','barn':'WorldStudio08/Barn','castle':'WorldStudio08/Castle'}[family]
        folder=ROOT/'ArtSource/Labs/World2026'/stem
        meta_path=folder/('ReviewV1/house.json' if family=='castle' else 'RegionV1/house.json')
        meta=read(meta_path)
        original=np.array([meta['position'][0],meta['sizeUnits'][1]-meta['position'][1]])
        delta=np.array(position)-original
        def move(p):return (np.array([p[0],meta['sizeUnits'][1]-p[1]])+delta).tolist()
        item={'id':id,'family':family,'position':position,'metadata':str(meta_path.relative_to(ROOT)).replace('\\','/'),'export':str((folder/'ExportV1/export.json').relative_to(ROOT)).replace('\\','/'),'offset':delta.tolist(),'entry':move(meta['entry']),'approach':move(meta['approach'])}
        data['buildings'].append(item)
        for i,p in enumerate(meta.get('footprints',[meta['footprint']])):physical(id+'-'+str(i),[move(q) for q in p],'building')
    data['paths']=recipe['paths']
    # Explicit contextual placements, reproducible small family, no random forest.
    for i,(x,y) in enumerate(recipe['trees']):
        data['props'].append({'id':'oak-'+str(i),'asset':'oak-reference' if i%2==0 else 'oak-forked','point':[x,y]})
        physical('oak-'+str(i),[[x+.5*np.cos(t),y+.5*np.sin(t)] for t in np.linspace(0,2*np.pi,16,endpoint=False)],'tree')
    assets={a['id']:a for a in read(ROOT/'ArtSource/Labs/World2026/Nature10/SourceV2/source.json')['assets']}
    for i,(x,y) in enumerate(recipe['rocks']):
        asset='fieldstone' if i%2==0 else 'broken-slab'
        data['props'].append({'id':'rock-'+str(i),'asset':asset,'point':[x,y]})
        physical('rock-'+str(i),[[x+p[0]/32,y-p[1]/32] for p in assets[asset]['footprintPixels']],'rock')
    return data

def navigation(data,bridge=True):
    scale=4; image=Image.new('L',(W*scale,H*scale),0);draw=ImageDraw.Draw(image)
    for p in data['physical']:draw.polygon([(round(x*scale),round((H-y)*scale)) for x,y in p['polygon']],fill=255)
    if not bridge:
        xs=np.linspace(53,59,25);draw.polygon([(round(x*scale),round((H-bank(x)[0])*scale)) for x in xs]+[(round(x*scale),round((H-bank(x)[1])*scale)) for x in xs[::-1]],fill=255)
    blocked=np.array(image)>0
    walk=distance_transform_edt(~blocked)>.625*scale
    labels,n=label(walk)
    def at(p):return int(labels[int((H-p[1])*scale),int(p[0]*scale)])
    a=at(data['spawn']); b=at([56,44]); c=at([48,81.5]);return walk,{'components':n,'spawn':a,'village':b,'castle':c,'connected':bool(a and a==b==c),'bridgeOpen':bridge}

def surfaces(out,data):
    width,height=W*PPU,H*PPU
    coverage=Image.new('L',(width,height));d=ImageDraw.Draw(coverage)
    paths=[]
    for path in data['paths']:
        pts=[(round(x*PPU),round((H-y)*PPU)) for x,y in path['points']];paths.append(pts);r=round(path['width']*PPU/2)
        d.line(pts,fill=255,width=r*2,joint='curve')
        for x,y in pts:d.ellipse((x-r,y-r,x+r,y+r),fill=255)
    d.ellipse((46*PPU,(H-67)*PPU,66*PPU,(H-54)*PPU),fill=255)
    coverage=np.array(coverage)
    # Cache full-domain distance fields once. Ground11 render continues to use
    # global coordinates and sources, including its established seam treatment.
    inside=distance_transform_edt(coverage>127); outside=distance_transform_edt(coverage<=127)
    original=ground.distance_transform_edt
    ground.distance_transform_edt=lambda mask:inside if mask[0,0]==(coverage>127)[0,0] else outside
    previous_stamps=ground.stamps
    ground.stamps=local_stamps
    recipe=read(ROOT/'ArtSource/Labs/World2026/Ground11/recipe.json');recipe['seed']=SEED
    sites=[{'id':p['id'],'kind':'tree','point':[p['point'][0],H-p['point'][1]],'influenceRadii':[1.22,.72]} for p in data['props'] if p['asset'].startswith('oak')]
    chunks=[]
    for y in range(0,height,512):
        for x in range(0,width,512):
            w,h=min(512,width-x),min(512,height-y)
            images,_=ground.render([x,y,w,h],coverage,paths,recipe,sites=sites)
            name=f'ground-{x}-{y}.png';images['final'].save(out/name);chunks.append({'file':name,'rect':[x,y,w,h]})
        print('Ground strip',y,flush=True)
    ground.distance_transform_edt=original
    ground.stamps=previous_stamps
    data['groundChunks']=chunks
    coverage=Image.fromarray(coverage);coverage.save(out/'road-coverage.png')

def local_stamps(image,bounds,coverage,sd,recipe,world,sites=None,library=ground.EXPORT):
    """Ground11 edge grammar, identical global anchors, bounded chunk iteration.
    Halo includes every possible 32px stamp, no modulo/reset at chunk edges.
    """
    x0,y0,w,h=bounds; height,width=coverage.shape;seed=recipe['seed'];m=ground.m
    sheet=Image.open(Path(library)/'edge-grammar.png').convert('RGBA');overlay=Image.new('RGBA',(w,h))
    for gy in range(max(0,(y0-54)//13),min(height//13+1,(y0+h+54)//13+1)):
        for gx in range(max(0,(x0-54)//13),min(width//13+1,(x0+w+54)//13+1)):
            xx=int((gx+float(m.ihash(gx,gy,seed+151)))*13);yy=int((gy+float(m.ihash(gx,gy,seed+157)))*13)
            if not 0<=xx<width or not 0<=yy<height or not x0-40<=xx<x0+w+40 or not y0-40<=yy<y0+h+40:continue
            v=int(m.ihash(gx,gy,seed+163)*8)%8
            if -5<sd[yy,xx]<2 and m.field(np.array(xx),np.array(yy),53,seed+167)>.48 and m.ihash(gx,gy,seed+169)>.50:
                overlay.alpha_composite(sheet.crop((v*64,0,v*64+32,32)),(xx-x0-16,yy-y0-27))
            elif 2<sd[yy,xx]<13 and m.ihash(gx,gy,seed+173)>.65:
                overlay.alpha_composite(sheet.crop((v*64,48,v*64+32,80)),(xx-x0-16,yy-y0-17))
    for i,p in enumerate([s for s in (sites or []) if s['kind']=='tree']):
        cx,cy=np.array(p['point'])*32
        for k in range(17):
            angle=float(m.ihash(i,k,seed+179))*math.tau;r=18+float(m.ihash(i,k,seed+181))*28
            xx=round(cx+math.cos(angle)*r);yy=round(cy+math.sin(angle)*r*.6);v=k%8
            if 0<=xx<width and 0<=yy<height and coverage[yy,xx]<10:
                overlay.alpha_composite(sheet.crop((v*64,80,v*64+32,112)),(xx-x0-16,yy-y0-20))
    image.alpha_composite(overlay)

def water(out,data):
    # Same Ground13 palette, source motifs and four-frame, 180ms playback;
    # new authored channel masks. It is a new composition, not a new simulator.
    x=np.arange(W*32)[None,:]/32; y=np.arange(18*32)[:,None]/32+17
    low,high=bank(x);depth=np.clip(np.minimum(y-low,high-y)/3,0,1)
    values=np.array([102,143,122])*(1-depth[...,None])+np.array([38,79,89])*depth[...,None]
    alpha=np.where((y>=low)&(y<=high),255,0).astype('uint8')
    motifs=[Image.open(ROOT/f'ArtSource/Labs/World2026/Ground13/ExportV2/water-motifs-{f}.png').convert('RGBA') for f in range(4)]
    for phase in range(4):
        arr=np.concatenate([np.clip(values,0,255).astype('uint8'),alpha[...,None]],axis=2)
        im=Image.fromarray(arr).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        for gx in range(25):
            px=45+gx*139;py=230+int(47*np.sin(gx*2.1));tile=motifs[(phase+gx)%4].crop((0,0,64,64))
            if px<W*32-64:im.alpha_composite(tile,(px,py))
        a=np.array(im);a[:,:,3]=np.flipud(alpha);Image.fromarray(a).save(out/f'river-{phase}.png')

def build(out):
    if out.exists():raise FileExistsError('Refuse existing destination')
    out.mkdir(parents=True);data=layout();water(out,data);surfaces(out,data)
    walk,open_result=navigation(data);_,closed_result=navigation(data,False)
    assert open_result['connected'],open_result
    assert not closed_result['connected'],closed_result
    Image.fromarray(walk.astype('uint8')*255).save(out/'navigation.png')
    write(out/'navigation-proof.json',{'open':open_result,'bridgeRemoved':closed_result,'actorClearance':.625,'method':'4-connected flood fill on 0.25u grid; all semantic physical polygons rasterized; bridge removed must disconnect spawn from both interior targets'})
    write(out/'layout.json',data)
    write(out/'manifest.json',{'schema':'valdoria-village-build/v1','seed':SEED,'inputs':{'recipe.json':sha(BASE/'recipe.json')},'files':{p.name:sha(p) for p in sorted(out.iterdir()) if p.is_file()}})
    print('Village authored',out,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['build']);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();build(args.output)
