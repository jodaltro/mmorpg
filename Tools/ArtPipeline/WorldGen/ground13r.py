"""Ground13R visual-only geology. Physical scalar/foot and Ground13 water are inputs."""
import argparse, json, math, shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
from scipy.spatial import cKDTree
import ground13 as g

ROOT=g.ROOT; BASE=ROOT/'ArtSource/Labs/World2026/Ground13R'
VERSION='valdoria-ground13r/1.0.0'
def write(p,d):
 p=Path(p);p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'),sort_keys=True)+'\n',encoding='utf-8',newline='\n')
def manifest(out,inputs):
 write(out/'manifest.json',{'schema':'valdoria-ground13r-build/v1','version':VERSION,'inputs':inputs,'files':{p.name:g.e.n.common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'}})
def recipe():
 p=BASE/'recipe.json'
 if p.exists():raise FileExistsError(p)
 # Contours and fracture mouths are authored composition, not seeded contour jitter.
 formations=[
  dict(id='southern-bluff',bounds=[42,23,54,35],atlas=[0,0,384,384],upper=[[43.7,27.5],[44.8,25.7],[46.7,25],[48.2,25.4],[49.1,25.1],[50.4,26.1],[50.9,27.4],[50.4,28.5],[51.3,29.5],[50.7,30.7],[49.3,31.2],[48.7,30.6],[47.5,31.5],[45.8,31.1],[45.4,29.9],[44.3,29.6]],faults=[dict(points=[[50.9,35],[50.2,33.6],[49.3,32.5],[49,31.2],[48.3,30.3]],width=.52,depth=1.0),dict(points=[[42.1,29.7],[43.1,29.1],[44.4,28.9],[45,28.1]],width=.43,depth=.72)],dense=[[45.8,26.8,1.5,.9],[49.4,27.8,1.2,.8],[46.6,30.4,1.1,.65]],clearings=[[47.2,28.3,1.1,.8],[44,31,.8,1.1]]),
  dict(id='western-scarp',bounds=[16,8,29,19],atlas=[384,0,416,352],upper=[[18.3,11.1],[20,9.7],[22.1,10.1],[23.2,9.6],[25.6,11.1],[26.1,12.4],[25.5,13.8],[26,15],[24.3,16.1],[22.8,15.6],[21,16.5],[19.3,15.3],[19.5,13.4],[18.1,12.7]],faults=[dict(points=[[24.6,19],[24.1,17.5],[23.2,16.5],[22.7,15.5],[22,14.7]],width=.62,depth=.95)],dense=[[21.7,11.8,1.5,.9],[24.1,13.8,1.4,.8]],clearings=[[20.8,14.2,1.0,.65]]),
  dict(id='northern-outcrop',bounds=[48,4,57,10],atlas=[384,352,288,192],upper=[[49.6,6],[50.8,5.2],[52.2,5.4],[53.1,5],[54.7,6],[54.2,7.2],[54.9,7.7],[53.5,8.6],[52.1,8.1],[50.7,8.5],[49.8,7.3]],faults=[dict(points=[[52.2,10],[52.3,8.9],[51.8,8.1],[51.8,7.3]],width=.45,depth=.7)],dense=[[52.6,6.5,1.0,.65]],clearings=[[50.8,6.3,.65,.45]])]
 write(p,dict(schema='valdoria-ground13r-recipe/v1',version=VERSION,seed=910213,ppu=32,physicalChange=False,strategy='B-visual-representation-only',atlasSize=[800,544],formations=formations,baseHeight=1.92,capRelief=.93,capTransition=.58,edgeDrop=.47,artisticStatus='candidate-not-approved'))

def curve(points,closed=False):
 p=np.array(points,float);result=[]
 for i in range(len(p) if closed else len(p)-1):
  a=p[(i-1)%len(p)] if closed or i else p[0];b=p[i];c=p[(i+1)%len(p)];d=p[(i+2)%len(p)] if closed or i+2<len(p) else p[-1]
  for t in np.linspace(0,1,max(4,int(np.linalg.norm(c-b)/.06)),endpoint=False):
   result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
 if not closed:result.append(p[-1])
 return np.array(result)
def distance(points,x,y,closed=False):
 q=curve(points,closed);shape=x.shape;flat=np.column_stack([x.ravel(),y.ravel()]);d,_=cKDTree(q).query(flat);d=d.reshape(shape)
 if not closed:return d
 inside=np.zeros(shape,bool)
 for a,b in zip(q,np.roll(q,-1,axis=0)):
  if abs(a[1]-b[1])<1e-12:continue
  inside^=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])
 return np.where(inside,d,-d)
def smooth(v):v=np.clip(v,0,1);return v*v*(3-2*v)
def fields(r):
 old=g.read(g.RELIEF);original=np.array(old['samples'])[:,:,0];step=r.get('visualStepUnits',.125);ratio=round(old['stepUnits']/step);assert ratio==2
 # Refine only the visual triangulation, exactly interpolating the physical producer's diagonal split.
 fy,fx=np.mgrid[:(original.shape[0]-1)*ratio+1,:(original.shape[1]-1)*ratio+1]/ratio
 ix=np.minimum(fx.astype(int),original.shape[1]-2);iy=np.minimum(fy.astype(int),original.shape[0]-2);u=fx-ix;v=fy-iy
 tl=original[iy,ix];tr=original[iy,ix+1];br=original[iy+1,ix+1];bl=original[iy+1,ix]
 s=np.where(u>=v,tl+(tr-tl)*u+(br-tr)*v,tl+(br-bl)*u+(bl-tl)*v);y=fy*old['stepUnits'];x=fx*old['stepUnits']
 h=np.zeros(s.shape);owner=np.full(s.shape,-1);cap=np.zeros(s.shape);fault=np.zeros(s.shape)
 for k,f in enumerate(r['formations']):
  x0,y0,x1,y1=f['bounds'];mask=(x>=x0-.5)&(x<=x1+.5)&(y>=y0-.5)&(y<=y1+.5);sd=distance(f['upper'],x,y,True);mesa=smooth((sd+r['capTransition']*.5)/r['capTransition']);cut=np.zeros(s.shape)
  for trace in f['faults']:cut=np.maximum(cut,trace['depth']*np.exp(-(distance(trace['points'],x,y)/trace['width'])**2))
  # Broad tilted bedding, a recessed shoulder, and authored incisions. No closed constant-height extrusion.
  z=r['baseHeight']+.16*(1-(y-y0)/(y1-y0))+.11*(x-x0)/(x1-x0)+r['capRelief']*mesa-r['edgeDrop']*(1-smooth(s/.95))-cut
  h=np.where(mask,np.maximum(.38,z),h);owner=np.where(mask,k,owner);cap=np.where(mask,mesa,cap);fault=np.where(mask,cut,fault)
 dy,dx=np.gradient(h,step);slope=np.hypot(dx,dy)
 return dict(s=s,h=h,owner=owner,cap=cap,fault=fault,slope=slope,dx=dx,dy=dy,step=step)

def relief(out,recipe_path=BASE/'recipe.json'):
 out=g.refuse(out);out.mkdir(parents=True);r=g.read(recipe_path);assert not r['physicalChange'];a=fields(r);s=a['s'];h=a['h'];owner=a['owner'];step=a['step'];groups={};feet=[];AW,AH=r['atlasSize']
 def group(row,kind):return groups.setdefault((row,kind),dict(row=row,kind=kind,vertices=[],uv=[],colors=[],triangles=[]))
 def height(p):return float(map_coordinates(h,[[p[1]/step],[p[0]/step]],order=1,mode='nearest')[0])
 def push(poly,row,kind,k):
  gg=group(row,'mixed');start=len(gg['vertices']);f=r['formations'][k];x0,y0,_,_=f['bounds'];ax,ay,w,hh=f['atlas'];gg.setdefault('selector',[])
  for p,z,light in poly:
   gg['vertices'].append([round(float(p[0]),6),round(float(48-p[1]+z),6),0]);gg['uv'].append([(ax+(p[0]-x0)*32)/AW,1-(ay+(p[1]-y0)*32)/AH] if kind=='top' else [float(p[0]*32/384),float((48-p[1]+z)*32/384)]);gg['colors'].append([float(light),float(light*.99),float(light*.96),1])
   gg['selector'].append([0 if kind=='top' else 1,0])
  for i in range(1,len(poly)-1):gg['triangles'].extend([start,start+i,start+i+1])
 for y in range(s.shape[0]-1):
  for x in range(s.shape[1]-1):
   if max(s[y:y+2,x:x+2].flat)<0:continue
   k=int(owner[y,x]);assert k>=0
   pts=[np.array([X*step,Y*step,s[Y,X]],float) for X,Y in [(x,y),(x+1,y),(x+1,y+1),(x,y+1)]]
   for ids in ((0,1,2),(0,2,3)):
    poly=g.clip([pts[i] for i in ids],2)
    if len(poly)<3:continue
    zs=[height(p) for p in poly];projected=np.array([[p[0],48-p[1]+z] for p,z in zip(poly,zs)])
    # Discard rear-facing folds, preserving every physical foot below for the contract.
    signed=sum((projected[i,0]-projected[0,0])*(projected[i+1,1]-projected[0,1])-(projected[i,1]-projected[0,1])*(projected[i+1,0]-projected[0,0]) for i in range(1,len(poly)-1))
    if signed<0:
     values=[]
     for p,z in zip(poly,zs):
      sample=lambda key:float(map_coordinates(a[key],[[p[1]/step],[p[0]/step]],order=1,mode='nearest')[0])
      light=float(np.clip(.96+.11*(-sample('dx')+sample('dy'))-.09*sample('slope'),.63,1.04));values.append((p,z,light))
     # Steep faces use the unchanged vertical mineral material and screen-scaled UVs.
     # Horizontal atlas UVs on a cliff would stretch each painted pixel into a stripe.
     kind='stone' if a['slope'][y,x]>r.get('mineralFaceSlope',.70) else 'top'
     push(values,int(y*step),kind,k)
    for p,q in zip(poly,poly[1:]+poly[:1]):
     if abs(p[2])>1e-7 or abs(q[2])>1e-7 or np.linalg.norm(q[:2]-p[:2])<1e-7:continue
     feet.extend([[round(float(v[0]),6),round(float(v[1]),6)] for v in [p,q]])
     dx,dy=q[0]-p[0],q[1]-p[1]
     if dx>=-1e-9:continue
     light=float(np.clip(.77+(-dy)*.14/max(math.hypot(dx,dy),1e-6)+dx*.08/max(math.hypot(dx,dy),1e-6),.52,.96))
     push([(p,0,light*.80),(q,0,light*.80),(q,height(q),light),(p,height(p),light)],int(y*step),'stone',k)
 before=sum(len(gg['vertices']) for gg in groups.values())
 for gg in groups.values():
  # Share only GPU-bit-identical corner data. Never reorder triangles or smooth a seam.
  attributes=['vertices','uv','colors','selector'];new={key:[] for key in attributes};lookup={};remap=[]
  for i in range(len(gg['vertices'])):
   key=np.array([v for name in attributes for v in gg[name][i]],dtype=np.float32).tobytes()
   if key not in lookup:
    lookup[key]=len(new['vertices'])
    for name in attributes:new[name].append(gg[name][i])
   remap.append(lookup[key])
  gg['triangles']=[remap[i] for i in gg['triangles']]
  gg.update(new)
 write(out/'visual-relief.json',dict(schema='valdoria-visual-relief/v1',version=VERSION,strategy=r['strategy'],physicalChange=False,heightIsPresentationOnly=True,vertexCompaction=dict(before=before,after=sum(len(gg['vertices']) for gg in groups.values()),rule='identical float32 position/uv/color/selector; triangle order preserved'),groups=list(groups.values()),groundFeet=feet,physicalLoops=g.read(g.e.HYDRO/'geometry.json')['rockLoops']))
 manifest(out,{'recipe':g.ref(recipe_path),'physicalScalar':g.ref(g.RELIEF),'physicalBoundary':g.ref(g.e.HYDRO/'geometry.json')})

def paint_layers(recipe_path=BASE/'recipe.json'):
 r=g.read(recipe_path);a=fields(r);AW,AH=r['atlasSize'];layers={name:np.zeros((AH,AW,4),np.uint8) for name in ['Quiet sward - Ground11','Foliage pockets','Soil recesses','Exposed mineral planes','Broken contact joints']};metrics=[]
 for f in r['formations']:
  x0,y0,x1,y1=f['bounds'];ax,ay,w,hh=f['atlas'];Y,X=np.mgrid[:hh,:w];x=x0+(X+.5)/32;y=y0+(Y+.5)/32
  sample=lambda key:map_coordinates(a[key],[y/a['step'],x/a['step']],order=1,mode='nearest')
  slope=sample('slope');edge=sample('s');fault=sample('fault');cap=sample('cap');dense=np.zeros(x.shape);clearing=np.zeros(x.shape)
  for cx,cy,rx,ry in f['dense']:dense=np.maximum(dense,np.exp(-(((x-cx)/rx)**2+((y-cy)/ry)**2)*1.8))
  for cx,cy,rx,ry in f['clearings']:
   outline=[[cx+u*rx,cy+v*ry] for u,v in [[-.9,-.2],[-.45,-.7],[.2,-.8],[.6,-.3],[.9,-.1],[.65,.5],[0,.65],[-.5,.4]]]
   clearing=np.maximum(clearing,smooth((distance(outline,x,y,True)+.28)/.55))
  meadow=g.e.g.sample_paint('meadow',x*32,y*32,r['seed']);earth=g.e.g.sample_paint('earth',x*32,y*32,r['seed']+29)
  stone=np.array(Image.open(g.BASE/'ExportV2/stratified-face.png').convert('RGB'));mineral=stone[np.floor((y-sample('h'))*32).astype(int)%384,np.floor(x*32).astype(int)%384].astype(float)
  mean=np.array([91,112,48]);quiet=mean+(meadow-mean)*.25
  # Coverage follows slope, incisions and authored clearings. Source luminance breaks the contact in pixel clusters.
  pigment=(earth[:,:,0]-earth[:,:,1])*.002+(meadow[:,:,1]-112)*.0014
  rock=np.clip((slope-.48)*1.3+fault*.27+np.clip(.48-edge,0,1)*.30+pigment,0,1)
  soil=np.clip(clearing*.95+fault*.35+np.clip(.75-cap,0,1)*.15-rock*.40,0,1)
  rock=np.round(rock*6)/6;soil=np.round(soil*6)/6
  grass=mean+(meadow-mean)*(.25+dense[:,:,None]*.60)
  region=lambda im:im[ay:ay+hh,ax:ax+w]
  region(layers['Quiet sward - Ground11'])[:,:,:3]=np.clip(np.rint(quiet),0,255).astype('uint8');region(layers['Quiet sward - Ground11'])[:,:,3]=255
  region(layers['Foliage pockets'])[:,:,:3]=np.clip(np.rint(grass),0,255).astype('uint8');region(layers['Foliage pockets'])[:,:,3]=np.rint(dense*255).astype('uint8')
  region(layers['Soil recesses'])[:,:,:3]=np.clip(np.rint(earth*.86),0,255).astype('uint8');region(layers['Soil recesses'])[:,:,3]=np.rint(soil*255).astype('uint8')
  region(layers['Exposed mineral planes'])[:,:,:3]=np.clip(np.rint(mineral*.98),0,255).astype('uint8');region(layers['Exposed mineral planes'])[:,:,3]=np.rint(rock*255).astype('uint8')
  joint=(fault>.48)&(slope>.65)&((earth[:,:,0]-earth[:,:,2])>36);region(layers['Broken contact joints'])[:,:,:3]=np.array([61,66,43],np.uint8);region(layers['Broken contact joints'])[:,:,3]=joint.astype('uint8')*35
  inside=edge>0;metrics.append(dict(id=f['id'],mineralFraction=float((rock[inside]>.5).mean()),soilFraction=float((soil[inside]>.5).mean()),quietFraction=float(((dense[inside]<.2)&(rock[inside]<.5)&(soil[inside]<.5)).mean())))
 return layers,metrics

def author():
 out=g.refuse(BASE/'SourceV2');out.mkdir(parents=True);layers,metrics=paint_layers();code='local s=Sprite(800,544,ColorMode.RGB);s:deleteLayer(s.layers[1]);'
 for i,(name,arr) in enumerate(layers.items()):
  file=out/f'layer-{i}.png';Image.fromarray(arr).save(file);code+=f'do local raw=app.open({g.e.n.q(file)});local im=Image(s.spec);im:drawSprite(raw,1);raw:close();local l=s:newLayer();l.name={json.dumps(name)};s:newCel(l,1,im,Point(0,0)) end;'
 code+=f's:saveAs({g.e.n.q(out/"upland-contacts.aseprite")});s:close();';g.e.n.lua(code,out/'initial-contact-authoring.lua');write(out/'composition.json',dict(schema='valdoria-upland-contacts/v1',version=VERSION,metrics=metrics,inputs={'recipe':g.ref(BASE/'recipe.json'),'meadow':g.ref(g.e.g.SOURCE/'meadow.aseprite'),'earth':g.ref(g.e.g.SOURCE/'earth.aseprite'),'stone':g.ref(g.BASE/'SourceV2/stratified-face.aseprite')},authority='upland-contacts.aseprite; export does not regenerate pixels'))

def export(out):
 out=g.refuse(out);out.mkdir(parents=True);source=BASE/'SourceV4/upland-contacts.aseprite';code=f'local s=app.open({g.e.n.q(source)});assert(s.width==800 and s.height==544 and #s.layers==6);local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({g.e.n.q(out/"top-atlas.png")});s:close();';g.e.n.lua(code,out/'export.lua');manifest(out,{'source':g.ref(source)})

def bedrock():
 out=g.refuse(BASE/'SourceV4');out.mkdir(parents=True);source=BASE/'SourceV3/upland-contacts.aseprite';shutil.copyfile(source,out/source.name);r=g.read(BASE/'recipe.json');a=fields(r);AW,AH=r['atlasSize'];overlay=np.zeros((AH,AW,4),np.uint8)
 patches=[[[[47.9,29.15],[48.6,29.45],[48.7,30.1],[49.25,30.55],[49.3,31.35],[48.65,31.2],[48,30.55],[47.6,30.15],[47.7,29.7]],[[43.7,28.4],[44.1,27.8],[45.1,27.7],[45.6,28.1],[45.3,28.9],[44.7,29],[44.3,28.7]],[[49.8,26.2],[50.5,26.3],[50.9,27.1],[50.3,27.9],[49.7,27.4],[49.9,26.9]]],[[[21.4,14.3],[22.2,14.3],[22.8,15.1],[23.3,15.6],[23.5,16.4],[22.8,16.4],[22.1,15.6],[21.4,15.1]]],[[[51.2,7],[52,7.1],[52.3,7.9],[52.7,8.9],[52,8.8],[51.5,8.2],[50.9,7.8]]]]
 soil_shapes=[[[[46.4,28.1],[47.3,27.9],[48,28.6],[48.3,29.4],[47.9,29.8],[47.1,29.3],[46.8,28.7],[46.2,28.6]]],[],[]]
 for k,f in enumerate(r['formations']):
  x0,y0,_,_=f['bounds'];ax,ay,w,hh=f['atlas'];Y,X=np.mgrid[:hh,:w];x=x0+(X+.5)/32;y=y0+(Y+.5)/32;sd=np.maximum.reduce([distance(p,x,y,True) for p in patches[k]]);soil=np.zeros(x.shape)
  for p in soil_shapes[k]:soil=np.maximum(soil,smooth((distance(p,x,y,True)+.2)/.4)*.8)
  earth=g.e.g.sample_paint('earth',x*32,y*32,r['seed']+29);height=map_coordinates(a['h'],[y/a['step'],x/a['step']],order=1);stone=np.array(Image.open(g.BASE/'ExportV2/stratified-face.png').convert('RGB'));pigment=stone[np.floor((y-height)*32).astype(int)%384,np.floor(x*32).astype(int)%384].astype(float)
  # A soil apron and broken native-pixel clusters seat bedrock tongues into the sward.
  mineral=np.round(smooth((sd+.08+(earth[:,:,0]-147)*.0015)/.22)*6)/6;apron=smooth((sd+.34)/.5)*.58;soil=np.maximum(soil,apron);alpha=soil+mineral*(1-soil);rgb=(earth*.84*soil[:,:,None]*(1-mineral[:,:,None])+pigment*mineral[:,:,None])/np.maximum(alpha[:,:,None],1e-6)
  overlay[ay:ay+hh,ax:ax+w,:3]=np.clip(np.rint(rgb),0,255).astype('uint8');overlay[ay:ay+hh,ax:ax+w,3]=np.rint(alpha*255).astype('uint8')
 Image.fromarray(overlay).save(out/'bedrock-tongues.png');code=f'local s=app.open({g.e.n.q(out/source.name)});local raw=app.open({g.e.n.q(out/"bedrock-tongues.png")});local im=Image(s.spec);im:drawSprite(raw,1);raw:close();local l=s:newLayer();l.name="Bedrock tongues and soil aprons";s:newCel(l,1,im,Point(0,0));s:saveAs({g.e.n.q(out/source.name)});s:close();';g.e.n.lua(code,out/'bedrock-contact-edit.lua');write(out/'contact-recipe.json',dict(schema='valdoria-upland-paint-patch/v1',rockPolygons=patches,soilPolygons=soil_shapes,source=g.ref(source),geometryRecipe=g.ref(BASE/'recipe.json'),physicalChange=False,authority='upland-contacts.aseprite'))

def refine_contacts():
 out=g.refuse(BASE/'SourceV3');out.mkdir(parents=True);source=BASE/'SourceV2/upland-contacts.aseprite';shutil.copyfile(source,out/source.name)
 code=f'local s=app.open({g.e.n.q(out/source.name)});for _,l in ipairs(s.layers) do if l.name=="Exposed mineral planes" then local cel=l:cel(1);local im=Image(cel.image);local levels={{0,2,4,5,6,6,6}};for y=0,im.height-1 do for x=0,im.width-1 do local c=im:getPixel(x,y);local a=app.pixelColor.rgbaA(c);local k=math.floor(a/255*6+.5);im:drawPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),math.floor(levels[k+1]/6*255+.5))) end end;cel.image=im end end;s:saveAs({g.e.n.q(out/source.name)});s:close();'
 g.e.n.lua(code,out/'final-mineral-contact-edit.lua');write(out/'provenance.json',dict(schema='valdoria-upland-contact-edit/v1',input=g.ref(source),recipe=g.ref(BASE/'recipe.json'),edit='Strengthen existing slope/fracture mineral clusters at the soil contact; leave quiet clearings and source RGB unchanged',authority='upland-contacts.aseprite'))

def main():
 p=argparse.ArgumentParser();p.add_argument('action',choices=['recipe','relief','author','refine-contacts','bedrock','export','verify']);p.add_argument('--output',type=Path);a=p.parse_args()
 if a.action=='recipe':recipe()
 elif a.action=='relief':relief(a.output)
 elif a.action=='author':author()
 elif a.action=='refine-contacts':refine_contacts()
 elif a.action=='bedrock':bedrock()
 elif a.action=='export':export(a.output)
 else:print(g.verify(a.output))
if __name__=='__main__':main()
