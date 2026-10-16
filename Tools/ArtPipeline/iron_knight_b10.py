"""Assemble B10 metadata and annotated editable copies; never redraw/reconstruct original poses."""
from pathlib import Path
import json,hashlib,subprocess
ROOT=Path('ArtSource/Labs/IronKnight2026');OUT=ROOT/'B10'
if (OUT/'editable').exists():raise FileExistsError('Refusing to overwrite editable B10 documents')
m=json.loads((ROOT/'manifest.json').read_text());review=json.loads((OUT/'hand-review.json').read_text());changes=[];lua=[]
m['schema']='iron-knight-b10-v1';m['id']='IronKnightB10';m['status']='experimental; anatomical review and user artistic approval pending';m['phaseRanges']=review['phaseRanges'];m['walkCadenceMultiplier']=1.25;m['sourceManifestSha256']=hashlib.sha256((ROOT/'manifest.json').read_bytes()).hexdigest()
# Sorting follows the anatomical arm crossing, not only the facing direction.
attack_depth={'south':[1]*15,'west':[-1]*6+[1]*8+[-1],'north':[-1]*7+[1]*5+[-1]*3,'east':[1]*8+[-1]*3+[1]*4}
for c in m['clips']:
 action=c['animation'];direction=c['direction'];c['sheet']=(ROOT/'frames'/action/direction/'sheet.png').as_posix();dest=OUT/'editable'/action/direction;dest.mkdir(parents=True,exist_ok=True)
 source=(ROOT/'editable'/action/direction/f'{action}-{direction}.aseprite').as_posix();target=(dest/f'{action}-{direction}.aseprite').as_posix();lua+=['do',f'local s=app.open("{source}")','local hands=s:newLayer();hands.name="GUIDE anatomical right grip (hidden)";hands.isVisible=false']
 for i,f in enumerate(c['frames']):
  old=f['rightHand'];f['rightHand']=review['contacts'][action][direction][i]
  if old!=f['rightHand']:changes.append({'action':action,'direction':direction,'frame':i,'before':old,'after':f['rightHand']})
  f['sourceDuration']=f['duration'];f['duration']=f['duration']/1.25 if action=='walk' else f['duration'];f['equipmentDepth']=attack_depth[direction][i] if action=='attack' else (-1 if direction=='north' else 1)
  f['handReview']='manual glove region; palm partially hidden in some turning Slash frames'
  hidden=action=='attack' and ((direction=='west' and (i<=5 or i==14)) or (direction=='north' and i in [4,5,12]) or (direction=='east' and i in [8,9,10]))
  f['handVisibility']='partially occluded; anatomical continuity estimate' if hidden else 'visible glove region reviewed'
  f['depthReason']='far arm / behind body' if f['equipmentDepth']<0 else 'near arm / in front of body'
  x,y=f['rightHand'];lua+=[f'local im=Image(256,256,ColorMode.RGB);im:drawPixel({x},{y},app.pixelColor.rgba(255,0,255,255));s:newCel(hands,s.frames[{i+1}],im,Point(0,0))',f's.frames[{i+1}].duration={f["duration"]}']
 if action=='attack':
  for phase,(a,b) in review['phaseRanges'][direction].items():lua += [f'local t=s:newTag(s.frames[{a+1}],s.frames[{b+1}]);t.name="attack-{phase}"']
 lua += [f's:saveAs("{target}")','s:close()','end']
(OUT/'prepare.lua').write_text('\n'.join(lua));r=subprocess.run(['D:/Aseprite/Aseprite.exe','-b','--script',str(OUT/'prepare.lua')],capture_output=True,text=True);print(r.stdout,r.stderr);assert r.returncode==0
(OUT/'manifest.json').write_text(json.dumps(m,indent=2));(OUT/'hand-changes.json').write_text(json.dumps(changes,indent=2));print('Prepared',len(changes),'reviewed contact corrections; 108 source poses unchanged')
