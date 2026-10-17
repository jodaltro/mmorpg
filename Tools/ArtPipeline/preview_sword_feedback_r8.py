"""Finish the R8 feedback study using local Aseprite; compose actual separate sword pixels."""
from pathlib import Path
import json,math,subprocess,argparse
from PIL import Image,ImageDraw,ImageChops
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);p.add_argument('--geometry',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 qa=json.loads((a.geometry/'qa.json').read_text());rows=qa['records']
 for r in rows:r['file']=str((a.renders/Path(r['file']).name).resolve())
 clips=[]
 for i,r in enumerate(rows):
  name=r['action']+'_'+r['view']
  if not clips or clips[-1]['name']!=name:clips.append(dict(name=name,first=i+1,last=i+1))
  else:clips[-1]['last']=i+1
 plan=dict(reference=str(ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/ValdoriaSwordsman.aseprite'),output=str(out/'SwordFeedback.aseprite'),canvas=[128,160],frames=[dict(path=r['file'],duration=r['seconds']) for r in rows],clips=clips)
 planfile=out/'plan.json';planfile.write_text(json.dumps(plan));ase='D:/Aseprite/Aseprite.exe'
 subprocess.run([ase,'-b','--script-param','plan='+str(planfile),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r8.lua')],check=True,capture_output=True)
 subprocess.run([ase,'-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--format','json-array','--sheet-type','rows','--sheet-columns','8'],check=True,capture_output=True)
 sheet=Image.open(out/'spritesheet.png').convert('RGBA');data=json.loads((out/'aseprite.json').read_text());sword=Image.open(ROOT/'ArtSource/Weapons/IronSword/frame_000.png').convert('RGBA');composites=[]
 for i,r in enumerate(rows):
  f=data['frames'][i]['frame'];body=sheet.crop((f['x'],f['y'],f['x']+128,f['y']+160));mask=Image.new('L',(128,160));d=ImageDraw.Draw(mask)
  for polygon in r['handForegroundPolygons']:d.polygon([tuple(v) for v in polygon],fill=255)
  fg=body.copy();fg.putalpha(ImageChops.multiply(mask,body.getchannel('A')));fg.save(out/f'hand-{i:03}.png')
  rad=math.radians(r['holdAngle']-38.79655);co,si=math.cos(rad),math.sin(rad);x,y=r['hand'][:2];x+=64;y+=32
  weapon=sword.transform((256,224),Image.Transform.AFFINE,(co,-si,31-co*x+si*y,si,co,45-si*x-co*y),Image.Resampling.NEAREST)
  im=Image.new('RGBA',(256,224),(0,0,0,0))
  if r['depth']<0:im.alpha_composite(weapon)
  im.alpha_composite(body,(64,32))
  if r['depth']>=0:im.alpha_composite(weapon)
  im.alpha_composite(fg,(64,32));composites.append(im)
 board=Image.new('RGB',(1024,488),(30,34,40));d=ImageDraw.Draw(board)
 for j,view in enumerate(['south','east']):
  selected=[i for i,r in enumerate(rows) if r['view']==view and r['action']=='sword-study']
  for col,i in enumerate(selected):board.paste(composites[i],(col*256,j*244+20),composites[i]);d.text((col*256+6,j*244+4),'Aseprite + separate sword / '+view+' '+str(rows[i]['index']),fill='white')
 board.save(out/'sword-contact-preview.png')
 sequence=[]
 for pose in range(8):
  board=Image.new('RGB',(512,244),(30,34,40));d=ImageDraw.Draw(board)
  for col,view in enumerate(['south','east']):
   i=next(i for i,r in enumerate(rows) if r['action']=='dodge' and r['view']==view and r['index']==pose);board.paste(composites[i],(col*256,20),composites[i]);d.text((col*256+6,4),'Aseprite study / expressive dodge / '+view,fill='white')
  sequence.append(board)
 sequence[0].save(out/'dodge-feedback-real-cadence.gif',save_all=True,append_images=sequence[1:],duration=[30,30,20,30,30,30,20,30],loop=0)
 sequence[0].save(out/'dodge-feedback-slow.gif',save_all=True,append_images=sequence[1:],duration=110,loop=0)
 (out/'qa.json').write_text(json.dumps(qa,indent=2));print('Finished local Aseprite feedback previews',len(rows))
if __name__=='__main__':main()
