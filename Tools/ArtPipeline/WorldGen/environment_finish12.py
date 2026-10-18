"""Ground12 presentation adapter; physical producers and approved paint are read-only.

Initial assisted masters are retained. Aseprite files own the final pixels;
export/build never regenerate those sources. No world generation during Play.
"""
import argparse,json,math,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import nature_reference10 as n
import ground_finish11 as g
import terrain_materials as m

ROOT=n.ROOT;BASE=ROOT/'ArtSource/Labs/World2026/Ground12';VERSION='valdoria-environment-finish/1.0.0'
HYDRO=ROOT/'ArtSource/Labs/World2026/WorldStudio05/BuildR4'
SPECS={
 'elm-vase':{'master':'exec-f8a4ac4a-fe60-421c-bed4-a8a16ab8dfa7.png','height':300,'anchorFraction':.55,'kind':'tree'},
 'hornbeam-open':{'master':'exec-3a80b79a-50af-4e21-a23b-76104efcd064.png','height':294,'anchorFraction':.55,'kind':'tree'},
 'hazel-layered':{'master':'exec-b42ad233-266c-4b24-b439-4f8dcc796a25.png','height':76,'anchorFraction':.57,'kind':'low'},
 'reeds-open':{'master':'exec-f569a0f5-f15b-4c71-a258-d4d4239a578c.png','height':82,'anchorFraction':.53,'kind':'low'},
 'sandstone-planes':{'master':'exec-a9799268-e276-47a1-a624-2e9dae41872f.png','kind':'material'}}

