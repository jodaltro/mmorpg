from pathlib import Path
import json,hashlib,random,math
ROOT=Path(__file__).resolve().parents[3];R9=ROOT/'ArtSource/Labs/World2026/R9';recipe=json.loads((R9/'Recipes/valdoria-village.json').read_text(encoding='utf-8-sig'));seed=int(recipe['seed']);rng=random.Random(seed)
# Anchored layout: authored locations are the artistic intent; seeded sub-pixel offsets allow stable controlled variation.
player=(-8.0,-1.0);protected={'Player':player,'Helena':(-10.0,.9),'Brann':(-3.0,-4.1),'Ponte dos Ecos':(18.0,1.7)}
props=[('house-wall',-3.4,-.4,0,(-6,-4,12,8),True),('house-roof',-3.4,2.55,0,(-6,-4,12,8),False),('tree-trunk',-13.35,-2.35,0,(-6,-4,12,8),True),('tree-canopy',-13.35,-1.0,0,(-6,-4,12,8),False),('tree-trunk',.25,-.75,0,(-6,-4,12,8),True),('tree-canopy',.25,.6,0,(-6,-4,12,8),False),('rock',-11.0,-1.4,0,(-6,-4,12,8),True)]
# terrain patch and road are deliberately allowed under the protected player; they never add collision.
layout=[]
for i,(asset,x,y,z,bounds,solid) in enumerate(props):
  if asset=='house-roof':
   wall=next(q for q in layout if q['asset']=='house-wall');pos=(wall['position'][0],round(wall['position'][1]+2.1,4))
  elif asset=='tree-canopy':
   trunk=next(q for q in reversed(layout) if q['asset']=='tree-trunk');pos=(trunk['position'][0],round(trunk['position'][1]+2.3,4))
  else:
   dx=rng.choice([-.0625,0,.0625]);dy=rng.choice([-.0625,0,.0625]);pos=(round(x+dx,4),round(y+dy,4));
  if not(-15<=pos[0]<=1 and -5.5<=pos[1]<=3):raise ValueError('Placement outside pilot region')
  if solid:
   for label,p in protected.items():
    if label=='Ponte dos Ecos':continue
    if math.dist(pos,p)<1.5:raise ValueError(f'{asset} overlaps protected {label}')
  layout.append({'asset':asset,'position':[pos[0],pos[1],z],'collision':solid,'sortingAnchor':[pos[0],pos[1]],'seedIndex':i})
obj={'schema':'valdoria-authored-layout/v1','biome':recipe['biome'],'seed':seed,'generator':'Tools/ArtPipeline/World/build_valdoria_layout_r9.py','recipeSha256':hashlib.sha256((R9/'Recipes/valdoria-village.json').read_bytes()).hexdigest(),'protectedAnchors':protected,'regionBounds':[-15,-5.5,16,8.5],'terrain':{'asset':'meadow','center':[-8,-1,0],'size':[12,8],'collision':False},'path':{'asset':'path','center':[-8,-1,0],'size':[3,8],'collision':False},'props':layout,'validation':{'seedDeterministic':True,'placementBounds':True,'protectedRadiusUnits':1.5,'pathWidthUnits':3,'runtimeGeneration':False,'navigation':'needs-unity-play-validation'}}
out=R9/'Layouts/valdoria-village-seed-620913.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8');print('layout objects',len(layout),'sha256',hashlib.sha256(out.read_bytes()).hexdigest())
