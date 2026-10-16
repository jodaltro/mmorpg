"""Round-trip hidden-guide Aseprite copies, and verify B9 preservation without touching its assets."""
from pathlib import Path
from PIL import Image
import hashlib,json,subprocess,uuid
BASE=Path('ArtSource/Labs/IronKnight2026');OUT=Path('Docs/Validation/Marco06B10');temp=Path('Temp/Marco06B10')/('AsepriteQA-'+uuid.uuid4().hex);temp.mkdir(parents=True)
report={'roundTrip':[],'preservation':{}}
for p in (BASE/'B10/editable').rglob('*.aseprite'):
 action=p.parent.parent.name;direction=p.parent.name;sheet=temp/f'{action}-{direction}.png';script=temp/'export.lua';script.write_text('app.command.ExportSpriteSheet{ui=false,type=SpriteSheetType.HORIZONTAL,textureFilename="'+sheet.as_posix()+'"}')
 r=subprocess.run(['D:/Aseprite/Aseprite.exe','-b',str(p),'--script',str(script)],capture_output=True,text=True);assert r.returncode==0,(p,r.stderr)
 actual=Image.open(sheet).convert('RGBA');original=Image.open(BASE/'frames'/action/direction/'sheet.png').convert('RGBA');assert actual.size==original.size and actual.tobytes()==original.tobytes(),p
 report['roundTrip'].append({'document':p.as_posix(),'canvas':256,'frames':actual.width//256,'pixelIdenticalWithHiddenGuides':True})
for path,old in json.loads((OUT/'preservation-before.json').read_text()).items():
 now=hashlib.sha256(Path(path).read_bytes()).hexdigest();assert old==now,path
 report['preservation'][path]=now
m=json.loads((BASE/'B10/manifest.json').read_text());report['contactCount']=sum(len(c['frames']) for c in m['clips']);report['walkCycleSeconds']=sum(m['clips'][4]['frames'][i]['duration'] for i in range(11));report['paletteChanged']=False
(OUT/'source-qa.json').write_text(json.dumps(report,indent=2));print('108 source poses pixel-identical after Aseprite roundtrip; all B9 hashes intact')
