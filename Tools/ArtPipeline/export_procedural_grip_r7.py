"""Finish a new procedural-grip render directory via local Aseprite, never overwrite sources."""
import argparse,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();qa=json.loads((a.renders/'qa.json').read_text());out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);frames=[];clips=[]
 for r in qa['records']:
  name=r['profile']+'-'+r['view']
  if not clips or clips[-1]['name']!=name:clips.append(dict(name=name,first=len(frames)+1,last=len(frames)+1))
  else:clips[-1]['last']+=1
  frames.append(dict(path=r['file'],duration=.18))
 plan=dict(reference=str(ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/ValdoriaSwordsman.aseprite'),output=str(out/'ProceduralGrip.aseprite'),frames=frames,clips=clips);temp=ROOT/'Temp/HumanoidR7/grip-plan.json';temp.write_text(json.dumps(plan))
 subprocess.run(['D:/Aseprite/Aseprite.exe','-b','--script-param','plan='+str(temp),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r6.lua')],capture_output=True,check=True)
 subprocess.run(['D:/Aseprite/Aseprite.exe','-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','6'],capture_output=True,check=True)
 print('Exported',len(frames),'procedural poses;',len(clips),'tags; existing artwork unchanged.')
if __name__=='__main__':main()
