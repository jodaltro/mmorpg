"""Export complete revised grip/body and finger-occlusion atlases using local Aseprite."""
import argparse,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 qa=json.loads((a.renders/'qa.json').read_text());rows=qa['records'];assert len(rows)==272
 clips=[]
 for i,r in enumerate(rows):
  name=r['action']+'_'+r['view']
  if not clips or clips[-1]['name']!=name:clips.append(dict(name=name,action=r['action'],direction=r['direction'],first=i+1,last=i+1,loop=r['action'] in ['idle','walk']))
  else:clips[-1]['last']=i+1
 plan=dict(reference=str(ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/ValdoriaSwordsman.aseprite'),output=str(out/'SwordContact.aseprite'),canvas=[128,160],frames=[dict(path=r['file'],duration=r['seconds']) for r in rows],clips=clips)
 planfile=ROOT/'Temp/HumanoidR8/sword-contact-plan.json';planfile.write_text(json.dumps(plan));ase='D:/Aseprite/Aseprite.exe'
 subprocess.run([ase,'-b','--script-param','plan='+str(planfile),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r8.lua')],check=True,capture_output=True)
 subprocess.run([ase,'-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','16'],check=True,capture_output=True)
 data=json.loads((out/'aseprite.json').read_text());sheet=Image.open(out/'spritesheet.png').convert('RGBA');foreground=Image.new('RGBA',sheet.size);bad=[]
 for i,r in enumerate(rows):
  f=data['frames'][i]['frame'];im=sheet.crop((f['x'],f['y'],f['x']+128,f['y']+160));bounds=im.getbbox();r['alphaBounds']=list(bounds)
  if not bounds or min(bounds[:2])<=0 or bounds[2]>=128 or bounds[3]>=160:bad.append(dict(index=i,bounds=bounds))
  mask=Image.new('L',(128,160));d=ImageDraw.Draw(mask)
  for polygon in r.pop('handForegroundPolygons'):d.polygon([tuple(v) for v in polygon],fill=255)
  fg=im.copy();fg.putalpha(ImageChops.multiply(mask,im.getchannel('A')));foreground.paste(fg,(f['x'],f['y']))
  assert r['qa']['maxUnaffectedBoneMatrixError']<1e-5
  assert r['qa']['arm']['socketError']<1e-4 and r['qa']['fingers']['maxContactError']<.001
  assert abs(r['qa']['arm']['upperLength']-r['qa']['arm']['expectedUpper'])<1e-5
  assert abs(r['qa']['arm']['lowerLength']-r['qa']['arm']['expectedLower'])<1e-5
  assert r['qa']['fingers']['maxFingerLengthChange']<1e-5
  assert r['qa']['headClearance']['penetratingGloveVertices']==0
 assert not bad,bad
 foreground.save(out/'fingers.png')
 # Retain a native editable Aseprite document for the exact derived contact pixels.
 subprocess.run([ase,'-b',str(out/'fingers.png'),'--save-as',str(out/'Fingers.aseprite')],check=True,capture_output=True)
 (out/'manifest.json').write_text(json.dumps(dict(canvas=[128,160],pivotUnity=[64,34],pivotTop=[64,126],ppu=32,clips=clips,frames=rows,artisticApproval='pending',method=qa['method']),indent=2))
 (out/'qa.json').write_text(json.dumps(dict(passed=True,frames=len(rows),clips=len(clips),cropped=bad,maxSocketError=max(r['qa']['arm']['socketError'] for r in rows),maxFingerContactError=max(r['qa']['fingers']['maxContactError'] for r in rows),maxUnaffectedBoneMatrixError=max(r['qa']['maxUnaffectedBoneMatrixError'] for r in rows),headPenetrationFrames=sum(r['qa']['headClearance']['penetratingGloveVertices']>0 for r in rows)),indent=2))
 print('Exported revised sword/contact and expressive dodge:',len(rows))
if __name__=='__main__':main()
