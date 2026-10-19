"""Village02 F: explicit ground annotations and opaque volume assembly.

Approved raster art remains immutable. Geometry is authored independently in
native-canvas coordinates, then transformed with the same placement as pixels.
"""
from pathlib import Path
import json,math,argparse,subprocess,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import distance_transform_edt,label
import ground_finish11 as ground
import village02_art as art

ROOT=art.ROOT;BASE=ROOT/'ArtSource/World/PlayableVillage02';OUT=BASE/'IntegrationV1';E=BASE/'ArtProductionV1';SCALE=2.2;W,H=282,335
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def write(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rect(x0,y0,x1,y1):return [[x0,y0],[x1,y0],[x1,y1],[x0,y1]]
def strip(a,b,width):
 a=np.array(a);b=np.array(b);v=b-a;n=np.array([-v[1],v[0]])/np.linalg.norm(v)*width/2;return [(a+n).tolist(),(a-n).tolist(),(b-n).tolist(),(b+n).tolist()]

# Hand-authored foundation/base planes, NOT alpha contours or roof bounds.
HOUSES={
 'H1':dict(anchor=[400,846],polygons=[[[150,725],[522,899],[730,778],[358,604]],[[43,690],[150,730],[260,625],[153,585]]]),
 'H2':dict(anchor=[420,659],polygons=[[[116,575],[650,722],[925,604],[391,457]]]),
 'H3':dict(anchor=[280,610],polygons=[[[66,536],[462,685],[575,650],[600,661],[748,590],[748,510],[215,370]]]),
 'H4':dict(anchor=[477,663],polygons=[[[129,577],[770,735],[1033,620],[392,462]]]),
 'H5':dict(anchor=[625,774],polygons=[[[115,655],[950,850],[1230,740],[395,545]]]),
 'H6':dict(anchor=[485,710],polygons=[[[174,605],[654,766],[785,704],[852,754],[1074,651],[1074,540],[305,450]]]),
 'B1':dict(anchor=[239,755],polygons=[[[106,726],[1070,937],[1380,819],[416,608]]]),
}

def specs():
 c=[
  dict(id='court',ground=True,visual=[[0,0],[1759,0],[1759,2071],[0,2071]],physical=[]),
  dict(id='rear-curtain',visual=[[500,440],[900,320],[1100,650],[800,900],[500,820]],physical=[strip([560,875],[1190,950],60)]),
  dict(id='west-curtain',visual=[[30,1450],[180,1510],[270,980],[270,590],[130,570]],physical=[strip([100,1480],[230,970],60),strip([170,1780],[100,1480],70)]),
  dict(id='east-curtain',visual=[[1510,540],[1640,540],[1735,1140],[1732,1480],[1370,1935],[1370,1590],[1580,1170]],physical=[strip([1370,1880],[1690,1450],65),strip([1690,1450],[1530,1030],60)]),
  dict(id='south-curtain',visual=[[945,1530],[1380,1575],[1380,1935],[945,1910]],physical=[[[925,1910],[1370,1935],[1390,1830],[945,1805]]]),
  dict(id='hall',visual=[[200,300],[900,450],[980,620],[980,875],[790,1060],[225,980]],physical=[[[230,980],[790,1060],[960,880],[400,800]]]),
  dict(id='keep',visual=[[820,0],[1650,0],[1650,520],[1545,1030],[1410,1150],[980,1070],[980,460],[860,440]],physical=[[[980,1070],[1410,1150],[1530,1030],[1100,950]]]),
  dict(id='service',visual=[[1100,1110],[1510,1210],[1560,1320],[1510,1390],[1360,1540],[1080,1480]],physical=[[[1080,1480],[1360,1540],[1500,1390],[1220,1330]]]),
  dict(id='arch',visual=[[440,1280],[660,1310],[680,1650],[440,1590]],physical=[],depth=[[440,1860],[660,1900],[670,1820],[450,1780]]),
  dict(id='gate-west',visual=[[40,1100],[300,1100],[500,1170],[500,1440],[445,1510],[445,1865],[170,1840],[170,1660],[45,1480]],physical=[[[170,1810],[440,1860],[470,1720],[200,1670]]]),
  dict(id='gate-east',visual=[[580,1150],[800,1150],[940,1250],[970,1420],[950,1910],[660,1910],[660,1500],[625,1450]],physical=[[[660,1910],[945,1910],[960,1770],[680,1770]]]),
 ]
 gate=[
  dict(id='arch',visual=[[0,0],[1710,0],[1710,1140],[0,1140]],physical=[],depth=[[680,900],[980,1010],[980,940],[680,830]]),
  dict(id='west-connector',visual=[[0,350],[275,430],[275,800],[0,730]],physical=[[[30,700],[245,780],[275,695],[60,615]]]),
  dict(id='east-connector',visual=[[1400,550],[1710,550],[1710,1140],[1400,1140]],physical=[[[1435,1085],[1695,950],[1695,870],[1435,1000]]]),
  dict(id='west-tower',visual=[[220,0],[740,0],[740,325],[690,860],[520,940],[220,830]],physical=[[[220,825],[520,930],[680,860],[380,755]]]),
  dict(id='east-tower',visual=[[1000,170],[1525,170],[1525,1030],[1290,1135],[970,1035]],physical=[[[980,1025],[1290,1125],[1490,1020],[1180,920]]]),
 ]
 return {'castle-compound':dict(anchor=[565,1830],parts=c),'gate':dict(anchor=[835,955],parts=gate),'bridge':dict(anchor=[398,1130],parts=[dict(id='deck',ground=True,visual=rect(0,0,796,1195),physical=[]),dict(id='left-rail',visual=rect(0,0,305,1195),physical=[rect(199,61,305,1136)]),dict(id='right-rail',visual=rect(489,0,796,1195),physical=[rect(489,61,598,1136)])])}

def split(out,annotations):
 """Read approved Aseprite pixels; repartition into new opaque depth groups."""
 out.mkdir();q=art.q
 for id,s in annotations.items():
  folder=out/id;folder.mkdir();meta=read(E/'SourceV1'/id/'house-source.json');w,h=meta['canvas'];owner=Image.new('RGB',(w,h),(1,0,0));d=ImageDraw.Draw(owner)
  for k,p in enumerate(s['parts']):d.polygon([tuple(v) for v in p['visual']],fill=(k+1,0,0))
  owner.save(folder/'ownership.png');n=len(s['parts'])
  lua=f'local input=app.open({q(E/"SourceV1"/id/(id+".aseprite"))});local pixels=Image(input.spec);pixels:drawSprite(input,1);local mask=app.open({q(folder/"ownership.png")});local m=mask.cels[1].image;local s=Sprite({w},{h},ColorMode.RGB);s.layers[1].name="Temporary";local imgs={{}};local ls={{}};'
  for p in s['parts']:lua+='do local l=s:newLayer();l.name='+json.dumps(p['id'])+';table.insert(ls,l);table.insert(imgs,Image(s.spec)) end;'
  lua+=f'for y=0,{h-1} do for x=0,{w-1} do local c=pixels:getPixel(x,y);if app.pixelColor.rgbaA(c)>0 then local k=app.pixelColor.rgbaR(m:getPixel(x,y));imgs[k]:drawPixel(x,y,c) end end end;'
  for k,p in enumerate(s['parts']):lua+=f's:newCel(ls[{k+1}],1,imgs[{k+1}],Point(0,0));imgs[{k+1}]:saveAs({q(folder/(p["id"]+".png"))});'
  lua+='s:deleteLayer(s.layers[1]);s:saveAs('+q(folder/(id+'.aseprite'))+');s:close();mask:close();input:close();'
  art.run_lua(lua,folder/'partition.lua')
  # Exclusive ownership recomposes exactly; no generated/repainted pixels.
  combined=Image.new('RGBA',(w,h))
  for p in s['parts']:combined.alpha_composite(Image.open(folder/(p['id']+'.png')))
  assert combined.tobytes()==Image.open(E/'ExportV1'/id/'composite.png').tobytes(),id
  write(folder/'provenance.json',dict(approvedSource=str((E/'SourceV1'/id/(id+'.aseprite')).relative_to(ROOT)).replace('\\','/'),sourceSHA256=sha(E/'SourceV1'/id/(id+'.aseprite')),recompositionPixelIdentical=True,canvas=[w,h],parts=s['parts']))
  print('Partitioned',id,flush=True)

def compile_layout():
 r=read(E/'layout-recipe.json');d=dict(schema='valdoria-village02-integration/v1',worldSize=[W,H],ppu=32,layoutDistanceScale=SCALE,artScale=1,spawn=[116.6,26.4],buildings=[],pieces=[],physical=[],roads=[],targets=[],townWalls=[])
 def phys(id,p,kind,owner=None):d['physical'].append(dict(id=id,polygon=p,kind=kind,owner=owner))
 def convert(p,anchor,pos):return [[pos[0]+(x-anchor[0])/32,pos[1]+(anchor[1]-y)/32] for x,y in p]
 for lot in r['lots']:
  id=lot['id'];s=HOUSES[id];pos=(np.array(lot['anchor'])*SCALE).tolist();polys=[convert(p,s['anchor'],pos) for p in s['polygons']]
  d['buildings'].append(dict(id=id,position=pos,anchorPixels=s['anchor'],polygons=polys,composite=str((E/'ExportV1'/id/'composite.png').relative_to(ROOT)).replace('\\','/')))
  for i,p in enumerate(polys):phys(id+'-'+str(i),p,'building',id)
  approach=[pos[0],pos[1]-1.4];d['targets'].append(dict(id=id,point=approach));pts=[approach]+[(np.array(p)*SCALE).tolist() for p in lot['access']];d['roads'].append(dict(id='access-'+id,points=pts,width=3.0))
 for road in r['roads']:d['roads'].append(dict(id=road['id'],points=(np.array(road['points'])*SCALE).tolist(),width=road['width']*1.4))
 for id,pos,anchor,lines,width in [('fence',[179,139],[237,218],[[[15,153],[237,218]],[[237,218],[371,157]]],14),('lowwall',[220,163],[240,238],[[[15,179],[240,238]],[[240,238],[368,145]]],21),('corner',[122,201],[260,270],[[[20,165],[260,270]],[[260,270],[400,140]]],28)]:
  polygons=[convert(strip(a,b,width),anchor,pos) for a,b in lines]
  d['buildings'].append(dict(id=id,prop=True,position=pos,anchorPixels=anchor,polygons=polygons,composite=str((E/'ExportV1'/id/'composite.png').relative_to(ROOT)).replace('\\','/')))
  for k,p in enumerate(polygons):phys(id+'-'+str(k),p,'prop',id)
 poses={'castle-compound':[180.4,215.6],'gate':[116.6,94.6],'bridge':[116.6,57.2]}
 for id,s in specs().items():
  pos=poses[id];item=dict(id=id,position=pos,anchorPixels=s['anchor'],parts=[])
  for p in s['parts']:
   polygons=[convert(poly,s['anchor'],pos) for poly in p['physical']];depth=convert(p.get('depth',p['physical'][0] if p['physical'] else rect(0,0,1,1)),s['anchor'],pos)
   item['parts'].append(dict(id=p['id'],ground=p.get('ground',False),depth=depth,polygons=polygons))
   for k,poly in enumerate(polygons):phys(id+'-'+p['id']+'-'+str(k),poly,'rail' if id=='bridge' else 'building',id+'/'+p['id'])
  d['pieces'].append(item)
 # Curtain follows the approved perimeter, with ends meeting the actual gate.
 points=[[143.4,94.8]]+(np.array(r['enclosure'][1:-1])*SCALE).tolist()+[[91.45,102.57]]
 for k,(a,b) in enumerate(zip(points,points[1:])):
  length=float(np.linalg.norm(np.array(b)-a));count=math.ceil(length/8.5)
  for j in range(count):
   u=(np.array(a)+(np.array(b)-a)*j/count).tolist();v=(np.array(a)+(np.array(b)-a)*(j+1)/count).tolist();poly=strip(u,v,1.5);id=f'town-{k}-{j}';d['townWalls'].append(dict(id=id,a=u,b=v,polygon=poly));phys(id,poly,'wall',id)
 def bank(x):return (32+.045*(x/SCALE)+1.2*np.sin(x/SCALE/17))*SCALE
 # Bridge's inner deck, not the much wider raster canvas, defines water gap.
 for id,a,b in [('west',0,113.69375),('east',119.44375,W)]:
  xx=np.linspace(a,b,math.ceil((b-a)*2)+1);lo=bank(xx)-4*SCALE;hi=bank(xx)+4*SCALE;phys('water-'+id,[[float(x),float(y)] for x,y in zip(xx,lo)]+[[float(x),float(y)] for x,y in zip(xx[::-1],hi[::-1])],'water')
 for id,p in [('west',rect(-2,-2,0,H+2)),('east',rect(W,-2,W+2,H+2)),('south',rect(-2,-2,W+2,0)),('north',rect(-2,H,W+2,H+2))]:phys('boundary-'+id,p,'boundary')
 d['targets']=[dict(id='entry',point=[116.6,103]),dict(id='common',point=[143,145.2]),dict(id='castle-court',point=[188,233])]+d['targets']
 return d

def nav(d,closed=False):
 scale=4;im=Image.new('L',(W*scale,H*scale));dr=ImageDraw.Draw(im)
 for p in d['physical']:dr.polygon([(round(x*scale),round(y*scale)) for x,y in p['polygon']],fill=255)
 if closed:dr.rectangle((113*scale,65*scale,120*scale,88*scale),fill=255)
 walk=distance_transform_edt(np.array(im)==0)>.625*scale;labs,n=label(walk)
 def at(p):return int(labs[round(p[1]*scale),round(p[0]*scale)])
 a=at(d['spawn']);checks={t['id']:bool(a and at(t['point'])==a) for t in d['targets']};return walk,dict(components=n,targets=checks,allConnected=all(checks.values()),bridgeClosed=closed,clearance=.625,step=.25)

def ground_chunks(out,d):
 """Ground11 painted materials; shared global pigment and semantic coverage.

Distance halo is local (64px), larger than all visual edge influence. Global
coordinates feed every pigment field; no independent per-tile material seed.
"""
 recipe=read(ground.BASE/'recipe.json');seed=recipe['seed'];paths=[(np.array(p['points'])*[32,-32]+[0,H*32]).tolist() for p in d['roads']];result=[]
 for y0 in range(0,H*32,512):
  for x0 in range(0,W*32,512):
   w,h=min(512,W*32-x0),min(512,H*32-y0);halo=64;xx0,yy0=x0-halo,y0-halo
   im=Image.new('L',(w+halo*2,h+halo*2));dr=ImageDraw.Draw(im)
   for p,path in zip(d['roads'],paths):
    pts=[(x-xx0,y-yy0) for x,y in path];radius=p['width']*16;dr.line(pts,fill=255,width=round(radius*2),joint='curve')
    for x,y in pts:dr.ellipse((x-radius,y-radius,x+radius,y+radius),fill=255)
   coverage=np.array(im)>127;sd=(distance_transform_edt(coverage)-distance_transform_edt(~coverage))[halo:halo+h,halo:halo+w]
   y,x=np.mgrid[y0:y0+h,x0:x0+w];m=ground.m;grass=ground.sample_paint('meadow',x,y,seed);earth=ground.sample_paint('earth',x,y,seed+29)
   macro=m.field(x,y,361,seed+91);meso=m.field(x,y,97,seed+97);quiet=np.clip((m.field(x,y,223,seed+101)-(1-recipe['grass']['quietAreaFraction']))*3.5,0,.7)
   grass=np.array([91.,112.,48.])+(grass-np.array([91.,112.,48.]))*(recipe['grass']['paintStrength']*(1-quiet*.8))[...,None];grass*=1+(macro[...,None]-.5)*recipe['grass']['macroAmplitude']*2+(meso[...,None]-.5)*recipe['grass']['mesoAmplitude']*2
   earth=np.array([147.,119.,78.])+(earth-np.array([147.,119.,78.]))*recipe['road']['paintStrength']
   noise=((m.field(x,y,9,seed+109)-.5)*1.1+(m.field(x,y,23,seed+111)-.5))*recipe['road']['edgeVisualPixels'];a=np.clip((sd+noise+1.5)/3,0,1);a=np.where(sd>=recipe['road']['edgeVisualPixels']+2,1,a)
   rgb=grass*(1-a[...,None])+earth*a[...,None];name=f'ground-{x0}-{y0}.png';Image.fromarray(np.clip(np.rint(rgb),0,255).astype('uint8')).save(out/name);result.append(dict(file=name,rect=[x0,y0,w,h]))
  print('Ground',y0,flush=True)
 d['groundChunks']=result

def build(out):
 if out.exists():raise FileExistsError('Refuse existing integration destination')
 d=compile_layout();walk,opened=nav(d);_,closed=nav(d,True)
 if not opened['allConnected']:raise ValueError(opened)
 if closed['targets']['entry']:raise ValueError('Bridge bypass')
 out.mkdir(parents=True);write(out/'annotations.json',dict(houses=HOUSES,compounds=specs(),units='native approved composite pixels, origin upper-left',authority='hand-authored ground/base planes; independent of visible roof alpha'))
 split(out/'DepthArt',specs());write(out/'navigation-proof.json',dict(open=opened,closed=closed));Image.fromarray(np.flipud(walk).astype('uint8')*255).save(out/'navigation.png')
 ground_chunks(out,d);water(out);write(out/'layout.json',d)
 write(out/'manifest.json',dict(recipeSHA256=sha(E/'layout-recipe.json'),generatorSHA256=sha(Path(__file__)),approvedCatalogSHA256=sha(E/'ExportV1/catalog.json'),files={str(p.relative_to(out)).replace('\\','/'):sha(p) for p in out.rglob('*') if p.is_file()}))

def water(out):
 if (out/'river-0.png').exists():raise FileExistsError('Water destination exists')
 x=np.arange(W*32)[None,:]/32;y=np.arange(45*32)[:,None]/32+55;center=(32+.045*x/SCALE+1.2*np.sin(x/SCALE/17))*SCALE;low=center-4*SCALE;high=center+4*SCALE;depth=np.clip(np.minimum(y-low,high-y)/(3*SCALE),0,1)
 rgb=np.array([102,143,122])*(1-depth[...,None])+np.array([38,79,89])*depth[...,None];alpha=np.where((y>=low)&(y<=high),255,0).astype('uint8')
 for phase in range(4):
  arr=np.concatenate([np.clip(rgb,0,255).astype('uint8'),alpha[...,None]],axis=2);im=Image.fromarray(np.flipud(arr));motif=Image.open(ROOT/f'ArtSource/Labs/World2026/Ground13/ExportV2/water-motifs-{phase}.png').convert('RGBA').crop((0,0,64,64))
  for i in range(65):
   px=45+i*139;xx=px/32;cy=(32+.045*xx/SCALE+1.2*math.sin(xx/SCALE/17))*SCALE;py=round((100-cy)*32+47*math.sin(i*2.1));im.alpha_composite(motif,(px,py))
  a=np.array(im);a[:,:,3]=np.flipud(alpha);Image.fromarray(a).save(out/f'river-{phase}.png')

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('action',choices=['plan','build']);ap.add_argument('--output',type=Path,default=OUT);args=ap.parse_args()
 if args.action=='plan':print(json.dumps(nav(compile_layout())[1]))
 else:build(args.output.resolve())
