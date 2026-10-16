"""Extract selected professional CC0 cels with local Aseprite; no pose generation."""
from pathlib import Path
import json,subprocess,hashlib
from PIL import Image,ImageDraw
SRC=Path('D:/unity/ExternalArt/IronKnight2026/extracted/BlueKnightUnarmed');OUT=Path('ArtSource/Labs/IronKnight2026/B11');OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'editable').exists():raise FileExistsError('Refusing to overwrite editable B11 sources')
from iron_knight_b11_anchors import hands
clips=[];lua=['local original=app.activeSprite'];report=[]
for action,folder,base,count in [('dodge','Jump',2753,9),('hurt','Damaged',1273,7),('death','Die',1409,23)]:
 for direction,d in [('south',8),('west',2),('north',4),('east',6)]:
  dest=OUT/'editable'/action/direction;dest.mkdir(parents=True);export=OUT/'frames'/action/direction;export.mkdir(parents=True);path=SRC/folder/f'BlueKnight_Unarmed_export_{folder}_dir{d}';data=json.loads(path.with_suffix('.json').read_text());sheet=Image.open(path.with_suffix('.png')).convert('RGBA');frames=[];lua+=['do','local s=Sprite(256,256,ColorMode.RGB)',f's.layers[1].name="Hormelz CC0 {folder} dir{d}"']
  for i,e in enumerate(data['frames']):
   r=e['frame'];x,y,w,h=[int(r[k]) for k in ['x','y','w','h']];f=sheet.crop((x,y,x+w,y+h));hand=hands[action][direction][i] if action!='death' else None;number=base+(d-1)*count+i
   lua+=([] if i==0 else ['s:newEmptyFrame()'])+[f's:newCel(s.layers[1],s.frames[{i+1}],original.cels[{number}].image,original.cels[{number}].position)',f's.frames[{i+1}].duration={e["duration"]}']
   frames.append({'png':(export/f'frame_{i:03}.png').as_posix(),'canvas':[256,256],'pivot':[128,114],'feet':[128,132],'rightHand':hand,'duration':e['duration'],'equipmentAngle':[-135,-155,90,-25][['south','west','north','east'].index(direction)],'equipmentDepth':-1 if direction in ['north','west'] else 1,'source':f'Hormelz/{folder}/dir{d}/frame{i}','sourceFrame':number,'events':[],'weaponPolicy':'hidden by confirmed death' if action=='death' else 'separate sword follows reviewed glove'});
   if hand and f.getpixel(hand)[3]==0:report.append([action,direction,i,hand])
  lua += [f's:saveAs("{dest.as_posix()}/{action}-{direction}.aseprite")',f'app.command.ExportSpriteSheet{{ui=false,type=SpriteSheetType.HORIZONTAL,textureFilename="{export.as_posix()}/sheet.png",dataFilename="{export.as_posix()}/aseprite.json"}}',f'app.command.SaveFileAs{{ui=false,filename="{export.as_posix()}/frame_000.png"}}','s:close()','app.activeSprite=original','end']
  clips.append({'animation':action,'direction':direction,'frameCount':count,'loop':False,'status':'preliminary artist review; user approval pending','sheet':(export/'sheet.png').as_posix(),'frames':frames})
(OUT/'extract.lua').write_text('\n'.join(lua));r=subprocess.run(['D:/Aseprite/Aseprite.exe','-b',str(SRC/'BlueKnight_Unarmed_export.aseprite'),'--script',str(OUT/'extract.lua')],capture_output=True,text=True);assert r.returncode==0,(r.stdout,r.stderr)
for c in clips:
 action=c['animation'];direction=c['direction'];folder={'dodge':'Jump','hurt':'Damaged','death':'Die'}[action];d={'south':8,'west':2,'north':4,'east':6}[direction];p=SRC/folder/f'BlueKnight_Unarmed_export_{folder}_dir{d}';sheet=Image.open(p.with_suffix('.png')).convert('RGBA');data=json.loads(p.with_suffix('.json').read_text())
 for i,f in enumerate(c['frames']):
  im=Image.open(f['png']).convert('RGBA');e=data['frames'][i]['frame'];x,y,w,h=[int(e[k]) for k in ['x','y','w','h']];assert im.tobytes()==sheet.crop((x,y,x+w,y+h)).tobytes();f['sha256']=hashlib.sha256(Path(f['png']).read_bytes()).hexdigest()
m={'schema':'iron-knight-b11-v1','id':'IronKnightB11','ppu':32,'sourceUrl':'https://hormelz.itch.io/8-directional-iron-knight','license':'CC0-1.0','baseManifest':'ArtSource/Labs/IronKnight2026/B10/manifest.json','baseCharacterSet':'Assets/Mmorpg/Art/Experimental/IronKnightB10/IronKnightB10.asset','baseSha256':hashlib.sha256(Path('ArtSource/Labs/IronKnight2026/B10/manifest.json').read_bytes()).hexdigest(),'status':'experimental B11; B10 approval preserved, new states awaiting user review','clips':clips};(OUT/'manifest.json').write_text(json.dumps(m,indent=2));print('156 cels exported pixel-identical through Aseprite. Candidate anchors requiring review:',report)
