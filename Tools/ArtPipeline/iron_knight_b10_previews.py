"""Assemble actual B9/B10 captures on a shared real-time timeline; no pose interpolation."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math,statistics
BASE=Path('Docs/Validation/Marco06B10');ART=Path('ArtSource/Labs/IronKnight2026');B10=ART/'B10';OUT=BASE/'previews';OUT.mkdir(parents=True,exist_ok=True)
metadata={v:{r['name']:r for r in map(json.loads,(BASE/v/'capture-metadata.jsonl').read_text('utf-8-sig').splitlines())} for v in ['baseline','candidate']}
def file(v,name):
 p=BASE/v/(name+'.png');return p if p.exists() else Path('Temp/Marco06B10/Captures')/v/(name+'.png')
def tile(v,name,scale=1):
 m=metadata[v][name];im=Image.open(file(v,name)).convert('RGB');x,y=m['playerScreen'];y=im.height-y;t=im.crop((round(x)-90,round(y)-100,round(x)+90,round(y)+70));return t.resize((180*scale,170*scale),Image.Resampling.NEAREST)
def panel(v,name,scale=2):
 t=tile(v,name,scale);b=Image.new('RGB',(360,382),(25,30,34));b.paste(t,(0,0));d=ImageDraw.Draw(b);m=metadata[v][name];d.text((5,343),f'{"B9" if v=="baseline" else "B10"} / timeScale {m["timeScale"]} / nearest 2x',fill='white');d.text((5,357),m['source']+' / '+m['phase'],fill='white');d.text((5,370),f'speed {math.hypot(*m["velocity"]):.2f} u/s',fill='white');return b
def names(prefix,n):return [f'{prefix}{i:02}' for i in range(n)]
previews=[]
def comparison(groups,name):
 frames=[];dt=80
 for group in groups:
  seqs={v:[metadata[v][n] for n in group if n in metadata[v]] for v in metadata};duration=min(s[-1]['realTime']-s[0]['realTime'] for s in seqs.values())
  for tick in range(max(1,int(duration/.08)+1)):
   t=tick*.08;b=Image.new('RGB',(720,382))
   for col,(v,seq) in enumerate(seqs.items()):
    first=seq[0]['realTime'];r=max((r for r in seq if r['realTime']-first<=t),key=lambda r:r['realTime'],default=seq[0]);b.paste(panel(v,r['name']),(col*360,0))
   frames.append(b)
 frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=dt,loop=0,optimize=False);previews.append({'file':name,'sharedTickMs':dt,'groups':groups,'method':'zero-order hold of captured images on equal elapsed real time after first sample, common shorter capture interval; no phase-normalization or interpolation'})
comparison([names(f'walk-{d}-',8) for d in [3,2,1,0]],'walk-b9-vs-b10.gif')
comparison([names(f'attack-{d}-',13) for d in range(4)],'basic-b9-vs-b10.gif')
comparison([names(f'attack-{d}-',24) for d in range(4,9)],'heavy-b9-vs-b10.gif')
groups=[names(f'walk-{d}-',8) for d in [3,2,1,0]];frames=[];durations=[]
for group in groups:
 for i,n in enumerate(group):
  frames.append(panel('candidate',n));durations.append(max(10,round((metadata['candidate'][group[i+1]]['realTime']-metadata['candidate'][n]['realTime'])*1000)) if i<len(group)-1 else 80)
frames[0].save(OUT/'b10-four-directions.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0)
frames=[];group=names('attack-8-',24)
for n in group:
 m=metadata['candidate'][n];src=Image.open(file('candidate',n)).convert('RGB');x,y=m['playerScreen'];y=src.height-y;zoom=src.crop((round(x)-130,round(y)-140,round(x)+130,round(y)+110)).resize((520,500),Image.Resampling.NEAREST);canvas=Image.new('RGB',(520,536),(25,30,34));canvas.paste(zoom,(0,0));draw=ImageDraw.Draw(canvas);draw.text((5,505),'B10 / real Unity / timeScale 0.35 / nearest 2x / F7',fill='white');draw.text((5,521),m['source']+' / '+m['phase'],fill='white');frames.append(canvas)
durations=[max(10,round((metadata['candidate'][group[i+1]]['realTime']-metadata['candidate'][n]['realTime'])*1000)) if i<23 else 80 for i,n in enumerate(group)];frames[0].save(OUT/'b10-f7-heavy.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0)
cut=[metadata['candidate'][n] for n in group if metadata['candidate'][n]['phase']=='cut'];Image.open(file('candidate',cut[len(cut)//2]['name'])).save(BASE/'candidate/f7-heavy-full.png')
(OUT/'timelines.json').write_text(json.dumps(previews,indent=2))
# Side-by-side stills of each phase from actual captures.
rows=[]
for d in range(4):
 for phase in ['preparation','cut','recovery']:
  b=Image.new('RGB',(720,382))
  for col,v in enumerate(['baseline','candidate']):
   seq=[metadata[v][n] for n in names(f'attack-{d}-',13) if metadata[v][n]['phase']==phase]
   if seq:b.paste(panel(v,seq[len(seq)//2]['name']),(col*360,0))
  rows.append(b)
board=Image.new('RGB',(1440,382*6))
for i,b in enumerate(rows):board.paste(b,((i%2)*720,(i//2)*382))
board.save(OUT/'attack-contacts-real.png')
# Annotated source poses: magenta=B9 anchor, green=B10 manually reviewed grip.
old=json.loads((ART/'manifest.json').read_text());new=json.loads((B10/'manifest.json').read_text());by={(c['animation'],c['direction']):c for c in new['clips']}
for action,count in [('idle',1),('walk',11),('attack',15)]:
 board=Image.new('RGB',(count*176,4*174),(40,43,48));draw=ImageDraw.Draw(board)
 for row,dr in enumerate(['south','west','north','east']):
  c=next(c for c in old['clips'] if c['animation']==action and c['direction']==dr);revised=by[(action,dr)]
  for i,f in enumerate(c['frames']):
   im=Image.open(f['png']).convert('RGBA').crop((88,72,168,144)).resize((160,144),Image.Resampling.NEAREST);xx=i*176;yy=row*174;board.paste(im,(xx,yy+22),im);draw.text((xx,yy+2),dr+' '+str(i),fill='white')
   for color,point in [('magenta',f['rightHand']),('lime',revised['frames'][i]['rightHand'])]:
    x,y=point;cx=xx+(x-88)*2;cy=yy+22+(y-72)*2;draw.ellipse((cx-2,cy-2,cx+2,cy+2),outline=color)
 board.save(OUT/f'hand-contacts-{action}.png')
# Quantify phase mapping and true blade/anchor measurements from end-of-frame samples.
ranges=new['phaseRanges'];directions={'(0.00, -1.00)':'south','(-1.00, 0.00)':'west','(0.00, 1.00)':'north','(1.00, 0.00)':'east'};report={}
for v,items in metadata.items():
 rows=list(items.values());attacks=[r for r in rows if r['state'].startswith('attack') and r['phase'] in ['preparation','cut','recovery'] and '/Slash/' in r['source']];outside=[]
 for r in attacks:
  direction=directions[r['visual']];i=int(r['source'].rsplit('frame',1)[-1]);a,b=ranges[direction][r['phase']]
  if not a<=i<=b:outside.append({'capture':r['name'],'sourceFrame':i,'phase':r['phase'],'expected':[a,b]})
 report[v]={'samples':len(rows),'phaseSamples':len(attacks),'outsideAnatomicalPhase':outside,'maxGripError':max(r['gripError'] for r in rows),'bladeLengthMin':min(r['bladeLength'] for r in rows),'bladeLengthMax':max(r['bladeLength'] for r in rows),'pivotScales':sorted(set(r['scale'] for r in rows))}
(BASE/'alignment-report.json').write_text(json.dumps(report,indent=2));print({v:{k:x for k,x in r.items() if k!='outsideAnatomicalPhase'}|{'phaseMismatchCount':len(r['outsideAnatomicalPhase'])} for v,r in report.items()})
