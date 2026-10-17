"""Local Aseprite finish and clipping gate for separate action canvases."""
import argparse,json,subprocess,math,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];LAB=ROOT/'ArtSource/Labs/Humanoid2026/R8';E=ROOT/'Docs/Validation/HumanoidStatesR8';ASE='D:/Aseprite/Aseprite.exe'
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);a=p.parse_args();records=json.loads((a.renders/'frames.json').read_text());reports=[]
 for action in ['dodge','death']:
  rows=[r for r in records if r['action']==action];out=LAB/action;out.mkdir(exist_ok=False);w,h=rows[0]['canvas'];clips=[]
  for i,r in enumerate(rows):
   if not clips or clips[-1]['direction']!=r['direction']:clips.append(dict(name=action+'_'+r['view'],direction=r['direction'],first=i+1,last=i+1,loop=False))
   else:clips[-1]['last']=i+1
  plan=dict(reference=str(ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/ValdoriaSwordsman.aseprite'),output=str(out/(action+'.aseprite')),canvas=[w,h],frames=[dict(path=r['file'],duration=r['seconds']) for r in rows],clips=clips);pp=ROOT/'Temp/HumanoidR8'/f'{action}-plan.json';pp.write_text(json.dumps(plan))
  subprocess.run([ASE,'-b','--script-param','plan='+str(pp),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r8.lua')],capture_output=True,check=True)
  subprocess.run([ASE,'-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','16' if action=='death' else '8'],capture_output=True,check=True)
  data=json.loads((out/'aseprite.json').read_text());sheet=Image.open(out/'spritesheet.png').convert('RGBA');images=[];bad=[]
  for i,f in enumerate(data['frames']):
   r=f['frame'];im=sheet.crop((r['x'],r['y'],r['x']+w,r['y']+h));box=im.getbbox();images.append(im);rows[i]['alphaBounds']=list(box) if box else None
   if not box or box[0]<=0 or box[1]<=0 or box[2]>=w or box[3]>=h:bad.append(dict(index=i,bbox=box))
  assert not bad,(action,bad)
  assert len(clips)==8 and all(abs(r['projectionPixelsPerMeter']-160/2.4)<1e-4 for r in rows)
  manifest=dict(action=action,canvas=[w,h],pivotTop=rows[0]['pivotTop'],pivotUnity=rows[0]['pivotUnity'],ppu=32,clips=clips,frames=rows,artisticApproval='pending',loop=False);(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
  report=dict(action=action,frames=len(rows),clips=len(clips),cropped=bad,ppu=32,canvas=[w,h],pivotTop=rows[0]['pivotTop'],pivotUnity=rows[0]['pivotUnity'],projectionPixelsPerMeter=160/2.4);reports.append(report)
  frames=[];n=clips[0]['last']-clips[0]['first']+1
  for i in range(n):
   board=Image.new('RGBA',(256*4,246*2),(30,34,40,255));d=ImageDraw.Draw(board)
   for j,clip in enumerate(clips):
    im=images[clip['first']-1+i];x=j%4*256+(256-w)//2;y=j//4*246+22+(224-h)//2;board.alpha_composite(im,(x,y));d.text((j%4*256+6,j//4*246+5),clip['name'],fill='white')
   frames.append(board.convert('RGB'))
  durations=([30,30,20,30,30,30,20,30] if action=='dodge' else [100]*(n-1)+[500]);durations[0]+=250 if action=='dodge' else 0;durations[-1]+=250 if action=='dodge' else 0
  frames[0].save(E/'previews'/f'{action}-eight-aseprite.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0)
  if action=='dodge':frames[0].save(E/'previews/dodge-eight-real-cadence.gif',save_all=True,append_images=frames[1:],duration=[30,30,20,30,30,30,20,30],loop=0)
  if action=='death':frames[-1].save(E/'previews/death-terminal-eight.png')
 (E/'canvas-gate.json').write_text(json.dumps(dict(passed=True,actions=reports,sourceAudit='spatial-audit.json: every native Roll/Death sample, eight views',noPhysicalRootMotion=True),indent=2));print(json.dumps(reports))
if __name__=='__main__':main()
