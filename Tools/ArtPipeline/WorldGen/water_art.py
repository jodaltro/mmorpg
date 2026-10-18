"""Editable pixel water source and chunk composition; no physical decisions from raster colors."""
import argparse,math,subprocess,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.spatial import cKDTree
import world_hydrology as water
import environment_geometry as geo
PALETTE=['#253e40','#2e5052','#3a6261','#507a70','#71988a','#98b3a0']
KINDS=['Shallow water','Deep water','Reflections','Shore sediment','Localized foam','Flow strokes']

def library(output):
 out=water.refuse(output);out.mkdir(parents=True);size=(128,192);frames=[]
 for frame in range(4):
  layers={name:Image.new('RGBA',size) for name in KINDS}
  for row,name in enumerate(KINDS):
   d=ImageDraw.Draw(layers[name]);yy=row*32
   if row<2:
    colors=PALETTE[2:] if row==0 else PALETTE[:4]
    for i,c in enumerate(colors):d.rectangle((2+i*5,yy+2,6+i*5,yy+7),fill=c)
    d.polygon([(34,yy+13),(43,yy+10),(55,yy+12),(69,yy+10),(85,yy+12),(93,yy+16),(82,yy+19),(65,yy+17),(49,yy+20),(36,yy+18)],fill=colors[1]);d.line([(39,yy+13),(49,yy+12),(57,yy+14),(69,yy+13)],fill=colors[2]);d.line((72,yy+16,84,yy+16),fill=colors[0])
   elif row==2:
    for x,y,length in [(44,13,10),(58,17,15),(76,11,8)]:
     dx=((frame+x)%4)-1;d.line((x+dx,yy+y,x+length+dx,yy+y),fill=PALETTE[4]);d.point((x+dx-2,yy+y+1),fill=PALETTE[3])
   elif row==3:
    d.polygon([(38,yy+15),(43,yy+11),(52,yy+13),(59,yy+10),(69,yy+12),(80,yy+11),(88,yy+15),(77,yy+19),(58,yy+17),(45,yy+19)],fill='#665e43');d.line([(42,yy+13),(50,yy+14),(60,yy+12),(68,yy+14)],fill='#8b845b');d.line((72,yy+14,82,yy+13),fill='#4a5b41')
   elif row==4:
    for x,y,length in [(45,12,6),(56,15,9),(70,11,5),(79,16,4)]:
     dx=(frame+x)%3;d.line((x+dx,yy+y,x+length+dx,yy+y),fill='#a7b9a0');d.point((x+dx-1,yy+y+1),fill='#71988a')
   else:
    dx=frame*2
    d.line([(40+dx,yy+17),(48+dx,yy+15),(57+dx,yy+16)],fill=PALETTE[3]);d.line((58+dx,yy+14,67+dx,yy+14),fill=PALETTE[4]);d.line((70+dx,yy+16,78+dx,yy+15),fill=PALETTE[2])
  for name,im in layers.items():im.save(out/(f'frame-{frame}-'+name.replace(' ','_')+'.png'))
 lua='local root=app.params["root"]\nlocal s=Sprite(128,192,ColorMode.RGB)\ns.layers[1].name="Temporary"\n'
 lua+='for f=2,4 do s:newEmptyFrame(f) end\n'
 for name in KINDS:
  lua+=f'local layer=s:newLayer();layer.name="{name}"\n'
  for f in range(4):lua+=f'local t=app.open(root.."/frame-{f}-{name.replace(" ","_")}.png");s:newCel(layer,{f+1},t.cels[1].image,Point(0,0));t:close()\n'
 lua+='s:deleteLayer(s.layers[1]);for _,f in ipairs(s.frames) do f.duration=0.18 end\nlocal tag=s:newTag(1,4);tag.name="water_flow";s:saveAs(root.."/water-motifs.aseprite")\n'
 lua+='for i,f in ipairs(s.frames) do local im=Image(s.spec);im:drawSprite(s,i);im:saveAs(root.."/water-frame-"..(i-1)..".png") end\n'
 (out/'assemble.lua').write_text(lua,encoding='utf8');subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'assemble.lua')],check=True)
 metadata={'schema':'valdoria-water-library/v1','canvas':[128,192],'module':[128,32],'functions':KINDS,'frames':4,'durationMs':180,'ppu':32,'light':'upper-left','source':'water-motifs.aseprite','license':'Original Valdoria project work','author':'Python-authored clusters assembled/exported by Aseprite 1.3.18.6','allowedTransforms':'translation for prelit forms; alpha geometry of flow strokes can follow tangent with world color reapplied','files':{p.name:water.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()}}
 water.write(out/'library.json',metadata)
 images=[Image.open(out/f'water-frame-{i}.png') for i in range(4)];images[0].save(out/'preview.gif',save_all=True,append_images=images[1:],duration=180,loop=0,disposal=2)
 # Preview is convenience only and deliberately outside source integrity list.
 return metadata

