"""Index real Ground13 Play captures; reuse the shared ReviewLite pipeline."""
import json
from pathlib import Path
from PIL import Image, ImageChops
import ground13 as g

ROOT=g.ROOT/'Docs/Validation/ValdoriaGround13'

def main():
 items=[]
 for file in sorted((ROOT/'QA').glob('captures-*.json')):
  for capture in g.read(file):
   row=dict(capture);row['original']=Path(row.pop('path')).relative_to('Docs/Validation/ValdoriaGround13').as_posix();items.append(row)
 for file in sorted((ROOT/'QA').glob('optimization-*-captures.json')):
  rows=g.read(file)
  label=file.stem.removesuffix('-captures')
  for row in rows:row['comparison']=label+'-'+row['comparison'];items.append(row)
 # Initial optimization captures have a historical filename.
 if (ROOT/'QA/optimization-captures.json').exists():
  for row in g.read(ROOT/'QA/optimization-captures.json'):
   row['comparison']='optimization-initial-'+row['comparison'];items.append(row)
 if (ROOT/'QA/water-captures.json').exists():items.extend(g.read(ROOT/'QA/water-captures.json'))
 # Input QA cameras are fixed explicitly in the retained scripts; motion has a per-frame trace.
 for folder in ('Gameplay','GameplayCandidate'):
  for path in sorted((ROOT/'Original'/folder).rglob('*.png')):
   name=path.stem;position=[28.5,14.25,-10];ortho=14.0625;state='candidate';group=folder+'-'+name
   if name.startswith(('00-','01-')):group=folder+'-context';state='before' if name.startswith('00-') else 'candidate'
   elif name.startswith(('04-','05-')):position=[14,11,-10];ortho=7.03125
   elif name.startswith(('06-','07-')):position=[11,7.03125,-10];ortho=7.03125
   elif name.startswith('11-'):position=[13,12.5,-10];ortho=7.03125
   elif name.startswith('12-'):position=[13,7.03125,-10];ortho=7.03125
   elif name.startswith('13-'):position=[30,7.03125,-10];ortho=7.03125
   elif name.startswith('15-'):position=[39,24,-10];group=folder+'-second';state='before' if name.endswith('before') else 'candidate'
   elif name.startswith('legacy-'):position=[12.09375,28.125,-10];ortho=7.03125
   camera={'position':position,'ortho':ortho,'ppu':32,'actorScale':1.25,'resolution':[1600,900],'reference':'AgentScripts/ValidateGround13Candidate.cs (same poses in first iteration)'}
   if path.parent.name=='Motion':camera={'mode':'CameraFollow','ortho':14.0625,'ppu':32,'resolution':[1600,900],'reference':f'Original/{folder}/play-qa.json per-frame trace','sequenceIndex':int(name.split('-')[-1])}
   items.append(dict(original=path.relative_to(ROOT).as_posix(),scene='Assets/Mmorpg/Scenes/ValdoriaGround13RefinementLab.unity',state=state,comparison=group,camera=camera,integral=True))
 for path in sorted((ROOT/'Original/CliffQA').glob('*.png')):
  items.append(dict(original=path.relative_to(ROOT).as_posix(),scene='Assets/Mmorpg/Scenes/ValdoriaGround13RefinementLab.unity',state='candidate',comparison=path.stem,camera={'position':[48,18,-10],'ortho':7.03125,'ppu':32,'resolution':[1600,900],'reference':'AgentScripts/Ground13CliffQA.cs'},integral=True))
 detail=ROOT/'Details';detail.mkdir(exist_ok=True)
 crops={'plateau-planes':('plateau',[440,320,1160,800]),'wet-bank':('water-bank',[280,230,1000,710]),'contact':('composition',[0,420,720,900]),'upper-relief':('relief-upper',[440,220,1160,700])}
 for name,(comparison,bounds) in crops.items():
  for state in ('before','candidate'):
   source=next(row for row in items if row['comparison']==comparison and row['state']==state);relative=f'Details/{name}-{state}.png'
   cropped=Image.open(ROOT/source['original']).crop(bounds)
   if (ROOT/relative).exists():
    if Image.open(ROOT/relative).tobytes()!=cropped.tobytes():raise ValueError('Refuse changed detail destination: '+relative)
   else:cropped.save(ROOT/relative)
   items.append(dict(original=relative,scene=source['scene'],state=state,comparison=name+'-detail',camera=source['camera'],integral=False,crop={'source':source['original'],'boundsLTRB':bounds,'sampling':'1:1 no resize'}))
 indexed={row['original'] for row in items};actual={p.relative_to(ROOT).as_posix() for folder in ['Original','Details'] for p in (ROOT/folder).rglob('*.png')}
 if indexed!=actual:raise ValueError({'missing':list(actual-indexed),'absent':list(indexed-actual)})
 for row in items:
  parts=Path(row['original']).parts
  row['reviewName']='-'.join(parts[1:]) if parts[0]=='Original' else Path(row['original']).name
 g.write(ROOT/'QA/capture-index.json',{'schema':'valdoria-capture-index/v1','images':items})
 proof=[]
 for folder in ['OptimizationFinal','OptimizationCandidate']:
  for a,b in [(0,1),(4,3)]:
   pa=ROOT/f'Original/{folder}/stage-{a}.png';pb=ROOT/f'Original/{folder}/stage-{b}.png';im=ImageChops.difference(Image.open(pa).convert('RGBA'),Image.open(pb).convert('RGBA'))
   import numpy as np
   changed=int(np.any(np.array(im)!=0,axis=2).sum());proof.append({'folder':folder,'states':[a,b],'differentPixels':changed,'identical':changed==0,'camera':'28.5,14.25,-10 / ortho14.0625 / 1600x900','actor':'held same pose','waterPhase':0})
 if not all(p['identical'] for p in proof):raise ValueError(proof)
 g.write(ROOT/'QA/packing-pixel-proof.json',proof);print('Indexed',len(items),'real captures and crops')

if __name__=='__main__':main()
