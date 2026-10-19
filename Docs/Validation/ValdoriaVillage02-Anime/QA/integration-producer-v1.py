"""Compile anime-painted facades and an explicitly placed private garden."""
from pathlib import Path
import copy,json,math
from PIL import Image
import village02_anime_art as art
import village02_integration as base
import architecture07r_reference as reference

ROOT=art.ROOT;BASE=art.BASE;EXPORT=BASE/'ExportV2';SOURCE=BASE/'SourceV2';OUT=BASE/'IntegrationV1'
read=art.read;write=art.write;sha=art.sha;q=art.q

def garden():
 import shutil
 src=BASE/'GardenSourceV1';out=BASE/'GardenExportV1'
 if src.exists() or out.exists():raise FileExistsError('New garden authoring destinations required')
 src.mkdir();out.mkdir();raw=BASE/'Masters/daisies.png';shutil.copy2(art.GENERATED/'exec-346778d9-9764-443b-9d08-12da7f2e84e8.png',raw)
 folder=src/'daisies';folder.mkdir();w,h=Image.open(raw).size
 lua='local input=Sprite{fromFile='+q(raw)+',oneFrame=true};app.activeSprite=input;assert(input.width=='+str(w)+' and input.height=='+str(h)+');local im=input.cels[1].image;for y=0,im.height-1 do for x=0,im.width-1 do local c=im:getPixel(x,y);if app.pixelColor.rgbaA(c)<250 then im:drawPixel(x,y,0) else im:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;app.command.SpriteSize{ui=false,width=64,height=48,method="nearest"};app.command.ColorQuantization{ui=false,maxColors=96,withAlpha=true,algorithm="octree"};app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"};app.command.ChangePixelFormat{ui=false,format="rgb"};local pixels=Image(input.spec);pixels:drawSprite(input,1);for y=0,47 do for x=0,63 do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then pixels:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;pixels:saveAs('+q(folder/'native-authority.png')+');local s=Sprite(64,48,ColorMode.RGB);local a=Image(s.spec);local b=Image(s.spec);for y=0,47 do for x=0,63 do if y<29 then a:drawPixel(x,y,pixels:getPixel(x,y)) else b:drawPixel(x,y,pixels:getPixel(x,y)) end end end;s.layers[1].name="Blossoms";s:newCel(s.layers[1],1,a);local l=s:newLayer();l.name="Foliage";s:newCel(l,1,b);s:saveAs('+q(folder/'daisies.aseprite')+');s:close();input:close();'
 art.old.run_lua(lua,folder/'bootstrap.lua')
 write(folder/'house-source.json',dict(schema='valdoria-authored-house/v1',id='daisies',sourceFile='daisies.aseprite',canvas=[64,48],ppu=32,groundAnchorPixels=[32,42],layers=['Blossoms','Foliage'],roles={'Blossoms':'wall','Foliage':'wall'},master={'path':raw.relative_to(ROOT).as_posix(),'sha256':sha(raw),'size':[w,h]},doorHeightUnits=None,spanUnits=2,physical='Non-solid low flowers; do not block paths',authority='Aseprite pixels',artisticStatus='candidate'))
 reference.export(folder,out/'daisies')
 assert Image.open(folder/'native-authority.png').tobytes()==Image.open(out/'daisies/composite.png').tobytes()
 write(out/'manifest.json',{'files':{p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}})

def ellipse(pos,rx,ry,n=20):return [[pos[0]+rx*math.cos(i*math.tau/n),pos[1]+ry*math.sin(i*math.tau/n)] for i in range(n)]

