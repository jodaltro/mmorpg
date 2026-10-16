"""Extract unchanged Hormelz CC0 poses with local Aseprite. Keep downloaded ZIP outside Unity Temp.
Run once in a fresh experiment directory; editable files are never overwritten.
Source default: D:/unity/ExternalArt/IronKnight2026/extracted/BlueKnightUnarmed.
"""
from pathlib import Path
import json,hashlib,subprocess,shutil
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]; SRC=Path('D:/unity/ExternalArt/IronKnight2026/extracted/BlueKnightUnarmed'); OUT=Path('ArtSource/Labs/IronKnight2026');OUT.mkdir(parents=True,exist_ok=True)
# Measured anatomical right glove contacts in source canvas coordinates; reviewed separately from body pivots.
walk={'south': [(104, 110), (103, 109), (103, 109), (104, 109), (105, 110), (105, 107), (106, 106), (106, 106), (105, 107), (106, 108), (107, 108)], 'west': [(106, 108), (107, 109), (108, 111), (109, 112), (108, 111), (107, 109), (105, 107), (104, 106), (104, 106), (105, 107), (106, 108)], 'north': [(152, 105), (152, 104), (152, 105), (152, 106), (152, 107), (151, 106), (152, 107), (153, 108), (153, 109), (153, 109), (153, 108)], 'east': [(127, 124), (127, 124), (126, 123), (126, 122), (125, 122), (125, 123), (126, 125), (127, 125), (127, 125), (127, 124), (127, 124)]}
attack={'south': [(105, 103), (105, 103), (110, 100), (115, 93), (128, 86), (120, 89), (107, 110), (124, 121), (132, 132), (131, 130), (130, 128), (133, 124), (115, 115), (112, 110), (108, 107)], 'west': [(143, 99), (144, 98), (143, 96), (144, 86), (138, 84), (138, 92), (111, 125), (100, 121), (98, 126), (103, 126), (104, 124), (107, 130), (98, 123), (99, 116), (132, 91)], 'north': [(146, 113), (146, 111), (147, 108), (145, 103), (139, 103), (137, 100), (147, 98), (109, 119), (115, 123), (112, 122), (108, 124), (104, 116), (138, 101), (144, 102), (151, 109)], 'east': [(120, 119), (120, 116), (119, 111), (117, 103), (120, 91), (117, 101), (130, 117), (143, 119), (148, 121), (148, 121), (151, 116), (144, 112), (135, 110), (127, 114), (124, 119)]}
idle={'south':(106,106),'west':(143,99),'north':(146,113),'east':(120,119)}
if (OUT/'editable').exists():raise FileExistsError('Refusing to overwrite editable documents; use a new output directory for another experiment')
clips=[];lua=['local original=app.activeSprite'];bounds={}
# Only the selected 4-direction idle pose, walk and slash are retained, not the complete package.
for action,folder,base,count in [('idle','Idle',2129,25),('walk','WalkFoward',3833,11),('attack','Slash',3425,15)]:
 for direction,d in [('south',8),('west',2),('north',4),('east',6)]:
  dest=OUT/'editable'/action/direction;dest.mkdir(parents=True,exist_ok=True)
  export=OUT/'frames'/action/direction;export.mkdir(parents=True,exist_ok=True)
  source=SRC/folder/f'BlueKnight_Unarmed_export_{folder}_dir{d}';data=json.loads(source.with_suffix('.json').read_text());sheet=Image.open(source.with_suffix('.png')).convert('RGBA');entries=data['frames'][:1] if action=='idle' else data['frames'];frames=[]
  lua+=['do','local s=Sprite(256,256,ColorMode.RGB)',f's.layers[1].name="Hormelz CC0 - {folder} dir{d}"']
  for i,e in enumerate(entries):
   r=e['frame'];x,y,w,h=[int(r[k]) for k in ['x','y','w','h']];im=sheet.crop((x,y,x+w,y+h));anchor=(walk if action=='walk' else attack)[direction][i] if action!='idle' else idle[direction]
   # Reject contacts outside the sprite; no guessed fallback enters the manifest.
   if im.getpixel(anchor)[3]==0:raise ValueError(('Reviewed contact no longer visible',action,direction,i,anchor))
   number=base+(d-1)*count+i
   lua += ([] if i==0 else ['s:newEmptyFrame()'])+[f's:newCel(s.layers[1],s.frames[{i+1}],original.cels[{number}].image,original.cels[{number}].position)',f's.frames[{i+1}].duration={e["duration"]}']
   png=export/f'frame_{i:03}.png'
   frames.append({'png':png.as_posix(),'canvas':[256,256],'pivot':[128,114],'feet':[128,132],'rightHand':list(anchor),'duration':e['duration'],'equipmentAngle':[-135,-155,90,-25][['south','west','north','east'].index(direction)],'equipmentDepth':-1 if direction=='north' else 1,'source':f'Hormelz/{folder}/dir{d}/frame{i}','sourceFrame':number,'events':[]})
  ase=(dest/f'{action}-{direction}.aseprite').as_posix();lua += [f's:saveAs("{ase}")',f'app.command.ExportSpriteSheet{{ui=false,type=SpriteSheetType.HORIZONTAL,textureFilename="{export.as_posix()}/sheet.png",dataFilename="{export.as_posix()}/aseprite.json"}}',f'app.command.SaveFileAs{{ui=false,filename="{export.as_posix()}/frame_000.png"}}','s:close()','app.activeSprite=original','end']
  clips.append({'animation':action,'direction':direction,'frameCount':len(frames),'loop':action!='attack','status':'experimental; artistic user approval pending','frames':frames})
(OUT/'extract.lua').write_text('\n'.join(lua))
p=subprocess.run(['D:/Aseprite/Aseprite.exe','-b',str(SRC/'BlueKnight_Unarmed_export.aseprite'),'--script',str(OUT/'extract.lua')],capture_output=True,text=True);print(p.stdout,p.stderr);assert p.returncode==0
for c in clips:
 for f in c['frames']:
  p=Path(f['png']);assert p.exists(),p
  im=Image.open(p).convert('RGBA');f['sha256']=hashlib.sha256(p.read_bytes()).hexdigest();f['visibleBounds']=im.getbbox()
manifest={'schema':'iron-knight-b9-v1','id':'IronKnightB9','ppu':32,'referenceSpeed':3.5,'coordinates':'top-left pixels','status':'experimental','sourceUrl':'https://hormelz.itch.io/8-directional-iron-knight','license':'CC0-1.0','clips':clips}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('Exported',sum(c['frameCount'] for c in clips),'frames through Aseprite')
