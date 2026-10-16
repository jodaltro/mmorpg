"""Export R5 through local Aseprite, compare frozen frames and build review artifacts."""
import json,hashlib,subprocess,argparse
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];LAB=ROOT/'ArtSource/Labs/Humanoid2026';R5=LAB/'R5';ASE='D:/Aseprite/Aseprite.exe'
def run(args):subprocess.run([ASE,'-b']+args,check=True,capture_output=True)
def export(doc,folder):
 run([str(doc),'--sheet',str(folder/'spritesheet.png'),'--list-tags','--data',str(folder/'aseprite.json'),'--format','json-array','--sheet-type','rows','--sheet-columns','8'])
 sheet=Image.open(folder/'spritesheet.png').convert('RGBA');data=json.loads((folder/'aseprite.json').read_text());return [sheet.crop((f['frame']['x'],f['frame']['y'],f['frame']['x']+128,f['frame']['y']+160)) for f in data['frames']],data

def panel(images,labels,scale=3):
 im=Image.new('RGBA',(128*len(images),180),'#263137');d=ImageDraw.Draw(im)
 for i,(image,label) in enumerate(zip(images,labels)):im.alpha_composite(image,(128*i,0));d.text((128*i+4,164),label,fill='white')
 return im.convert('RGB').resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);a=p.parse_args();src=a.renders.resolve();out=R5/'Results';out.mkdir(exist_ok=False)
 old=json.loads((LAB/'Preview/Male/manifest.json').read_text());poses=json.loads((src/'pose-metadata.json').read_text());new=json.loads((src/'inspection.json').read_text())['Male'];assert new['frames']==old['frames'],'Sampling changed'
 frames=[dict(path=str(src/f['file']),reference=str(src/'Reference'/(f['clip']+'_'+str(f['index']).zfill(3)+'.png')),duration=.125 if f['clip'].startswith('idle') else .111,hand=pose['rightHand']['pixel']) for f,pose in zip(new['frames'],poses)]
 plan=dict(output=str((out/'ValdoriaSwordsman.aseprite').resolve()),frames=frames,clips=old['clips']);planpath=ROOT/'Temp/HumanoidR5/finish-plan.json';planpath.write_text(json.dumps(plan));run(['--script-param','plan='+str(planpath.resolve()),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/finish_humanoid_outfit_r5.lua')]);images,data=export(out/'ValdoriaSwordsman.aseprite',out)
 # Independently finish body-only re-renders using the original Lua pass.
 ref=src/'ReferenceExport';ref.mkdir(exist_ok=False);refplan=dict(output=str((ref/'Reference.aseprite').resolve()),frames=[dict(path=f['reference'],duration=f['duration']) for f in frames],clips=old['clips']);rp=ROOT/'Temp/HumanoidR5/ref-plan.json';rp.write_text(json.dumps(refplan));run(['--script-param','plan='+str(rp.resolve()),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/build_humanoid_study.lua')]);refs,_=export(ref/'Reference.aseprite',ref)
 frozen=Image.open(LAB/'Preview/Male/spritesheet.png').convert('RGBA');olddata=json.loads((LAB/'Preview/Male/aseprite.json').read_text());original=[]
 for f in olddata['frames']:
  r=f['frame'];original.append(frozen.crop((r['x'],r['y'],r['x']+128,r['y']+160)))
 integrity=[]
 for i,(im,reference,base) in enumerate(zip(images,refs,original)):
  box=im.getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<128 and box[3]<160,'Outfit clipped by canvas';assert set(im.getchannel('A').get_flattened_data())<={0,255};assert data['frames'][i]['duration']==olddata['frames'][i]['duration']
  diff=sum(x!=y for x,y in zip(reference.get_flattened_data(),base.get_flattened_data()));integrity.append(dict(index=i,referencePixelDifferences=diff,referenceExact=diff==0,sourceFrame=poses[i]['sourceFrame'],bbox=box,frameHash=hashlib.sha256(im.tobytes()).hexdigest()))
 qa=dict(frames=52,walkFrames=48,clips=8,canvas=[128,160],ppu=32,pivotTopLeft=[64,126],samplingIdentical=True,durationsIdentical=True,referenceRerenderExactFrames=sum(x['referenceExact'] for x in integrity),referenceRerenderPixelDifferences=sum(x['referencePixelDifferences'] for x in integrity),bodyGeometryRemoved=False,canvasClipping=False,framesQA=integrity,artisticApproval=False)
 (out/'qa.json').write_text(json.dumps(qa,indent=2));(out/'pose-metadata.json').write_text(json.dumps(poses,indent=2));(out/'manifest.json').write_text(json.dumps(dict(character='ValdoriaSwordsman-R5',license='CC0-1.0 plus project authored fitting/finish',canvas=[128,160],ppu=32,pivot=[64,126],ground=[64,144],clips=old['clips'],frames=new['frames'],directions={'south':0,'east':1,'north':2,'west':3},handAnchorsCertified=False),indent=2))
 order=[('south',0,1),('east',39,40),('north',26,27),('west',13,14)]
 panel([original[0],images[0]],['Approved body','R5 outfit']).save(out/'original-vs-outfit.png');panel([images[i] for _,i,_ in order],['South','Left','North','Right']).save(out/'four-directions.png')
 for direction,idle,start in order:
  seq=[panel([images[start+i]],['R5 '+direction]) for i in range(12)]*2;seq[0].save(out/('walk_'+direction+'.gif'),save_all=True,append_images=seq[1:],duration=110,loop=0,disposal=2,optimize=False)
 seq=[panel([original[1+i],images[1+i]],['Approved','Dressed']) for i in range(12)]*2;seq[0].save(out/'walk-original-vs-outfit.gif',save_all=True,append_images=seq[1:],duration=110,loop=0,disposal=2,optimize=False)
 seq=[panel([images[start+i] for _,_,start in order],['South','Left','North','Right'],2) for i in range(12)]*2;seq[0].save(out/'walk-four-directions.gif',save_all=True,append_images=seq[1:],duration=110,loop=0,disposal=2,optimize=False)
 for name,start in [('south',1),('left',40),('north',27),('right',14)]:
  board=Image.new('RGBA',(128*6,180*2),'#263137');d=ImageDraw.Draw(board)
  for i in range(12):board.alpha_composite(images[start+i],((i%6)*128,(i//6)*180));d.text(((i%6)*128+4,(i//6)*180+163),str(i),fill='white')
  board.convert('RGB').resize((1536,720),Image.Resampling.NEAREST).save(out/('pose-review-'+name+'.png'))
 panel([images[0],images[39],images[26]],['Front detail','Side detail','Back detail'],5).save(out/'outfit-details-nearest.png')
 print(json.dumps({k:v for k,v in qa.items() if k!='framesQA'},indent=2))
if __name__=='__main__':main()
