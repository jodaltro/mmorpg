"""Read-only source inventory and component proposals; proposals are NOT approved cuts."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Docs/Art/Audit'
OUT.mkdir(parents=True, exist_ok=True)
inventory = []
for path in sorted((ROOT/'assets_para_usar').glob('*.png')):
    im = Image.open(path)
    a = np.asarray(im.convert('RGBA'))[:,:,3]
    labels, count = ndimage.label(a >= 32)
    regions = []
    for index, box in enumerate(ndimage.find_objects(labels), 1):
        if box is None: continue
        y,x = box
        area = int(np.sum(labels[box] == index))
        if area < 120: continue
        regions.append({'rect':[x.start,y.start,x.stop-x.start,y.stop-y.start], 'area':area})
    regions.sort(key=lambda r:(r['rect'][1]//40,r['rect'][0]))
    bg=Image.new('RGBA',im.size,(40,44,53,255)); bg.alpha_composite(im.convert('RGBA'))
    draw=ImageDraw.Draw(bg)
    for i,r in enumerate(regions):
        x,y,w,h=r['rect'];draw.rectangle((x,y,x+w,y+h),outline='#6fff9a',width=1);draw.text((x,y),str(i),fill='white',stroke_width=1,stroke_fill='black')
    bg.convert('RGB').save(OUT/(path.stem+'-components.jpg'),quality=92)
    inventory.append({'file':str(path.relative_to(ROOT)), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'format':im.format,'mode':im.mode,'size':im.size,'transparent':int(np.sum(a==0)),'semitransparent':int(np.sum((a>0)&(a<255))),'low_alpha_1_7':int(np.sum((a>0)&(a<8))),'opaque':int(np.sum(a==255)), 'candidate_components':regions})
(OUT/'inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
print('\n'.join(f"{r['file']}: {r['size']} {r['mode']}; alpha 0={r['transparent']}, partial={r['semitransparent']}, opaque={r['opaque']}; components={len(r['candidate_components'])}" for r in inventory))
