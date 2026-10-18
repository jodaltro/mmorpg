"""Original Valdoria vegetation pixel source. Aseprite layers are editable authority.
No AI raster, source resampling, mirrored lighting or runtime tree synthesis.
"""
import argparse,json,math,random,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
import world_hydrology as common
KINDS=['oak','elm','hazel','fern','wildflowers','reeds','drygrass','plantgroup']
SIZES={'oak':(192,256),'elm':(256,320),'hazel':(96,96),'fern':(64,64),'wildflowers':(64,80),'reeds':(64,112),'drygrass':(64,80),'plantgroup':(96,80)}
LAYER_NAMES=['Shadow - ground plane','Trunk - structure','Bark and branches','Canopy - dark volume','Foliage - planes','Highlights and accents']
GREEN=['#283c30','#334c35','#425d3b','#557345','#6d8652','#8b9b67','#a5ad7d']
BARK=['#352f29','#4c4031','#665139','#82674a','#9a805d']

def polygon_lobe(draw,cx,cy,rx,ry,rng,color):
 pts=[]
 for j in range(14):
  a=j*math.tau/14;factor=rng.uniform(.82,1.12);pts.append((round(cx+math.cos(a)*rx*factor),round(cy+math.sin(a)*ry*factor)))
 draw.polygon(pts,fill=color)
 return pts

