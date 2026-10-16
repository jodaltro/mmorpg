"""Finish audited combat candidates via the same Aseprite pass; never accept cropped frames."""
import argparse,json,subprocess,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];R6=ROOT/'ArtSource/Labs/Humanoid2026/R6';ASE='D:/Aseprite/Aseprite.exe'
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);a=p.parse_args();records=json.loads((a.renders/'combat-frames.json').read_text());out=R6/'CombatCandidate';out.mkdir(exist_ok=False);frames=[];clips=[]
 for record in records:
  name=record['action']+'_'+record['view']
  if not clips or clips[-1]['name']!=name:clips.append(dict(name=name,action=record['action'],direction=record['direction'],first=len(frames)+1,last=len(frames)+1,loop=False))
  else:clips[-1]['last']+=1
  frames.append(dict(path=record['file'],duration=record['seconds']))
 plan=dict(reference=str((ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/ValdoriaSwordsman.aseprite').resolve()),output=str((out/'CombatCandidate.aseprite').resolve()),frames=frames,clips=clips);pp=ROOT/'Temp/HumanoidR6/combat-plan.json';pp.write_text(json.dumps(plan));subprocess.run([ASE,'-b','--script-param','plan='+str(pp),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r6.lua')],capture_output=True,check=True);subprocess.run([ASE,'-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
 data=json.loads((out/'aseprite.json').read_text());sheet=Image.open(out/'spritesheet.png').convert('RGBA');images=[];cropped=[]
 for i,f in enumerate(data['frames']):
  r=f['frame'];im=sheet.crop((r['x'],r['y'],r['x']+128,r['y']+160));b=im.getbbox();images.append(im)
  if b[0]<=0 or b[1]<=0 or b[2]>=128 or b[3]>=160:cropped.append(dict(index=i,action=records[i]['action'],direction=records[i]['direction'],bbox=b))
 (out/'qa.json').write_text(json.dumps(dict(frames=len(images),clips=len(clips),cropped=cropped,eligibleForIntegration=not cropped),indent=2));(out/'manifest.json').write_text(json.dumps(dict(clips=clips,frames=records),indent=2))
 for action in ['attack-preparation','attack-cut','attack-recovery','hurt']:
  selected=[c for c in clips if c['action']==action];n=max(c['last']-c['first']+1 for c in selected);sequence=[]
  for i in range(n):
   panel=Image.new('RGBA',(128*8,180),'#263137');d=ImageDraw.Draw(panel)
   for x,c in enumerate(selected):panel.alpha_composite(images[min(c['first']-1+i,c['last']-1)],(128*x,0));d.text((128*x+2,164),str(c['direction'])+' '+action,fill='white')
   sequence.append(panel.convert('RGB').resize((2048,360),Image.Resampling.NEAREST))
  sequence[0].save(out/(action+'-eight.gif'),save_all=True,append_images=sequence[1:],duration=80,loop=0,disposal=2,optimize=False)
 print('COMBAT_CANDIDATE',len(images),'cropped',len(cropped))
if __name__=='__main__':main()
