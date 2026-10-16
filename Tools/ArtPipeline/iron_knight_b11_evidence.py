"""Assemble original-cel boards and previews from actual Unity EOF captures only."""
from pathlib import Path
import json, hashlib, math
from PIL import Image, ImageDraw

ROOT=Path('Docs/Validation/Marco06B11'); OUT=ROOT/'previews'; OUT.mkdir(exist_ok=True)
M=json.loads(Path('ArtSource/Labs/IronKnight2026/B11/manifest.json').read_text())
for action in ['dodge','hurt','death']:
 clips=[c for c in M['clips'] if c['animation']==action]; cols=min(12,clips[0]['frameCount']); rows=math.ceil(clips[0]['frameCount']/cols)
 board=Image.new('RGB',(cols*112,4*rows*116),(35,39,45));d=ImageDraw.Draw(board)
 for direction,c in enumerate(clips):
  for i,f in enumerate(c['frames']):
   x=(i%cols)*112;y=(direction*rows+i//cols)*116
   im=Image.open(f['png']).convert('RGBA').crop((80,60,176,156));board.paste(im,(x,y+18),im);d.text((x,y),f'{c["direction"]} {i}',fill='white')
 board.save(OUT/f'{action}-source-board.png')

def captures(folder,name):
 folder=ROOT/folder; trace=json.loads((folder/f'{name}.json').read_text());lo=trace[0]['time'];hi=trace[-1]['time']
 entries={}
 for line in (folder/'state-captures.jsonl').read_text().splitlines():
  e=json.loads(line)
  if e['row']['name']==name and lo<=e['row']['time']<=hi:entries[e['file']]=e
 return [(folder/e['file'],e['row']) for e in sorted(entries.values(),key=lambda e:e['row']['time'])]

def tile(path,row,label=''):
 crop=ROOT/'captures'/path.parent.name/(path.name+'.png');crop.parent.mkdir(parents=True,exist_ok=True)
 if Path(str(path)+'.png').exists():
  im=Image.open(str(path)+'.png').convert('RGB');x=round(row['screenX']);y=round(im.height-row['screenY']);im=im.crop((x-144,y-144,x+144,y+112));im.save(crop)
 else:im=Image.open(crop).convert('RGB')
 canvas=Image.new('RGB',(288,290),(25,29,34));canvas.paste(im,(0,34));d=ImageDraw.Draw(canvas)
 d.text((6,3),label,fill='white');d.text((6,17),f'{row["state"]} | HP {row["hp"]} | {row["source"].split("/")[-1]}',fill=(210,220,230));return canvas

def gif(name,segments,slow=1):
 frames=[];durations=[];provenance=[]
 for folder,segment,label in segments:
  rows=captures(folder,segment)
  for i,(path,row) in enumerate(rows):
   frames.append(tile(path,row,label+(' | 3x slower' if slow==3 else ' | game time')))
   dt=rows[i+1][1]['time']-row['time'] if i+1<len(rows) else .08
   durations.append(max(20,round(dt*1000*slow/10)*10));provenance.append({'capture':str(ROOT/'captures'/path.parent.name/(path.name+'.png')),'frame':row['frame'],'time':row['time'],'source':row['source']})
 frames[0].save(OUT/f'{name}.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False)
 (OUT/f'{name}-provenance.json').write_text(json.dumps(provenance,indent=2))

dirs=['south','west','north','east']
gif('dodge-unity',[('candidate',f'dodge-{i}',f'Dodge {v}') for i,v in enumerate(dirs)])
gif('dodge-unity-slow',[('candidate',f'dodge-{i}',f'Dodge {v}') for i,v in enumerate(dirs)],3)
gif('hurt-unity',[('candidate','confirmed-incoming','Accepted spatial melee -> Hurt')])
gif('death-unity',[('candidate','death-0','Death: 23 cels, held terminal'),('candidate','death-held-0','Terminal pose remains visible')])
gif('walk-dodge-walk',[('candidate','walk-dodge-walk','Walk -> Dodge -> Walk')])
gif('attack-hurt',[('candidate','attack-hurt','Accepted damage: Slash then Hurt')])
gif('hurt-death',[('candidate','hurt-before-death-0','Hurt -> accepted lethal hit'),('candidate','death-0','Death -> held terminal')])

for action,prefix in [('dodge','dodge'),('hurt','hurt'),('death','death')]:
 seq=[]
 for i in range(4):
  rows=captures('candidate',f'{prefix}-{i}');picked={}
  for p,r in rows:
   if r['state']==action:picked.setdefault(r['source'],(p,r))
  seq.append(list(picked.values()))
 count=max(len(r) for r in seq);cols=min(8,count);row_count=math.ceil(count/cols);board=Image.new('RGB',(cols*288,4*row_count*290),(25,29,34))
 for di,rows in enumerate(seq):
  for fi,(p,r) in enumerate(rows):board.paste(tile(p,r,dirs[di]),((fi%cols)*288,(di*row_count+fi//cols)*290))
 board.save(OUT/f'{action}-unity-board.png')

for name in ['walk','basic','heavy']:
 frames=[]
 for direction in range(1 if name=='heavy' else 4):
  segment=f'regression-{name}'+('' if name=='heavy' else f'-{direction}')
  left=captures('baseline',segment);right=captures('candidate',segment)
  # Sample each actual recording at the same elapsed game time; preserve only captured poses.
  for t in [i*.04 for i in range(25 if name=='heavy' else 16)]:
   a=min(left,key=lambda r:abs(r[1]['time']-left[0][1]['time']-t));b=min(right,key=lambda r:abs(r[1]['time']-right[0][1]['time']-t))
   im=Image.new('RGB',(576,290));im.paste(tile(*a,'B10 original'),(0,0));im.paste(tile(*b,'B11 reused B10'),(288,0));frames.append(im)
 frames[0].save(OUT/f'b10-vs-b11-{name}.gif',save_all=True,append_images=frames[1:],duration=70,loop=0,optimize=False)

before=json.loads((ROOT/'preservation-before.json').read_text());bad=[p for p,h in before.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
assert not bad,bad
(ROOT/'preservation-after.json').write_text(json.dumps({'checkedFiles':len(before),'changed':bad,'allB10FilesByteIdentical':True,'baseManifestSha256':hashlib.sha256(Path(M['baseManifest']).read_bytes()).hexdigest()},indent=2))
print('Previews from real EOF captures; B10 files unchanged:',len(before))
