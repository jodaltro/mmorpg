"""Author a new anime-directed revision from retained AI paintings in Aseprite.

Registration measures silhouette alignment; it never derives physical obstacles.
World floor planes remain explicit annotations and require separate Unity QA.
"""
from pathlib import Path
import argparse,json,subprocess,hashlib,copy
import numpy as np
from PIL import Image
from scipy.ndimage import affine_transform
from scipy.optimize import minimize
import village02_art as old
import architecture07r_reference as ref

ROOT=old.ROOT;BASE=ROOT/'ArtSource/World/PlayableVillage02/AnimeRebuildV1'
OLD=old.BASE;ASE=old.ASE
FILES={
 'H1':'exec-0fe53510-219f-4fcd-9c0b-58547d682ed2.png',
 'H2':'exec-f7c7f772-d152-4543-a64a-395e3ddaee43.png',
 'H3':'exec-20d43725-ba50-4ed5-a87c-4a8abc19f60f.png',
 'H4':'exec-d3cb7a46-63b8-4779-a458-9a600a72ecbb.png',
 'H5':'exec-eb608047-40b5-453c-ace8-5a37e322fff4.png',
 'H6':'exec-56d99779-b41e-4d3d-9290-bb1798e3f8a3.png',
 'B1':'exec-d7ad8427-9aef-4c51-a550-a3fe344237ab.png',
 'castle-compound':'exec-ba2bf498-4056-4766-a2ff-63e493e2c254.png',
 'gate':'exec-5c18248a-bd64-4ac1-9ada-269ab4145169.png',
 'wall':'exec-7d9c51df-f4df-4369-b300-9e9414755c34.png',
 'corner':'exec-7479f07e-5dc7-4882-8e4a-b252fe20b664.png',
 'lowwall':'exec-fe70ac58-037f-4765-a9f1-1f9fc3e90a66.png',
 'bridge':'exec-e3c3cc4e-1e4f-4b0d-8bab-24a7115863cd.png',
 'fence':'exec-eedc130f-009a-4ebd-8d18-dd716ab8895f.png',
 'fountain':'exec-470f4251-1a7b-4286-a3d3-6567c948090a.png'}
GENERATED=Path('C:/Users/Administrator/.codex/generated_images/01a15208-6529-72b2-8644-15d4aa6153f6')
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def q(p):return json.dumps(str(Path(p).resolve()).replace('\\','/'))

def retain():
 import shutil
 dest=BASE/'Masters';dest.mkdir(exist_ok=False)
 for id,name in FILES.items():shutil.copy2(GENERATED/name,dest/(id+'.png'))
 write(dest/'provenance.json',{'tool':'built-in image_gen','files':{id:{'sourceFilename':name,'sha256':sha(dest/(id+'.png'))} for id,name in FILES.items()},'direction':'Release That Witch OFFICIAL ANIME only; poor neglected town / maintained bright castle','artisticApproval':False,'deterministicFromSeed':False})

