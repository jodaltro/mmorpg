from pathlib import Path
import json,hashlib,subprocess
from PIL import Image,ImageDraw
SRC=Path('D:/unity/ExternalArt/IronKnight2026/extracted/BlueKnightUnarmed');OUT=Path('Docs/Validation/Marco06B11');OUT.mkdir(parents=True,exist_ok=True);(OUT/'source-review').mkdir(exist_ok=True)
if (OUT/'preservation-before.json').exists():raise FileExistsError('Refusing to overwrite the initial preservation snapshot and reviewed inventory')
paths=[p for p in Path('ArtSource/Labs/IronKnight2026/B10').rglob('*') if p.is_file()]+[p for p in Path('Assets/Mmorpg/Art/Experimental/IronKnightB10').rglob('*') if p.is_file()]+[Path('Assets/Mmorpg/Scenes/Marco06B10CombatPolish.unity')]
(OUT/'preservation-before.json').write_text(json.dumps({p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2))
items=[]
for folder in sorted(SRC.iterdir()):
 if not folder.is_dir():continue
 clips=[]
 for j in sorted(folder.glob('*.json')):
  data=json.loads(j.read_text());im=Image.open(j.with_suffix('.png'));clips.append({'direction':int(j.stem.rsplit('dir',1)[1]),'frames':len(data['frames']),'seconds':sum(e['duration'] for e in data['frames']),'durations':[e['duration'] for e in data['frames']],'canvas':[256,256],'sheet':j.with_suffix('.png').name})
 items.append({'name':folder.name,'source':str(folder),'unarmed':True,'directions':clips,'potential':'pending visual review' if folder.name in ['Jump','RunningJump','Damaged','Damaged_001','Die','Die_001'] else 'not selected for B11'})
for action in ['Jump','RunningJump','Damaged','Damaged_001','Die','Die_001']:
 for direction,d in [('south',8),('west',2),('north',4),('east',6)]:
  p=SRC/action/f'BlueKnight_Unarmed_export_{action}_dir{d}';data=json.loads(p.with_suffix('.json').read_text());sheet=Image.open(p.with_suffix('.png')).convert('RGBA');n=len(data['frames']);b=Image.new('RGB',(640,((n+3)//4)*180),(40,43,48));draw=ImageDraw.Draw(b);seq=[]
  for i,e in enumerate(data['frames']):
   r=e['frame'];x,y,w,h=[int(r[k]) for k in ['x','y','w','h']];f=sheet.crop((x,y,x+w,y+h));tile=f.crop((80,60,176,156)).resize((144,144),Image.Resampling.NEAREST);xx=i%4*160;yy=i//4*180;b.paste(tile,(xx,yy+20),tile);draw.text((xx,yy),f'{action} {direction} {i}',fill='white');bg=Image.new('RGBA',(96,96),(40,43,48,255));bg.alpha_composite(f.crop((80,60,176,156)));seq.append(bg.convert('RGB').resize((384,384),Image.Resampling.NEAREST))
  b.save(OUT/'source-review'/f'{action}-{direction}.png');seq[0].save(OUT/'source-review'/f'{action}-{direction}.gif',save_all=True,append_images=seq[1:],duration=[round(e['duration']*1000) for e in data['frames']],loop=0)
(OUT/'source-inventory.json').write_text(json.dumps({'sourceUrl':'https://hormelz.itch.io/8-directional-iron-knight','license':'CC0-1.0','package':'Knight-Only_BlueKnightUnarmed.zip','sourceDocumentSha256':hashlib.sha256((SRC/'BlueKnight_Unarmed_export.aseprite').read_bytes()).hexdigest(),'actions':items},indent=2));print([(a['name'],a['directions'][0]['frames'],round(a['directions'][0]['seconds'],3)) for a in items])
Path('Temp/Marco06B11').mkdir(parents=True,exist_ok=True);Path('Temp/Marco06B11/tags.lua').write_text('local s=app.activeSprite;print("canvas "..s.width.." "..s.height.." frames "..#s.frames);for _,t in ipairs(s.tags) do if not tonumber(t.name) then print(t.name.." "..t.fromFrame.frameNumber.." "..t.toFrame.frameNumber) end end')
r=subprocess.run(['D:/Aseprite/Aseprite.exe','-b',str(SRC/'BlueKnight_Unarmed_export.aseprite'),'--script','Temp/Marco06B11/tags.lua'],capture_output=True,text=True);assert r.returncode==0;(OUT/'aseprite-tags.txt').write_text(r.stdout);print(r.stdout)
