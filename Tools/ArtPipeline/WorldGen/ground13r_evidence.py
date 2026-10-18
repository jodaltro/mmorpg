"""Index real Ground13R Play captures and derive timed GIFs without synthetic phases."""
import json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
import ground13r as r
ROOT=r.ROOT/'Docs/Validation/ValdoriaGround13R'

def temporal():
 data=r.g.read(ROOT/'QA/water-live.json');assert data['realTemporalReplay'] and not data['error'];shots=data['captures'];assert len(shots)==12
 phases=[s['phase'] for s in shots];assert all(s['animatorFrames']==[s['phase']]*6 for s in shots);assert all(b==(a+1)%4 for a,b in zip(phases,phases[1:]));assert any(a==3 and b==0 for a,b in zip(phases,phases[1:]));assert all(b['renderedFrame']>a['renderedFrame'] and b['time']>a['time'] for a,b in zip(shots,shots[1:]))
 pixels={};durations=[max(20,round((b['time']-a['time'])*100)*10) for a,b in zip(shots,shots[1:])];durations.append(int(np.median(durations)));same=[]
 for shot in shots:
  assert all(p.endswith(f"-f{shot['phase']}.png") and '/ValdoriaGround13Final/' in p for p in shot['textures'])
  image=Image.open(ROOT/shot['original']).convert('RGB');assert image.size==(1600,900)
  if shot['phase'] in pixels:same.append(image.tobytes()==pixels[shot['phase']])
  else:pixels[shot['phase']]=image.tobytes()
 animations=ROOT/'Animations';animations.mkdir(exist_ok=True);outputs=[]
 for name,crop,scale in [('water-live-full',None,2),('water-live-detail',[280,230,1000,710],1)]:
  images=[]
  for shot in shots:
   im=Image.open(ROOT/shot['original']).convert('RGB');im=im.crop(crop) if crop else im
   if scale>1:im=im.resize((im.width//scale,im.height//scale),Image.Resampling.NEAREST)
   images.append(im)
  sheet=Image.new('RGB',(images[0].width,images[0].height*len(images)))
  for i,im in enumerate(images):sheet.paste(im,(0,i*im.height))
  palette=sheet.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in images];path=animations/(name+'.gif')
  if path.exists():raise FileExistsError(path)
  frames[0].save(path,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False);outputs.append(dict(path=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),crop=crop,scaleDivisor=scale,frames=len(frames),durationsMs=durations,source='Actual WaterLive PNGs in observed temporal order; shared palette, no dithering, no interpolation'))
 r.write(ROOT/'QA/water-temporal-validation.json',dict(passed=True,observedPhases=phases,observedTransitions=[[a,b] for a,b in zip(phases,phases[1:])],renderedFrameCapture=True,sourceTexturesUnchanged=True,repeatedPhasePixelsIdentical=all(same),gifDerivatives=outputs,originals=[dict(path=s['original'],sha256=hashlib.sha256((ROOT/s['original']).read_bytes()).hexdigest(),time=s['time'],phase=s['phase']) for s in shots]))

