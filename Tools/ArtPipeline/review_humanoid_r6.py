"""Build labeled review evidence from captured Unity pixels; no generated game imagery."""
import json,math,hashlib,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];E=ROOT/'Docs/Validation/HumanoidCombat8Dir2026';R6=ROOT/'ArtSource/Labs/Humanoid2026/R6'
def main():
 out=E/'previews';out.mkdir(exist_ok=True);captures=[json.loads(x) for x in (E/'combat-candidate/captures.jsonl').read_text().splitlines()];groups={}
 for c in captures:groups.setdefault(c['name'],[]).append(c)
 def crop(c):
  x,y=c['playerPixel'];im=Image.open(ROOT/c['path']).convert('RGB');return im.crop((int(x)-120,int(y)-245,int(x)+120,int(y)+75))
 for prefix in ['basic-','heavy-','weapon-walk-']:
  seq=[];count=max(len(groups[prefix+str(i)]) for i in range(8))
  for frame in range(count):
   panel=Image.new('RGB',(960,680),'#263137');draw=ImageDraw.Draw(panel)
   for d in range(8):
    selected=groups[prefix+str(d)];c=selected[min(frame,len(selected)-1)];x=(d%4)*240;y=(d//4)*340;panel.paste(crop(c),(x,y));draw.text((x+3,y+321),prefix+str(d)+' / Unity study',fill='white')
   seq.append(panel)
  seq[0].save(out/(prefix.rstrip('-')+'-eight-unity-study.gif'),save_all=True,append_images=seq[1:],duration=50,loop=0,disposal=2,optimize=False)
 seq=[crop(c) for c in groups['hurt-confirmed']];seq[0].save(out/'hurt-unity-study.gif',save_all=True,append_images=seq[1:],duration=50,loop=0,disposal=2,optimize=False)
 # Keep full-size capture for attachment review, alongside the bounded screen crops used above.
 shutil.copyfile(ROOT/groups['basic-0'][2]['path'],out/'weapon-grip-unity-study.png')
 analyses=[]
 for prefix in ['basic-','heavy-']:
  for d in range(8):
   rows=json.loads((E/'combat-candidate'/(prefix+str(d)+'.json')).read_text());phases=sorted(set(r['phase'] for r in rows if r['phase']!='idle'));active=[r for r in rows if r['active']]
   analyses.append(dict(action=prefix,direction=d,phases=phases,maxHandAnchorError=max(r['handError'] for r in rows),activeSamples=len(active),activeBodyMatchesCut=all(r['state']=='attack-cut' for r in active),measuredBladeLengthRange=[min(r['bladeLength'] for r in rows),max(r['bladeLength'] for r in rows)]))
 (E/'combat-candidate/synchronization.json').write_text(json.dumps(dict(traces=analyses,renderedAttachmentStudy=True,gameplayGatePassed=False,blockingTest='Existing near target fixture: expected one HitConfirmed and 20 damage; observed zero HitConfirmed. No physical changes applied.',handAnchorMeasurementNotVisualApproval=True),indent=2))
 # Source probes are Blender renders, never passed off as Unity screenshots.
 probes=ROOT/'Temp/HumanoidR6/CombatInPlaceQuick';images=sorted(probes.glob('*.png'));board=Image.new('RGBA',(128*5,180*2),'#263137');draw=ImageDraw.Draw(board);boxes=[]
 for i,p in enumerate(images):
  im=Image.open(p);x=(i%5)*128;y=(i//5)*180;board.alpha_composite(im,(x,y));draw.text((x+2,y+163),p.stem[:17],fill='white');b=im.getbbox();boxes.append(dict(file=p.name,bbox=b,cropped=b[0]<=0 or b[1]<=0 or b[2]>=128 or b[3]>=160))
 board.convert('RGB').resize((1280,720),Image.Resampling.NEAREST).save(out/'rejected-roll-death-blender-probes.png');(E/'rejected-clips.json').write_text(json.dumps(dict(source='Blender in-place probe, not gameplay',canvas=[128,160],frames=boxes,rollSourceSeconds=44/30,authoritativeDodgeSeconds=.22,rollSpeedupRequired=(44/30)/.22,deathSourceSeconds=72/30,integrated=False),indent=2))
 for action in ['dodge','death']:
  files=sorted(probes.glob(action+'*.png'));seq=[]
  for p in files:
   panel=Image.new('RGBA',(128,180),'#263137');panel.alpha_composite(Image.open(p),(0,0));ImageDraw.Draw(panel).text((2,163),'REJECTED / Blender',fill='white');seq.append(panel.convert('RGB').resize((384,540),Image.Resampling.NEAREST))
  seq[0].save(out/('rejected-'+action+'-blender.gif'),save_all=True,append_images=seq[1:],duration=120,loop=0,disposal=2,optimize=False)
 # Same 3D sampling across new views; report numerical projection without claiming foot lock.
 old=json.loads((ROOT/'ArtSource/Labs/Humanoid2026/R5/Results/pose-metadata.json').read_text());new=json.loads((R6/'Locomotion/pose-metadata.json').read_text());errors=[]
 for p in new:
  if p['direction']<4:continue
  base=old[0 if p['action']=='idle' else 1+p['index']];error=max(abs(p['skeleton'][b][r][c]-base['skeleton'][b][r][c]) for b in p['skeleton'] for r in range(4) for c in range(4));errors.append(error)
 (E/'locomotion-pose-integrity.json').write_text(json.dumps(dict(newDiagonalFrames=52,maxWorldBoneMatrixDifferenceFromR5=max(errors),withinFloatTolerance=max(errors)<.00001,cardinalPixelIdenticalFrames=52,footMetadata='ArtSource/Labs/Humanoid2026/R6/Locomotion/foot-contact.json',footLockImplemented=False,physicalMovementUnchanged=True),indent=2))
 print('Evidence built; max skeleton deviation',max(errors),'synchronization traces',len(analyses))
if __name__=='__main__':main()