def registration(id):
 master=BASE/'Masters'/f'{id}.png'
 if id=='fountain':return dict(scale=102.4/970,offset=[0,0],padding=[0,0,0,0],canvas=[round(1536*102.4/970),round(1024*102.4/970)],anchor=[765*102.4/970,730*102.4/970],note='Explicit painted basin diameter annotation 970 master pixels ->3.2u; no inferred collider')
 target=Image.open(OLD/'ExportV1'/id/'composite.png').convert('RGBA');source=Image.open(master).convert('RGBA')
 w,h=target.size;mw,mh=source.size;factor=4
 a=(np.array(target.getchannel('A'))[::factor,::factor]>249).astype(float)
 b=(np.array(source.getchannel('A'))[::factor,::factor]>249).astype(float)
 base=min(w/mw,h/mh);yy=np.arange(a.shape[0])[:,None];weights=np.where(yy>a.shape[0]*.55,4.,.3)
 def score(v):
  scale=base*v[0];dx,dy=v[1],v[2]
  projected=affine_transform(b,np.eye(2)/scale,offset=[-dy/scale,-dx/scale],output_shape=a.shape,order=0,mode='constant')>.5
  intersect=np.sum(weights*(projected&(a>.5)));union=np.sum(weights*(projected|(a>.5)))
  return 1-intersect/max(union,1)
 initial=[1,(w-mw*base)/factor/2,(h-mh*base)/factor/2]
 fit=minimize(score,initial,method='Powell',bounds=[(.8,1.2),(-w*.12/factor,w*.12/factor),(-h*.15/factor,h*.15/factor)],options={'maxiter':55,'xtol':.0005,'ftol':.00005})
 pad=[32,32,32,32] if id.startswith('H') or id=='B1' else [64,192,64,32] if id in ('castle-compound','gate') else [0,0,0,0]
 scale=base*fit.x[0];dx=round(fit.x[1]*factor);dy=round(fit.x[2]*factor)
 return dict(scale=float(scale),offset=[dx,dy],padding=pad,canvas=[w+pad[0]+pad[2],h+pad[1]+pad[3]],weightedLowerSilhouetteIoU=1-float(fit.fun),referenceCanvas=[w,h],note='Uniform nearest registration in Aseprite; mask comparison measures placement, not physical geometry')

def plan():
 p=BASE/'registration.json'
 if p.exists():raise FileExistsError(p)
 results={id:registration(id) for id in FILES};write(p,results)
 print(json.dumps({id:round(v.get('weightedLowerSilhouetteIoU',1),4) for id,v in results.items()}))