def boundary_distance(loops,x,y):
 # Dense boundary samples approximate Euclidean distance with <= 1/128 u sampling error.
 samples=[]
 for loop in loops:
  for a,b in zip(loop,loop[1:]+loop[:1]):
   a,b=np.array(a),np.array(b);n=max(1,int(math.ceil(np.linalg.norm(b-a)*128)));t=np.arange(n)/n;samples.extend(a[None,:]+(b-a)[None,:]*t[:,None])
 tree=cKDTree(np.array(samples));d,_=tree.query(np.c_[np.asarray(x).ravel(),np.asarray(y).ravel()]);return d.reshape(np.asarray(x).shape)

def render_chunk(solution,library_path,bounds):
 sources=[Image.open(Path(library_path)/f'water-frame-{f}.png').convert('RGBA') for f in range(4)];g=solution['geometry'];vf=g['waterFields'];seed=solution['seed'];ox,oy,W,H=bounds;masks=water.rasterize(solution,bounds);wet=masks['surface']
 y,x=np.mgrid[oy:oy+H,ox:ox+W];wx=(x+.5)/32;wy=(y+.5)/32;dist=boundary_distance(g['waterLoops'],wx,wy);bank=(~wet)&(dist<=solution['recipe']['wetMarginUnits'])
 if not (wet|bank).any():return []
 dep=masks['depth'];shallow=np.array(sources[0])[2,7,:3];deep=np.array(sources[0])[34,7,:3]
 mix=np.clip(dep/.020,0,1);base=shallow[None,None,:]*(1-mix[:,:,None])+deep[None,None,:]*mix[:,:,None]
 bands=np.floor(np.sin(x*.043+y*.012+seed)*.75+np.sin(x*.113-y*.075)*.35+1.5);base=(np.floor(np.clip(base+(bands-1.5)[:,:,None]*3,0,255)/2)*2).astype('uint8')
 edgecolor=np.array([90,121,95]);base=np.where((wet&(dist<.20))[:,:,None],base*.72+edgecolor*.28,base).astype('uint8')
 sediment=np.array(sources[0])[111,40,:3].astype(float);bankcolors=np.clip(sediment[None,:]+np.array([[-7,2,1],[4,8,3],[17,19,8],[32,32,17]]),0,255).astype('uint8')
 bindex=np.clip(np.floor(dist/solution['recipe']['wetMarginUnits']*4),0,3).astype(int);rgba=np.zeros((H,W,4),dtype='uint8');rgba[:,:,:3]=np.where(wet[:,:,None],base,bankcolors[bindex]);rgba[:,:,3]=np.where(wet,255,np.where(bank,np.clip((1-dist/solution['recipe']['wetMarginUnits'])*200,0,180),0)).astype('uint8')
 candidates=[]
 for gy in range((oy-80)//47,(oy+H+80)//47+1):
  for gx in range((ox-80)//59,(ox+W+80)//59+1):
   n=(gx*73856093^gy*19349663^seed*83492791)&0xffffffff;px=gx*59+((n>>2)%39);py=gy*47+((n>>10)%31)
   if not ox-64<=px<ox+W+64 or not oy-64<=py<oy+H+64:continue
   scalar=geo.sample_triangular(vf['surface'],(px+.5)/32,(py+.5)/32).item();fx=geo.sample_triangular(np.array(vf['flow'])[:,:,0],px/32,py/32).item();fy=geo.sample_triangular(np.array(vf['flow'])[:,:,1],px/32,py/32).item();speed=math.hypot(fx,fy)
   if scalar>0:
    row=5 if speed>.2 and n%3==0 else 2
    if scalar<.23 and speed>.3 and n%3==1:row=4
    if row==2 and n%3:continue
    candidates.append((px,py,row,n,fx,fy))
   elif n%2==0:candidates.append((px,py,3,n,0,0))
 images=[]
 for f in range(4):
  im=Image.fromarray(rgba.copy());bank_stamps=Image.new('RGBA',(W,H))
  for px,py,row,n,fx,fy in candidates:
   source=sources[(f+n%4)%4].crop((32,row*32,96,row*32+32));alpha=source.getchannel('A')
   if row==5:
    alpha=alpha.rotate(-math.degrees(math.atan2(fy,fx)),Image.Resampling.NEAREST,expand=True);source=Image.new('RGBA',alpha.size,PALETTE[3]);source.putalpha(alpha)
   if row==3:
    source.putalpha(alpha.point(lambda v:v//3));bank_stamps.alpha_composite(source,(int(px-ox-source.width//2),int(py-oy-source.height//2)))
   else:im.alpha_composite(source,(int(px-ox-source.width//2),int(py-oy-source.height//2)))
  arr=np.array(im);arr[~wet&~bank]=0;arr[bank]=rgba[bank];im=Image.fromarray(arr);bst=np.array(bank_stamps);bst[~bank]=0;im=Image.alpha_composite(im,Image.fromarray(bst));images.append(im)
 return images

def compose(solution,library_path,output):
 library_path=Path(library_path);out=Path(output);meta=geo.read(library_path/'library.json')
 if meta['schema']!='valdoria-water-library/v1':raise ValueError('Water library schema')
 for name,h in meta['files'].items():
  if Path(name).name!=name or water.sha((library_path/name).read_bytes())!=h:raise ValueError('Water library checksum')
 g=solution['geometry'];w,h=g['sizeUnits'];step=g['stepUnits'];chunk=256;entries=[]
 for cy in range(math.ceil(h*32/chunk)):
  for cx in range(math.ceil(w*32/chunk)):
   bounds=[cx*chunk,cy*chunk,min(chunk,int(w*32)-cx*chunk),min(chunk,int(h*32)-cy*chunk)];images=render_chunk(solution,library_path,bounds)
   if not images:continue
   names=[]
   for f,im in enumerate(images):name=f'water-{cx}-{cy}-f{f}.png';im.save(out/name);names.append(name)
   entries.append({'id':f'{cx}-{cy}','rectPixels':bounds,'frames':names})
 yy,xx=np.mgrid[0:h+step:step,0:w+step:step];d=boundary_distance(g['waterLoops'],xx,yy);inside=geo.sample_triangular(g['waterFields']['surface'],xx,yy)>=0;bankfield=solution['recipe']['wetMarginUnits']-np.where(inside,-d,d)
 water.write(out/'water-render.json',{'schema':'valdoria-water-render/v1','ppu':32,'stepUnits':step,'sizeUnits':[w,h],'durationMs':meta['durationMs'],'chunks':entries,'surfaceScalarRef':'geometry.json/waterFields.surface','bankScalar':np.round(bankfield,7).tolist(),'light':'upper-left','sampling':'Point, uncompressed, no mipmaps; shared clipped geometry, chunk textures are replaceable art','sourceLibrarySha256':water.sha((library_path/'library.json').read_bytes())})
 return entries

def ImageColor(value):return tuple(int(value[i:i+2],16) for i in (1,3,5))
def export_library(source,output):
 out=water.refuse(output);out.mkdir(parents=True);source=Path(source);target=out/'water-motifs.aseprite';target.write_bytes(source.read_bytes())
 lua='local root=app.params["root"];local s=app.open(root.."/water-motifs.aseprite");assert(s.width==128 and s.height==192 and #s.frames==4 and #s.layers==6,"Water library contract");for i,f in ipairs(s.frames) do assert(math.abs(f.duration-0.18)<0.001,"Duration contract");local im=Image(s.spec);im:drawSprite(s,i);im:saveAs(root.."/water-frame-"..(i-1)..".png") end'
 (out/'export.lua').write_text(lua);subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'export.lua')],check=True)
 metadata={'schema':'valdoria-water-library/v1','canvas':[128,192],'module':[128,32],'functions':KINDS,'frames':4,'durationMs':180,'ppu':32,'light':'upper-left','source':'water-motifs.aseprite','parentSha256':water.sha(source.read_bytes()),'license':'Original Valdoria project water source; preserve provenance on edits','files':{p.name:water.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()}}
 water.write(out/'library.json',metadata);return metadata

def main():
 p=argparse.ArgumentParser();p.add_argument('command',choices=['library','export-library']);p.add_argument('--output',required=True);p.add_argument('--source');a=p.parse_args()
 if a.command=='library':library(a.output)
 else:export_library(a.source,a.output)
if __name__=='__main__':main()
