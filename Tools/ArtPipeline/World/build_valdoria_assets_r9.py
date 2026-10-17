from pathlib import Path
from PIL import Image
import argparse,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3]
R9=ROOT/'ArtSource/Labs/World2026/R9'
RENDER=R9/'Blender/rendered'; SOURCES=R9/'Sources'; ASE=R9/'Aseprite'
UNITY=ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR9/Props'
NAMES=['meadow','path','tree-canopy','tree-trunk','rock','house-wall','house-roof']
AP=argparse.ArgumentParser();AP.add_argument('--replace-r9-outputs',action='store_true');args=AP.parse_args()
if not RENDER.is_dir():raise SystemExit('Blender renders are missing; run the R9 Blender source first.')
for folder,name,suffix in [(SOURCES,n,'.png') for n in NAMES]+[(ASE,n,'.aseprite') for n in NAMES]+[(UNITY,n,'.png') for n in NAMES]+[(SOURCES,'manifest','.json')]:
 p=folder/(name+suffix)
 if p.exists():
  if not args.replace_r9_outputs:raise SystemExit('Refusing to overwrite: '+str(p))
  p.unlink()
SOURCES.mkdir(parents=True,exist_ok=True);ASE.mkdir(parents=True,exist_ok=True);UNITY.mkdir(parents=True,exist_ok=True)
aseprite=Path(r'D:\Aseprite\Aseprite.exe');manifest={'generator':'Tools/ArtPipeline/World/build_valdoria_assets_r9.py','blenderSource':'ArtSource/Labs/World2026/R9/Blender/build_valdoria_pilot.py','asepriteVersion':'1.3.18.6','license':'Created locally for this project; no external/purchased art','ppu':32,'filter':'Point','files':[]}
for name in NAMES:
 source=RENDER/(name+'.png');im=Image.open(source).convert('RGBA');canvas=im.size;anchor=(canvas[0]//2,canvas[1]-1)
 if name not in ('meadow','path'):
  bbox=im.getchannel('A').getbbox()
  if not bbox:raise RuntimeError('Empty alpha: '+name)
  left,top,right,bottom=bbox;im=im.crop(bbox);ax=max(0,min(im.width-1,anchor[0]-left));ay=max(0,min(im.height-1,anchor[1]-top));pivot=[round(ax/im.width,6),round(1-ay/im.height,6)]
 else:ax,ay=canvas[0]//2,canvas[1]//2;pivot=[.5,.5]
 p=SOURCES/(name+'.png');u=UNITY/(name+'.png');im.save(p,optimize=True);im.save(u,optimize=True)
 a=ASE/(name+'.aseprite');subprocess.run([str(aseprite),'-b',str(p.resolve()),'--save-as',str(a.resolve())],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
 manifest['files'].append({'id':name,'unityAsset':u.relative_to(ROOT).as_posix(),'sourceRender':source.relative_to(ROOT).as_posix(),'canvas':[im.width,im.height],'fullRenderCanvas':list(canvas),'worldSizeUnits':[round(im.width/32,4),round(im.height/32,4)],'pivotNormalizedBottomLeft':pivot,'groundAnchorPixelsFromTopLeft':[ax,ay],'sourceRenderSha256':sha(source),'pngSha256':sha(p),'asepriteEditableSha256':sha(a)})
(SOURCES/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
recipePath=R9/'Recipes/valdoria-village.json';recipe=json.loads(recipePath.read_text(encoding='utf-8-sig'))
by={x['id']:x for x in manifest['files']}
mods=[('terrain.meadow','meadow','background','none'),('path.compact-earth','path','background','none'),('tree.canopy','tree-canopy','split-canopy','none'),('tree.trunk','tree-trunk','y-by-anchor','trunk-only'),('rock.moss','rock','y-by-anchor','footprint-only'),('building.wall','house-wall','y-by-anchor','foundation'),('building.roof','house-roof','split-roof','none')]
recipe['modules']=[]
for mid,key,sorting,collision in mods:
 x=by[key];recipe['modules'].append({'id':mid,'kind':key,'source':x['unityAsset'],'visibleSizeUnits':x['worldSizeUnits'],'pivotNormalizedBottomLeft':x['pivotNormalizedBottomLeft'],'groundAnchorPixelsFromTopLeft':x['groundAnchorPixelsFromTopLeft'],'sorting':sorting,'collision':collision})
recipe['pilot'].update({'regionAnchor':'Player','regionLocalBounds':[-7,-4.5,15,9],'maxProps':8,'pathWidthUnits':3.0,'mode':'isolated-protected-preview'})
recipe['pilot'].pop('bounds',None)
recipe['generation']['strategy']='seeded-authored-anchor-layout';recipe['generation']['runtimeGeneration']=False;recipe['generation']['placementConstraints']['protectedRadiusUnits']=1.5;recipe['generation']['protectedAnchors']=['Player','Helena — acolhimento','Brann — forja','Ponte dos Ecos'];recipe['status']={'art':'pilot-unreviewed','navigation':'visual-only-colliders-added-in-isolated-r9','scene':'generated-by-unity-editor-only'}
recipePath.write_text(json.dumps(recipe,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
print('Prepared',len(manifest['files']),'Unity PNGs, Aseprite sources, pivots and recipe metadata.')
