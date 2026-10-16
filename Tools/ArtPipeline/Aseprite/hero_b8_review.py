"""B8 QA/previews only. All artwork is authored and transformed by Aseprite Lua."""
from pathlib import Path
import json,hashlib,math,csv,sys
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
LAB=ROOT/'ArtSource/Labs/AnimationResearch/Marco06B8'
BASE=LAB
SUFFIX='-r2' if '-r2' in sys.argv else ''
LAB=BASE/('review'+SUFFIX)
LAB.mkdir(exist_ok=True)
rig=json.loads((BASE/f'hero-rig-south{SUFFIX}.aseprite.rig.json').read_text())
frames=[Image.open(BASE/f'frames{SUFFIX}/frame_{i:03}.png').convert('RGBA') for i in range(8)]
source=Image.open(ROOT/'ArtSource/Labs/Aseprite/HeroB7/walk-r2/frame_000.png').convert('RGBA')
colors=set(source.getdata())-{(0,0,0,0)}
BG=(32,39,48,255)
def present(im,scale=4):
 b=Image.new('RGBA',im.size,BG);b.alpha_composite(im);return b.convert('RGB').resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
def gif(ims,path,ds):
 ims[0].save(path,save_all=True,append_images=ims[1:],duration=ds,disposal=2,optimize=False)
def board(ims,labels,path):
 b=Image.new('RGB',(384*4,410*2),BG[:3]);d=ImageDraw.Draw(b)
 for i,im in enumerate(ims):
  x=i%4*384;y=i//4*410;b.paste(present(im),(x,y+24));d.text((x+8,y+5),labels[i],fill='white')
 b.save(path)
labels=['L contact','L absorption','R passing','R lift','R contact','R absorption','L passing','L lift']
board(frames,labels,LAB/'poses.png')
overlays=[];rows=[];manifest=[];limits=[]
headhash=[]
for i,(im,f) in enumerate(zip(frames,rig['frames'])):
 assert set(im.getdata())-{(0,0,0,0)}<=colors
 assert set(im.getchannel('A').getdata())=={0,255}
 headhash.append(hashlib.sha256(im.crop((39,34,56,51)).tobytes()).hexdigest())
 over=im.copy();d=ImageDraw.Draw(over)
 for name,(a,b) in f['joints'].items():
  d.line([tuple(a),tuple(b)],fill='#ff55cc');x,y=a;d.ellipse((x-1,y-1,x+1,y+1),fill='#55ffcc')
 overlays.append(over)
 hands={}
 for side,key in [('R','rightHand'),('L','leftHand')]:
  p=[math.floor(v+.5) for v in f['joints'][side+' hand'][0]]
  layer=Image.open(BASE/f'parts{SUFFIX}/{side}-hand-{i}.png').convert('RGBA')
  hands[key]=p
  assert layer.getpixel(tuple(p))[3]==255,(i,key,p)
 foot=Image.open(BASE/f'parts{SUFFIX}/{f["support"]}-boot-{i}.png').convert('RGBA')
 box=foot.getbbox();y=box[3]-1
 xs=[x for x in range(96) if foot.getpixel((x,y))[3]];x=(min(xs)+max(xs))/2
 # Root travels south = +canvas Y; horizontal root remains 48.
 start=i//4*4;local0=rig['frames'][start]['joints'][f['support']+' boot'][1]
 rows.append(dict(frame=i,t=i*.03,support=f['support'],soleX=x,soleY=y,worldSoleY=y+112*i*.03,targetY=f['joints'][f['support']+' boot'][1][1]))
 for part in rig['parts']:
  a,b=f['joints'][part['name']];u=[part['endpoint'][k]-part['pivot'][k] for k in range(2)];v=[b[k]-a[k] for k in range(2)]
  angle=math.degrees(math.atan2(u[0]*v[1]-u[1]*v[0],u[0]*v[0]+u[1]*v[1]));ratio=math.hypot(*v)/math.hypot(*u)
  if abs(angle)>part['angleLimit'] or not .65<=ratio<=1.4:limits.append(dict(frame=i,part=part['name'],angle=angle,lengthRatio=ratio))
 manifest.append(dict(png=f'../frames{SUFFIX}/frame_{i:03}.png',duration=.03,pivot=[48,70],**hands,hand=[(hands['rightHand'][0]-48)/32,(70-hands['rightHand'][1])/32],equipmentAngle=-135,equipmentDepth=1,sha256=hashlib.sha256((BASE/f'frames{SUFFIX}/frame_{i:03}.png').read_bytes()).hexdigest()))
board(overlays,labels,LAB/'joints.png')
gif([present(im) for im in frames]*2,LAB/'two-cycles.gif',[30]*16)
gif([present(im) for im in overlays]*2,LAB/'joints-two-cycles.gif',[30]*16)
old=[Image.open(ROOT/f'ArtSource/Characters/Hero/walk/south/frame_{i:03}.png').convert('RGBA') for i in range(2)]
b7=[Image.open(ROOT/f'ArtSource/Labs/Aseprite/HeroB7/walk-r2/frame_{i:03}.png').convert('RGBA') for i in range(4)]
for name,other,dt,title in [('b7',b7,120,'B7 480ms cycle'),('original',old,125,'Original 250ms cycle')]:
 ims=[]
 for t in range(0,480,10):
  b=Image.new('RGB',(768,410),BG[:3]);b.paste(present(other[(t//dt)%len(other)]),(0,24));b.paste(present(frames[(t//30)%8]),(384,24));d=ImageDraw.Draw(b);d.text((8,5),title,fill='white');d.text((392,5),'B8 240ms cycle - rejected draft',fill='white');ims.append(b)
 gif(ims,LAB/f'{name}-vs-b8.gif',[10]*48)
with (LAB/'foot-trajectory.csv').open('w',newline='') as out:
 w=csv.DictWriter(out,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
slips=[]
for start in [0,4]:
 ys=[r['worldSoleY'] for r in rows[start:start+4]];slips.append(max(ys)-min(ys))
qa=dict(frames=8,unique=len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames}),sourcePaletteOnly=True,binaryAlpha=True,headCropHashes=headhash,headStable=len(set(headhash))==1,worldSoleRangePerStancePx=slips,withinFrameDriftPx=112*.03,cycleMs=240,rootDistancePerCyclePx=112*.24,stanceMs=120,constraintViolations=limits,unityTest=False,artisticStatus='rejected-not-better-than-B7')
(LAB/'qa-report.json').write_text(json.dumps(qa,indent=2)+'\n')
(LAB/'manifest-candidate.json').write_text(json.dumps(dict(status='rejected-not-importable',coordinates='top-left pixels',ppu=32,frames=manifest),indent=2)+'\n')
# Small static diagnostic plot in pixel units, not artwork.
b=Image.new('RGB',(800,320),'#202730');d=ImageDraw.Draw(b);d.text((16,8),'Sole world Y: flat = locked. Orange intended; cyan rendered.',fill='white')
for start in [0,4]:
 seq=rows[start:start+4]
 for key,color in [('worldSoleY','#55ffcc')]:
  pts=[(40+r['frame']*95,280-(r[key]-85)*9) for r in seq];d.line(pts,fill=color,width=2)
 for r in seq:
  x=40+r['frame']*95;y=280-(r['targetY']+112*r['t']-85)*9;d.ellipse((x-3,y-3,x+3,y+3),fill='orange');d.text((x,295),str(r['frame']),fill='white')
b.save(LAB/'foot-trajectory.png')
print(json.dumps({k:v for k,v in qa.items() if k not in ['headCropHashes','constraintViolations']},indent=2));print('constraint violations',len(limits))
