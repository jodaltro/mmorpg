"""Finish the complete synchronized bow draw with local Aseprite; study only."""
import argparse,json,subprocess,math
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--revision',choices=['v3','v4'],default='v3');a=p.parse_args();q=json.loads((a.renders/'qa.json').read_text());out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 records=q['records'];assert len(records)==74
 for view in ('south','east'):
  rows=[r for r in records if r['view']==view];assert [r['sourceFrame'] for r in rows]==list(range(1,38))
  assert max(max(r['left']['socketError'],r['right']['socketError']) for r in rows)<1e-4
 plan=dict(reference=str(ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/ValdoriaSwordsman.aseprite'),output=str(out/'BowDraw.aseprite'),frames=[dict(path=r['composite'],duration=1/24) for r in records],clips=[dict(name='draw-south',first=1,last=37),dict(name='draw-east',first=38,last=74)])
 temp=ROOT/'Temp/HumanoidR7/bow-draw-plan.json';temp.write_text(json.dumps(plan))
 subprocess.run(['D:/Aseprite/Aseprite.exe','-b','--script-param','plan='+str(temp),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r6.lua')],capture_output=True,check=True)
 subprocess.run(['D:/Aseprite/Aseprite.exe','-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
 data=json.loads((out/'aseprite.json').read_text());sheet=Image.open(out/'spritesheet.png');frames=[]
 for i in range(37):
  canvas=Image.new('RGB',(512,360),(30,34,40))
  for col,idx in enumerate((i,i+37)):
   f=data['frames'][idx]['frame'];im=sheet.crop((f['x'],f['y'],f['x']+128,f['y']+160)).resize((256,320),Image.Resampling.NEAREST);canvas.paste(im,(col*256,20),im)
  frames.append(canvas)
 preview=ROOT/f'Docs/Validation/HumanoidSwordR7/previews/bow-draw-{a.revision}.gif';frames[0].save(preview,save_all=True,append_images=frames[1:],duration=42,loop=0)
 # Pure data evidence: same evaluated bow frame drives both arm targets; no second animation clock.
 q['sampleRate']=24;q['framesPerView']=37;q['revision']=a.revision
 q['presentation']='Composite sprites for this diagnostic only; editable body and bow remain separate in Blender. Not a runtime equipment implementation.'
 q['maxSocketError']=max(max(r['left']['socketError'],r['right']['socketError']) for r in records)
 q['maxAdjacentStringStep']=max(math.dist(records[i]['string'],records[i-1]['string']) for i in range(1,len(records)) if records[i]['view']==records[i-1]['view'])
 q['releaseFrame']=records[0]['releaseFrame']
 q['maxAdjacentHandStep']=max(math.dist(records[i]['handTarget'],records[i-1]['handTarget']) for i in range(1,len(records)) if records[i]['view']==records[i-1]['view'])
 q['maxFingerContactError']=max(max(r['wrap']['maxContactError'],r['pinch']['maxContactError']) for r in records)
 q['maxFingerLengthChange']=max(max(r['wrap']['maxFingerLengthChange'],r['pinch']['maxFingerLengthChange']) for r in records)
 assert all(math.dist(r['handTarget'],r['string'])<1e-6 for r in records if r['stringContact'])
 assert any(math.dist(r['handTarget'],r['string'])>.02 for r in records if not r['stringContact'])
 assert q['maxAdjacentHandStep']<.13 and q['maxFingerLengthChange']<1e-5
 if a.revision=='v4':
  q['minimumSampledHeadDistance']=min(r['headClearance']['minSignedHeadSurfaceDistance'] for r in records)
  q['penetratingGloveSamples']=sum(r['headClearance']['penetratingGloveVertices']>0 for r in records)
  q['maximumRightElbowFlexion']=max(r['rightElbowFlexionDegrees'] for r in records)
  q['maximumAdjacentElbowStep']=max(math.dist(records[i]['right']['elbow'],records[i-1]['right']['elbow']) for i in range(1,len(records)) if records[i]['view']==records[i-1]['view'])
  assert q['penetratingGloveSamples']==0 and q['minimumSampledHeadDistance']>=.015 and q['maximumRightElbowFlexion']<=125 and q['maximumAdjacentElbowStep']<=.1
 (ROOT/f'Docs/Validation/HumanoidSwordR7/bow-draw-{a.revision}.json').write_text(json.dumps(q,indent=2))
 print(json.dumps(dict(frames=74,maxSocketError=q['maxSocketError'],maxAdjacentStringStep=q['maxAdjacentStringStep'])))
if __name__=='__main__':main()
