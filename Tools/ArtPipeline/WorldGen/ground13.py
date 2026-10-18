"""Ground13: visual terracing, authored water replay and lossless plant packing.

No edits to WorldRegion, water/navigation/physics, approved sources or old assets.
All visual outputs are offline; Aseprite remains the pixel authority.
"""
import argparse,json,math,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import environment_finish12 as e
import environment_geometry as geo
import terrain_materials as m

ROOT=e.ROOT;BASE=ROOT/'ArtSource/Labs/World2026/Ground13';VERSION='valdoria-ground13/1.0.0'
RELIEF=ROOT/'ArtSource/Labs/World2026/WorldStudio04/BuildR6/A/relief-field.json'

def read(p):return e.read(p)
def write(p,d):e.write(p,d)
def ref(p):return e.n.arch.ref(p)
def refuse(p):return e.refuse(p)
def manifest(out,inputs):
 write(out/'manifest.json',{'schema':'valdoria-ground13-build/v1','version':VERSION,'inputs':inputs,'files':{p.name:e.n.common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'}})

def author():
 out=refuse(BASE/'SourceV1');out.mkdir(parents=True)
 shutil.copyfile(e.BASE/'SourceV1/sandstone-planes.aseprite',out/'stratified-face.aseprite')
 shutil.copyfile(e.g.SOURCE/'meadow.aseprite',out/'upland-sward.aseprite')
 # Native pixel motifs, not random sparkle: four shapes, four coherent loop phases.
 code='local s=Sprite(128,128,ColorMode.RGB);s.layers[1].name="Broken ripple recess";for _,name in ipairs({"Sky reflection groups","Fine moving crests","Shallow sediment accents"}) do local l=s:newLayer();l.name=name end;'
 for phase in range(4):
  code+=('s:newEmptyFrame();' if phase else '')+f's.frames[{phase+1}].duration=.18;local images={{Image(s.spec),Image(s.spec),Image(s.spec),Image(s.spec)}};'
  shift=[0,1,2,1][phase];alpha=[58,70,79,70][phase]
  shapes=[[(9,20,14),(18,24,9),(11,29,5)],[(75,17,10),(82,21,13),(73,29,6)],[(12,84,18),(24,89,7)],[(79,87,16),(88,92,11),(77,97,7)]]
  for variant,lines in enumerate(shapes):
   for j,(x,y,length) in enumerate(lines):
    for k in range(length):
     if k in (3,4) and j==1:continue
     yy=y+(1 if k>length*.65 else 0);xx=x+k+shift
     code+=f'images[2]:drawPixel({xx},{yy},app.pixelColor.rgba(149,181,153,{alpha}));'
     if k<length*.55:code+=f'images[1]:drawPixel({xx},{yy+2},app.pixelColor.rgba(34,72,73,22));'
     if j==0 and 2<k<length-2:code+=f'images[3]:drawPixel({xx},{yy-1},app.pixelColor.rgba(178,201,172,{alpha//2}));'
  for x,y in [(21,43),(43,39),(91,48),(108,40),(25,111),(39,104),(94,116)]:
   for dx,dy,col in [(0,0,(102,119,84)),(1,0,(131,145,100)),(1,1,(76,103,83))]:code+=f'images[4]:drawPixel({x+dx},{y+dy},app.pixelColor.rgba({col[0]},{col[1]},{col[2]},38));'
  code+=f'for i,l in ipairs(s.layers) do s:newCel(l,{phase+1},images[i],Point(0,0)) end;'
 code+=f's:saveAs({e.n.q(out/"water-material.aseprite")});s:close();'
 e.n.lua(code,out/'initial-water-authoring.lua')
 write(BASE/'recipe.json',{'schema':'valdoria-ground13-recipe/v1','version':VERSION,'seed':910213,'ppu':32,'physicalChange':False,'strategy':'B-visual-representation-only','thresholds':[0,.65,1.6],'heights':[.45,1.5,2.9],'bankExtentPixels':18,'waterPhaseMs':180,'waterDeepScalar':.012,'light':'upper-left','artisticStatus':'candidate','capFacets':[{'bounds':[41,22,55,36],'planes':[[1,.45,-64.5],[-.35,1,-14.0],[-1,0,44],[0,-1,25]]}]})

def export(out,source=BASE/'SourceV2'):
 out=refuse(out);out.mkdir(parents=True);source=Path(source);code=''
 for name in ['stratified-face','upland-sward','water-material']:
  code+=f'do local s=app.open({e.n.q(source/(name+".aseprite"))});'
  if name=='water-material':
   code+='assert(s.width==128 and s.height==128 and #s.frames==4,"Water source contract");'
   code+=f'for f=1,4 do local im=Image(s.spec);im:drawSprite(s,f);im:saveAs({e.n.q(out)}.."/water-motifs-"..(f-1)..".png") end;'
  else:code+=f'local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({e.n.q(out/(name+".png"))});'
  code+='s:close() end\n'
 e.n.lua(code,out/'export.lua');manifest(out,{p.name:ref(p) for p in source.glob('*.aseprite')})

def atlas(out):
 """Keep legacy used UV rectangles in place; pack new images into unused space.

 The atlas is for explicitly UV-mapped meshes, not a Unity SpriteAtlas asset.
 """
 out=refuse(out);out.mkdir(parents=True);old=ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaVisual09/vegetation-atlas.png';im=Image.open(old).convert('RGBA');W,H=im.size;occupied=np.zeros((H,W),bool)
 meta=read(ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5/sprites.json');used=[]
 for s in meta['sprites']:
  if s['species'] not in ('wildflowers','drygrass'):continue
  x,y,w,h=s['rectPixels'];occupied[max(0,y-2):y+h+2,max(0,x-2):x+w+2]=True;used.append(s['rectPixels'])
 records={old.relative_to(ROOT).as_posix():{'originalSize':[W,H],'sourceRect':[0,0,W,H],'rect':[0,0,W,H],'identityForProtectedRects':used}}
 folder=ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaGround12'
 inputs={'legacy':ref(old),'legacyRects':ref(ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5/sprites.json')}
 for name in ['hazel-layered-body','reeds-open-body','fern-0-body','fern-1-body','elm-vase-shadow','hornbeam-open-shadow']:
  src=folder/(name+'.png');raw=Image.open(src).convert('RGBA');box=raw.getbbox() if 'shadow' in name else (0,0,*raw.size);tile=raw.crop(box);w,h=tile.size;place=None
  for y in range(2,H-h-2,2):
   for x in range(2,W-w-2,2):
    if not occupied[y-2:y+h+2,x-2:x+w+2].any():place=x,y;break
   if place:break
  if place is None:raise ValueError('Atlas has no protected free rectangle')
  x,y=place;im.paste(tile,(x,y));occupied[y-2:y+h+2,x-2:x+w+2]=True
  # Extrude2px so Point sampling at a UV edge cannot borrow another family.
  for pad in (1,2):
   im.paste(tile.crop((0,0,w,1)),(x,y-pad));im.paste(tile.crop((0,h-1,w,h)),(x,y+h-1+pad));im.paste(tile.crop((0,0,1,h)),(x-pad,y));im.paste(tile.crop((w-1,0,w,h)),(x+w-1+pad,y))
  records[src.relative_to(ROOT).as_posix()]={'originalSize':list(raw.size),'sourceRect':list(box),'rect':[x,y,w,h]};inputs[name]=ref(src)
 im.save(out/'plants-shared.png');write(out/'atlas.json',{'schema':'valdoria-ground13-atlas/v1','size':[W,H],'entries':records,'pixelChanges':'None in sampled rectangles; unused legacy atlas space repurposed','rotation':False,'scale':1,'padding':2});manifest(out,inputs)

def clip(poly,slot,positive=True):
 result=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  sa=a[slot]*(1 if positive else -1);sb=b[slot]*(1 if positive else -1)
  if sa>=-1e-10:result.append(a)
  if (sa>=0)!=(sb>=0):result.append(a+(b-a)*sa/(sa-sb))
 return result

def relief(out,recipe=BASE/'recipe.json'):
 out=refuse(out);out.mkdir(parents=True);r=read(recipe)
 if r['physicalChange'] or r['strategy']!='B-visual-representation-only':raise ValueError('No physical change authorized')
 field=read(RELIEF);samples=np.array(field['samples']);s=samples[:,:,0];step=field['stepUnits'];H,W=s.shape;yy,xx=np.mgrid[:H,:W]*step;s1=s-r['thresholds'][1]
 for f in r.get('shoulderFacets',[]):
  x0,y0,x1,y1=f['bounds'];mask=(xx>=x0)&(xx<=x1)&(yy>=y0)&(yy<=y1)
  for a,b,c in f['planes']:s1=np.where(mask,np.minimum(s1,-(a*xx+b*yy+c)),s1)
 s2=np.minimum(s-r['thresholds'][2],s1-.55)
 for f in r['capFacets']:
  x0,y0,x1,y1=f['bounds'];mask=(xx>=x0)&(xx<=x1)&(yy>=y0)&(yy<=y1)
  for a,b,c in f['planes']:s2=np.where(mask,np.minimum(s2,-(a*xx+b*yy+c)),s2)
 heights=r['heights'];groups={};feet=[]
 def group(row,kind):return groups.setdefault((row,kind),{'row':row,'kind':kind,'vertices':[],'uv':[],'colors':[],'triangles':[]})
 def emit(poly,height,kind,colour,row):
  if len(poly)<3:return
  g=group(row,kind);start=len(g['vertices'])
  for p in poly:
   g['vertices'].append([round(float(p[0]),6),round(float(48-p[1]+height),6),0]);g['uv'].append([float(p[0]*32/384),float(-p[1]*32/384)]);g['colors'].append(list(colour))
  for i in range(1,len(poly)-1):g['triangles'].extend([start,start+i,start+i+1])
 for y in range(H-1):
  for x in range(W-1):
   if max(s[y:y+2,x:x+2].flat)<0:continue
   pts=[np.array([X*step,Y*step,s[Y,X],s1[Y,X],s2[Y,X]],float) for X,Y in [(x,y),(x+1,y),(x+1,y+1),(x,y+1)]]
   for ids in ((0,1,2),(0,2,3)):
    triangle=[pts[i] for i in ids]
    for band in range(3):
     poly=clip(triangle,2+band)
     if band<2:poly=clip(poly,3+band,False)
     # Lower ledge mineral, upper terraces sward. Shapes work without texture.
     emit(poly,heights[band],'stone' if band==0 else 'grass',([.93,.91,.85,1] if band==0 else [.76,.80,.73,1] if band==1 else [.82,.85,.77,1]),y//4)
    for band,scalar in enumerate((s,s1,s2)):
     poly=clip(triangle,2+band)
     if band and not poly:continue
     for a,b in zip(poly,poly[1:]+poly[:1]):
      if abs(a[2+band])>1e-7 or abs(b[2+band])>1e-7:continue
      if np.linalg.norm(a[:2]-b[:2])<1e-7:continue
      low=0 if band==0 else heights[band-1];high=heights[band];dx,dy=b[0]-a[0],b[1]-a[1];length=max(math.hypot(dx,dy),1e-9);light=float(np.clip(.76+(-dy/length)*.15+(dx/length)*.10,.52,.98))
      if band==0:feet.extend([[round(float(a[0]),6),round(float(a[1]),6)],[round(float(b[0]),6),round(float(b[1]),6)]])
      # Rear walls are occluded by their own upland in this fixed 3/4 projection.
      # Emitting them as transparent 2D meshes would paint a false retaining ring.
      if dx>=-1e-9:continue
      g=group(y//4,'stone');start=len(g['vertices'])
      for p,h in [(a,low),(b,low),(b,high),(a,high)]:
       g['vertices'].append([round(float(p[0]),6),round(float(48-p[1]+h),6),0]);g['uv'].append([float(p[0]*32/384),float((48-p[1]+h)*32/384)]);v=light*(.82 if h==low else 1);g['colors'].append([v,v*.97,v*.90,1])
      g['triangles'].extend([start,start+2,start+1,start,start+3,start+2])
 write(out/'visual-relief.json',{'schema':'valdoria-visual-relief/v1','strategy':r['strategy'],'physicalChange':False,'heightIsPresentationOnly':True,'thresholds':r['thresholds'],'heights':heights,'groups':list(groups.values()),'groundFeet':feet,'physicalLoops':read(e.HYDRO/'geometry.json')['rockLoops']});manifest(out,{'relief':ref(RELIEF),'geometry':ref(e.HYDRO/'geometry.json'),'recipe':ref(recipe)})

def water(out,library=BASE/'ExportV2',recipe=BASE/'recipe.json'):
 out=refuse(out);out.mkdir(parents=True);r=read(recipe);render=read(e.HYDRO/'water-render.json');surface=np.array(Image.open(e.HYDRO/'surface.png'))>0;depth=np.array(Image.open(e.HYDRO/'depth.png')).astype(float)/65535;H,W=surface.shape;Y,X=np.mgrid[:H,:W];seed=r['seed'];inside=distance_transform_edt(surface);outside=distance_transform_edt(~surface);flow=np.array(Image.open(e.HYDRO/'flow.png').convert('RGBA'))
 base=np.array(Image.open(e.BASE/'BuildV2/ground-bank.png').convert('RGBA'));coverage=m.Context().masks['coverage'];edge=np.clip(1-outside/r['bankExtentPixels'],0,1)*(~surface)*(coverage==0);patch=np.clip((m.field(X,Y,33,seed+4)-.38)*2,0,.8);soil=e.g.sample_paint('earth',X,Y,seed);influence=edge*(.08+patch*.14);base[:,:,:3]=np.clip(np.rint(base[:,:,:3]*(1-influence[...,None])+soil*.8*influence[...,None]),0,255).astype('uint8')
 Image.fromarray(base).save(out/'bank-ground.png');Image.fromarray(np.rint(edge*255).astype('uint8')).save(out/'bank-influence.png')
 t=np.clip(depth/r['waterDeepScalar'],0,1);t=np.round(t*18)/18
 values=np.array([102,143,122])*(1-t[...,None])+np.array([38,79,89])*t[...,None]
 broad=m.field(X,Y,94,seed+21);rest=m.field(X,Y,157,seed+23);values*=1+((broad-.5)*.075)[...,None]
 # Narrow value contacts vary by shoreline context, never a constant width outline.
 width=3+7*m.field(X,Y,41,seed+25);rim=np.clip(1-inside/width,0,1)*surface;sediment=np.array([94,113,90]);values=values*(1-rim[...,None]*.38)+sediment*rim[...,None]*.38
 motifs=[Image.open(Path(library)/f'water-motifs-{f}.png').convert('RGBA') for f in range(4)];frames=[]
 for phase in range(4):
  image=Image.fromarray(np.clip(np.rint(values),0,255).astype('uint8')).convert('RGBA');overlay=Image.new('RGBA',(W,H))
  # Global parent anchors with quiet areas, not a repeating tile of glints.
  for gy in range(H//62+1):
   for gx in range(W//78+1):
    px=int((gx+float(m.ihash(gx,gy,seed+31)))*78);py=int((gy+float(m.ihash(gx,gy,seed+33)))*62)
    if not (4<=px<W-4 and 4<=py<H-4 and surface[py,px] and inside[py,px]>6 and rest[py,px]>.38):continue
    variant=int(m.ihash(gx,gy,seed+35)*4)%4;f=(phase+int(m.ihash(gx,gy,seed+37)*4))%4;tile=motifs[f].crop((variant%2*64,variant//2*64,variant%2*64+64,variant//2*64+64));arr=np.array(tile);arr[:,:,3]=np.rint(arr[:,:,3]*(.65 if depth[py,px]<.002 else .95)).astype('uint8');overlay.alpha_composite(Image.fromarray(arr),(px-32,py-32))
  image=Image.alpha_composite(image,overlay);frames.append(np.array(image))
 for chunk in render['chunks']:
  x,y,w,h=chunk['rectPixels']
  for phase,name in enumerate(chunk['frames']):
   original=np.array(Image.open(e.HYDRO/name).convert('RGBA'));a=original[:,:,3].copy();v=frames[phase][y:y+h,x:x+w,:3];deep=np.clip(inside[y:y+h,x:x+w]/3,0,1);original[:,:,:3]=np.clip(np.rint(v*deep[...,None]+original[:,:,:3]*(1-deep[...,None])),0,255).astype('uint8');assert np.array_equal(original[:,:,3],a);Image.fromarray(original).save(out/name)
 write(out/'water.json',{'schema':'valdoria-water-finish/v1','seed':seed,'chunks':render['chunks'],'durationMs':180,'functionalMasksChanged':False,'worldOrigin':[0,0],'sampling':'global motifs and fields, cropped after all phases; no per-chunk phase restart','simulation':'authored pixel material replay, no hydraulic simulation'});manifest(out,{'library':ref(Path(library)/'manifest.json'),'recipe':ref(recipe),'hydrology':ref(e.HYDRO/'manifest.json'),'ground12':ref(e.BASE/'BuildV2/manifest.json')})

def verify(folder):
 d=read(Path(folder)/'manifest.json')
 for name,sha in d['files'].items():
  if Path(name).name!=name or e.n.common.sha((Path(folder)/name).read_bytes())!=sha:raise ValueError('Output '+name)
 for v in d['inputs'].values():
  if e.n.common.sha((ROOT/v['path']).read_bytes())!=v['sha256']:raise ValueError('Input '+v['path'])
 return {'passed':True,'files':len(d['files'])}

def main():
 p=argparse.ArgumentParser();p.add_argument('action',choices=['author','export','atlas','relief','water','verify']);p.add_argument('--output',type=Path);a=p.parse_args()
 if a.action=='author':author()
 elif a.action=='export':export(a.output)
 elif a.action=='atlas':atlas(a.output)
 elif a.action=='relief':relief(a.output)
 elif a.action=='water':water(a.output)
 else:print(json.dumps(verify(a.output)))

if __name__=='__main__':main()