def write(p,d):n.write(p,d)
def read(p):return n.read(p)
def refuse(p):return n.common.refuse(p)
def manifest(out,inputs):
 write(out/'manifest.json',{'schema':'valdoria-environment-finish-build/v1','version':VERSION,'inputs':inputs,'files':{p.name:n.common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'}})

def author(master_dir):
 out=refuse(BASE/'SourceV1');out.mkdir(parents=True);masters=refuse(BASE/'Masters');masters.mkdir();code='';records=[]
 for id,s in SPECS.items():
  master=masters/(id+'.png');shutil.copy2(Path(master_dir)/s['master'],master);W,H=Image.open(master).size
  if s['kind']=='material':w,h=384,384;cw,ch=w,h;ax,ay=0,0
  else:h=s['height'];w=round(W*h/H);cw,ch=w+16,h+20;ax,ay=round(w*s['anchorFraction'])+8,h+5
  names=['Recessed planes','Material body','Lit planes','Fine accents'] if s['kind']=='material' else ['Ground shadow','Structural wood and roots','Recessed foliage','Leaf volumes','Lit accents']
  records.append({'id':id,'kind':s['kind'],'canvas':[cw,ch],'anchor':[ax,ay],'ppu':32,'layers':names,'source':id+'.aseprite','master':n.arch.ref(master)})
  code+=f'do local raw=app.open({n.q(master)});app.command.SpriteSize{{ui=false,width={w},height={h},method="nearest"}};'
  if s['kind']!='material':
   code+='local a=raw.cels[1].image;for y=0,a.height-1 do for x=0,a.width-1 do local c=a:getPixel(x,y);local r,g,b,alpha=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),app.pixelColor.rgbaA(c);if alpha<190 or (r>g*1.9 and r>b*1.8 and g<95) then a:drawPixel(x,y,0) elseif alpha<255 then a:drawPixel(x,y,app.pixelColor.rgba(r,g,b,255)) end end end;'
  code+='app.command.ColorQuantization{ui=false,maxColors=112,withAlpha=true,algorithm="octree"};app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"};app.command.ChangePixelFormat{ui=false,format="rgb"};local paint=Image(raw.spec);paint:drawSprite(raw,1);'
  code+=f'local s=Sprite({cw},{ch},ColorMode.RGB);local layers={{}};local images={{}};'
  for name in names:code+=f'local l=s:newLayer();l.name={json.dumps(name)};table.insert(layers,l);table.insert(images,Image(s.spec));'
  code+=f'for y=0,{h-1} do for x=0,{w-1} do local c=paint:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local r,g,b=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c);local v=(r+g+b)/3;local part;'
  if s['kind']=='material':code+='part=v<70 and 1 or v<135 and 2 or v<185 and 3 or 4;images[part]:drawPixel(x,y,c);'
  else:
   code+='part=(r>g*1.08 and r>b*1.2) and 2 or v<72 and 3 or v>158 and 5 or 4;images[part]:drawPixel(x+8,y+8,c);'
  code+='end end end;'
  if s['kind']!='material':
   # Small editable contact shadow. Never a physical footprint.
   rx=35 if s['kind']=='tree' else w*.32;ry=7 if s['kind']=='tree' else 3
   code+=f'for y=0,{ch-1} do for x=0,{cw-1} do local d=((x-{ax})/{rx})^2+((y-{ay+2})/{ry})^2;if d<1 then images[1]:drawPixel(x,y,app.pixelColor.rgba(29,38,23,d<.4 and 45 or 20)) end end end;'
  code+=f'for i,l in ipairs(layers) do s:newCel(l,1,images[i],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs({n.q(out/(id+".aseprite"))});s:close();raw:close() end\n'
 # Lower plants: two intentionally drawn fern fans, unlike the old uniform rays.
 for variant in range(2):
  id='fern-'+str(variant);cw,ch,ax,ay=80,56,40,49;names=['Ground shadow','Stems','Recessed fronds','Lit fronds']
  records.append({'id':id,'kind':'low','canvas':[cw,ch],'anchor':[ax,ay],'ppu':32,'layers':names,'source':id+'.aseprite','master':None})
  code+=f'do local s=Sprite({cw},{ch},ColorMode.RGB);local layers={{}};local images={{}};'
  for name in names:code+=f'local l=s:newLayer();l.name={json.dumps(name)};table.insert(layers,l);table.insert(images,Image(s.spec));'
  fronds=[(-32,-17),(-22,-28),(-7,-37),(12,-31),(30,-15)] if variant==0 else [(-29,-12),(-17,-33),(3,-30),(20,-22),(29,-6)]
  for j,(dx,dy) in enumerate(fronds):
   pts=[]
   for k in range(23):
    t=k/22;pts.append((round(ax+dx*t),round(ay+dy*math.sin(t*math.pi/2))))
   for k,(x,y) in enumerate(pts):
    code+=f'images[2]:drawPixel({x},{y},app.pixelColor.rgba(98,116,52,255));'
    if k%2==0 and 2<k<21:
     length=round(6*math.sin(k/22*math.pi))
     for side in (-1,1):
      for v in range(1,length+1):
       xx=x+side*v;yy=y-1+v//3;col=(91,121,55) if side==1 else (132,151,70)
       code+=f'images[{3 if side==1 else 4}]:drawPixel({xx},{yy},app.pixelColor.rgba({col[0]},{col[1]},{col[2]},255));'
  code+=f'for i,l in ipairs(layers) do s:newCel(l,1,images[i],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs({n.q(out/(id+".aseprite"))});s:close() end\n'
 # Water motif study, two sparse directional accents, four phases, editable.
 code+='do local s=Sprite(64,64,ColorMode.RGB);s.layers[1].name="Submerged sediment";for _,name in ipairs({"Broken ripple shadow","Reflected sky","Foam at local contacts"}) do local l=s:newLayer();l.name=name end;for f=1,4 do if f>1 then s:newEmptyFrame() end;s.frames[f].duration=.18;for i,l in ipairs(s.layers) do local im=Image(s.spec);if i==3 then for _,line in ipairs({{7+f,18,11},{30-f,43,7}}) do for k=0,line[3] do if k~=4 then im:drawPixel(line[1]+k,line[2]+math.floor(k/8),app.pixelColor.rgba(157,193,161,95)) end end end end;s:newCel(l,f,im,Point(0,0)) end end;'
 code+=f's:saveAs({n.q(out/"water-accents.aseprite")});s:close() end'
 n.lua(code,out/'initial-authoring.lua');write(out/'source.json',{'schema':'valdoria-environment-source/v1','version':VERSION,'assets':records,'pixelAuthority':'Retained Aseprite; bootstrap never runs during export','layers':'Exterior pixel ownership, not unseen reconstructed faces','light':'upper-left','status':'candidate','authorship':'Original project ImageGen assisted masters, Aseprite interpretation; ferns and water accents authored in Lua. No third-party image inputs.'})
 write(BASE/'recipe.json',{'schema':'valdoria-environment-finish-recipe/v1','version':VERSION,'seed':910212,'ppu':32,'geometryChange':False,'vegetationPlacement':'existing anchors only','treeAssets':['elm-vase','hornbeam-open'],'wetBankExtentPixels':18,'waterPhaseMs':180,'visualDeepScalar':.012,'artisticStatus':'candidate-awaiting-user-review'})

def export(out,source=BASE/'SourceV1'):
 out=refuse(out);out.mkdir(parents=True);source=Path(source);meta=read(source/'source.json');code=''
 for spec in meta['assets']:
  id=spec['id'];code+=f'do local s=app.open({n.q(source/spec["source"])});assert(s.width=={spec["canvas"][0]} and s.height=={spec["canvas"][1]},"Canvas contract");'
  code+=f'local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({n.q(out/(id+".png"))});'
  if spec['kind']!='material':
   code+=f'local im=Image(s.spec);im:drawImage(s.cels[1].image,s.cels[1].position);im:saveAs({n.q(out/(id+"-shadow.png"))});s.layers[1].isVisible=false;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({n.q(out/(id+"-body.png"))});'
  code+='s:close() end\n'
 code+=f'do local s=app.open({n.q(source/"water-accents.aseprite")});for f=1,4 do local im=Image(s.spec);im:drawSprite(s,f);im:saveAs({n.q(out) }.."/water-accents-"..(f-1)..".png") end;s:close() end'
 n.lua(code,out/'export.lua');write(out/'sprites.json',meta);manifest(out,{p.name:n.arch.ref(p) for p in source.glob('*.aseprite')}|{'metadata':n.arch.ref(source/'source.json')})

def painting(texture,x,y,seed):
 # Same overlapping patch basis as Ground11, with a supplied editable painting.
 im=np.array(texture.convert('RGB')).astype(float);step=128.;gx=np.floor(x/step).astype(int);gy=np.floor(y/step).astype(int);result=np.zeros(x.shape+(3,));weightSum=np.zeros(x.shape)
 for dy in (0,1):
  for dx in (0,1):
   px=gx+dx;py=gy+dy;u=x/step-px;v=y/step-py;weight=(.5+.5*np.cos(np.pi*np.clip(u,-1,1)))*(.5+.5*np.cos(np.pi*np.clip(v,-1,1)))
   ox=np.floor(m.ihash(px,py,seed)*128);oy=np.floor(m.ihash(px,py,seed+1)*128);xx=np.clip(x-px*step+128+ox,0,383).astype(int);yy=np.clip(y-py*step+128+oy,0,383).astype(int);result+=im[yy,xx]*weight[...,None];weightSum+=weight
 return result/np.maximum(weightSum[...,None],1e-9)

def build(out,library=BASE/'ExportV1',recipe=BASE/'recipe.json'):
 out=refuse(out);library=Path(library);r=read(recipe)
 if r['geometryChange'] or r['ppu']!=32 or r['version']!=VERSION or not 0<=r['wetBankExtentPixels']<=24 or not .001<=r['visualDeepScalar']<=.05 or type(r['seed']) is not int:raise ValueError('Presentation recipe contract')
 # Validate retained pixel export inputs and files before composition.
 verify(library);out.mkdir(parents=True)
 W,H=2048,1536;y,x=np.mgrid[:H,:W];ctx=m.Context();rock=ctx.sample(ctx.rock,x,y)
 stone=painting(Image.open(library/'sandstone-planes.png'),x,y,r['seed'])
 grass=g.sample_paint('meadow',x,y,g.SEED)
 # Top and wall interpretations differ; shared meshes/UVs are untouched.
 # Mineral planes dominate the blocked outcrop. Grass occupies selected recesses,
 # rather than blending over every rock plane and muddying their readability.
 pockets=(m.field(x,y,109,r['seed']+5)>.64)&(rock>1.0)
 exposure=np.where(pockets,.65,.96)
 top=grass*(1-exposure[...,None])+stone*exposure[...,None]
 for name,values in [('relief-top',top),('relief-face',stone)]:Image.fromarray(np.clip(np.rint(values),0,255).astype('uint8')).convert('RGBA').save(out/(name+'.png'))
 base=np.array(Image.open(g.BASE/'WorldFinal/final.png').convert('RGBA'));surface=np.array(Image.open(HYDRO/'surface.png').convert('L'))>0
 distance=distance_transform_edt(~surface);near=np.clip(1-distance/r['wetBankExtentPixels'],0,1)*(~surface)
 # Ground11 stays byte-identical outside the narrow authorised bank interface.
 near*=1-(ctx.masks['coverage']>0)
 soil=g.sample_paint('earth',x,y,g.SEED+13);patch=(m.field(x,y,17,r['seed']+9)>.40)*.18
 strength=near*(.12+patch);rgb=base[:,:,:3].astype(float);rgb=rgb*(1-strength[...,None])+soil*.76*strength[...,None]
 base[:,:,:3]=np.clip(np.rint(rgb),0,255).astype('uint8');Image.fromarray(base).save(out/'ground-bank.png');Image.fromarray((near*255).astype('uint8')).save(out/'bank-influence.png')
 render=read(HYDRO/'water-render.json');depth=np.array(Image.open(HYDRO/'depth.png')).astype(float)/65535
 wet=np.clip(distance_transform_edt(surface)/9,0,1)
 for chunk in render['chunks']:
  x0,y0,w,h=chunk['rectPixels'];Y,X=np.mgrid[y0:y0+h,x0:x0+w];dep=depth[y0:y0+h,x0:x0+w];t=np.clip(dep/r['visualDeepScalar'],0,1)
  shallow=np.array([100,137,115]);deep=np.array([42,85,84]);colour=shallow*(1-t[...,None])+deep*t[...,None]
  modulation=(m.field(X,Y,29,r['seed']+17)-.5)*.055+(m.field(X,Y,101,r['seed']+19)-.5)*.06;colour*=1+modulation[...,None]
  for phase,name in enumerate(chunk['frames']):
   original=np.array(Image.open(HYDRO/name).convert('RGBA'));alpha=original[:,:,3].copy();shade=wet[y0:y0+h,x0:x0+w]
   values=colour.copy();values=values*shade[...,None]+original[:,:,:3]*(1-shade[...,None])
   # Sparse authored motifs in world space, no frame-dependent random noise.
   motif=np.array(Image.open(library/f'water-accents-{phase}.png').convert('RGBA'));mx=(X//1)%64;my=Y%64;paint=motif[my,mx];amount=paint[:,:,3]/255*(dep>.001)*.45
   values=values*(1-amount[...,None])+paint[:,:,:3]*amount[...,None]
   original[:,:,:3]=np.clip(np.rint(values),0,255).astype('uint8');assert np.array_equal(original[:,:,3],alpha);Image.fromarray(original).save(out/name)
 write(out/'composition.json',{'schema':'valdoria-environment-composition/v1','version':VERSION,'seed':r['seed'],'geometryChanged':False,'bankMaximumPixels':r['wetBankExtentPixels'],'waterChunks':render['chunks'],'groundChangeRestrictedToBank':True,'plantAnchorsSource':n.arch.ref(n.ref.SOURCE.parent/'RegionV1/vegetation.json')})
 manifest(out,{'library':n.arch.ref(library/'manifest.json'),'recipe':n.arch.ref(recipe),'ground11':n.arch.ref(g.BASE/'WorldFinal/final.png'),'hydrology':n.arch.ref(HYDRO/'manifest.json'),'sourceRegion':n.arch.ref(ctx.region_path)})

def verify(folder):
 folder=Path(folder);d=read(folder/'manifest.json')
 if d['version']!=VERSION:raise ValueError('Version')
 for name,expected in d['files'].items():
  if Path(name).name!=name or n.common.sha((folder/name).read_bytes())!=expected:raise ValueError('Output hash: '+name)
 for spec in d['inputs'].values():
  if n.common.sha((ROOT/spec['path']).read_bytes())!=spec['sha256']:raise ValueError('Input hash: '+spec['path'])
 return {'passed':True,'files':len(d['files'])}

def main():
 p=argparse.ArgumentParser();p.add_argument('action',choices=['author','export','build','verify']);p.add_argument('--masters',type=Path);p.add_argument('--output',type=Path);p.add_argument('--library',type=Path,default=BASE/'ExportV1');p.add_argument('--recipe',type=Path,default=BASE/'recipe.json');a=p.parse_args()
 if a.action=='author':author(a.masters)
 elif a.action=='export':export(a.output)
 elif a.action=='build':build(a.output,a.library,a.recipe)
 else:print(json.dumps(verify(a.output)))

if __name__=='__main__':main()
