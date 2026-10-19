"""Deliberate Village02 plan and neutral 2.5D volumes. No production pixels.

Recipe -> lots/access -> footprints -> faces/physics/navigation -> Unity.
All coordinates are projected ground units; height is a visual vertical offset.
"""
from pathlib import Path
import argparse, hashlib, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt, label

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT/'ArtSource/World/PlayableVillage02'
W,H = 128,152

def write(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rect(x0,y0,x1,y1): return [[x0,y0],[x1,y0],[x1,y1],[x0,y1]]
def recipe():
    return dict(schema='valdoria-village02-plan/v1',seed=220261018,worldSize=[W,H],ppu=32,
        status='layout-blockout-awaiting-user-review',spawn=[53,12],actorClearance=.625,
        projection=dict(widthSlope=-.18,depthShear=.35,heightAxis=[0,1],doorHeight=4.85),
        rationale='River crossing becomes a bent street; frontage lots and rear service yards; independent north-east lordly ward.',
        enclosure=[[57,43],[92,46],[111,62],[115,95],[104,125],[70,133],[36,120],[18,97],[16,68],[29,46],[49,43]],
        roads=[dict(id='approach',width=5.5,points=[[53,2],[53,26],[53,44],[54,51],[60,58],[63,69],[67,80],[76,90],[82,98],[83,107]]),
               dict(id='croft-lane',width=3.5,points=[[54,51],[44,57],[39,72],[40,89],[48,101],[59,105],[76,101],[82,98]]),
               dict(id='east-service',width=3.5,points=[[63,69],[76,72],[88,76],[100,87],[101,94]])],
        commons=[[58,61],[71,64],[75,70],[67,76],[59,72]],
        lots=[
          dict(id='H1',function='gate household / rear workyard',anchor=[35,54],width=12,depth=8,height=6.8,roof=4,access=[[35,51.4],[44,51.4],[48,54]],lot=[[23,50],[42,49],[45,63],[24,66]]),
          dict(id='H2',function='street household / kitchen garden',anchor=[76,52],width=14,depth=8,height=7,roof=4.2,access=[[76,49.2],[66,50],[55,53]],lot=[[66,48],[87,48],[94,64],[74,64]]),
          dict(id='H3',function='croft household / long rear plot',anchor=[28,76],width=12,depth=9,height=6.4,roof=3.5,access=[[28,73.4],[35,73.4],[39,72]],lot=[[20,70],[36,68],[36,91],[22,93]]),
          dict(id='H4',function='market frontage / shared drying yard',anchor=[48,79],width=13,depth=8,height=7.4,roof=4.5,access=[[48,76.3],[55,76],[64,75]],lot=[[40,75],[58,73],[61,94],[43,96]]),
          dict(id='H5',function='east household / storage yard',anchor=[91,67],width=15,depth=8,height=7,roof=4,access=[[91,64],[81,64],[74,67]],lot=[[81,62],[103,63],[108,78],[90,80]]),
          dict(id='H6',function='upper croft household',anchor=[34,101],width=13,depth=8,height=6.7,roof=3.8,access=[[34,98.3],[42,98],[48,101]],lot=[[26,96],[45,94],[49,115],[35,117]]),
          dict(id='B1',function='communal barn / loading court',anchor=[58,107],width=17,depth=10,height=8,roof=5,access=[[58,103.9],[59,101],[64,101]],lot=[[48,100],[70,99],[74,122],[53,124]])],
        castle=dict(function='small lordly ward; keep + hall + service range + private court',
          perimeter=[[78,97],[102,97],[109,108],[106,123],[91,128],[72,122],[70,107],[78,97]],
          gate=[82,98],court=[[79,104],[100,104],[101,111],[84,113],[76,109]],
          volumes=[dict(id='C-keep',anchor=[98,115],width=11,depth=8,height=16,roof=0),
                   dict(id='C-hall',anchor=[81,117],width=14,depth=7,height=9,roof=5),
                   dict(id='C-service',anchor=[99,105],width=8,depth=5,height=5.4,roof=2.5)]),
        terrain=dict(model='authored contour study; no physical elevation change',contours=[[[17,91],[35,100],[61,105],[74,102],[93,96],[114,100]],[[26,114],[48,119],[69,117],[75,110],[96,108],[112,116]],[[50,128],[69,124],[80,122],[104,127]]]),
        promotion='Never add to Build Settings before user layout/blockout review and later final gameplay QA.')

def footprint(s):
    x,y=s['anchor'];w=s['width'];d=s['depth']
    return [[x-w/2,y+w*.09],[x+w/2,y-w*.09],[x+w/2+.35*d,y-w*.09+d],[x-w/2+.35*d,y+w*.09+d]]

def strip(a,b,width):
    a=np.array(a,dtype=float);b=np.array(b,dtype=float);v=b-a;n=np.array([-v[1],v[0]])/np.linalg.norm(v)*width/2
    return [(a+n).tolist(),(a-n).tolist(),(b-n).tolist(),(b+n).tolist()]

def compile_plan(r):
    data=dict(schema='valdoria-village02-blockout/v1',worldSize=r['worldSize'],spawn=r['spawn'],ppu=32,volumes=[],physical=[],surfaces=[],lots=r['lots'],roads=r['roads'],castle=r['castle'],terrain=r['terrain'])
    def physical(id,p,kind):data['physical'].append(dict(id=id,polygon=p,kind=kind))
    def face(points,tone):return dict(polygon=points,tone=tone)
    def prism(id,p,h,kind='wall',roof=0):
        p=np.array(p,dtype=float);q=p+[0,h];faces=[]
        # Visible lower-facing faces, then top. Same projected base drives collision.
        for i in range(len(p)):
            a,b=p[i],p[(i+1)%len(p)]
            if b[0]>=a[0] or (i==1 and kind=='building'):
                faces.append(face([a.tolist(),b.tolist(),(b+[0,h]).tolist(),(a+[0,h]).tolist()],.57 if b[1]<a[1] else .43))
        faces.append(face(q.tolist(),.73))
        if roof:
            left=(q[0]+q[3])/2+[0,roof];right=(q[1]+q[2])/2+[0,roof]
            faces += [face([q[0].tolist(),q[1].tolist(),right.tolist(),left.tolist()],.39),face([left.tolist(),right.tolist(),q[2].tolist(),q[3].tolist()],.54)]
            faces.append(face([q[1].tolist(),q[2].tolist(),right.tolist()],.61))
        data['volumes'].append(dict(id=id,kind=kind,footprint=p.tolist(),height=h,roofRise=roof,faces=faces))
        physical(id,p.tolist(),kind)
    for s in r['lots']+r['castle']['volumes']:
        prism(s['id'],footprint(s),s['height'],'building',s['roof'])
    def curtain(points,prefix,h,gate=None):
        for i,(a,b) in enumerate(zip(points,points[1:])):
            # The inner gate deliberately splits the south curtain at the passage.
            if gate is not None and i==0:
                for j,(u,v) in enumerate([(a,[79,97]),([85,97],b)]):prism(prefix+f'-{i}-{j}',strip(u,v,1.8),h)
            else:prism(prefix+f'-{i}',strip(a,b,1.8),h)
        # Joint caps occupy the shared node, hiding open butt joints in blockout.
        for i,p in enumerate(points[1:-1]):
            x,y=p;prism(prefix+f'-joint-{i}',rect(x-1.1,y-1.1,x+1.1,y+1.1),h+.15)
    curtain(r['enclosure'],'town',5.8)
    curtain(r['castle']['perimeter'],'ward',6.8,True)
    for id,x,y,h in [('G-west',46,43,10),('G-east',60,43,10),('C-gate-west',76,98,10),('C-gate-east',88,98,10),('T-west',18,97,9),('T-east',115,95,9)]:
        prism(id,rect(x-3,y-3,x+3,y+3),h)
    # Gate lintels are raised spans only; no invisible ground collider in passage.
    for id,x0,x1,y,h in [('G-lintel',49,57,43,7),('C-lintel',79,85,98,7)]:
        p=rect(x0,y-1,x1,y+2);q=np.array(p)
        data['volumes'].append(dict(id=id,kind='span',footprint=p,height=h,roofRise=0,faces=[face((q+[0,h]).tolist(),.70),face([[x0,y-1+h],[x1,y-1+h],[x1,y-1+h+3],[x0,y-1+h+3]],.55)]))
    # River polygon reaches both map edges. Opening exists only on the bridge.
    def banks(x):return 32+.045*x+1.2*math.sin(x/17)
    for id,a,b in [('river-west',0,49),('river-east',57,W)]:
        xx=np.linspace(a,b,int((b-a)*2)+1);p=[[float(x),banks(x)-4] for x in xx]+[[float(x),banks(x)+4] for x in xx[::-1]];physical(id,p,'water')
    xx=np.linspace(0,W,257);river=[[float(x),banks(x)-4] for x in xx]+[[float(x),banks(x)+4] for x in xx[::-1]]
    data['surfaces'] += [dict(id='river',polygon=river,tone='water'),dict(id='bridge',polygon=rect(49,26,57,44),tone='bridge'),dict(id='common',polygon=r['commons'],tone='road'),dict(id='ward-court',polygon=r['castle']['court'],tone='court')]
    for x in [48.7,57.3]:prism('bridge-rail-'+str(x),rect(x-.3,26,x+.3,40),1.1,'rail')
    for id,p in [('west',rect(-2,-2,0,H+2)),('east',rect(W,-2,W+2,H+2)),('south',rect(-2,-2,W+2,0)),('north',rect(-2,H,W+2,H+2))]:physical('boundary-'+id,p,'boundary')
    for s in r['lots']:
        data['roads'].append(dict(id='access-'+s['id'],width=2.5,points=s['access']))
    data['targets']=[dict(id='entry',point=[53,49]),dict(id='common',point=[65,66]),dict(id='ward',point=[83,108])]+[dict(id=s['id'],point=s['access'][0]) for s in r['lots']]
    return data

def navigation(d,closed=False):
    scale=4;im=Image.new('L',(W*scale,H*scale));draw=ImageDraw.Draw(im)
    for p in d['physical']:draw.polygon([(round(x*scale),round(y*scale)) for x,y in p['polygon']],fill=255)
    if closed:draw.rectangle((49*scale,29*scale,57*scale,40*scale),fill=255)
    walk=distance_transform_edt(np.array(im)==0)>.625*scale;labels,n=label(walk)
    def at(p):return int(labels[round(p[1]*scale),round(p[0]*scale)])
    start=at(d['spawn']);checks={t['id']:bool(start and at(t['point'])==start) for t in d['targets']}
    return walk,dict(bridgeClosed=closed,clearance=.625,step=.25,components=n,targets=checks,allConnected=all(checks.values()))

def plan_image(r,d,out):
    im=Image.new('RGB',(1280,1450),'#e9e5db');dr=ImageDraw.Draw(im);scale=7.8;ox=140;oy=1320
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16);big=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',31)
    def pt(p):return (round(ox+p[0]*scale),round(oy-p[1]*scale))
    dr.text((60,32),'VALDORIA 02  /  PLANTA PARA APROVAÇÃO',font=big,fill='#27353a');dr.text((60,78),'Estudo autorado • unidades projetadas • sem produção de sprites',font=font,fill='#505c59')
    for x in range(0,W+1,8):dr.line([pt([x,0]),pt([x,H])],fill='#d8d6cb')
    for y in range(0,H+1,8):dr.line([pt([0,y]),pt([W,y])],fill='#d8d6cb')
    for s in d['surfaces']:dr.polygon([pt(p) for p in s['polygon']],fill={'water':'#91b5bd','bridge':'#a2957e','road':'#cdbf9d','court':'#b6b4a8'}[s['tone']])
    for contour in r['terrain']['contours']:dr.line([pt(p) for p in contour],fill='#b5bba2',width=3)
    for lot in r['lots']:
        dr.polygon([pt(p) for p in lot['lot']],outline='#89957d',width=2)
    for road in d['roads']:dr.line([pt(p) for p in road['points']],fill='#c3b18b',width=round(road['width']*scale),joint='curve')
    for v in d['volumes']:
        if v['kind']=='span':continue
        dr.polygon([pt(p) for p in v['footprint']],fill='#6d7575' if v['kind']!='building' else '#a18f78',outline='#39494c',width=2)
        if v['kind']=='building':
            cx=sum(p[0] for p in v['footprint'])/4;cy=sum(p[1] for p in v['footprint'])/4;dr.text(pt([cx-2,cy+1]),v['id'],font=small,fill='white')
    for s in r['lots']:
        p=pt(s['access'][0]);dr.ellipse((p[0]-4,p[1]-4,p[0]+4,p[1]+4),fill='#ac5d34')
    labels=[('EXTERIOR',[57,13]),('PONTE / ÚNICA ENTRADA',[60,30]),('PORTÃO',[60,43]),('COMUM',[62,67]),('PÁTIO DE CARGA',[45,98]),('RECINTO SENHORIAL',[72,134]),('N',[124,146])]
    for text,p in labels:dr.text(pt(p),text,font=small,fill='#263b42')
    dr.line([pt([0,0]),pt([16,0])],fill='#263b42',width=4);dr.text((ox,oy+10),'0                 16 u',font=small,fill='#263b42')
    dr.text((60,1383),'Lotes verdes • volumes cinza/ocre • ruas areia • entradas cobre • curvas: relevo proposto',font=font,fill='#3e504f')
    im.save(out)

def build(out,recipe_path):
    if out.exists():raise FileExistsError('Refuse existing output')
    r=json.loads(recipe_path.read_text(encoding='utf-8'));d=compile_plan(r)
    walk,opened=navigation(d);_,closed=navigation(d,True)
    if not opened['allConnected']:raise ValueError(opened)
    if closed['targets']['entry']:raise ValueError('Bridge is not necessary')
    out.mkdir(parents=True);write(out/'layout.json',d);write(out/'navigation-proof.json',dict(open=opened,closed=closed))
    Image.fromarray(np.flipud(walk).astype('uint8')*255).save(out/'navigation.png');plan_image(r,d,out/'plan.png')
    write(out/'manifest.json',dict(schema='valdoria-village02-build/v1',recipe=sha(recipe_path),generator=sha(Path(__file__)),files={p.name:sha(p) for p in sorted(out.iterdir())}))
    print(json.dumps(opened))

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('action',choices=['recipe','build']);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--recipe',type=Path,default=BASE/'recipe.json');a=ap.parse_args()
    if a.action=='recipe':
        if a.output.exists():raise FileExistsError(a.output)
        a.output.parent.mkdir(parents=True,exist_ok=True);write(a.output,recipe())
    else:build(a.output,a.recipe)
