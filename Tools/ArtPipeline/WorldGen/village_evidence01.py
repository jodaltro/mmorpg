"""Derive review index, 1:1 crops and GIFs from actual Unity recordings."""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
import playable_village01 as v

ROOT=v.ROOT/'Docs/Validation/ValdoriaPlayableVillage01'
def gif(rows,name,scale=2):
    frames=[Image.open(ROOT/r['original']).convert('RGB') for r in rows]
    frames=[im.resize((im.width//scale,im.height//scale),Image.Resampling.NEAREST) for im in frames]
    # One shared palette, no dithering or interpolated frames.
    board=Image.new('RGB',(frames[0].width,frames[0].height*len(frames)))
    for i,im in enumerate(frames):board.paste(im,(0,i*im.height))
    palette=board.quantize(colors=256,dither=Image.Dither.NONE)
    frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
    times=[r['time'] for r in rows];durations=[max(10,round((b-a)*1000/10)*10) for a,b in zip(times,times[1:])]
    durations.append(durations[-1]);out=ROOT/'Animations'/name;out.parent.mkdir(exist_ok=True)
    frames[0].save(out,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
    return {'file':str(out.relative_to(ROOT)),'sourceImages':[r['original'] for r in rows],'durationsMs':durations,'scaleDivisor':scale,'sampling':'nearest','palette':'shared 256 colors, no dithering','interpolation':False,'bytes':out.stat().st_size,'sha256':v.sha(out)}
def build():
    qa=ROOT/'QA';index=v.read(qa/'capture-index.json');rows=index['images']
    play=v.read(qa/'play-qa.json');collision=v.read(qa/'collision-qa.json')
    assert play['passed'] and play['error'] is None
    assert collision['error'] is None and all(r['pass'] for r in collision['results'])
    trace=play['trace'];points=np.array([[r['x'],r['y']] for r in trace]);steps=np.linalg.norm(np.diff(points,axis=0),axis=1)
    assert max(steps)<1, 'Unexpected discontinuity in real-input exploration'
    assert all(a['frame']<b['frame'] and a['time']<b['time'] for a,b in zip(trace,trace[1:]))
    v.write(qa/'exploration-continuity.json',{'passed':True,'samples':len(trace),'framesAdvanced':play['framesAdvanced'],'seconds':play['seconds'],'maximumObservedStepUnits':float(max(steps)),'distanceUnits':float(sum(steps)),'teleports':0,'method':'Consecutive sampled Rigidbody positions, increasing rendered-frame clock; source runner only feeds Input System keys. Collision/photo fixtures excluded.'})
    standalone=ROOT/'Standalone/QA/capture-index.json'
    if standalone.exists():
        assert v.read(ROOT/'Standalone/QA/standalone.json')['passed']
        for row in v.read(standalone)['images']:
            row['original']='Standalone/'+row['original'];row['camera']['actorScale']=1.25;rows.append(row)
    details=ROOT/'Details';details.mkdir(exist_ok=True)
    cases=[('village-overview-crop','final-overview',[450,0,1150,900]),('gate-stone-contact','final-bridge-gate-front',[640,16,1024,640]),('castle-wall-native','08-castle-courtyard',[560,120,960,520]),('west-wall-native','final-west-wall',[600,80,860,700])]
    for name,source,bounds in cases:
        parent=next(r for r in rows if Path(r['original']).stem==source)
        path=details/(name+'.png')
        if path.exists():raise FileExistsError('Refuse crop overwrite')
        with Image.open(ROOT/parent['original']) as im:im.crop(bounds).save(path)
        rows.append({'original':str(path.relative_to(ROOT)),'scene':parent['scene'],'state':'1:1 inspection crop of '+source,'comparison':name,'camera':parent['camera'],'integral':False,'crop':{'source':parent['original'],'boundsLTRB':bounds,'sampling':'1:1'}})
    water=sorted([r for r in rows if Path(r['original']).name.startswith('water-live-')],key=lambda r:r['frame'])
    phases=[r['waterPhase'] for r in water]
    assert len(water)==8 and set(phases)=={0,1,2,3}
    assert any(a==3 and b==0 for a,b in zip(phases,phases[1:])),phases
    gaps=[{'from':a,'to':b,'afterImage':water[i]['original']} for i,(a,b) in enumerate(zip(phases,phases[1:])) if (a+1)%4!=b]
    motion=sorted([r for r in rows if Path(r['original']).name.startswith('motion-')],key=lambda r:r['frame']);assert len(motion)==16
    v.write(qa/'temporal-evidence.json',{'waterPhasesObserved':phases,'samplingGaps':gaps,'limitation':'PNG encoding can miss an animation phase; this sampled sequence is not a frame-perfect animation recording. No phases were forced.','source':'Actual Unity Play frames after end-of-frame, phases unforced','animations':[gif(water,'water-live.gif'),gif(motion,'exploration-live.gif')]})
    v.write(qa/'capture-index.json',index)
    lines=['# Valdoria Playable Village 01 — capturas','', 'PNGs integrais são a autoridade. ReviewLite são cópias para revisão; recortes e câmeras de inspeção estão identificados. A exploração contínua está em `QA/play-qa.json`, separada das fixtures de colisão e fotografia.','', '[Água em movimento](Animations/water-live.gif) · [Câmera em movimento](Animations/exploration-live.gif)','', '| Captura | ReviewLite | Original | Estado |','|---|---|---|---|']
    for r in rows:
        label=Path(r['original']).stem;lines.append(f'| {label} | [PNG](ReviewLite/{label}.png) | [PNG]({r["original"]}) | {r["state"]} |')
    (ROOT/'Index.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    print('Indexed',len(rows),'real originals/crops; phases',phases)
if __name__=='__main__':build()