def author(out):
 if out.exists():raise FileExistsError(out)
 out.mkdir(parents=True);reg=read(BASE/'registration.json')
 for id in FILES:
  p=out/id;p.mkdir();r=reg[id];master=BASE/'Masters'/f'{id}.png';mw,mh=Image.open(master).size;nw,nh=round(mw*r['scale']),round(mh*r['scale']);w,h=r['canvas'];px,py,_,_=r['padding'];dx,dy=r['offset'];dx+=px;dy+=py
  if id=='fountain':
   names=['Basin','Water','Spout'];anchor=r['anchor'];meta=dict(schema='valdoria-authored-house/v1',id=id,ppu=32,doorHeightUnits=None,spanUnits=3.2,roles={'Basin':'wall','Water':'wall','Spout':'wall'})
   # Semantic separation of visible painted pixels; no hidden bowl reconstruction.
   ownerlua='for y=0,h-1 do for x=0,w-1 do local index=1;if y<h*0.65 and y>h*0.37 then index=2 elseif y<h*0.37 then index=3 end;owner:drawPixel(x,y,app.pixelColor.rgba(index,0,0,255)) end end;'
  else:
   meta=copy.deepcopy(read(OLD/'SourceV1'/id/'house-source.json'));names=meta['layers'];anchor=[meta['groundAnchorPixels'][0]+px,meta['groundAnchorPixels'][1]+py]
   ownerlua='local ms=app.open('+q(OLD/'SourceV1'/id/'ownership.png')+');owner:drawImage(ms.cels[1].image,Point('+str(px)+','+str(py)+'));ms:close();'
  # Numbered H1/H2/... PNGs must NOT be opened as an implicit animation.
  # Otherwise Aseprite expands the first frame to the sequence's maximum canvas,
  # and SpriteSize squashes that frame independently of the intended registration.
  lua='local input=Sprite{fromFile='+q(master)+',oneFrame=true};app.activeSprite=input;assert(#input.frames==1 and input.width=='+str(mw)+' and input.height=='+str(mh)+',"Single PNG canvas required");local im=input.cels[1].image;for y=0,im.height-1 do for x=0,im.width-1 do local c=im:getPixel(x,y);if app.pixelColor.rgbaA(c)<250 then im:drawPixel(x,y,0) else im:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;'
  lua+=f'app.command.SpriteSize{{ui=false,width={nw},height={nh},method="nearest"}};local s=Sprite({w},{h},ColorMode.RGB);s.layers[1].name="Painting";local pixels=Image(s.spec);local resized=Image(input.spec);resized:drawSprite(input,1);pixels:drawImage(resized,Point({dx},{dy}));s:newCel(s.layers[1],1,pixels,Point(0,0));app.activeSprite=s;'
  lua+='app.command.ColorQuantization{ui=false,maxColors=192,withAlpha=true,algorithm="octree"};app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"};app.command.ChangePixelFormat{ui=false,format="rgb"};pixels=Image(s.spec);pixels:drawSprite(s,1);for y=0,pixels.height-1 do for x=0,pixels.width-1 do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then pixels:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end;'
  lua+='pixels:saveAs('+q(p/'native-authority.png')+');local w=s.width;local h=s.height;local owner=Image(w,h,ColorMode.RGB);owner:clear(app.pixelColor.rgba(1,0,0,255));'+ownerlua+'owner:saveAs('+q(p/'ownership.png')+');local layers={};local imgs={};'
  for name in names:lua+='local l=s:newLayer();l.name='+json.dumps(name)+';table.insert(layers,l);table.insert(imgs,Image(w,h,ColorMode.RGB));'
  lua+='for y=0,h-1 do for x=0,w-1 do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local k=app.pixelColor.rgbaR(owner:getPixel(x,y));imgs[k]:drawPixel(x,y,c) end end end;for k=1,#layers do s:newCel(layers[k],1,imgs[k],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs('+q(p/(id+'.aseprite'))+');s:close();input:close();'
  old.run_lua(lua,p/'bootstrap.lua')
  meta.update(sourceFile=id+'.aseprite',canvas=[w,h],groundAnchorPixels=anchor,master={'path':master.relative_to(ROOT).as_posix(),'sha256':sha(master),'size':[mw,mh]},registration=r,layers=names,alphaOperation='Aseprite alpha<250 ->0, remaining ->255; no halo retained',paletteOperation='Aseprite octree<=192, no dithering',authority='Editable Aseprite; export reads pixels',worldReady=False,artisticStatus='candidate anime revision; not approved',normalizedBy='Uniform silhouette registration against known authored placement; final doorway/foundation reviewed in Unity')
  write(p/'house-source.json',meta);print('Authored',id,flush=True)

def export(out,source):
 if out.exists():raise FileExistsError(out)
 out.mkdir(parents=True);assets=[]
 for id in FILES:
  ref.export(source/id,out/id);meta=read(source/id/'house-source.json');a=np.array(Image.open(source/id/'native-authority.png'));b=np.array(Image.open(out/id/'composite.png'));assert np.array_equal(a,b),id
  assert set(np.unique(b[:,:,3]))=={0,255},id
  assets.append(dict(id=id,ppu=32,canvas=meta['canvas'],groundAnchorPixels=meta['groundAnchorPixels'],source=(source/id/(id+'.aseprite')).relative_to(ROOT).as_posix(),sourceSHA256=sha(source/id/(id+'.aseprite')),composite=(out/id/'composite.png').relative_to(ROOT).as_posix(),compositeSHA256=sha(out/id/'composite.png'),registration=meta['registration'],worldReady=False))
 write(out/'catalog.json',{'schema':'valdoria-village02-anime-art/v1','assets':assets,'reference':'Official anime only','approved':False});write(out/'manifest.json',{'generatorSHA256':sha(__file__),'files':{p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}})
 print('Exported',len(assets))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['retain','plan','author','export']);p.add_argument('--output',type=Path);p.add_argument('--source',type=Path,default=BASE/'SourceV1');a=p.parse_args()
 if a.action=='retain':retain()
 elif a.action=='plan':plan()
 elif a.action=='author':author(a.output.resolve())
 else:export(a.output.resolve(),a.source.resolve())
