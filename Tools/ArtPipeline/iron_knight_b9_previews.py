import json
from PIL import Image,ImageDraw
from pathlib import Path
out=Path('ArtSource/Labs/IronKnight2026/review');m=json.load(open('ArtSource/Labs/IronKnight2026/manifest.json'));clips={c['direction']:c for c in m['clips'] if c['animation']=='walk'}
imgs=[]
for i in range(11):
 b=Image.new('RGB',(384,116),(44,46,52));d=ImageDraw.Draw(b)
 for n,(name,c) in enumerate(clips.items()):
  f=Image.open(c['frames'][i]['png']).convert('RGBA').crop((80,65,176,165));b.paste(f,(n*96,16),f);d.text((n*96,1),name,fill='white')
 imgs.append(b)
for scale in [1,4]:
 seq=[f.resize((f.width*scale,f.height*scale),Image.Resampling.NEAREST) for f in imgs];seq[0].save(out/f'four-directions-{scale}x.gif',save_all=True,append_images=seq[1:],duration=[70,60,70,70,60,70,70,60,70,70,60],loop=0)
# Comparison holds each source's actual cadence on a shared 10 ms timeline.
paths=[Path('ArtSource/Labs/Aseprite/HeroB7/walk-r2'),Path('ArtSource/Labs/AnimationResearch/Marco06B8/frames-r2')];old=[]
for p in paths:
 data=json.load(open(p/'frames.json'));entries=data['frames'];entries=list(entries.values()) if isinstance(entries,dict) else entries;old.append(([Image.open(f).convert('RGBA') for f in sorted(p.glob('frame_*.png'))],[e['duration']/1000 for e in entries]))
def at(t,fs,ds):
 t=t%sum(ds)
 for f,d in zip(fs,ds):
  if t<d:return f
  t-=d
 return fs[-1]
frames=[]
b9=[Image.open(f['png']).convert('RGBA') for f in clips['south']['frames']]
for tick in range(160):
 t=tick*.01;b=Image.new('RGB',(288,116),(44,46,52));d=ImageDraw.Draw(b)
 for j,(fs,ds) in enumerate(old+[(b9,[1/15]*11)]):
  f=at(t,fs,ds);f=f.crop((80,65,176,165)) if j==2 else f
  b.paste(f,(j*96,16),f);d.text((j*96+8,2),['B7','B8','B9'][j],fill='white')
 frames.append(b.resize((1152,464),Image.Resampling.NEAREST))
frames[0].save(out/'b7-b8-b9.gif',save_all=True,append_images=frames[1:],duration=10,loop=0)
board=Image.new('RGB',(11*128,4*144),(44,46,52));dr=ImageDraw.Draw(board)
for row,(name,c) in enumerate(clips.items()):
 for i,f in enumerate(c['frames']):
  im=Image.open(f['png']).convert('RGBA').crop((96,76,160,140)).resize((128,128),Image.Resampling.NEAREST);board.paste(im,(i*128,row*144+16),im);x,y=f['rightHand'];cx=i*128+(x-96)*2;cy=row*144+16+(y-76)*2;dr.ellipse((cx-2,cy-2,cx+2,cy+2),outline='magenta');dr.text((i*128,row*144),name+' '+str(i),fill='white')
board.save(out/'walk-hand-review.png')
