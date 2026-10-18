"""Index Ground12 real captures and labelled 1:1 detail crops for ReviewLite."""
import json
from pathlib import Path
from PIL import Image
import environment_finish12 as e

ROOT=e.ROOT/'Docs/Validation/ValdoriaGround12'

def main():
 items=[]
 for state in ('before','after','final'):
  for capture in e.read(ROOT/f'QA/captures-{state}.json'):
   row=dict(capture);row['original']=str(Path(row.pop('path')).relative_to('Docs/Validation/ValdoriaGround12')).replace('\\','/');row['frameMeaning']='Capture requested after rendered settling frames; PNG written by Unity at end of frame';items.append(row)
 detail=ROOT/'Details';detail.mkdir(exist_ok=False)
 crops={'plateau-planes':('plateau',[440,320,1160,800]),'wet-bank':('water-bank',[280,230,1000,710]),'old-tree-volume':('historical-tree',[400,140,1120,620]),'environment-contact':('composition',[0,450,720,890])}
 for name,(comparison,bounds) in crops.items():
  for state in ('before','final'):
   source=next(row for row in items if row['comparison']==comparison and row['state']==state)
   relative=f'Details/{name}-{state}.png';im=Image.open(ROOT/source['original']);im.crop(bounds).save(ROOT/relative)
   items.append(dict(original=relative,scene=source['scene'],state=state,comparison=name+'-detail',camera=source['camera'],integral=False,crop={'source':source['original'],'boundsLTRB':bounds,'sampling':'1:1, no resize'}))
 # QA screenshots use fixed cameras explicitly set in ValidateGround12.cs.
 gameplay=ROOT/'Original/Gameplay';scene='Assets/Mmorpg/Scenes/ValdoriaEnvironmentFinishLab.unity';context=[28.5,14.25,-10]
 for path in sorted(gameplay.glob('*.png')):
  name=path.stem;position=context;ortho=14.0625;state='final';group='gameplay-'+name
  if name.startswith(('00-','01-')):group='gameplay-context';state='before' if name.startswith('00-') else 'final'
  elif name.startswith(('04-','05-')):position=[14,11,-10];ortho=7.03125
  elif name.startswith(('06-','07-')):position=[11,7.03125,-10];ortho=7.03125
  elif name.startswith('11-'):position=[13,12.5,-10];ortho=7.03125
  elif name.startswith('12-'):position=[13,7.03125,-10];ortho=7.03125
  elif name.startswith('13-'):position=[30,7.03125,-10];ortho=7.03125
  elif name.startswith('15-'):position=[39,24,-10];group='gameplay-second-area';state='before' if name.endswith('before') else 'final'
  elif name.startswith('legacy-'):position=[12.09375,28.125,-10];ortho=7.03125
  items.append(dict(original=path.relative_to(ROOT).as_posix(),scene=scene,state=state,comparison=group,camera={'position':position,'ortho':ortho,'ppu':32,'actorScale':1.25,'resolution':[1600,900],'reference':'AgentScripts/ValidateGround12.cs; fixed camera during settled capture'},integral=True))
 for i,path in enumerate(sorted((gameplay/'Motion').glob('*.png'))):
  items.append(dict(original=path.relative_to(ROOT).as_posix(),scene=scene,state='final-moving',comparison='motion-'+str(i),camera={'mode':'CameraFollow','ortho':14.0625,'ppu':32,'actorScale':1.25,'resolution':[1600,900],'reference':'Original/Gameplay/play-qa.json: per-frame camera trace; 20 captures at >=0.10s spacing','sequenceIndex':i},integral=True))
 e.write(ROOT/'QA/capture-index.json',{'schema':'valdoria-capture-index/v1','images':items})
 print('Indexed',len(items),'PNG captures/detail crops; originals unchanged')

if __name__=='__main__':main()
