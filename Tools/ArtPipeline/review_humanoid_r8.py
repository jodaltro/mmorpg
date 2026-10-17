"""Build explicitly labelled previews from real Unity screenshots, not simulated gameplay."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];E=ROOT/'Docs/Validation/HumanoidStatesR8';OUT=E/'previews'
def captures(name,state=None):
 p=E/(name+'.json')
 if not p.exists():return []
 rows=json.loads(p.read_text());lo=min(r['frame'] for r in rows);hi=max(r['frame'] for r in rows);items={}
 for line in (E/'captures.jsonl').read_text().splitlines():
  r=json.loads(line)
  if r['name']==name and lo<=r['row']['frame']<=hi and (state is None or r['row']['state']==state):items[r['path']]=r
 return sorted(items.values(),key=lambda r:r['row']['time'])
def crop(r):
 im=Image.open(ROOT/r['path']);x,y=r['row']['screenRoot'];return im.crop((round(x)-280,round(y)-260,round(x)+280,round(y)+160)).convert('RGB')
def gif(items,name):
 if not items:return
 frames=[crop(r) for r in items];durations=[]
 for i,r in enumerate(items):
  delta=items[i+1]['row']['time']-r['row']['time'] if i+1<len(items) and items[i+1]['name']==r['name'] else .15*r['timeScale']
  durations.append(max(20,min(600,round(delta/r['timeScale']*1000))))
 frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=durations,loop=0)
def main():
 for group,name in [('death-1','death-west-unity.gif'),('hurt-3','hurt-unity.gif'),('walk-dodge-walk','walk-dodge-walk-unity-slow.gif'),('idle-dodge-idle-attack','dodge-to-attack-unity-slow.gif')]:gif(captures(group),name)
 gif(captures('heavy-to-hurt','hurt')+captures('hurt-to-death'),'hurt-to-death-unity.gif');gif(captures('death-before-restart')+captures('restart-to-idle'),'death-to-restart-unity.gif')
 groups=[captures('dodge-'+str(d),'dodge') for d in range(8)]
 if all(groups):
  seq=[]
  for i in range(8):
   board=Image.new('RGB',(1120,464),(30,34,40));draw=ImageDraw.Draw(board)
   for d,rows in enumerate(groups):
    # Ordered screenshots at each visible pose, native pixels via integer downsample.
    r=rows[min(i,len(rows)-1)];im=crop(r).resize((280,210),Image.Resampling.NEAREST);x=d%4*280;y=d//4*232;board.paste(im,(x,y+22));draw.text((x+6,y+5),'Unity dodge '+str(d)+' / x0.35',fill='white')
   seq.append(board)
  seq[0].save(OUT/'dodge-eight-unity-slow.gif',save_all=True,append_images=seq[1:],duration=80,loop=0)
  crop(groups[3][min(3,len(groups[3])-1)]).save(OUT/'sword-dodge-transition.png')
 rows=captures('death-1');
 if rows:Image.open(ROOT/rows[-1]['path']).save(OUT/'corpse-held-unity.png')
 # Quantitative report uses every rendered sample, not only the screenshots selected for GIF.
 report={}
 for prefix in ['dodge','death','hurt']:
  report[prefix]=[]
  for d in range(8):
   p=E/f'{prefix}-{d}.json'
   if not p.exists():continue
   rows=json.loads(p.read_text());active=[r for r in rows if r['state']==prefix]
   report[prefix].append(dict(direction=d,renderedSamples=len(active),poses=len({r['sprite'] for r in active}),allVisible=all(r['visible'] for r in active),maxGripError=max((r['grip'] for r in active),default=0),terminalHeld=rows[-1]['complete'] if prefix=='death' else None))
 (E/'presentation-qa.json').write_text(json.dumps(report,indent=2));print('R8 previews built from actual Unity frames')
if __name__=='__main__':main()
