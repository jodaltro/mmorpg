"""Authored building references: initial layer preparation and a noncanonical review yard.

Normal export uses architecture07r_reference.export and reads Aseprite pixels only.
"""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt
import architecture07r_reference as ref

ROOT=ref.ROOT


def prepare(design, output):
    design=Path(design); data=ref.read(design); out=ref.common.refuse(output); out.mkdir(parents=True)
    n=data['nativeSize']; names=data['layers']; factor=n/1254
    mask=Image.new('RGB',(1254,1254),(names.index(data['defaultLayer'])+1,0,0)); draw=ImageDraw.Draw(mask)
    for name,points in data['regions']:
        draw.polygon([tuple(p) for p in points],fill=(names.index(name)+1,0,0))
    mask.resize((n,n),Image.Resampling.NEAREST).save(out/'ownership.png')
    lua='local input=app.open(app.params["paint"]);local im=input.cels[1].image;for y=0,im.height-1 do for x=0,im.width-1 do local c=im:getPixel(x,y);if app.pixelColor.rgbaA(c)<100 then im:drawPixel(x,y,0) end end end;'
    lua+=f'app.command.SpriteSize{{ui=false,width={n},height={n},method="nearest"}};'
    lua+='app.command.ColorQuantization{ui=false,maxColors=128,withAlpha=true,algorithm="octree"};app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"};app.command.ChangePixelFormat{ui=false,format="rgb"};input:saveAs(app.params["palette"]);local pixels=input.cels[1].image:clone();local m=app.open(app.params["mask"]);local ownership=m.cels[1].image;'
    lua+=f'local s=Sprite({n},{n},ColorMode.RGB);s.layers[1].name="Temporary";local layers={{}};local images={{}};'
    for name in names:
        lua+=f'local l=s:newLayer();l.name={json.dumps(name)};table.insert(layers,l);table.insert(images,Image({n},{n},ColorMode.RGB));'
    lua+=f'for y=0,{n-1} do for x=0,{n-1} do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local part=app.pixelColor.rgbaR(ownership:getPixel(x,y));images[part]:drawPixel(x,y,c) end end end;'
    lua+='for i=1,#layers do s:newCel(layers[i],1,images[i],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs(app.params["output"]);s:close();m:close();input:close();'
    (out/'initial-authoring.lua').write_text(lua,encoding='utf8')
    params={'paint':design.parent/'painted-master.png','mask':out/'ownership.png','palette':out/'native-palette.png','output':out/data['sourceFile']}
    args=[r'D:\Aseprite\Aseprite.exe','-b']
    for k,p in params.items():args+=['--script-param',k+'='+str(p.resolve()).replace('\\','/')]
    subprocess.run(args+['--script',str((out/'initial-authoring.lua').resolve())],check=True)
    meta={k:v for k,v in data.items() if k not in ['regions','defaultLayer','nativeSize']}
    meta.update({'schema':'valdoria-authored-house/v1','canvas':[n,n],'ppu':32,'scaleFromPaintedMaster':factor,'groundAnchorPixels':(np.array(data['groundAnchorMaster'])*factor).tolist(),'design':ref.arch.ref(design),'authoring':'Blender clay composition, built-in ImageGen paint, Aseprite alpha cleanup/palette/layers; not hand-painted claim','pixelAuthority':data['sourceFile'],'artisticStatus':'candidate awaiting user review'})
    ref.common.write(out/'house-source.json',meta)
    return meta


def review_yard(source, exported, output):
    """Physical architecture test only. Explicitly not an environmentally accepted world lot."""
    out=ref.common.refuse(output);source=Path(source);exported=Path(exported);ref.arch.verify_files(exported)
    meta=ref.read(source/'house-source.json'); point=np.array([32.,32.]); size=80
    polygons=[(ref.local(p,meta)+point).tolist() for p in meta['physicalFootprintsMaster']]
    yy,xx=np.mgrid[:size*4,:size*4];x=(xx+.5)*.25;y=(yy+.5)*.25
    blocked=np.zeros(x.shape,bool)
    for polygon in polygons:blocked|=ref.arch.inside(polygon,x,y)
    walk=~blocked; clearance=distance_transform_edt(walk)*.25
    path=(ref.local(meta['courtyardRouteMaster'],meta)+point).tolist()
    for a,b in zip(path,path[1:]):
        for t in np.linspace(0,1,max(2,int(np.linalg.norm(np.array(b)-a)/.1))):
            px,py=np.array(a)*(1-t)+np.array(b)*t
            if clearance[int(py*4),int(px*4)]<.57:raise ValueError('Gate/courtyard actor clearance failed')
    pose={k:(ref.local([v],meta)[0]+point).tolist() for k,v in meta['posesMaster'].items()}
    out.mkdir(parents=True)
    data={'schema':'valdoria-authored-architecture-review/v1','id':meta['id'],'seed':meta['seed'],'position':point.tolist(),'sizeUnits':[size,size],'footprints':polygons,'footprint':(ref.local(meta['footprintMaster'],meta)+point).tolist(),'entry':pose['entry'],'approach':pose['front'],'poses':pose,'courtyardRoute':path,'reviewOnly':True,'siteQA':{'worldLotAccepted':False,'note':'Flat architectural review yard; no existing terrain, road, water or vegetation is altered. Geographic placement remains a future explicit terrain recipe decision.'},'doorHeightUnits':(meta['doorOpeningMasterPixels']['foot'][1]-meta['doorOpeningMasterPixels']['head'][1])*meta['scaleFromPaintedMaster']/32}
    # Each physical architectural volume supplies its own depth plane. These are
    # guides for presentation; only footprints above create collision/nav masks.
    data['depthGroups']=[
        {'id':'Keep','parts':['KeepWalls','KeepRoof','KeepDoor'],'outline':polygons[2]},
        {'id':'LeftTower','parts':['LeftTower'],'outline':polygons[0]},
        {'id':'RightTower','parts':['RightTower'],'outline':polygons[1]},
        {'id':'Gate','parts':['GateArch','GateTimber','Foundation'],'outline':(ref.local([[375,999],[618,1080],[658,1054],[413,973]],meta)+point).tolist()},
        {'id':'Curtain','parts':['CurtainWalls'],'outline':polygons[5]}]
    ref.common.write(out/'house.json',data)
    ref.common.write(out/'navigation.json',{'schema':'valdoria-architecture-navigation/v1','size':[320,320],'stepUnits':.25,'architectureBlocked':blocked.ravel().tolist(),'walkable':walk.ravel().tolist(),'actorClearanceIncluded':False})
    inputs={'art':ref.arch.ref(exported/'manifest.json'),'source':ref.arch.ref(source/meta['sourceFile']),'metadata':ref.arch.ref(source/'house-source.json')}
    ref.common.write(out/'manifest.json',{'schema':'valdoria-authored-house-region-build/v1','inputs':inputs,'files':{p.name:ref.common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()}})
    return data


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['prepare','yard']);parser.add_argument('--design');parser.add_argument('--source');parser.add_argument('--exported');parser.add_argument('--output',required=True);a=parser.parse_args()
    print(prepare(a.design,a.output)['id'] if a.command=='prepare' else review_yard(a.source,a.exported,a.output)['siteQA'])