def source_layers(kind,variant):
 W,H=SIZES[kind];fx=W//2;fy=H-20 if kind not in ['oak','elm'] else H-28;rng=random.Random(610206+KINDS.index(kind)*100+variant*137);layers=[Image.new('RGBA',(W,H)) for _ in LAYER_NAMES];d=[ImageDraw.Draw(i) for i in layers]
 if kind in ['oak','elm']:
  large=kind=='elm';wide=[1.,.82,1.08][variant];lean=[-7,10,-13][variant];trunkTop=int(fy*.44);trunkWidth=11 if large else 9
  # Roots and tapered crooked trunk, separate from the crown's volume/footprint.
  d[0].ellipse((fx-W*.30,fy-9,fx+W*.35,fy+13),fill=(24,37,27,53));d[0].ellipse((fx-W*.21,fy-5,fx+W*.25,fy+9),fill=(24,35,25,43))
  pts=[(fx-15,fy+1),(fx-7,fy-11),(fx-5,fy-54),(fx+lean-4,trunkTop),(fx+lean+4,trunkTop-3),(fx+7,fy-58),(fx+8,fy-12),(fx+21,fy+2),(fx+6,fy-1),(fx-1,fy-5),(fx-7,fy+1)]
  d[1].polygon(pts,fill=BARK[1]);d[2].polygon([(fx-7,fy-10),(fx-4,fy-57),(fx+lean-3,trunkTop),(fx+lean+1,trunkTop),(fx+1,fy-57),(fx+2,fy-7)],fill=BARK[3]);d[2].line([(fx+5,fy-15),(fx+2,fy-41),(fx+4,fy-70),(fx+lean,trunkTop+9)],fill=BARK[0],width=2)
  for n in range(13):
   yy=fy-12-n*6;xx=fx+rng.randint(-4,4);d[2].line((xx,yy,xx+1,yy-4),fill=BARK[2 if n%3 else 4])
  for side in [-1,1]:
   for n in range(3):
    root=(fx+lean//2,fy-65-n*24);end=(fx+side*(34+n*12)+lean,root[1]-28-rng.randint(0,17));d[1].line([root,(root[0]+side*15,root[1]-4),end],fill=BARK[1],width=7-n);d[2].line([(root[0]-2,root[1]-2),(end[0]-1,end[1]-1)],fill=BARK[3],width=2)
  # Distinct authored crown grammars: spreading, high forked, windward/asymmetric.
  if variant==0:centers=[(-.28,.42,.17,.12),(.03,.33,.21,.14),(.28,.43,.19,.13),(-.20,.57,.20,.14),(.18,.57,.22,.15),(-.04,.48,.22,.16),(-.34,.52,.11,.10),(.34,.56,.13,.12)]
  elif variant==1:centers=[(-.12,.25,.18,.12),(.08,.30,.17,.14),(-.23,.43,.18,.15),(.20,.46,.20,.16),(-.16,.58,.20,.16),(.15,.64,.17,.12),(-.30,.58,.12,.11),(.28,.59,.10,.13)]
  else:centers=[(-.33,.37,.17,.12),(-.12,.31,.19,.13),(.12,.41,.18,.14),(-.30,.53,.20,.14),(-.04,.55,.21,.16),(.25,.59,.17,.13),(-.41,.59,.12,.09),(.13,.68,.13,.10)]
  if large:
   # Elm's higher fork and pendant side branches differ structurally from the oak.
   centers=[(-.27,.39,.12,.12),(-.12,.29,.15,.12),(.08,.27,.13,.14),(.24,.38,.14,.14),(-.30,.53,.14,.15),(-.11,.47,.16,.18),(.13,.48,.18,.17),(.31,.55,.12,.13),(-.21,.65,.13,.13),(.08,.64,.13,.12)] if variant==0 else [(-.16,.23,.12,.13),(.07,.20,.12,.12),(.20,.33,.12,.14),(-.22,.39,.14,.14),(.03,.43,.14,.17),(.25,.53,.12,.14),(-.23,.57,.12,.15),(-.04,.64,.14,.12)] if variant==1 else [(-.32,.32,.15,.11),(-.14,.24,.13,.13),(.08,.31,.16,.12),(-.34,.49,.12,.14),(-.12,.48,.15,.16),(.13,.51,.16,.16),(.27,.62,.12,.14),(-.09,.68,.13,.11)]
  centers=[(fx+int(dx*W*wide)+lean//2,int(yy*fy),int(rx*W),int(ry*fy)) for dx,yy,rx,ry in centers]
  mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask)
  for cx,cy,rx,ry in centers:polygon_lobe(md,cx,cy,rx,ry,rng,255)
  # One coherent crown, not concentric shaded balls. Small connected leaf planes carry volume.
  occupied=np.array(mask)>0;yy,xx=np.mgrid[0:H,0:W];level=(fy*.75-yy)/(fy*.60)+(fx-xx)/(W*1.4)
  structural=np.sin(xx*.082+yy*.047)*.34+np.sin(xx*.043-yy*.091)*.22
  index=np.clip(np.floor(2.0+level+structural),0,4).astype(int);colors=np.array([tuple(int(c[i:i+2],16) for i in (1,3,5)) for c in GREEN]);rgba=np.zeros((H,W,4),dtype='uint8');rgba[:,:,:3]=colors[index];rgba[:,:,3]=occupied.astype('uint8')*255;layers[3]=Image.fromarray(rgba)
  for n in range(1500 if large else 1050):
   x=rng.randrange(W);y=rng.randrange(H)
   if not occupied[y,x]:continue
   length=rng.randrange(3,8);dx=rng.choice([-1,1]);base=int(index[y,x]);color=GREEN[max(0,min(4,base+rng.choice([-1,0,1])))];pts=[(x,y),(x+dx*length,y-1),(x+dx*(length+1),y+1),(x+dx*3,y+3)];d[4].polygon(pts,fill=color)
   if n%4==0 and base>=2:d[5].line((x,y-1,x+dx*max(2,length-3),y-2),fill=GREEN[min(5,base+1)])
  # Branch pockets and ragged lower silhouette explain crown structure without a dark oval outline.
  for n,(cx,cy,rx,ry) in enumerate(centers):
   if n%3==variant%3:
    d[4].line([(cx-rx*.6,cy+ry*.5),(cx-rx*.2,cy+ry*.64),(cx+rx*.3,cy+ry*.45)],fill=GREEN[0],width=2)
  for i in [4,5]:
   a=np.array(layers[i]);a[~occupied]=0;layers[i]=Image.fromarray(a)
 elif kind=='hazel':
  d[0].ellipse((fx-30,fy-5,fx+31,fy+7),fill=(26,39,28,57));count=[5,7,4][variant];mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask)
  for j in range(count):
   xx=fx+rng.randint(-24,24);yy=fy-rng.randint(18,39);d[1].line((fx,fy,xx,yy),fill=BARK[2],width=2);polygon_lobe(md,xx,yy,17+variant*2,15,rng,255)
  occupied=np.array(mask)>0;yy,xx=np.mgrid[0:H,0:W];index=np.clip(np.floor(2.2+(fy-yy)/45+(fx-xx)/100+np.sin(xx*.16+yy*.08)*.30),1,4).astype(int);colors=np.array([tuple(int(c[i:i+2],16) for i in (1,3,5)) for c in GREEN]);a=np.zeros((H,W,4),dtype='uint8');a[:,:,:3]=colors[index];a[:,:,3]=occupied.astype('uint8')*255;layers[3]=Image.fromarray(a)
  for j in range(230):
   x=rng.randrange(5,W-5);y=rng.randrange(15,fy)
   if occupied[y,x]:
    base=int(index[y,x]);d[4].polygon([(x,y),(x+4,y-2),(x+6,y),(x+2,y+2)],fill=GREEN[max(1,base-1)]);d[5].line((x,y-1,x+3,y-2),fill=GREEN[min(4,base)])
  for i in [4,5]:
   a=np.array(layers[i]);a[~occupied]=0;layers[i]=Image.fromarray(a)

 else:
  d[0].ellipse((fx-18,fy-3,fx+22,fy+5),fill=(26,36,26,38));n={'fern':9,'wildflowers':8,'reeds':13,'drygrass':15,'plantgroup':17}[kind]+variant*2
  for j in range(n):
   bx=fx+rng.randint(-16 if W==64 else -30,16 if W==64 else 30);height=rng.randint(17,40)+(20 if kind=='reeds' else 0);lean=rng.randint(-13,13)+[-4,3,0][variant];tip=(bx+lean,fy-height);c=GREEN if kind!='drygrass' else ['#5b5439','#706342','#8c7a4d','#a29161','#b6a779','#c8ba8e']
   if kind=='fern' or kind=='plantgroup' and j%3==0:
    d[1].line([(bx,fy),(bx+lean//2,fy-height//2),tip],fill=c[2]);
    for k in range(2,8):
     t=k/9;xx=bx+lean*t;yy=fy-height*t;spread=(1-t)*10+2;d[4].polygon([(xx,yy+3),(xx-spread,yy-3),(xx-spread*.6,yy-4),(xx,yy)],fill=c[2+k%2]);d[5].line((xx,yy,xx+spread,yy-4),fill=c[3])
   elif kind=='wildflowers' or kind=='plantgroup' and j%4==1:
    d[1].line((bx,fy,tip[0],tip[1]),fill=GREEN[2]);d[4].polygon([(bx,fy-8),(bx-6,fy-13),(bx-5,fy-16),(bx+1,fy-10)],fill=GREEN[3]);flower=['#c7bd8e','#9a8a79','#bdb496'][j%3];d[5].line((tip[0]-3,tip[1],tip[0]+3,tip[1]),fill=flower,width=2);d[5].line((tip[0],tip[1]-2,tip[0],tip[1]+2),fill=flower);d[5].point(tip,fill='#a38a45')
   else:
    d[4].polygon([(bx-2,fy),(bx+lean*.5-1,fy-height*.5),tip,(bx+lean*.5+1,fy-height*.5),(bx+2,fy)],fill=c[2]);d[5].line((bx,fy-2,tip[0],tip[1]+2),fill=c[3])
    if kind=='reeds' and j%3==0:d[1].line((tip[0],tip[1]-7,tip[0],tip[1]+1),fill='#756145',width=3);d[5].line((tip[0]-1,tip[1]-6,tip[0]-1,tip[1]-2),fill='#998054')
    elif kind=='drygrass' and j%3==0:d[5].line((tip[0]-2,tip[1]-1,tip[0]+2,tip[1]-1),fill=c[4])
 return layers,[fx,fy]

def pack_library(output):
 out=Path(output);metadata=json.loads((out/'source.json').read_text(encoding='utf8'));entries=[];shelf_x=shelf_y=row_height=0;atlas=Image.new('RGBA',(1024,2048))
 for item in metadata['species']:
  for variant in range(3):
   for part in ['shadow','trunk','crown']:
    filename=f'{item["id"]}-v{variant}-{part}.png';im=Image.open(out/filename).convert('RGBA');rect=im.getbbox()
    if rect is None:continue
    crop=im.crop(rect);w,h=crop.size
    if shelf_x+w+4>1024:shelf_x=0;shelf_y+=row_height+4;row_height=0
    if shelf_y+h+4>2048:raise ValueError('Vegetation atlas overflow')
    atlas.paste(crop,(shelf_x+2,shelf_y+2));entries.append({'id':f'{item["id"]}-v{variant}-{part}','species':item['id'],'variant':variant,'part':part,'rectPixels':[shelf_x+2,shelf_y+2,w,h],'sourceRect':list(rect),'offsetUnits':[(rect[0]-item['groundAnchor'][0])/32,(item['groundAnchor'][1]-rect[3])/32]});shelf_x+=w+4;row_height=max(row_height,h)
 used=shelf_y+row_height+4;height=2**math.ceil(math.log2(used));atlas=atlas.crop((0,0,1024,height));atlas.save(out/'vegetation-atlas.png');common.write(out/'sprites.json',{'schema':'valdoria-vegetation-sprites/v1','ppu':32,'atlasSize':list(atlas.size),'species':metadata['species'],'sprites':entries})
 common.write(out/'library.json',{'schema':'valdoria-vegetation-library/v1','source':'eight original editable Aseprite documents, three silhouettes per species','author':'Original Valdoria procedural branch/leaf pixel authorship, Aseprite layer exports','license':'Original project work','light':'upper-left','allowMirror':False,'files':{p.name:common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file() and p.name!='library.json'}})
 return entries

def library(output):
 out=common.refuse(output);out.mkdir(parents=True);species=[]
 lua='local root=app.params["root"]\n'
 for kind in KINDS:
  W,H=SIZES[kind]
  for v in range(3):
   layers,anchor=source_layers(kind,v)
   for i,im in enumerate(layers):im.save(out/f'{kind}-v{v}-layer{i}.png')
  species.append({'id':kind,'canvas':[W,H],'groundAnchor':anchor,'variants':3,'footprintRadius':{'oak':.30,'elm':.40}.get(kind,0),'canopyRadius':{'oak':2.3,'elm':3.0,'hazel':1.0}.get(kind,.55),'perspective':'2D three-quarter, ground anchor fixed; no z-height actor changes'})
  lua+=f'do local s=Sprite({W},{H},ColorMode.RGB);s.layers[1].name="Temporary";for f=2,3 do s:newEmptyFrame(f) end\n'
  for i,name in enumerate(LAYER_NAMES):
   lua+=f'local l=s:newLayer();l.name="{name}";'
   for v in range(3):lua+=f'local t=app.open(root.."/{kind}-v{v}-layer{i}.png");s:newCel(l,{v+1},t.cels[1].image,Point(0,0));t:close();'
   lua+='\n'
  lua+='s:deleteLayer(s.layers[1]);for _,f in ipairs(s.frames) do f.duration=0.18 end\n'
  lua+=f's:saveAs(root.."/{kind}.aseprite")\n'
  for v in range(3):
   for part,visible in [('shadow',[1]),('trunk',[2,3]),('crown',[4,5,6])]:
    lua+='for _,l in ipairs(s.layers) do l.isVisible=false end;'
    for index in visible:lua+=f's.layers[{index}].isVisible=true;'
    lua+=f'local im=Image(s.spec);im:drawSprite(s,{v+1});im:saveAs(root.."/{kind}-v{v}-{part}.png")\n'
  lua+='s:close() end\n'
 (out/'assemble.lua').write_text(lua,encoding='utf8');common.write(out/'source.json',{'schema':'valdoria-vegetation-source/v1','species':species,'layers':LAYER_NAMES,'variantsAreAnimation':False});subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'assemble.lua')],check=True);return pack_library(out)

def export_library(source,output):
 # Copy editable source set, then export the actual edited layers; never regenerate branch geometry.
 source=Path(source);out=common.refuse(output);out.mkdir(parents=True);meta=json.loads((source/'source.json').read_text());(out/'source.json').write_bytes((source/'source.json').read_bytes());lua='local root=app.params["root"]\n'
 for item in meta['species']:
  kind=item['id'];(out/(kind+'.aseprite')).write_bytes((source/(kind+'.aseprite')).read_bytes());lua+=f'local s=app.open(root.."/{kind}.aseprite");assert(#s.frames==3 and #s.layers==6 and s.width=={item["canvas"][0]} and s.height=={item["canvas"][1]},"Vegetation source contract")\n'
  for v in range(3):
   for part,indices in [('shadow',[1]),('trunk',[2,3]),('crown',[4,5,6])]:
    lua+='for _,l in ipairs(s.layers) do l.isVisible=false end;'
    for i in indices:lua+=f's.layers[{i}].isVisible=true;'
    lua+=f'local im=Image(s.spec);im:drawSprite(s,{v+1});im:saveAs(root.."/{kind}-v{v}-{part}.png")\n'
  lua+='s:close()\n'
 (out/'export.lua').write_text(lua);subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'export.lua')],check=True);return pack_library(out)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['library','export-library']);p.add_argument('--output',required=True);p.add_argument('--source');a=p.parse_args();library(a.output) if a.command=='library' else export_library(a.source,a.output)
