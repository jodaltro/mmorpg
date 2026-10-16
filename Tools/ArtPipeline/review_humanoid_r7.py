"""Review real Unity captures and immutable Aseprite exports; never edits game art."""
import json,math,re,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];E=ROOT/'Docs/Validation/HumanoidSwordR7';OUT=E/'previews'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def vec(s):return [float(v) for v in re.findall(r'[-+]?\d*\.?\d+(?:[Ee][-+]?\d+)?',s)]
def main():
 OUT.mkdir(exist_ok=True);unique={}
 for line in (E/'captures.jsonl').read_text().splitlines():
  c=json.loads(line);unique[(c['name'],c['path'])]=c
 groups={}
 for c in unique.values():groups.setdefault(c['name'],[]).append(c)
 for g in groups.values():g.sort(key=lambda x:x['time'])
 def crop(c):
  x,y=c['playerPixel'];im=Image.open(ROOT/c['path']).convert('RGB');return im.crop((int(x)-120,int(y)-245,int(x)+120,int(y)+75))
 def gif(names,path,labels=None):
  columns=min(4,len(names));rows=math.ceil(len(names)/columns);seq=[]
  for i in range(max(len(groups[n]) for n in names)):
   panel=Image.new('RGB',(columns*240,rows*342),'#263137');draw=ImageDraw.Draw(panel)
   for j,n in enumerate(names):
    c=groups[n][min(i,len(groups[n])-1)];x=j%columns*240;y=j//columns*342;panel.paste(crop(c),(x,y));draw.text((x+3,y+323),(labels[j] if labels else n)+' / Unity',fill='white')
   seq.append(panel)
  seq[0].save(OUT/path,save_all=True,append_images=seq[1:],duration=50,loop=0,disposal=2,optimize=False)
 for prefix in ['basic','heavy','weapon-walk']:
  gif([f'{prefix}-{d}' for d in range(8)],prefix+'-eight-unity.gif')
 gif(['basic-3'],'near-hit-unity.gif');gif(['wall-3'],'wall-block-unity.gif')
 gif(['grip-'+p+'-'+str(d) for p in ['sword-neutral','sword-adjusted-grip'] for d in [0,3]],'procedural-grip-unity-study.gif')
 board=Image.new('RGB',(960,684),'#263137');draw=ImageDraw.Draw(board)
 for d in range(8):
  g=groups[f'basic-{d}'];c=g[min(2,len(g)-1)];x=d%4*240;y=d//4*342;board.paste(crop(c),(x,y));draw.text((x+3,y+323),f'Grip / direction {d}',fill='white')
 board.save(OUT/'grip-eight-unity.png')
 c=groups['f7-basic-3'][min(3,len(groups['f7-basic-3'])-1)];shutil.copyfile(ROOT/c['path'],OUT/'f7-actual-sweep.png')
 shutil.copyfile(E/'locomotion-gameplay/after-f5.png',OUT/'valdoria-after-f5.png')
 qa=[]
 for prefix in ['basic','heavy','continuous','f7-basic']:
  for d in range(8):
   rows=load(E/f'{prefix}-{d}.json');active=[r for r in rows if r['active']];phases=sorted({r['phase'] for r in rows if r['phase']!='idle'})
   r=dict(action=prefix,direction=d,phases=phases,renderedFrames=len(rows),maxRenderedGripError=max(x['handError'] for x in rows),activeBodyMatchesCut=bool(active) and all(x['state']=='attack-cut' for x in active),bladeLength=[min(x['bladeLength'] for x in rows),max(x['bladeLength'] for x in rows)],transitionToIdle=any(x['state']=='idle' for x in rows),sortingTested='bladeSorting' in rows[0])
   if r['sortingTested']:r['sortingMatchesFrameDepth']=all(x['bladeSorting']==x['bodySorting']+x['depth'] for x in rows)
   qa.append(r)
 assert all(r['maxRenderedGripError']<1e-4 and r['activeBodyMatchesCut'] and r['transitionToIdle'] and len(r['phases'])==3 for r in qa)
 (E/'presentation-qa.json').write_text(json.dumps(dict(traces=qa,technicalPass=True,artisticApproval=False,heavySharesBasicDrawings=True,renderedGripMeasurementNotFingerContactCertification=True),indent=2))
 matrices=[]
 for p in sorted(E.glob('matrix-*.json')):
  data=load(p)
  # This asynchronous observation precedes weapon LateUpdate; rendered error is measured above.
  for r in data:
   if 'gripError' in r:r['preLateUpdateGripSeparation']=r.pop('gripError')
  p.write_text(json.dumps(data,indent=2));assert len(data)==8 and all(r['passed'] for r in data),p
  matrices.append(dict(scenario=data[0]['scenario'],directions=8,damage=[r['damage'] for r in data],hits=[r['hits'] for r in data],passed=True))
 (E/'combat-summary.json').write_text(json.dumps(dict(scenarios=matrices,cases=sum(r['directions'] for r in matrices),allPassed=True,negativeCasesUseRealAuthorityAndSweep=True,fixtureNotes=['Wall at 0.65, target at 1.3; collider does not straddle wall. Same placement without wall hits in all sectors.','TrainingDummy auto recovery disabled only inside matrix fixture to prevent stale previousHealth from resetting observed damage.','Death cancellation fixture sets authoritative CombatState dead; official DeathStates separately tests full lifecycle.','Moving opposite test begins movement 0.01s before click; no out-of-range target tracking.']),indent=2))
 old=load(E/'r6-reproduced-before-change.json');new=load(E/'near-gate.json')
 (E/'r6-vs-r7.json').write_text(json.dumps(dict(r6Damage=old['actualDamage'],r6Hits=old['actualHitCount'],r6ActualOverlapCount=sum(r['overlaps'] for r in old['samples']),r6RootLos=all(r['rootLos'] for r in old['samples']),r6GripLosFailures=sum(not r['gripLos'] for r in old['samples']),r7Damage=new['actualDamage'],r7Hits=new['actualHitCount'],sameActorRoot=[-2.75,0],sameTarget=[-1.9,0],targetColliderBounds='center (-1.9,0), extents (0.325,0.55)',capsuleWidth=.16,authoritativeRange=1.25,phaseSeconds=[.06,.14,.16],cause='No sampled capsule overlaps target; projected grip LOS also differs. No overlap alone is sufficient for the miss.'),indent=2))
 # Native procedural pose review, finished by the local Aseprite Lua pipeline.
 lab=ROOT/'ArtSource/Labs/Humanoid2026/R7/GripStudy';data=load(lab/'aseprite.json');sheet=Image.open(lab/'spritesheet.png').convert('RGBA');poses=[]
 for f in data['frames']:
  r=f['frame'];poses.append(sheet.crop((r['x'],r['y'],r['x']+128,r['y']+160)))
 # Compact 3 poses across, 4 profile/view rows, 2x nearest enlargement at the end.
 panel=Image.new('RGBA',(384,720),'#263137');draw=ImageDraw.Draw(panel)
 for row,indices in enumerate([[0,1,2],[3,4,5],[6,7,8],[9,10,11]]):
  for col,i in enumerate(indices):panel.alpha_composite(poses[i],(col*128,row*180));draw.text((col*128+2,row*180+162),['neutral S','adjusted S','neutral E','adjusted E'][row]+f' / pose {col}',fill='white')
 panel.convert('RGB').resize((768,1440),Image.Resampling.NEAREST).save(OUT/'procedural-grip-poses.png')
 print('Evidence built:',len(qa),'presentation traces;',sum(r['directions'] for r in matrices),'combat cases; 12 procedural source poses.')
if __name__=='__main__':main()