def build():
 if OUT.exists():raise FileExistsError(OUT)
 OUT.mkdir();depth=OUT/'DepthArt';depth.mkdir();d=copy.deepcopy(read(base.BASE/'IntegrationV2/layout.json'));reg=read(BASE/'registration.json')
 for b in d['buildings']:
  id=b['id'];b['composite']=(EXPORT/id/'composite.png').relative_to(ROOT).as_posix();px,py,_,_=reg[id]['padding'];b['anchorPixels']=[b['anchorPixels'][0]+px,b['anchorPixels'][1]+py];b['canvas']=read(SOURCE/id/'house-source.json')['canvas']
 for piece in d['pieces']:
  id=piece['id'];folder=depth/id;folder.mkdir();src=base.BASE/('IntegrationV1' if id=='bridge' else 'IntegrationV2')/'DepthArt'/id;provenance=read(src/'provenance.json');px,py,_,_=reg[id]['padding'];w,h=read(SOURCE/id/'house-source.json')['canvas'];piece['anchorPixels']=[piece['anchorPixels'][0]+px,piece['anchorPixels'][1]+py];piece['canvas']=[w,h]
  # Translate explicit semantic ownership, not visual silhouettes into colliders.
  owner=Image.new('RGB',(w,h),(1,0,0));owner.paste(Image.open(src/'ownership.png'),(px,py));owner.save(folder/'ownership.png');names=[p['id'] for p in piece['parts']]
  lua='local input=app.open('+q(SOURCE/id/(id+'.aseprite'))+');local pixels=Image(input.spec);pixels:drawSprite(input,1);local mask=app.open('+q(folder/'ownership.png')+');local owner=mask.cels[1].image;local s=Sprite('+str(w)+','+str(h)+',ColorMode.RGB);local imgs={};local ls={};'
  for name in names:lua+='do local l=s:newLayer();l.name='+json.dumps(name)+';table.insert(ls,l);table.insert(imgs,Image(s.spec)) end;'
  lua+='for y=0,s.height-1 do for x=0,s.width-1 do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local k=app.pixelColor.rgbaR(owner:getPixel(x,y));imgs[k]:drawPixel(x,y,c) end end end;'
  for k,name in enumerate(names):lua+=f's:newCel(ls[{k+1}],1,imgs[{k+1}]);imgs[{k+1}]:saveAs('+q(folder/(name+'.png'))+');'
  lua+='s:deleteLayer(s.layers[1]);s:saveAs('+q(folder/(id+'.aseprite'))+');s:close();mask:close();input:close();'
  art.old.run_lua(lua,folder/'partition.lua');combined=Image.new('RGBA',(w,h))
  for name in names:combined.alpha_composite(Image.open(folder/(name+'.png')))
  assert combined.tobytes()==Image.open(EXPORT/id/'composite.png').tobytes(),id
  write(folder/'provenance.json',dict(source=(SOURCE/id/(id+'.aseprite')).relative_to(ROOT).as_posix(),sourceSHA256=sha(SOURCE/id/(id+'.aseprite')),canvas=[w,h],parts=names,pixelIdenticalRecomposition=True,groundPlanesUnchanged=True,ownershipOrigin='Existing explicit ground/depth partition translated by canvas padding; visually reviewed in Play'))
  print('Partitioned',id,flush=True)
 nature=ROOT/'ArtSource/Labs/World2026/Nature10/ExportV3';natureData=read(nature/'sprites.json');assets={a['id']:a for a in natureData['assets']}
 d['garden']=[dict(id='court-fountain',kind='fountain',position=[192.8,235],composite=(EXPORT/'fountain/composite.png').relative_to(ROOT).as_posix(),canvas=read(SOURCE/'fountain/house-source.json')['canvas'],anchorPixels=read(SOURCE/'fountain/house-source.json')['groundAnchorPixels'],polygon=ellipse([192.8,235],1.6,.5))]
 for id,asset,pos in [('court-oak-west','oak-reference',[174,235]),('court-oak-east','oak-forked',[211,232.5])]:
  meta=assets[asset];d['garden'].append(dict(id=id,kind='tree',position=pos,composite=(nature/(asset+'-composite.png')).relative_to(ROOT).as_posix(),canvas=meta['canvas'],anchorPixels=meta['groundAnchorPixels'],polygon=ellipse(pos,meta['physicalRadius'],meta['physicalRadius']),provenance={'spritesSHA256':sha(nature/'sprites.json'),'compositeSHA256':sha(nature/(asset+'-composite.png'))}))
 for item in d['garden']:d['physical'].append(dict(id=item['id'],kind='garden',owner=item['id'],polygon=item['polygon']))
 flowerPositions=[[190.0,234.1],[195.5,234.1],[190,236.5],[195.5,236.5],[171.2,227.0],[172.5,228.2],[173.8,229.4],[208.8,225.5],[210.2,226.5],[211.4,227.5],[175.6,236.1],[172.5,234.0],[209.5,233.5],[212,233.2]]
 d['flowers']=[dict(id='court-daisies-'+str(i),position=p) for i,p in enumerate(flowerPositions)]
 d['flowerAsset']={'composite':(BASE/'GardenExportV1/daisies/composite.png').relative_to(ROOT).as_posix(),'canvas':[64,48],'anchorPixels':[32,42]}
 d['revision']='Anime-directed art; original120 solid planes retained, three explicitly authored garden solids added; flowers non-solid'
 assert d['physical'][:120]==read(base.BASE/'IntegrationV2/layout.json')['physical']
 _,opened=base.nav(d);_,closed=base.nav(d,True);assert opened['allConnected'],opened;assert not any(closed['targets'].values())
 write(OUT/'layout.json',d);write(OUT/'navigation-proof.json',dict(open=opened,closed=closed,original120PlanesUnchanged=True,gardenAdded=3))
 write(OUT/'manifest.json',dict(generatorSHA256=sha(__file__),artManifestSHA256=sha(EXPORT/'manifest.json'),gardenManifestSHA256=sha(BASE/'GardenExportV1/manifest.json'),baseLayoutSHA256=sha(base.BASE/'IntegrationV2/layout.json'),files={p.relative_to(OUT).as_posix():sha(p) for p in OUT.rglob('*') if p.is_file()}))

if __name__=='__main__':
 import sys
 if sys.argv[1]=='garden':garden()
 elif sys.argv[1]=='build':build()
