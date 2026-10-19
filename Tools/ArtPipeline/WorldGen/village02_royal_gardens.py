"""Explicit spacious royal precinct; Aseprite authority, no runtime generation."""
from pathlib import Path
import json, math, shutil
import numpy as np
from PIL import Image
import village02_anime_art as art
import village02_anime_integration as integration
import village02_integration as base

ROOT=art.ROOT
OUT=ROOT/'ArtSource/World/PlayableVillage02/RoyalGardensV1'
OLD=art.BASE/'IntegrationV2'
read=art.read; write=art.write; sha=art.sha; q=art.q

def ellipse(p,rx,ry):
 return [[round(p[0]+rx*math.cos(i*math.pi/10),6),round(p[1]+ry*math.sin(i*math.pi/10),6)] for i in range(20)]

def author(id,master,size,anchor,names):
 p=OUT/'Source'/id;p.mkdir(parents=True)
 w,h=size
 lua='local input=Sprite{fromFile='+q(master)+',oneFrame=true};app.activeSprite=input;assert(#input.frames==1);local im=input.cels[1].image;for y=0,im.height-1 do for x=0,im.width-1 do local c=im:getPixel(x,y);if app.pixelColor.rgbaA(c)<250 then im:drawPixel(x,y,0) else im:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;'
 lua+=f'app.command.SpriteSize{{ui=false,width={w},height={h},method="nearest"}};app.command.ColorQuantization{{ui=false,maxColors=192,withAlpha=true,algorithm="octree"}};app.command.ChangePixelFormat{{ui=false,format="indexed",dithering="none"}};app.command.ChangePixelFormat{{ui=false,format="rgb"}};local pixels=Image(input.spec);pixels:drawSprite(input,1);pixels:saveAs('+q(p/'native-authority.png')+f');local s=Sprite({w},{h},ColorMode.RGB);local ls={{}};local imgs={{}};'
 for name in names:lua+='do local l=s:newLayer();l.name='+json.dumps(name)+';table.insert(ls,l);table.insert(imgs,Image(s.spec)) end;'
 if id=='fountain':ownership=f'local k=y<{h}*.37 and 3 or y<{h}*.65 and 2 or 1;'
 else:ownership='local k=(app.pixelColor.rgbaR(c)>app.pixelColor.rgbaG(c)*1.02) and 2 or 1;'
 lua+=f'for y=0,{h-1} do for x=0,{w-1} do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then '+ownership+'imgs[k]:drawPixel(x,y,c) end end end;for i,l in ipairs(ls) do s:newCel(l,1,imgs[i]) end;s:deleteLayer(s.layers[1]);s:saveAs('+q(p/(id+'.aseprite'))+');s:close();input:close();'
 art.old.run_lua(lua,p/'author.lua')
 meta=dict(schema='valdoria-authored-house/v1',id=id,ppu=32,canvas=size,groundAnchorPixels=anchor,sourceFile=id+'.aseprite',layers=names,roles={name:'wall' for name in names},master=dict(path=master.relative_to(ROOT).as_posix(),sha256=sha(master)),authority='Aseprite pixels; nearest uniform resampling, octree192 no dithering',artisticApproval=False)
 write(p/'house-source.json',meta)
 dest=OUT/'Export'/id;art.ref.export(p,dest)
 with Image.open(p/'native-authority.png') as a,Image.open(dest/'composite.png') as b:assert a.tobytes()==b.tobytes()
 return dict(composite=(dest/'composite.png').relative_to(ROOT).as_posix(),canvas=size,anchorPixels=anchor)

