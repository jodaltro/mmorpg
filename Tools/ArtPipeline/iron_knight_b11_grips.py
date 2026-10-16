from pathlib import Path
from PIL import Image,ImageDraw
import json
m=json.load(open('ArtSource/Labs/IronKnight2026/B11/manifest.json'));out=Path('Docs/Validation/Marco06B11/source-review')
for c in m['clips']:
 if c['animation']=='death':continue
 b=Image.new('RGB',(1120,((len(c['frames'])+3)//4)*260),(40,43,48));dr=ImageDraw.Draw(b)
 for i,f in enumerate(c['frames']):
  xx=i%4*280;yy=i//4*260;im=Image.open(f['png']).convert('RGBA').crop((88,72,168,144)).resize((240,216),Image.Resampling.NEAREST);b.paste(im,(xx,yy+20),im);dr.text((xx,yy),f'{c["animation"]} {c["direction"]} {i}',fill='white');x,y=f['rightHand'];cx=xx+(x-88)*3;cy=yy+20+(y-72)*3;dr.ellipse((cx-3,cy-3,cx+3,cy+3),outline='magenta')
  for x in range(90,161,10):dr.text((xx+(x-88)*3,yy+240),str(x),fill='yellow')
  for y in range(80,141,10):dr.text((xx+242,yy+20+(y-72)*3),str(y),fill='yellow')
 b.save(out/f'grip-{c["animation"]}-{c["direction"]}.png')
