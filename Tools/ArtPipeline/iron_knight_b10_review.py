"""Review original B9 pixels; annotations only, no sprite generation."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
BASE=Path('ArtSource/Labs/IronKnight2026');OUT=BASE/'B10/review';OUT.mkdir(parents=True,exist_ok=True)
m=json.loads((BASE/'manifest.json').read_text())
for c in m['clips']:
 frames=c['frames'];cols=4;rows=(len(frames)+3)//4;b=Image.new('RGB',(1120,rows*260),(40,43,48));d=ImageDraw.Draw(b)
 for i,f in enumerate(frames):
  xx=i%4*280;yy=i//4*260;im=Image.open(f['png']).convert('RGBA');tile=im.crop((88,72,168,144)).resize((240,216),Image.Resampling.NEAREST);b.paste(tile,(xx,yy+20),tile);d.text((xx,yy),f'{c["direction"]} {c["animation"]} {i:02}',fill='white')
  hx,hy=f['rightHand'];cx=xx+(hx-88)*3;cy=yy+20+(hy-72)*3;d.ellipse((cx-3,cy-3,cx+3,cy+3),outline='magenta')
  for x in range(90,161,10):d.text((xx+(x-88)*3,yy+240),str(x),fill='yellow')
  for y in range(80,141,10):d.text((xx+242,yy+20+(y-72)*3),str(y),fill='yellow')
 b.save(OUT/f'{c["animation"]}-{c["direction"]}-grid.png')
