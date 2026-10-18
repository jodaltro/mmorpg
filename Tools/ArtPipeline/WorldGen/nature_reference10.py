"""Small authored nature study. Paint authority is Aseprite, not the initial author.

AI masters are retained as provenance. Export and composition are deterministic;
AI painting itself is not claimed reproducible. Original world producers are read-only.
"""
import argparse,copy,json,math,shutil,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import distance_transform_edt
import world_hydrology as common
import environment_architecture as arch
import architecture07r_reference as ref
import terrain_materials as mat
import material_refinement as finish

ROOT=common.ROOT;BASE=ROOT/'ArtSource/Labs/World2026/Nature10';DOC=ROOT/'Docs/Validation/ValdoriaNature10'
VERSION='valdoria-authored-nature/1.0.0'
GENERATED=Path('C:/Users/Administrator/.codex/generated_images/01a14b5b-0ccf-7062-aba5-78b8e4e46efb')
ASSETS={
 'oak-reference':{'master':'exec-dcfb5697-a821-4cb0-b808-3ed798a5dbd3.png','canvas':[448,448],'fitHeight':400,'anchorMaster':[615,1244],'kind':'tree','physicalRadius':.5},
 'oak-forked':{'master':'exec-73e62aa4-92cd-469f-b706-ec9cc4c948cc.png','canvas':[448,448],'fitHeight':400,'anchorMaster':[648,1240],'kind':'tree','physicalRadius':.5},
 'fieldstone':{'master':'exec-95673dd7-1b24-40e6-8ba4-fca8fab505d3.png','canvas':[256,192],'fitWidth':208,'anchorMaster':[760,850],'kind':'rock','footprintPixels':[[-88,-8],[-63,-26],[5,-27],[77,-10],[89,4],[52,17],[-18,20],[-70,9]]},
 'broken-slab':{'master':'exec-2f5d4c87-1d33-4a36-b834-0da3d1e6bbdb.png','canvas':[192,128],'fitWidth':144,'anchorMaster':[857,760],'kind':'rock','footprintPixels':[[-66,-7],[-47,-17],[19,-12],[65,-1],[44,8],[-33,7]]}}

def write(p,v):Path(p).parent.mkdir(parents=True,exist_ok=True);common.write(p,v)
def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def q(p):return json.dumps(str(p).replace('\\','/'))
def lua(code,path):
 path.write_text(code,encoding='utf8',newline='\n');subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script',str(path)],check=True)
def manifest(folder,inputs):
 write(folder/'manifest.json',{'schema':'valdoria-nature-build/v1','version':VERSION,'inputs':inputs,'files':{p.name:common.sha(p.read_bytes()) for p in sorted(folder.iterdir()) if p.is_file() and p.name!='manifest.json'}})

def outside_distance(poly,x,y):
 d=np.full(x.shape,np.inf)
 for a,b in zip(poly,poly[1:]+poly[:1]):
  dx,dy=b[0]-a[0],b[1]-a[1];t=np.clip(((x-a[0])*dx+(y-a[1])*dy)/max(1e-20,dx*dx+dy*dy),0,1);d=np.minimum(d,np.hypot(x-a[0]-t*dx,y-a[1]-t*dy))
 return np.where(arch.inside(poly,x,y),0,d)

