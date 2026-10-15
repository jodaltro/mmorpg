"""Assemble real Editor captures. No synthesized/interpolated gameplay frames."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'Docs/Validation/Marco06B3'
def gif(paths,name,duration):
    frames=[]
    for p in paths:
        if not p.exists():continue
        im=Image.open(p).convert('RGB');cx,cy=im.width//2,im.height//2
        # Crop only for legibility; nearest enlargement retains original pixels.
        frames.append(im.crop((cx-130,cy-100,cx+130,cy+100)).resize((520,400),Image.Resampling.NEAREST))
    if frames:frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=duration,loop=0,optimize=False)
gif([OUT/f'walk-{d}-{f}.png' for d in range(4) for f in range(5)],'gameplay-walk.gif',170)
gif([OUT/f'attack-{d}-{phase}.png' for d in range(4) for phase in ('preparation','active')],'gameplay-attack-keys.gif',180)
gif(sorted(OUT.glob('fight-[0-9][0-9].png')),'gameplay-combat.gif',400)
print('Real-capture GIFs assembled; keyframe montages are not a framerate-accurate recording.')