def index():
 items=[]
 for file in sorted((ROOT/'QA').glob('captures-*.json')):items.extend(r.g.read(file))
 for row in r.g.read(ROOT/'QA/packing-captures.json'):row['comparison']='packing-'+row['comparison'];items.append(row)
 if (ROOT/'QA/packing-final-captures.json').exists():
  for row in r.g.read(ROOT/'QA/packing-final-captures.json'):row['comparison']='packing-final-'+row['comparison'];items.append(row)
 if (ROOT/'QA/packing-compact-captures.json').exists():
  for row in r.g.read(ROOT/'QA/packing-compact-captures.json'):row['comparison']='packing-compact-'+row['comparison'];items.append(row)
 data=r.g.read(ROOT/'QA/water-live.json')
 for i,s in enumerate(data['captures']):items.append(dict(original=s['original'],scene=s['scene'],state='C-Ground13R-water-live',comparison='live-'+str(i),camera={'position':data['camera'],'ortho':data['ortho'],'ppu':32,'resolution':[1600,900]},integral=True,renderedFrame=s['renderedFrame'],unityTime=s['time'],waterPhase=s['phase'],sourceTexturePaths=s['textures'],mode=data['method']))
 for folder in ['Gameplay','CliffQA']:
  for path in sorted((ROOT/'Original'/folder).rglob('*.png')):
   name=path.stem;position=[28.5,14.25,-10];ortho=14.0625;state='C-Ground13R';group=folder+'-'+name
   if name.startswith(('00-','01-')):group=folder+'-context';state='B-Ground13' if name.startswith('00-') else 'C-Ground13R'
   elif name.startswith(('04-','05-')):position=[14,11,-10];ortho=7.03125
   elif name.startswith(('06-','07-')):position=[11,7.03125,-10];ortho=7.03125
   elif name.startswith('11-'):position=[13,12.5,-10];ortho=7.03125
   elif name.startswith('12-'):position=[13,7.03125,-10];ortho=7.03125
   elif name.startswith('13-'):position=[30,7.03125,-10];ortho=7.03125
   elif name.startswith('15-'):position=[39,24,-10];group=folder+'-second';state='B-Ground13' if name.endswith('before') else 'C-Ground13R'
   elif name.startswith('legacy-'):position=[12.09375,28.125,-10];ortho=7.03125
   if folder=='CliffQA':position=[48,18,-10];ortho=7.03125
   camera={'position':position,'ortho':ortho,'ppu':32,'actorScale':1.25,'resolution':[1600,900],'reference':'AgentScripts/ValidateGround13R.cs or Ground13RCliffQA.cs'}
   if path.parent.name=='Motion':camera={'mode':'CameraFollow','ortho':14.0625,'resolution':[1600,900],'ppu':32,'sequenceIndex':int(name.split('-')[-1]),'trace':'Original/Gameplay/play-qa.json'}
   items.append(dict(original=path.relative_to(ROOT).as_posix(),scene='Assets/Mmorpg/Scenes/ValdoriaGround13RLab.unity',state=state,comparison=group,camera=camera,integral=True))
 details=ROOT/'Details';details.mkdir(exist_ok=True)
 for version in ['Candidate','Delivery']:
  if not (ROOT/'Original'/version).exists():continue
  for label,pose,box in [('benches','plateau',[440,320,1160,800]),('upland','upland',[440,260,1160,740]),('mineral-contact','plateau',[440,400,1160,880])]:
   for state in ['B-Ground13','C-Ground13R']:
    source=next(v for v in items if v['original']==f'Original/{version}/{pose}-{state}.png');prefix='' if version=='Candidate' else 'Delivery-';path=f'Details/{prefix}{label}-{state}.png';im=Image.open(ROOT/source['original']).crop(box)
    if (ROOT/path).exists():assert Image.open(ROOT/path).tobytes()==im.tobytes()
    else:im.save(ROOT/path)
    items.append(dict(original=path,scene=source['scene'],state=state,comparison=version+'-'+label+'-detail',camera=source['camera'],integral=False,crop={'source':source['original'],'boundsLTRB':box,'sampling':'1:1 no resize'}))
 for row in items:
  p=Path(row['original']);row['reviewName']='-'.join(p.parts[1:]) if p.parts[0]=='Original' else 'Details-'+p.name
 actual={p.relative_to(ROOT).as_posix() for folder in ['Original','Details'] for p in (ROOT/folder).rglob('*.png')};assert actual=={r['original'] for r in items}
 r.write(ROOT/'QA/capture-index.json',dict(schema='valdoria-capture-index/v1',images=items));navigation(items);print('Indexed',len(items),'PNGs')

def navigation(items):
 lines=['# Ground13R - indice visual','', 'Candidata atual: **Delivery**. Final/Refined/Candidate sao estudos internos anteriores.','', '| Vista | A: relevo12 | B: Ground13 | C: Ground13R | D: neutro novo | Neutro anterior |','|---|---|---|---|---|---|']
 for pose in ['plateau','upland','upper-area','composition','second-area']:
  states=['A-Ground12','B-Ground13','C-Ground13R','D-Ground13R-neutral','E-Ground13-neutral'];links=[f'[{s}](ReviewLite/Delivery-{pose}-{s}.png)' for s in states];lines.append('| '+pose+' | '+' | '.join(links)+' |')
 lines+=['','## Detalhes 1:1','']
 for name in ['benches','upland','mineral-contact']:lines.append(f'- {name}: [antes](Details/Delivery-{name}-B-Ground13.png), [candidata](Details/Delivery-{name}-C-Ground13R.png).')
 lines+=['','## Agua temporal real','', '[GIF integral reduzido](Animations/water-live-full.gif) | [GIF detalhe 1:1](Animations/water-live-detail.gif). Derivados dos PNGs observados, sem fases fabricadas.','', '| Captura | Fase | Tempo Unity | Frame Unity | Original | ReviewLite |','|---|---:|---:|---:|---|---|']
 for i,s in enumerate(r.g.read(ROOT/'QA/water-live.json')['captures']):lines.append(f"| {i:02} | {s['phase']} | {s['time']:.6f} | {s['renderedFrame']} | [PNG]({s['original']}) | [PNG](ReviewLite/WaterLive-{Path(s['original']).name}) |")
 lines+=['','## Catalogo completo','', '| Estado e grupo | Original integral ou recorte identificado | ReviewLite |','|---|---|---|']
 for row in items:lines.append(f"| {row['state']} / {row['comparison']} | [PNG]({row['original']}) | [PNG](ReviewLite/{row['reviewName']}) |")
 (ROOT/'Index.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')

if __name__=='__main__':temporal();index()