def author():
 out=common.refuse(BASE/'SourceV2');out.mkdir(parents=True);masters=BASE/'Masters';masters.mkdir(exist_ok=True)
 records=[];code=''
 for id,spec in ASSETS.items():
  src=GENERATED/spec['master'];target=masters/(id+'.png');shutil.copy2(src,target);W,H=Image.open(target).size
  factor=spec.get('fitHeight',0)/H if 'fitHeight' in spec else spec['fitWidth']/W
  nw,nh=round(W*factor),round(H*factor);cw,ch=spec['canvas'];ox,oy=(cw-nw)//2,16;anchor=[round(spec['anchorMaster'][0]*nw/W+ox),round(spec['anchorMaster'][1]*nh/H+oy)]
  names=['Ground shadow','Root and trunk','Structural branches','Canopy recesses','Foliage volumes','Leaf accents'] if spec['kind']=='tree' else ['Ground shadow','Front planes','Upper planes','Right planes','Basal moss','Fracture accents']
  record=dict(spec,id=id,sourceFile=id+'.aseprite',groundAnchorPixels=anchor,ppu=32,nativeRaster=[nw,nh],nativeOffset=[ox,oy],layers=names,master=arch.ref(target),artisticStatus='candidate pending user visual review',layersAreExteriorOwnershipNotHiddenFaces=True)
  records.append(record)
  code+=f'\ndo local input=app.open({q(target)});app.command.SpriteSize{{ui=false,width={nw},height={nh},method="nearest"}};'
  code+='local raw=input.cels[1].image;for y=0,raw.height-1 do for x=0,raw.width-1 do local c=raw:getPixel(x,y);local r,g,b,a=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),app.pixelColor.rgbaA(c);if x==0 or y==0 or x==raw.width-1 or y==raw.height-1 or a<150 or (r>g*1.85 and r>b*1.7 and g<85) then raw:drawPixel(x,y,0) elseif a<255 then raw:drawPixel(x,y,app.pixelColor.rgba(r,g,b,255)) end end end;'
  code+='app.command.ColorQuantization{ui=false,maxColors=144,withAlpha=true,algorithm="octree"};app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"};app.command.ChangePixelFormat{ui=false,format="rgb"};local paint=input.cels[1].image;'
  code+=f'local s=Sprite({cw},{ch},ColorMode.RGB);s.layers[1].name="Temporary";local layers={{}};local images={{}};'
  for name in names:code+=f'local l=s:newLayer();l.name={json.dumps(name)};table.insert(layers,l);table.insert(images,Image({cw},{ch},ColorMode.RGB));'
  code+=f'for y=0,{nh-1} do for x=0,{nw-1} do local c=paint:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local r,g,b=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c);local Y=y/{nh};local X=x/{nw};local part=2;'
  if spec['kind']=='tree':
   code+='if Y>.71 then part=2 elseif r>g*1.06 and r>b*1.23 then part=3 elseif (r+g+b)/3<80 then part=4 elseif g>150 and r>110 then part=6 else part=5 end;'
  else:
   code+='if Y<.44 and X<.79 then part=3 elseif X>.75 then part=4 elseif Y>.62 and g>r*.91 and b<g*.73 then part=5 elseif (r+g+b)/3>187 then part=6 else part=2 end;'
  code+=f'images[part]:drawPixel(x+{ox},y+{oy},c) end end end;'
  # Deliberate translucent cast/contact shape, independently editable from body.
  ax,ay=anchor;rx=110 if spec['kind']=='tree' else spec.get('fitWidth',160)*.42;ry=22 if spec['kind']=='tree' else 10
  if spec['kind']=='tree':
   code+=f'for y=0,math.floor({nh}*.72) do for x=0,{nw-1} do if app.pixelColor.rgbaA(paint:getPixel(x,y))>0 then local sx=math.floor({ax}+(x+{ox}-{ax})*.70+({ay}-y-{oy})*.07);local sy=math.floor({ay}+(x+{ox}-{ax})*.035+({ay}-y-{oy})*.075);if sx>=0 and sy>=0 and sx<{cw} and sy<{ch} then images[1]:drawPixel(sx,sy,app.pixelColor.rgba(29,36,23,25)) end end end end;'
  else:code+=f'for y=0,{ch-1} do for x=0,{cw-1} do local u=(x-{ax}-8)/{rx};local v=(y-{ay}-5)/{ry};local d=u*u+v*v;if d<1 then local a=d<.35 and 36 or d<.72 and 25 or 13;images[1]:drawPixel(x,y,app.pixelColor.rgba(29,36,23,a)) end end end;'
  code+=f'for i=1,#layers do s:newCel(layers[i],1,images[i],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs({q(out/(id+".aseprite"))});s:close();input:close() end\n'
 write(out/'source.json',{'schema':'valdoria-authored-nature-source/v1','version':VERSION,'assets':records,'light':'upper-left warm, cool recesses','license':'Original project AI-assisted paint and Aseprite interpretation; original masters and prompts retained','sourceAuthority':'Aseprite RGBA layers; normal export never regenerates paint'})
 lua(code,out/'initial-authoring.lua')
 # Small pixel brushes, explicitly authored as 6 shape variants, not noise.
 author_brushes(out)
 write(BASE/'recipe.json',{'schema':'valdoria-nature-composition/v1','version':VERSION,'seed':910210,'regionSize':[64,48],'treeReplacements':[{'instance':'A/oak/26/00026','asset':'oak-reference','point':[14.5,41.65625],'beforeRadius':.3,'afterRadius':.5},{'instance':'A/elm/15/00015','asset':'oak-forked','point':[10.46875,39.125],'beforeRadius':.4,'afterRadius':.5}],'rocks':[{'id':'reference-boulder','asset':'fieldstone','point':[10.5,44.6]},{'id':'broken-slab-01','asset':'broken-slab','point':[16.0,45.5]},{'id':'broken-slab-02','asset':'broken-slab','point':[49,45]}],'surfacePalette':{'grass':['#273f29','#38532e','#4c6833','#607b3b','#7f954d','#a1ac68'],'dirt':['#5f4a34','#795a3e','#98764e','#b39669','#c5ad85','#dfc89c'],'rock':['#3a403d','#535b55','#797a68','#aaa088','#c4b795','#e0ceaa'],'road':['#69533c','#806444','#997d53','#b39768','#c8af80','#dec59a']},'physicalChange':'Only two study trunks (.3/.4 -> .5u radius) and three declared rock footprints. Terrain, water, road, building and other plants unchanged.'})

