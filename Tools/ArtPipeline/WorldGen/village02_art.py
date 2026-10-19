"""Village02 phase E: new authored masters -> layered Aseprite -> read-only exports.

No old art is regenerated. Bootstrap is provenance, never the normal export path.
The gallery is an art/scale review; this does not claim world collision integration.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'ArtSource/World/PlayableVillage02/ArtProductionV1'
ASE='D:/Aseprite/Aseprite.exe'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def write(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def q(p):return json.dumps(str(Path(p).resolve()).replace('\\','/'))
def run_lua(code,p):
    p.write_text(code,encoding='utf-8');subprocess.run([ASE,'-b','--script',str(p.resolve())],check=True,capture_output=True)

# Door annotations are explicit authorship in master pixels, not inferred from alpha.
# Their human-scale normalization is reviewed beside Quaternius in the Unity gallery.
SPECS={
 'H1':dict(door=[650,854,1060],roof=[(.12,.49),(.28,.16),(.79,.29),(.98,.52),(.94,.56),(.70,.66),(.13,.50)],chimney=[.23,.08,.38,.33]),
 'H2':dict(door=[570,656,864],roof=[(.04,.45),(.43,.10),(.70,.15),(.98,.47),(.68,.62),(.04,.47)],chimney=[.63,.07,.77,.32]),
 'H3':dict(door=[389,672,915],roof=[(.02,.49),(.21,.04),(.66,.22),(.99,.61),(.65,.69),(.05,.51)],chimney=[.56,.12,.68,.34]),
 'H4':dict(door=[655,634,847],roof=[(.06,.45),(.27,.08),(.81,.28),(.97,.54),(.91,.60),(.71,.68),(.47,.54),(.34,.50),(.29,.54),(.06,.47)],chimney=[.18,.02,.30,.30]),
 'H5':dict(door=[748,690,875],roof=[(.03,.46),(.24,.07),(.86,.29),(.98,.51),(.72,.67),(.04,.48)],chimney=[.67,.12,.79,.36]),
 'H6':dict(door=[619,670,870],roof=[(.09,.47),(.28,.04),(.79,.28),(.94,.54),(.91,.62),(.73,.67),(.54,.59),(.09,.48)],chimney=[.68,.19,.80,.38]),
 'B1':dict(door=[239,624,790],roof=[(.03,.44),(.22,.07),(.79,.29),(.98,.62),(.71,.70),(.61,.57),(.04,.46)],chimney=None),
 'castle-compound':dict(door=[749,628,730]),
 'gate':dict(span=[620,850],units=8,anchor=[733,861]),
 'wall':dict(span=[75,1490],units=12,anchor=[765,760]),
 'corner':dict(span=[50,1000],units=8,anchor=[1000,925]),
 'bridge':dict(span=[367,655],units=7,anchor=[511,1350]),
 'fence':dict(span=[50,1070],units=8,anchor=[1070,820]),
 'lowwall':dict(span=[50,1090],units=8,anchor=[1090,880]),
}

def ownership(id,size,spec):
    w,h=size;im=Image.new('RGB',size,(1,0,0));d=ImageDraw.Draw(im)
    def poly(points,index):d.polygon([(round(x*w),round(y*h)) for x,y in points],fill=(index,0,0))
    def box(points,index):d.rectangle(tuple(round(v*(w if i%2==0 else h)) for i,v in enumerate(points)),fill=(index,0,0))
    if id.startswith('H') or id=='B1':
        names=['Walls','Roof','Foundation','Openings','Details']
        poly(spec['roof'],2)
        # Authored broad ownership bands, not hidden-surface reconstruction.
        poly([(.02,.70),(.70,.92),(.99,.72),(.99,1),(.02,1)],3)
        x,head,foot=spec['door'];d.rectangle((x-55,head,x+55,foot),fill=(4,0,0))
        if spec['chimney']:box(spec['chimney'],5)
    elif id=='castle-compound':
        names=['Curtain','Court','KeepWalls','KeepPlatform','HallWalls','HallRoof','ServiceWalls','ServiceRoof','GateWest','GateEast','GateArch','GateTimber']
        poly([(.09,.40),(.90,.39),(.93,.78),(.52,.91),(.13,.75)],2)
        poly([(.55,.08),(.93,.04),(.94,.56),(.54,.53)],3)
        poly([(.54,.05),(.94,.02),(.94,.23),(.55,.22)],4)
        poly([(.14,.18),(.54,.20),(.54,.55),(.14,.52)],5)
        poly([(.13,.17),(.20,.14),(.52,.22),(.58,.34),(.54,.37),(.17,.32)],6)
        poly([(.59,.54),(.91,.57),(.91,.77),(.59,.74)],7)
        poly([(.58,.53),(.65,.52),(.91,.58),(.94,.65),(.89,.67),(.58,.61)],8)
        poly([(.08,.56),(.27,.58),(.27,.91),(.08,.89)],9)
        poly([(.36,.59),(.54,.60),(.54,.94),(.36,.92)],10)
        poly([(.24,.62),(.39,.64),(.40,.80),(.25,.78)],11)
        poly([(.23,.71),(.39,.73),(.40,.90),(.23,.89)],12)
    elif id=='bridge':
        names=['Deck','LeftRail','RightRail','Abutments'];box([.0,.0,.37,1],2);box([.65,.0,1,1],3);box([.0,.0,1,.16],4);box([.0,.86,1,1],4)
    elif id=='gate':
        names=['CurtainConnectors','LeftTower','RightTower','ArchChamber','TimberGate']
        box([.10,.0,.39,1],2);box([.56,.10,.91,1],3);poly([(.34,.24),(.61,.33),(.64,.63),(.34,.55)],4);box([.37,.48,.60,.90],5)
    elif id in ('wall','corner','lowwall'):
        names=['Masonry','Coping','Foundation'];poly([(.0,.0),(1,0),(1,.58),(.65,.48),(0,.26)],2);poly([(0,.54),(.68,.88),(1,.58),(1,1),(0,1)],3)
    else:
        names=['Rails','PostsAndFootings','Gate'];box([.32,.37,.55,.82],3)
        for x in [.05,.35,.54,.70,.93]:box([x-.025,.30,x+.025,.91],2)
    return im,names

def author(out):
    if out.exists():raise FileExistsError('Refuse existing Aseprite source directory')
    out.mkdir(parents=True)
    for id,s in SPECS.items():
        p=out/id;p.mkdir();master=BASE/'Masters'/f'{id}.png';im=Image.open(master);w,h=im.size
        if 'door' in s:
            x,head,foot=s['door'];scale=4.85*32/(foot-head);anchor=[x,foot];door=[head,foot]
        else:
            scale=s['units']*32/(s['span'][1]-s['span'][0]);anchor=s['anchor'];door=None
        nw,nh=round(w*scale),round(h*scale);mask,names=ownership(id,im.size,s);mask.resize((nw,nh),Image.Resampling.NEAREST).save(p/'ownership.png')
        lua='local input=app.open('+q(master)+');local im=input.cels[1].image;'
        # Explicit source operation removes the generator's semi-transparent halo.
        lua+='for y=0,im.height-1 do for x=0,im.width-1 do local c=im:getPixel(x,y);local a=app.pixelColor.rgbaA(c);if a<250 then im:drawPixel(x,y,0) else im:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;'
        lua+=f'app.command.SpriteSize{{ui=false,width={nw},height={nh},method="nearest"}};'
        lua+='app.command.ColorQuantization{ui=false,maxColors=192,withAlpha=true,algorithm="octree"};app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"};app.command.ChangePixelFormat{ui=false,format="rgb"};'
        # The quantizer may average alpha inside palette entries; restore binary
        # coverage after returning to RGB, without altering their RGB pigments.
        lua+='local final=input.cels[1].image;for y=0,final.height-1 do for x=0,final.width-1 do local c=final:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then final:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;'
        lua+='local pixels=Image(input.spec);pixels:drawSprite(input,1);pixels:saveAs('+q(p/'native-authority.png')+');local ms=app.open('+q(p/'ownership.png')+');local owner=ms.cels[1].image;'
        lua+=f'local s=Sprite({nw},{nh},ColorMode.RGB);s.layers[1].name="Temporary";local layers={{}};local imgs={{}};'
        for name in names:lua+=f'local l=s:newLayer();l.name={json.dumps(name)};table.insert(layers,l);table.insert(imgs,Image({nw},{nh},ColorMode.RGB));'
        lua+=f'for y=0,{nh-1} do for x=0,{nw-1} do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local k=app.pixelColor.rgbaR(owner:getPixel(x,y));imgs[k]:drawPixel(x,y,c) end end end;'
        lua+='for k=1,#layers do s:newCel(layers[k],1,imgs[k],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs('+q(p/(id+'.aseprite'))+');s:close();ms:close();input:close();'
        run_lua(lua,p/'bootstrap.lua')
        # Familiar source contract permits the existing authored-reference exporter.
        meta=dict(schema='valdoria-authored-house/v1',id=id,sourceFile=id+'.aseprite',canvas=[nw,nh],ppu=32,layers=names,
            groundAnchorPixels=[anchor[0]*nw/w,anchor[1]*nh/h],roles={name:'roof' if name in ['Roof','HallRoof','ServiceRoof','KeepPlatform'] else 'ground' if name=='Court' else 'wall' for name in names},
            master=dict(path=str(master.relative_to(ROOT)).replace('\\','/'),sha256=sha(master),size=[w,h]),
            scaleFromPaintedMaster=[nw/w,nh/h],doorMaster=s.get('door'),doorHeightUnits=(door[1]-door[0])*nh/h/32 if door else None,
            normalizedBy='human door annotation, 4.85u target' if door else 'explicit span annotation',
            spanMaster=s.get('span'),spanUnits=s.get('units'),alphaOperation='Aseprite: alpha <250 ->0, remaining ->255; removes generated fringe/halo',paletteOperation='Aseprite octree <=192, no dithering; RGBA export',
            authority='Editable .aseprite; export reads current pixels without rebuilding from master',
            layerOwnership='Authored broad semantic masks; independent editable visible pixels, no hidden surfaces reconstructed',
            worldReady=False,worldIntegration='Phase F must annotate/validate exact source footprints and connections; no collider inferred from these raster bounds',
            artisticStatus='candidate; layout approval does not approve these pixels')
        write(p/'house-source.json',meta)
        print('Authored',id,nw,nh,flush=True)

def export(out,source):
    out=out.resolve();source=source.resolve()
    if out.exists():raise FileExistsError('Refuse existing export directory')
    import architecture07r_reference as ref
    out.mkdir(parents=True);catalog=[]
    for id in SPECS:
        parts=ref.export(source/id,out/id);meta=read(source/id/'house-source.json')
        with Image.open(source/id/'native-authority.png') as a,Image.open(out/id/'composite.png') as b:
            if not np.array_equal(np.array(a),np.array(b)):raise ValueError('Layer reconstruction changed pixels '+id)
        composite=out/id/'composite.png';im=Image.open(composite);alpha=np.array(im.getchannel('A'))
        if set(np.unique(alpha))!={0,255}:raise ValueError('Nonbinary alpha '+id)
        row=dict(id=id,ppu=32,canvas=meta['canvas'],groundAnchorPixels=meta['groundAnchorPixels'],doorHeightUnits=meta['doorHeightUnits'],spanUnits=meta['spanUnits'],source=str((source/id/(id+'.aseprite')).relative_to(ROOT)).replace('\\','/'),sourceSHA256=sha(source/id/(id+'.aseprite')),export=str((out/id/'export.json').relative_to(ROOT)).replace('\\','/'),composite=str(composite.relative_to(ROOT)).replace('\\','/'),compositeSHA256=sha(composite),worldReady=False,parts=len(parts))
        catalog.append(row)
    write(out/'catalog.json',dict(schema='valdoria-village02-art-catalog/v1',assets=catalog,stage='E-art-production',worldIntegrated=False))
    write(out/'manifest.json',dict(schema='valdoria-village02-art-build/v1',catalogSHA256=sha(out/'catalog.json'),inputs={id:sha(source/id/(id+'.aseprite')) for id in SPECS},files={id+'/composite.png':sha(out/id/'composite.png') for id in SPECS}))
    return catalog

def verify(out):
    import architecture07r_reference as ref
    catalog=read(out/'catalog.json');results=[]
    for a in catalog['assets']:
        ref.arch.verify_files(out/a['id']);assert sha(ROOT/a['source'])==a['sourceSHA256'];assert sha(ROOT/a['composite'])==a['compositeSHA256']
        m=read(out/a['id']/'manifest.json')
        for v in m['inputs'].values():assert sha(ROOT/v['path'])==v['sha256']
        meta=read(ROOT/m['inputs']['metadata']['path']);assert sha(ROOT/meta['master']['path'])==meta['master']['sha256']
        im=Image.open(ROOT/a['composite']);alpha=np.array(im.getchannel('A'));assert set(np.unique(alpha))=={0,255}
        if a['doorHeightUnits']:assert abs(a['doorHeightUnits']-4.85)<.015
        results.append(dict(id=a['id'],binaryAlpha=True,sourceAndExportHashes=True,doorHeightUnits=a['doorHeightUnits'],canvas=im.size))
    return dict(passed=True,assets=len(results),results=results,worldIntegrationTested=False)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('action',choices=['author','export','verify']);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--source',type=Path,default=BASE/'SourceV1');a=ap.parse_args()
    a.output=a.output.resolve();a.source=a.source.resolve()
    if a.action=='author':author(a.output)
    elif a.action=='export':print('Exported',len(export(a.output,a.source)))
    else:print(json.dumps(verify(a.output)))