def build():
 if OUT.exists():raise FileExistsError(OUT)
 (OUT/'Masters').mkdir(parents=True)
 shutil.copy2(Path('C:/Users/Administrator/.codex/generated_images/01a15208-6529-72b2-8644-15d4aa6153f6/exec-99896281-f97d-4001-ad10-58316555eace.png'),OUT/'Masters/garden-floor.png')
 shutil.copy2(art.BASE/'Masters/fountain.png',OUT/'Masters/fountain.png')
 floor=author('garden-floor',OUT/'Masters/garden-floor.png',[3072,1536],[0,1536],['Maintained lawns','Limestone promenades'])
 scale=409.6/970
 font=author('fountain',OUT/'Masters/fountain.png',[round(1536*scale),round(1024*scale)],[765*scale,804*scale],['Basin','Water','Spout'])
 d=read(OLD/'layout.json')
 oldfont=next(g for g in d['garden'] if g['id']=='court-fountain')
 oldfont.update(font,position=[182,200],polygon=ellipse([182,200],6.4,1.2))
 # Preserve the120 architectural planes and two original tree trunks exactly.
 d['physical']=[p for p in d['physical'] if p['id']!='court-fountain']
 d['physical'].append(dict(id='court-fountain',kind='garden',owner='court-fountain',polygon=oldfont['polygon']))
 positions=[[145,185],[145,213],[160,185],[208,185],[219,211],[220,223]]
 treeAssets=[g for g in d['garden'] if g['kind']=='tree']
 for i,pos in enumerate(positions):
  g=json.loads(json.dumps(treeAssets[i%2]));g.update(id='royal-oak-'+str(i),position=pos,polygon=ellipse(pos,.5,.5));d['garden'].append(g);d['physical'].append(dict(id=g['id'],kind='garden',owner=g['id'],polygon=g['polygon']))
 # New enclosure has a12u southern entrance; back notch avoids the barn lot.
 perimeter=[[133,175],[232,175],[232,253],[216,268],[163,268],[163,225],[133,225]]
 segments=[([133,175],[176,175]),([188,175],[232,175])]+list(zip(perimeter[1:],perimeter[2:]+[perimeter[0]]))
 walls=[]
 for side,(a,b) in enumerate(segments):
  count=math.ceil(math.dist(a,b)/9)
  for i in range(count):
   p=(np.array(a)+(np.array(b)-a)*i/count).tolist();r=(np.array(a)+(np.array(b)-a)*(i+1)/count).tolist();id=f'royal-wall-{side}-{i}';polygon=base.strip(p,r,1.5);walls.append(dict(id=id,a=p,b=r,polygon=polygon));d['physical'].append(dict(id=id,kind='royal-wall',owner=id,polygon=polygon))
 d['royalWalls']=walls;d['royalPrecinct']=dict(perimeter=perimeter,entrance=[182,175],floor=dict(**floor,position=[134,176],sizeUnits=[96,48]),fountainDiameterUnits=12.8,previousDiameterUnits=3.2,renderScale=1,source='New enlarged native raster, not Transform scaling')
 for i,p in enumerate([[150,189],[153,190],[156,191],[150,207],[153,208],[156,209],[206,190],[209,191],[212,192],[207,208],[210,209],[213,210],[170,185],[172,185],[194,185],[196,185],[171,217],[173,218],[197,217],[199,218]]):d['flowers'].append(dict(id='royal-flower-'+str(i),position=p))
 keep={'entry','castle-court'}
 d['targets']=[t for t in d['targets'] if t['id'] in keep]
 for id,p in [('royal-entry',[182,180]),('fountain-west',[173,200]),('fountain-north',[182,205]),('fountain-east',[191,200]),('fountain-south',[182,195]),('west-lawns',[142,205]),('east-lawns',[224,205])]:d['targets'].append(dict(id=id,point=p))
 d['revision']='RoyalGardensV1: expanded royal enclosure, native12.8u fountain, maintained96x48u garden floor; preserved original120 architecture planes'
 opened=base.nav(d)[1];closed=base.nav(d,True)[1];assert opened['allConnected'],opened;assert not any(closed['targets'].values()),closed
 write(OUT/'layout.json',d);write(OUT/'navigation-proof.json',dict(open=opened,closed=closed))
 # The old compact keep enclosure stays as the rear palace, inside a large precinct.
 finalize()

def finalize():
 if (OUT/'manifest.json').exists():raise FileExistsError('Completed destination')
 d=read(OUT/'layout.json');perimeter=d['royalPrecinct']['perimeter'];walls=d['royalWalls']
 from scipy.spatial import ConvexHull
 oldpoints=[p for x in read(OLD/'layout.json')['physical'] if (x.get('owner') or '').startswith('castle-compound/') for p in x['polygon']]
 oldBounds=float(ConvexHull(oldpoints).volume)
 area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(perimeter,perimeter[1:]+perimeter[:1])))/2
 write(OUT/'dimensions.json',dict(newEnclosedArea=area,oldKeepFootprintHullArea=oldBounds,areaRatio=area/oldBounds,formalGardenFloorArea=96*48,oldFountainDiameter=3.2,newFountainDiameter=12.8,fountainDiameterRatio=4,physical=len(d['physical']),newWallSegments=len(walls),oldArchitectureUnchanged=d['physical'][:120]==read(OLD/'layout.json')['physical'][:120],treeCount=sum(g['kind']=='tree' for g in d['garden']),flowerPatches=len(d['flowers'])))
 write(OUT/'manifest.json',dict(generatorSHA256=sha(__file__),baseLayoutSHA256=sha(OLD/'layout.json'),files={p.relative_to(OUT).as_posix():sha(p) for p in OUT.rglob('*') if p.is_file()}))
 print(json.dumps(read(OUT/'dimensions.json')))

if __name__=='__main__':
 import sys
 if len(sys.argv)>1 and sys.argv[1]=='finalize':finalize()
 else:build()