def author_brushes(p):
 code='local s=Sprite(192,96,ColorMode.RGB);s.layers[1].name="Contact shadow";local names={"Leaf and soil masses","Lit blade edges","Small stone planes"};for _,n in ipairs(names) do local l=s:newLayer();l.name=n end;local images={Image(s.spec),Image(s.spec),Image(s.spec),Image(s.spec)};'
 # Explicit blade rhythm with negative spaces and highlights; no random sprinkling.
 shapes=[[(7,21,5,14),(10,22,12,12),(14,22,19,16)],[(5,21,8,12),(9,23,14,15),(16,22,23,18)],[(9,22,6,17),(11,21,13,13),(15,23,21,15)],[(5,22,8,17),(12,22,11,12),(17,23,24,17)],[(9,22,4,16),(14,23,17,14)],[(6,22,11,15),(15,22,20,16),(21,23,25,20)]]
 for j,blades in enumerate(shapes):
  for ax,ay,bx,by in blades:
   code+=f'do local ax,ay,bx,by={j*32+ax},{ay},{j*32+bx},{by};for k=0,7 do local t=k/7;local x=math.floor(ax+(bx-ax)*t);local y=math.floor(ay+(by-ay)*t);images[2]:drawPixel(x,y,app.pixelColor.rgba(59,81,35,255));images[2]:drawPixel(x+1,y,app.pixelColor.rgba(77,103,43,255));if k>3 then images[3]:drawPixel(x-1,y,app.pixelColor.rgba(129,147,72,255)) end end end;'
  for dx,dy in [(9,48),(15,51),(21,46)]:
   x=j*32+dx;y=dy;code+=f'images[4]:drawPixel({x},{y},app.pixelColor.rgba(164,153,122,255));images[4]:drawPixel({x+1},{y},app.pixelColor.rgba(186,175,141,255));images[4]:drawPixel({x},{y+1},app.pixelColor.rgba(91,91,73,255));'
  for dx,dy in [(7,77),(9,78),(13,81),(18,76),(22,79)]:code+=f'images[2]:drawPixel({j*32+dx},{dy},app.pixelColor.rgba(128,101,64,255));images[3]:drawPixel({j*32+dx},{dy-1},app.pixelColor.rgba(174,148,97,255));'
 code+='for i=1,#s.layers do s:newCel(s.layers[i],1,images[i],Point(0,0)) end;'
 code+=f's:saveAs({q(p/"ground-brushes.aseprite")});s:close()'
 lua(code,p/'initial-brushes.lua')

