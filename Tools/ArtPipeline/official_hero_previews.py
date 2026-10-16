"""Curate B12 previews using actual Unity end-of-frame captures, with provenance."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root=Path('Docs/Validation/Marco06B12');raw=root/'gameplay';out=root/'previews';out.mkdir(exist_ok=True);crops=root/'captures';crops.mkdir(exist_ok=True)
all_rows=[json.loads(s) for s in (raw/'state-captures.jsonl').read_text(encoding='utf-8').splitlines()]

def frames(segment):
 trace=json.loads((raw/(segment+'.json')).read_text(encoding='utf-8'));lo=trace[0]['time'];hi=trace[-1]['time'];items={}
 for e in all_rows:
  if e['row']['name']==segment and lo<=e['row']['time']<=hi:items[e['file']]=e
 return sorted(items.values(),key=lambda e:e['row']['time'])

def image(e):
 p=raw/(e['file']+'.png');target=crops/p.name
 if p.exists():
  im=Image.open(p).convert('RGB');r=e['row'];x=round(r['screenX']);y=round(im.height-r['screenY']);im=im.crop((x-144,y-144,x+144,y+112));im.save(target)
 else:im=Image.open(target).convert('RGB')
 board=Image.new('RGB',(288,290),(25,29,34));board.paste(im,(0,34));draw=ImageDraw.Draw(board);r=e['row'];draw.text((6,3),'Official Iron Knight | Unity game time',fill='white');draw.text((6,17),f'{r["state"]} | HP {r["hp"]} | {r["source"].split("/")[-1]}',fill=(210,220,230));return board

for name,segments in {'walk':[f'regression-walk-{i}' for i in range(4)],'attacks':[f'regression-basic-{i}' for i in range(4)]+['regression-heavy'],'states':[f'dodge-{i}' for i in range(4)]+['confirmed-incoming','attack-hurt','death-0','death-held-0']}.items():
 sequence=[];durations=[];provenance=[]
 for segment in segments:
  rows=frames(segment)
  for i,e in enumerate(rows):
   sequence.append(image(e));dt=rows[i+1]['row']['time']-e['row']['time'] if i+1<len(rows) else .1;durations.append(max(20,round(dt*100)*10));provenance.append({'capture':(crops/(e['file']+'.png')).as_posix(),'frame':e['row']['frame'],'time':e['row']['time'],'source':e['row']['source']})
 sequence[0].save(out/(name+'.gif'),save_all=True,append_images=sequence[1:],duration=durations,loop=0,optimize=False)
 (out/(name+'-provenance.json')).write_bytes((json.dumps(provenance,indent=2)+'\n').encode('utf-8'))
print('Walk, attacks and state GIFs assembled from real official-world captures.')
