import json,subprocess,hashlib,argparse
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];R5=ROOT/'ArtSource/Labs/Humanoid2026/R5';R6=ROOT/'ArtSource/Labs/Humanoid2026/R6'
ASE='D:/Aseprite/Aseprite.exe'
def board(images,labels,scale=2):
 im=Image.new('RGBA',(128*len(images),180),'#263137');d=ImageDraw.Draw(im)
 for i,(sprite,label) in enumerate(zip(images,labels)):im.alpha_composite(sprite,(128*i,0));d.text((128*i+2,164),label,fill='white')
 return im.convert('RGB').resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
def main():
 p=argparse.ArgumentParser();p.add_argument('--renders',type=Path,required=True);a=p.parse_args();src=a.renders;out=R6/'Locomotion';out.mkdir(exist_ok=False)
 poses=json.loads((src/'diagonal-poses.json').read_text());views=json.loads((R6/'views.json').read_text());oldposes=json.loads((R5/'Results/pose-metadata.json').read_text());olddata=json.loads((R5/'Results/aseprite.json').read_text());oldsheet=Image.open(R5/'Results/spritesheet.png').convert('RGBA');frames=[];clips=[];metas=[]
 for view in views:
  d=view['unityIndex'];name=view['name']
  for action,count in [('idle',1),('walk',12)]:
   first=len(frames)+1
   for i in range(count):
    if d<4:
     base=[0,39,26,13][d]+(0 if action=='idle' else 1+i);frame=dict(referenceFrame=base+1,duration=olddata['frames'][base]['duration']/1000);meta=dict(oldposes[base]);meta.update(referenceFrame=base)
    else:
     meta=next(p for p in poses if p['clip']==action+'_'+name and p['index']==i);frame=dict(path=meta['file'],duration=.125 if action=='idle' else .111)
    meta=dict(meta);meta.update(action=action,direction=d,name=name);frames.append(frame);metas.append(meta)
   clips.append(dict(name=action+'_'+name,action=action,direction=d,first=first,last=len(frames),loop=True))
 plan=dict(reference=str((R5/'Results/ValdoriaSwordsman.aseprite').resolve()),output=str((out/'Locomotion8Dir.aseprite').resolve()),frames=frames,clips=clips);pp=ROOT/'Temp/HumanoidR6/locomotion-plan.json';pp.write_text(json.dumps(plan));subprocess.run([ASE,'-b','--script-param','plan='+str(pp),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_humanoid_r6.lua')],check=True,capture_output=True)
 subprocess.run([ASE,'-b',plan['output'],'--sheet',str(out/'spritesheet.png'),'--data',str(out/'aseprite.json'),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
 data=json.loads((out/'aseprite.json').read_text());sheet=Image.open(out/'spritesheet.png').convert('RGBA');images=[];hashes=[];cardinal=[]
 for i,f in enumerate(data['frames']):
  r=f['frame'];im=sheet.crop((r['x'],r['y'],r['x']+128,r['y']+160));box=im.getbbox();assert box and 0<box[0]<box[2]<128 and 0<box[1]<box[3]<160;assert f['duration']==round(frames[i]['duration']*1000);images.append(im);hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
  if 'referenceFrame' in frames[i]:
   old=olddata['frames'][frames[i]['referenceFrame']-1]['frame'];ref=oldsheet.crop((old['x'],old['y'],old['x']+128,old['y']+160));assert ref.tobytes()==im.tobytes();cardinal.append(dict(newIndex=i,r5Index=frames[i]['referenceFrame']-1,identical=True))
 assert len(images)==104 and len(cardinal)==52 and len(data['meta']['frameTags'])==16
 names=[v['name'] for v in views];board([images[d*13] for d in range(8)],names,2).save(out/'eight-idles.png')
 for selected,file in [(range(8),'walk-eight-directions.gif'),(range(4,8),'walk-diagonals.gif')]:
  sequence=[board([images[d*13+1+i] for d in selected],[names[d] for d in selected],2) for i in range(12)]*2;sequence[0].save(out/file,save_all=True,append_images=sequence[1:],duration=110,loop=0,disposal=2,optimize=False)
 grid=Image.new('RGBA',(12*128,8*180),'#263137');draw=ImageDraw.Draw(grid)
 for d in range(8):
  for i in range(12):grid.alpha_composite(images[d*13+1+i],(i*128,d*180));draw.text((i*128+2,d*180+164),names[d]+' '+str(i),fill='white')
 grid.convert('RGB').save(out/'all-96-walk-poses.png')
 board([images[d*13] for d in range(4)],names[:4],3).save(out/'cardinals-preserved.png')
 comparison=[]
 for d in range(4):
  r=olddata['frames'][[0,39,26,13][d]]['frame'];comparison.extend([oldsheet.crop((r['x'],r['y'],r['x']+128,r['y']+160)),images[d*13]])
 board(comparison,['R5','R6']*4,2).save(out/'r5-vs-r6-cardinals.png')
 for d in range(4,8):board([images[d*13+1+i] for i in [0,3,6,9]],[names[d]+' '+str(i) for i in [0,3,6,9]],3).save(out/('diagonal-'+names[d]+'.png'))
 foot=[]
 for d in range(4,8):
  group=[m for m in metas if m['direction']==d and m['action']=='walk'];foot.append(dict(direction=d,name=names[d],feet=[dict(phase=m['index'],pixel=m['feet'],leftWorldZ=m['skeleton']['foot_l'][2][3],rightWorldZ=m['skeleton']['foot_r'][2][3]) for m in group],note='Same professional pose timeline; projection changes by view. Fixed pivot; no foot-lock or root-motion correction applied.'))
 (out/'foot-contact.json').write_text(json.dumps(foot,indent=2));(out/'pose-metadata.json').write_text(json.dumps(metas,indent=2));(out/'manifest.json').write_text(json.dumps(dict(canvas=[128,160],ppu=32,pivot=[64,126],clips=clips,frames=104,cardinalsCopied=True,views=views),indent=2));qa=dict(frames=104,walk=96,idle=8,clips=16,cardinalsIdentical=cardinal,clippedFrames=0,frameHashes=hashes,artisticApproval=False);(out/'qa.json').write_text(json.dumps(qa,indent=2));print('R6_LOCOMOTION_EXPORTED',len(images), 'identical cardinals',len(cardinal))
if __name__=='__main__':main()