def export(output,source=None):
 source=Path(source) if source else BASE/'SourceV2';out=common.refuse(output);out.mkdir(parents=True);meta=read(source/'source.json');items=[];code=''
 for item in meta['assets']:
  id=item['id'];code+=f'do local s=app.open({q(source/item["sourceFile"])});assert(s.width=={item["canvas"][0]} and s.height=={item["canvas"][1]} and #s.layers==6 and #s.frames==1,"Source contract");'
  groups=[('shadow',[1]),('trunk',[2,3]),('crown',[4,5,6])] if item['kind']=='tree' else [('shadow',[1]),('body',[2,3,4,5,6])]
  for part,indices in groups:
   code+='for _,l in ipairs(s.layers) do l.isVisible=false end;'
   for i in indices:code+=f's.layers[{i}].isVisible=true;'
   code+=f'local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({q(out/(id+"-"+part+".png"))});'
   items.append({'id':id+'-'+part,'asset':id,'part':part,'file':id+'-'+part+'.png','anchorPixels':item['groundAnchorPixels']})
  code+=f'for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({q(out/(id+"-composite.png"))});s:close() end\n'
 code+=f'local s=app.open({q(source/"ground-brushes.aseprite")});local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({q(out/"ground-brushes.png")});s:close()'
 lua(code,out/'export.lua')
 for v in range(6):
  p={'id':'grass-contact-v'+str(v),'asset':'ground-brushes','part':'contact','file':'grass-contact-v'+str(v)+'.png','anchorPixels':[16,24]}
  Image.open(out/'ground-brushes.png').crop((v*32,0,v*32+32,32)).save(out/p['file']);items.append(p)
 atlas=Image.new('RGBA',(1024,1024));x=y=row=0
 for p in items:
  im=Image.open(out/p['file']).convert('RGBA');rect=im.getbbox();trim=im.crop(rect);w,h=trim.size
  if x+w+4>1024:y+=row;x=0;row=0
  if y+h+4>1024:raise ValueError('Explicit new atlas page required')
  atlas.paste(trim,(x+2,y+2));p.update(rectPixels=[x+2,y+2,w,h],offsetUnits=[(rect[0]-p['anchorPixels'][0])/32,(p['anchorPixels'][1]-rect[3])/32],sourceRect=list(rect));x+=w+4;row=max(row,h+4)
 atlas.save(out/'nature-atlas.png');write(out/'sprites.json',{'schema':'valdoria-nature-sprites/v1','atlasSize':[1024,1024],'ppu':32,'sprites':items,'assets':meta['assets']});manifest(out,{p.name:arch.ref(p) for p in list(source.glob('*.aseprite'))+[source/'source.json']});return items

