"""Editable, deterministic material atlas and three World Studio candidates.
Original algorithmic pixel art; no downloaded or generated-image assets.
"""
import argparse, json, math, random, hashlib, subprocess
from pathlib import Path
from PIL import Image, ImageDraw
import terrain_agent as terrain
ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'ArtSource/Labs/World2026/WorldStudio01'
RECIPES=ROOT/'ArtSource/Labs/World2026/WorldGen/Recipes'
PALETTES={
 'grass':['#3e5040','#526343','#617447','#71814c','#839057','#98a16a'],
 'dirt':['#685440','#80684b','#957d59','#ab9268','#baa57b','#cbbb90'],
 'rock':['#3f4549','#555b59','#6d7069','#85887c','#9fa28e','#b4b49b'],
 'slope':['#514a40','#6d604a','#847355','#998362','#af9a72','#c0ad85']}

def tile(kind,variant):
    colors=PALETTES[kind]; rng=random.Random(f'studio01:{kind}:{variant}')
    im=Image.new('RGBA',(32,32),colors[2]); d=ImageDraw.Draw(im)
    # Broad interlocking pigment clusters, repeated periodically through edges.
    for _ in range(15):
        x,y=rng.randrange(32),rng.randrange(32); rx,ry=rng.randrange(3,10),rng.randrange(2,5)
        col=colors[rng.choice([1,2,2,3])]
        poly=[(x-rx,y),(x-rx//2,y-ry),(x+rx//2,y-ry),(x+rx,y),(x+rx//2,y+ry),(x-rx//2,y+ry)]
        for ox in (-32,0,32):
            for oy in (-32,0,32):d.polygon([(a+ox,b+oy) for a,b in poly],fill=col)
    if kind=='grass':
        for _ in range(20):
            x,y=rng.randrange(2,30),rng.randrange(3,30)
            d.line([(x-1,y),(x-1,y-2),(x,y-1),(x+2,y-3)],fill=colors[3])
            if rng.random()<.45:d.line([(x,y-1),(x,y-3)],fill=colors[4])
    elif kind=='rock':
        for y in (-6,10,26):
            for x in (-12,8,28):
                x+=rng.randrange(-2,3); y1=y+rng.randrange(-2,3)
                shape=[(x,y1+3),(x+5,y1),(x+17,y1+1),(x+21,y1+7),(x+15,y1+13),(x+2,y1+12)]
                d.polygon(shape,fill=colors[1]);d.polygon([(a,b-1) for a,b in shape[:-1]],fill=colors[2])
                d.line([shape[0],shape[1],shape[2]],fill=colors[4]);d.line([shape[3],shape[4],shape[5]],fill=colors[0])
    else:
        for _ in range(14):
            x,y=rng.randrange(2,29),rng.randrange(2,29)
            d.line((x,y,x+2,y),fill=colors[1]);d.point((x,y-1),fill=colors[3])
    # Common two-pixel border from a periodic base makes variant joins coherent.
    base=PALETTES[kind][2]
    for q in range(32):
        for k in (0,1,30,31):im.putpixel((q,k),Image.new('RGBA',(1,1),base).getpixel((0,0)));im.putpixel((k,q),Image.new('RGBA',(1,1),base).getpixel((0,0)))
    return im

def transition(kind,mask,v):
    fg=tile(kind,v); bg=tile('grass',v)
    for y in range(32):
        for x in range(32):
            # Same edge function for every variant. Bits mark grass-facing N,E,S,W.
            wobble=lambda q: 4+(0,1,2,1,0,-1,-2,-1)[(q//2)%8]
            distances=[]
            if mask&1:distances.append(y-wobble(x))
            if mask&2:distances.append(31-x-wobble(y))
            if mask&4:distances.append(31-y-wobble(x))
            if mask&8:distances.append(x-wobble(y))
            distance=min(distances,default=99)
            if distance<0:fg.putpixel((x,y),bg.getpixel((x,y)))
            elif distance==0:fg.putpixel((x,y),tuple(bytes.fromhex(PALETTES[kind][1][1:]))+(255,))
            elif distance==1 and kind=='rock':fg.putpixel((x,y),tuple(bytes.fromhex(PALETTES[kind][4][1:]))+(255,))
    return fg

def atlas(output):
    output=Path(output)
    if output.exists():raise FileExistsError(output)
    output.mkdir(parents=True)
    sheet=Image.new('RGBA',(512,288)); tiles=[]
    for kind in ('grass','dirt','slope'):
        for v in range(4):tiles.append(tile(kind,v))
    for kind in ('dirt','rock'):
        for mask in range(16):
            for v in range(4):tiles.append(transition(kind,mask,v))
    for i,im in enumerate(tiles):sheet.paste(im,((i%16)*32,(i//16)*32))
    sheet.save(output/'surfaces.png')
    cliff=Image.new('RGBA',(128,64));d=ImageDraw.Draw(cliff)
    for v in range(4):
        x=v*32
        d.polygon([(x,14),(x+8,7),(x+20,9),(x+31,14),(x+31,57),(x+24,62),(x+5,61),(x,56)],fill='#343c3c')
        d.polygon([(x,15),(x+8,9),(x+21,11),(x+31,16),(x+29,49),(x+23,57),(x+5,56),(x+2,47)],fill='#6d7069')
        d.polygon([(x+3,17),(x+9,12),(x+15,14),(x+12,34),(x+8,48),(x+4,46)],fill='#969783')
        d.polygon([(x+18,15),(x+28,18),(x+26,48),(x+21,54),(x+16,42)],fill='#505a56')
        for y in (25,40,51):
            d.line([(x+2,y+v),(x+10,y-2),(x+18,y),(x+29,y-3)],fill='#414a48',width=2)
            d.line([(x+3,y-2+v),(x+10,y-4),(x+17,y-2)],fill='#969783')
        d.line([(x,14),(x+8,7),(x+20,9),(x+31,14)],fill='#a5ab83',width=2)
        d.line((x+3,59,x+26,60),fill='#4b5841',width=2)
    cliff.save(output/'cliffs.png')
    # Aseprite creates an editable, layered source from the raster modules.
    lua=output/'assemble.lua'
    lua.write_text('''local p=app.params['root']
local a=app.open(p..'/surfaces.png')
a.layers[1].name='Surfaces - clusters and transition masks'
local notes=a:newLayer(); notes.name='Paint refinements (editable)'
a:saveAs(p..'/materials-v1.aseprite')
a:close()
local c=app.open(p..'/cliffs.png'); c.layers[1].name='Rock faces - upper left light'
local l=c:newLayer(); l.name='Paint refinements (editable)'
c:saveAs(p..'/cliffs-v1.aseprite'); c:close()
''',encoding='utf-8')
    subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(output).replace('\\','/'),'--script',str(lua)],check=True)
    manifest={'schema':'valdoria-terrain-materials/v1','ppu':32,'surfaceCanvas':[32,32],'cliffCanvas':[32,64],
      'pivotSurface':[.5,.5],'pivotCliff':[.5,0], 'variants':4,'edgeBits':'N=1 E=2 S=4 W=8; neighbour grass',
      'tiles':len(tiles),'palette':PALETTES,'light':'upper-left','author':'Original algorithmic pixel art authored for Valdoria, Python + Aseprite 1.3.18.6',
      'license':'Original project material; no third-party source imagery','artStatus':'candidate-awaiting-user-review',
      'files':{p.name:terrain.digest(p.read_bytes()) for p in output.iterdir() if p.is_file()}}
    (output/'materials.json').write_bytes(terrain.canonical(manifest)+b'\n')

def recipe(variant):
    r={'schema':'valdoria-terrain-recipe/v1','regionId':f'valdoria-studio01-{variant}','seed':{'A':710101,'B':710202,'C':710303}[variant],
       'size':[64,48],'cellSizeUnits':1,'baseElevation':.40,'noiseAmplitude':.10,'waterCandidateBelow':.05,
       'thermalErosion':{'iterations':8,'talus':.045},'features':[],
       'protectedZones':[{'id':'construction-pad','rect':[6,29,10,9],'targetElevation':.4}],
       'route':{'points':[[2,34],[14,33],[25,29],[33,24],[44,22],[60,18]],'halfWidth':2.2,'targetElevation':.4},
       'navigation':{'maxSlope':.11,'maxElevation':.68}}
    if variant=='A':
        r['features']=[{'kind':'hill','center':[43,13],'radius':[19,13],'strength':.18},{'kind':'valley','center':[30,34],'radius':[24,12],'strength':.12}]
    elif variant=='B':
        r['features']=[{'kind':'hill','center':[22,13],'radius':[13,10],'strength':.53},{'kind':'hill','center':[47,28],'radius':[13,12],'strength':.50},{'kind':'hill','center':[52,7],'radius':[11,8],'strength':.34}]
        r['navigation']['maxElevation']=.62
    else:
        r['noiseAmplitude']=.16
        r['features']=[{'kind':'hill','center':[19,8],'radius':[23,15],'strength':.73},{'kind':'hill','center':[48,5],'radius':[20,16],'strength':.78},
         {'kind':'hill','center':[48,37],'radius':[18,16],'strength':.62},{'kind':'valley','center':[32,26],'radius':[35,11],'strength':.24}]
        r['navigation']['maxElevation']=.61
    return r

def decorate(region):
    w,h=region['size'];l=region['layers']; indices=[]; faces=[]
    # Explicit blocking is a rocky escarpment, not invisible elevation shading.
    kinds=['rock' if l['blocked'][i] or l['material'][i]=='rock' else 'dirt' if l['route'][i] else 'grass' for i in range(w*h)]
    for i,kind in enumerate(kinds):
        x,y=i%w,i//w;v=int(terrain.lattice(region['seed']+91,x,y)*4)%4; mask=0
        for bit,dx,dy in ((1,0,-1),(2,1,0),(4,0,1),(8,-1,0)):
            nx,ny=x+dx,y+dy
            if 0<=nx<w and 0<=ny<h and kinds[ny*w+nx]=='grass':mask|=bit
        index=v if kind=='grass' else (12 if kind=='dirt' else 76)+mask*4+v
        indices.append(index)
        if l['blocked'][i] and y+1<h and not l['blocked'][i+w] and not l['route'][i+w]: faces.append({'cell':i,'variant':v,'anchor':'south-edge','heightUnits':2})
    region['presentation']={'schema':'valdoria-terrain-presentation/v1','tileIndices':indices,'cliffFaces':faces,'materials':'materials-v1',
      'sorting':'surfaces=-2000; cliff/player=100-round(footWorldY*16)','heightAffectsActor':False}
    # One safe traversal corridor: these points are cell centres, not PNG coordinates.
    region['routePoints']=[[2,34],[14,33],[25,29],[33,24],[44,22],[60,18]]
    return region

def build(output):
    output=Path(output)
    if output.exists():raise FileExistsError(output)
    output.mkdir(parents=True)
    for name in 'ABC':
        r=recipe(name); rp=RECIPES/f'valdoria-studio01-{name}.json'
        if rp.exists() and terrain.read_json(rp)!=r:raise FileExistsError(rp)
        if not rp.exists():rp.write_bytes(terrain.canonical(r)+b'\n')
        target=output/name
        terrain.write_output(r,None,target)
        region=decorate(terrain.read_json(target/'region.json'))
        (target/'world-region.json').write_bytes(terrain.canonical(region)+b'\n')
        nav=region['navigation']; (target/'navigation.json').write_bytes(terrain.canonical(nav)+b'\n')
        manifest=terrain.read_json(target/'manifest.json')
        manifest['studioOutputs']={n:terrain.digest((target/n).read_bytes()) for n in ('world-region.json','navigation.json')}
        manifest['materialSha256']=terrain.digest((SOURCE/'Materials/materials.json').read_bytes())
        (target/'manifest.json').write_bytes(terrain.canonical(manifest)+b'\n')
    return output

def verify(output):
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        other=build(Path(tmp)/'regions')
        for name in 'ABC':
            for f in (other/name).iterdir():
                if f.read_bytes()!=(Path(output)/name/f.name).read_bytes():raise ValueError(f'Non-reproducible {name}/{f.name}')
    print('PASS: all A/B/C artifacts and manifests reproduce byte-for-byte')


def generate_candidate(recipe_path, patch_path, output):
    r=terrain.read_json(recipe_path);patch=terrain.read_json(patch_path) if patch_path else None
    target=Path(output);terrain.write_output(r,patch,target)
    region=decorate(terrain.read_json(target/'region.json'))
    region['routePoints']=r.get('route',{}).get('points',[])
    (target/'world-region.json').write_bytes(terrain.canonical(region)+b'\n')
    (target/'navigation.json').write_bytes(terrain.canonical(region['navigation'])+b'\n')
    manifest=terrain.read_json(target/'manifest.json')
    manifest['studioOutputs']={n:terrain.digest((target/n).read_bytes()) for n in ('world-region.json','navigation.json')}
    manifest['materialSha256']=terrain.digest((SOURCE/'Materials/materials.json').read_bytes())
    (target/'manifest.json').write_bytes(terrain.canonical(manifest)+b'\n')
    return target

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['atlas','build','verify','generate']);p.add_argument('--output',type=Path,required=True);p.add_argument('--recipe',type=Path);p.add_argument('--patch',type=Path);a=p.parse_args()
    if a.command=='generate':
        if not a.recipe:p.error('--recipe required')
        generate_candidate(a.recipe,a.patch,a.output)
    else:{'atlas':atlas,'build':build,'verify':verify}[a.command](a.output)
