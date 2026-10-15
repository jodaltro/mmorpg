"""Build previews only from real Unity ScreenCapture frames; never synthesize poses."""
import json
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'Docs/Validation/Marco06B4'
metadata={}
for line in (BASE/'capture-metadata.jsonl').read_text('utf-8-sig').splitlines():
    m=json.loads(line);metadata[m['name']]=m

def preview(pattern,output):
    frames=[];names=[]
    for p in sorted(BASE.glob(pattern)):
        m=metadata.get(p.stem)
        if m is None: continue
        src=Image.open(p).convert('RGB');x,y=m['playerScreen'];y=src.height-y
        # Follow the player only in the exported review crop; actual gameplay camera is unchanged.
        tile=src.crop((round(x)-115,round(y)-115,round(x)+115,round(y)+90)).resize((460,410),Image.Resampling.NEAREST)
        frame=Image.new('RGB',(460,445),'#142023');frame.paste(tile,(0,0));draw=ImageDraw.Draw(frame)
        draw.text((8,415),'UNITY GAMEPLAY / PROVISIONAL TWO-POSE WALK' if output.startswith('walk') else 'UNITY GAMEPLAY / GRIP + PHYSICAL SWEEP',fill='#e6d9ac')
        draw.text((8,430),m['source']+' / '+m['phase'],fill='white');frames.append(frame);names.append(p.name)
    if not frames:raise ValueError(pattern)
    frames[0].save(BASE/output,save_all=True,append_images=frames[1:],duration=90 if output.startswith('walk') else 60,loop=0,optimize=False)
    return dict(file=output,captures=names,method='real ScreenCapture, moving review crop, nearest enlargement, sampled cadence; no interpolated poses')
reports=[preview('walk-*.png','walk-provisional.gif'),preview('attack-*.png','attack-grip-sweep.gif')]
(BASE/'previews.json').write_text(json.dumps(reports,indent=2)+'\n','utf-8')
print('Saved real gameplay GIFs. No new animation drawings claimed.')