def compose(output,exported=None,bounds=None):
 out=common.refuse(output);out.mkdir(parents=True);exported=Path(exported) if exported else BASE/'ExportV3';arch.verify_files(exported);r=read(BASE/'recipe.json');old=read(ROOT/'ArtSource/Labs/World2026/WorldStudio09/Recipes/terrain-A.json');ramp=copy.deepcopy(old);ramp['palette'].update(r['surfacePalette']);seed=r['seed']
 ctx=mat.Context(library_dir=ROOT/'ArtSource/Labs/World2026/WorldStudio09/Terrain/Library');W,H=2048,1536
 bounds=bounds or [0,0,W,H];x0,y0,w,h=bounds;y,x=np.mgrid[y0:y0+h,x0:x0+w]
 wet=ctx.sample(ctx.layers['moistureMilli'],x,y)/1000;rock=ctx.sample(ctx.rock,x,y);cov=ctx.masks['coverage'][y0:y0+h,x0:x0+w]/255
 # Low-amplitude pigment masses. Shape comes from authored brushes / semantics,
 # never an independent grid per cell or screen chunk.
 tone=2.28+(mat.field(x,y,181,seed)-.5)*.70+(mat.field(x,y,59,seed+3)-.5)*.32+(wet-.5)*.25
 # Continuous pigment, avoiding contour bands which read as polygon islands.
 base=finish.ramp(ramp,'grass',tone);Image.fromarray(base).save(out/'base.png')
 road=finish.ramp(ramp,'road',2.25+(mat.field(x,y,137,seed+7)-.5)*.45+(mat.field(x,y,21,seed+8)-.5)*.14)
 shoulder=ctx.masks['shoulders'][y0:y0+h,x0:x0+w]/255
 soil=finish.ramp(ramp,'dirt',2.2+(mat.field(x,y,71,seed+13)-.5)*.15)
 blend=(shoulder*(1-cov)*.28)[...,None];trans=np.rint(base*(1-blend)+soil*blend).astype('uint8');trans=np.rint(trans*(1-cov[...,None])+road*cov[...,None]).astype('uint8')
 # Same rock domain and world-space UV. Stronger coherent mineral planes, not
 # another boulder silhouette or an interpretation of pixels as collision.
 structure,joints=finish.rock_structure(x,y,seed);plane=(mat.field(x*.8+y*.25,y,109,seed+19)-.5)*.55
 stone=finish.ramp(ramp,'rock',2.65+plane);stone[:,:,:3]=np.clip(stone[:,:,:3].astype(float)+structure[...,None]*1.55,0,255).astype('uint8')
 ra=np.clip((rock+.10)/.20,0,1)[...,None];trans=np.rint(trans*(1-ra)+stone*ra).astype('uint8');trans[:,:,3]=255
 # Contact pigment follows declared ground footprints, not the crown rectangle.
 worldx=x/32;worldy=y/32;exposure=np.zeros(x.shape)
 for p in r['treeReplacements']:
  dx=worldx-p['point'][0];dy=worldy-p['point'][1];d=np.sqrt((dx/1.15)**2+(dy/.65)**2);shape=(mat.field(x,y,17,seed+101)-.5)*.32;exposure=np.maximum(exposure,np.clip((1.1-d+shape)*.38,0,.30))
 house=read(ref.SOURCE.parent/'RegionV1/house.json');dist=outside_distance(house['footprint'],worldx,worldy)
 exposure=np.maximum(exposure,np.clip((.38-dist)/.38,0,1)*.22*(mat.field(x,y,11,seed+107)>.34))
 for p in r['rocks']:
  a=next(v for v in read(BASE/'SourceV2/source.json')['assets'] if v['id']==p['asset']);poly=(np.array(a['footprintPixels'])/32+np.array(p['point'])).tolist();d=outside_distance(poly,worldx,worldy);exposure=np.maximum(exposure,np.clip((.40-d)/.40,0,1)*.30)
 exposure=np.rint(exposure*12)/12;exposure*=1-cov;exposure*=rock<0
 trans=np.rint(trans*(1-exposure[...,None])+soil*exposure[...,None]).astype('uint8')
 Image.fromarray(trans).save(out/'transitions.png');final=Image.fromarray(trans)
 brushes=Image.open(exported/'ground-brushes.png').convert('RGBA');overlay=Image.new('RGBA',(w,h))
 # Seeded parents, variable children; translation only, source light preserved.
 for py in range(-1,H//144+2):
  for px in range(-1,W//144+2):
   cx=(px+float(mat.ihash(px,py,seed+31)))*144;cy=(py+float(mat.ihash(px,py,seed+37)))*144
   for n in range(5+int(mat.ihash(px,py,seed+41)*10)):
    xx=int(cx+(mat.ihash(px,n+py*53,seed+43)-.5)*82);yy=int(cy+(mat.ihash(py,n+px*71,seed+47)-.5)*70)
    if not 0<=xx<W or not 0<=yy<H or not x0-32<=xx<x0+w+32 or not y0-32<=yy<y0+h+32:continue
    if float(ctx.sample(ctx.rock,np.array(xx),np.array(yy)))>-.12:continue
    v=int(mat.ihash(px+n,py,seed+53)*6)%6
    row=2 if ctx.masks['coverage'][yy,xx]>180 else 0
    if 30<ctx.masks['coverage'][yy,xx]<=180:continue
    stamp=brushes.crop((v*32,row*32,v*32+32,row*32+32));overlay.alpha_composite(stamp,(xx-x0-16,yy-y0-24))
 final=Image.alpha_composite(final,overlay);final.save(out/'final.png')
 # Cliff pigment uses the same families; UVs/vertex lighting remain authored04.
 cliff=finish.cliff_texture(ramp,[W,H]).crop((x0,y0,x0+w,y0+h));cliff.save(out/'cliff.png')
 compose_access(out,brushes,ramp,r)
 # Contacts are small local overlays, independently editable brushes and source
 # footprints; no wide decal can disguise a boundary/collision discrepancy.
 inputs={'recipe':arch.ref(BASE/'recipe.json'),'sourceExport':arch.ref(exported/'manifest.json'),'world':arch.ref(mat.BASE),'road':arch.ref(Path(mat.ROAD)/'road.json'),'house':arch.ref(ref.SOURCE.parent/'RegionV1/house.json')}
 write(out/'composition.json',{'schema':'valdoria-nature-material-composition/v1','version':VERSION,'seed':seed,'boundsPixels':bounds,'sizePixels':[W,H],'geometryChanged':False,'stageNames':['base','transitions','final'],'inputs':inputs});manifest(out,inputs)

def compose_access(out,brushes,ramp,r):
 p=ref.SOURCE.parent/'RegionV1';meta=read(p/'access-render.json');old=Image.open(p/'access.png').convert('RGBA');mask=np.array(old)[:,:,3];rect=meta['rectPixels'];h,w=mask.shape;yy,xx=np.mgrid[rect[1]:rect[1]+h,rect[0]:rect[0]+w]
 colour=finish.ramp(ramp,'road',2.15+(mat.field(xx,yy,59,r['seed']+73)-.5)*.48+(mat.field(xx,yy,13,r['seed']+74)-.5)*.13)
 # 1-3px broken appearance fringe, same centerline and walk clearance.
 distance=distance_transform_edt(mask>0);edge=(mask>0)&(mat.field(xx,yy,9,r['seed']+79)>.60)&(distance<2.5);colour[:,:,3]=np.where(edge,160,mask)
 image=Image.fromarray(colour);overlay=Image.new('RGBA',image.size)
 for y in range(4,h-4,9):
  for x in range(4,w-4,11):
   if 0<distance[y,x]<5 and mat.ihash(x,y,r['seed']+83)>.72:
    v=int(mat.ihash(x,y,r['seed']+89)*6)%6;stamp=brushes.crop((v*32,0,v*32+32,32));overlay.alpha_composite(stamp,(x-16,y-23))
   elif distance[y,x]>6 and mat.ihash(x,y,r['seed']+91)>.82:
    v=int(mat.ihash(x,y,r['seed']+93)*6)%6;stamp=brushes.crop((v*32,64,v*32+32,96));overlay.alpha_composite(stamp,(x-16,y-24))
 image=Image.alpha_composite(image,overlay);image.save(out/'access.png');write(out/'access-render.json',meta)

def placement(output):
 out=common.refuse(output);out.mkdir(parents=True);r=read(BASE/'recipe.json');meta=read(BASE/'SourceV2/source.json');assets={a['id']:a for a in meta['assets']};parent=ref.SOURCE.parent/'RegionV1';old=read(parent/'navigation.json');base=np.array(old['walkable']).reshape(192,256);after=base.copy();plants=read(parent/'vegetation.json')['instances'];yy,xx=np.mgrid[.125:48:.25,.125:64:.25]
 # Rebuild only the vegetation occupancy over the unchanged architecture+water
 # mask so original small trunk occupancy can be replaced, not merely unioned.
 ctx=ref.veg.Context();building=read(parent/'house.json');after=ctx.baseWalk&~arch.inside(building['footprint'],xx,yy)
 changes={v['instance']:v for v in r['treeReplacements']}
 byid={p['id']:p for p in plants}
 if len(changes)!=len(r['treeReplacements']):raise ValueError('Duplicate replacement ID')
 for id,change in changes.items():
  if id not in byid:raise ValueError('Unknown ecological instance '+id)
  original=byid[id];asset=assets[change['asset']]
  if original['point']!=change['point'] or original['footprintRadius']!=change['beforeRadius'] or asset['physicalRadius']!=change['afterRadius']:raise ValueError('Replacement anchor/radius contract mismatch '+id)
  d2=(xx-original['point'][0])**2+(yy-original['point'][1])**2
  if np.any((d2<=change['afterRadius']**2)&(d2>change['beforeRadius']**2)&~base):raise ValueError('Expanded trunk overlaps previous blocked ground '+id)
 for p in plants:
  radius=changes[p['id']]['afterRadius'] if p['id'] in changes else p['footprintRadius']
  if radius:after&=~((xx-p['point'][0])**2+(yy-p['point'][1])**2<=radius**2)
 footprints=[]
 for prop in r['rocks']:
  a=assets[prop['asset']];poly=(np.array(a['footprintPixels'])/32+np.array(prop['point'])).tolist();occupied=arch.inside(poly,xx,yy)
  if np.any(occupied&~base):raise ValueError('New boulder overlaps existing blocked ground '+prop['id'])
  samples=[ctx.sample(float(x),float(y)) for x,y in zip(xx[occupied],yy[occupied])]
  if not samples or any(s['surfaceWater'] or s['solid'] or s['reserved'] or s['roadDistance']<.7 for s in samples):raise ValueError('Boulder violates water/rock/reserve/road clearance '+prop['id'])
  after&=~occupied;footprints.append(dict(prop,footprint=poly,siteQA={'minimumRoadDistance':min(s['roadDistance'] for s in samples),'minimumWaterDistance':min(s['waterDistance'] for s in samples)}))
 clearance=distance_transform_edt(after)*.25
 if any(clearance[int(y*4),int(x*4)]<.57 for x,y in building['access']['points']):raise ValueError('Nature study blocks approved entrance access')
 write(out/'navigation-before.json',dict(old));write(out/'navigation-after.json',dict(old,walkable=after.ravel().tolist(),natureStudyOnly=True));write(out/'placement.json',dict(r,rocks=footprints,beforePlants=len(plants),ecologicalPositionsChanged=False));manifest(out,{'recipe':arch.ref(BASE/'recipe.json'),'library':arch.ref(BASE/'ExportV3/manifest.json'),'sourceMetadata':arch.ref(BASE/'SourceV2/source.json'),'baseNavigation':arch.ref(parent/'navigation.json')})

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['author','export','compose','placement']);p.add_argument('--source');p.add_argument('--output');p.add_argument('--bounds',type=json.loads);a=p.parse_args()
 if a.command=='author':author()
 elif a.command=='export':export(a.output,a.source)
 elif a.command=='compose':compose(a.output,bounds=a.bounds)
 else:placement(a.output)
