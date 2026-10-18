"""Versioned material direction and constrained authored architecture catalog.

The Aseprite documents remain pixel authority. This tool authors NEW revisions;
export() only reads them. No resizing, new footprints or hidden faces are inferred.
"""
import argparse, copy, json, math, shutil, subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import architecture07r_reference as ref
import environment_architecture as arch
import world_hydrology as common
import vegetation_art
import terrain_materials

ROOT=common.ROOT
BASE=ROOT/'ArtSource/Labs/World2026/WorldStudio09'
EVIDENCE=ROOT/'Docs/Validation/ValdoriaWorldStudio09'
VERSION='valdoria-visual-direction/1.0.0'
FAMILIES={
 'house':('ArtSource/Labs/World2026/WorldStudio07R','rural-reference.aseprite','RegionV1'),
 'barn':('ArtSource/Labs/World2026/WorldStudio08/Barn','barn-reference.aseprite','RegionV1'),
 'castle':('ArtSource/Labs/World2026/WorldStudio08/Castle','castle-reference.aseprite','ReviewV1')}
PALETTES={
 'grass':['#304728','#405b2c','#547036','#6a8440','#84994f','#a2ad6a'],
 'dirt':['#624d39','#7d6043','#98784f','#af9263','#c4a97d','#d8c297'],
 'rock':['#3e443c','#555e50','#717966','#929680','#b0b19a','#ccc7ab'],
 'mud':['#3d4030','#505039','#696044','#827650','#9b8d65','#b4a47d'],
 'sand':['#85724f','#9b865c','#b09b6b','#c5b17c','#d8c591','#e7d6a7'],
 'road':['#6c563e','#846a49','#9f8259','#b39a6d','#c7af84','#d9c49b']}

def write(p,data):
 Path(p).parent.mkdir(parents=True,exist_ok=True)
 common.write(p,data)
def runlua(lua,path):
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(lua,encoding='utf8')
 subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script',str(path)],check=True)
def q(p): return json.dumps(str(p).replace('\\','/'))

# The treatment preserves the alpha of EVERY cel, including contact shadows.
LUA='''
local function clamp(x) return math.max(0,math.min(255,math.floor(x+.5))) end
local function revise(src,dst,kind,aged,seed)
 local s=app.open(src)
 for _,cel in ipairs(s.cels) do
  local im=cel.image:clone();local layer=cel.layer.name
  for it in im:pixels() do
   local c=it();local a=app.pixelColor.rgbaA(c)
   if a>0 and layer~="Shadow" and layer~="Shadow - ground plane" then
    local r,g,b=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c)
    local x,y=it.x+cel.position.x,it.y+cel.position.y
    local lum=.2126*r+.7152*g+.0722*b
    if kind=="barn" then
     if layer=="Roof" or layer=="Eaves" then
      r,g,b=r*.94,g*.93,b*.98+2
     elseif layer=="Foundation" then r,g,b=r*.96,g*.97,b*.99 end
    elseif kind=="castle" then
     if layer~="KeepRoof" and layer~="GateTimber" and layer~="KeepDoor" then
      r,g,b=r*.96,g*.975,b*.98+2
     end
    elseif kind=="vegetation" then
     if layer=="Canopy - dark volume" or layer=="Foliage - planes" or layer=="Highlights and accents" then
      if g>r*1.025 and g>b*1.06 then
       -- Separate cool pockets, leaf planes and warm upper-left light.
       local u=x/s.width;local v=y/s.height
       local plane=math.sin(x*.053+y*.031)+.55*math.sin(x*.107-y*.069)
       local light=math.max(-1,math.min(1,(.53-v)*1.3+(.50-u)*.45+plane*.23))
       local k=(lum-48)/104
       r=r*(.88+.10*k)+light*6;g=g*(1.04+.045*k)+light*9;b=b*(.76+.07*k)+light*1.5
       if layer=="Canopy - dark volume" and plane<-.85 then r,g,b=r-5,g-7,b-2 end
      end
     elseif layer=="Trunk - structure" or layer=="Bark and branches" then
      local grain=math.sin(x*1.7+y*.08)
      r,g,b=r*1.04+grain*3,g*.99+grain*2,b*.94
     end
    elseif kind=="motifs" then
     local old={}
     -- Row-aware palette mapping is injected below.
     PALETTE_MAP
    end
    if aged then
     -- Coherent small lichen colonies, smoke and worn grain, all clipped to
     -- already painted opaque planes. No invented geometry / collision.
     local u,v=x/s.width,y/s.height
     local colony=math.sin(x*.061+seed*.017)+math.sin(y*.091-x*.023)+.6*math.sin(x*.137+y*.117)
     local stone=layer=="Foundation" or layer=="KeepWalls" or layer=="CurtainWalls" or layer=="LeftTower" or layer=="RightTower"
     if stone and v>.49 and lum>55 and colony>1.60 and g>r*.70 then
      local t=.20+(colony-1.6)*.12;r=r*(1-t)+95*t;g=g*(1-t)+105*t;b=b*(1-t)+62*t
     elseif (layer=="Roof" or layer=="KeepRoof") and colony>1.95 and v>.20 then
      r,g,b=r*.94,g*.98,b*.92
     elseif (layer=="TimbersFront" or layer=="TimbersSide" or layer=="GateTimber") and colony>1.25 and lum>65 then
      r,g,b=r*1.04+2,g*1.03+2,b*1.04+2
     end
    end
    it(app.pixelColor.rgba(clamp(r),clamp(g),clamp(b),a))
   end
  end
  cel.image=im
 end
 s:saveAs(dst);s:close()
end
'''

def author():
 common.refuse(BASE);BASE.mkdir(parents=True)
 old=json.loads((ROOT/'ArtSource/Labs/World2026/WorldStudio04/Library/library.json').read_text())
 mapping='local row=math.floor(y/32);local ramps={'+','.join('{'+','.join('{'+','.join(str(v) for v in bytes.fromhex(c[1:]))+'}' for c in old['palette'][k])+'}' for k in terrain_materials.KINDS)+'};local news={'+','.join('{'+','.join('{'+','.join(str(v) for v in bytes.fromhex(c[1:]))+'}' for c in PALETTES[k])+'}' for k in terrain_materials.KINDS)+'}; if ramps[row+1] then local best,dist=1,1e20;for j,p in ipairs(ramps[row+1]) do local d=(r-p[1])^2+(g-p[2])^2+(b-p[3])^2;if d<dist then best=j;dist=d end end; local p=news[row+1][best];r,g,b=p[1],p[2],p[3] end'
 lua=LUA.replace('PALETTE_MAP',mapping)
 catalog={'schema':'valdoria-architecture-catalog/v1','version':VERSION,'artisticStatus':'candidate; original sources approved separately','families':{},'automaticVariations':['maintained','weathered'],'newArtRequired':['new orientation','different dimensions','new roof silhouette','moving openings','new annex','hidden faces'],'approvalRecord':arch.ref(ROOT/'Docs/Validation/ValdoriaWorldStudio08/artistic-approval.json')}
 for family,(folder,filename,region) in FAMILIES.items():
  parent=ROOT/folder;meta=ref.read(parent/'SourceV1/house-source.json');poly=ref.local(meta['footprintMaster'],meta)
  dims=np.ptp(poly,axis=0).tolist()
  modules=[]
  for layer in meta['layers']:
   modules.append({'id':f'{family}.{layer.lower()}.v1','layer':layer,'reuse':'family-specific authored projection; not free combinatorics','approvedSource':arch.ref(parent/'SourceV1'/filename)})
  catalog['families'][family]={'source':arch.ref(parent/'SourceV1'/filename),'metadata':arch.ref(parent/'SourceV1/house-source.json'),'region':arch.ref(parent/region/'manifest.json'),'dimensionsProjectedUnits':dims,'orientation':'authored-SE','roof':'authored-pitched' if family!='castle' else 'authored-keep-and-towers','openings':'authored-fixed','annex':'authored-fixed','materials':'valdoria-09','modules':modules,'worldLotAccepted':family!='castle','depthGroups':5 if family=='castle' else 1,'partsAreNotIndependentGeometry':True}
  for variant in ['maintained','weathered']:
   dst=BASE/'Architecture'/family/variant/'Source';dst.mkdir(parents=True)
   m=copy.deepcopy(meta);m.update(id=f'{family}-09-{variant}',sourceFile=filename,artisticStatus='candidate 09',parentSource=arch.ref(parent/'SourceV1'/filename),directionVersion=VERSION)
   write(dst/'house-source.json',m)
   lua+=f'\nrevise({q(parent/"SourceV1"/filename)},{q(dst/filename)},"{family}",{str(variant=="weathered").lower()},910209)\n'
  recipe={'schema':'valdoria-authored-architecture-recipe/v1','catalogVersion':VERSION,'family':family,'seed':910209,'dimensionsProjectedUnits':dims,'orientation':'authored-SE','roof':catalog['families'][family]['roof'],'materials':'valdoria-09','openings':'authored-fixed','annex':'authored-fixed','decoration':'authored-fixed','conservation':'weathered','position':[29,41] if family=='house' else [38.5,45.5] if family=='barn' else [32,32],'placement':'world' if family!='castle' else 'review-yard'}
  write(BASE/'Recipes'/f'{family}.json',recipe)
 # Source copies keep every original species, but revise only representative set.
 dst=BASE/'Vegetation/Source';dst.mkdir(parents=True)
 src=ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5'
 shutil.copy2(src/'source.json',dst/'source.json')
 for kind in vegetation_art.KINDS:
  if kind in ['oak','elm','hazel','fern','reeds']:
   lua+=f'\nrevise({q(src/(kind+".aseprite"))},{q(dst/(kind+".aseprite"))},"vegetation",false,910209)\n'
  else:shutil.copy2(src/(kind+'.aseprite'),dst/(kind+'.aseprite'))
 dst=BASE/'Terrain/Source';dst.mkdir(parents=True)
 lua+=f'\nrevise({q(ROOT/"ArtSource/Labs/World2026/WorldStudio04/Library/terrain-motifs.aseprite")},{q(dst/"terrain-motifs.aseprite")},"motifs",false,910209)\n'
 runlua(lua,BASE/'author-revisions.lua')
 write(BASE/'catalog.json',catalog)
 recipe=ref.read(ROOT/'ArtSource/Labs/World2026/WorldStudio04/Recipes/recipe-A.json');recipe.update(palette=PALETTES,artDirection='contextual-hierarchy',directionReference='house07R-material-families-09',pigmentContrast=1.12)
 write(BASE/'Recipes/terrain-A.json',recipe)
 write(BASE/'provenance.json',{'schema':'valdoria-direction-provenance/v1','version':VERSION,'method':'New Aseprite per-cel material edits; original alpha and canvases unchanged. No image generation or Blender needed for existing approved volumes. Lua authors initial revisions; subsequent export reads actual edited sources.','originals':{k:arch.ref(ROOT/v[0]/'SourceV1'/v[1]) for k,v in FAMILIES.items()},'authorTool':arch.ref(BASE/'author-revisions.lua'),'license':'Preserves original project and ImageGen provenance in original source metadata','status':'candidate pending visual user review'})

def validate_recipe(r,catalog=None):
 c=catalog or ref.read(BASE/'catalog.json')
 if not isinstance(r,dict) or not isinstance(c,dict):raise ValueError('Recipe/catalog objects required')
 if c.get('schema')!='valdoria-architecture-catalog/v1' or r.get('schema')!='valdoria-authored-architecture-recipe/v1' or r.get('catalogVersion')!=c['version']:raise ValueError('Recipe/catalog version mismatch')
 if not isinstance(r.get('family'),str) or r['family'] not in c['families']:raise ValueError('Unsupported architecture family')
 spec=c['families'][r['family']]
 allowed={'schema','catalogVersion','family','seed','dimensionsProjectedUnits','orientation','roof','materials','openings','annex','decoration','conservation','position','placement'}
 if set(r)-allowed:raise ValueError('Unknown recipe fields')
 for key in ['dimensionsProjectedUnits','orientation','roof','materials','openings','annex']:
  if r.get(key)!=spec[key]:raise ValueError('Unsupported authored combination: '+key+'; new art required')
 if r.get('decoration')!='authored-fixed':raise ValueError('Unsupported decoration')
 if r.get('conservation') not in ['maintained','weathered','seeded']:raise ValueError('Unsupported conservation')
 if not isinstance(r.get('seed'),int) or isinstance(r.get('seed'),bool):raise ValueError('Integer seed required')
 if not isinstance(r.get('position'),list) or len(r['position'])!=2 or not all(isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) for v in r['position']):raise ValueError('Finite position required')
 if r.get('placement') not in ['world','review-yard']:raise ValueError('Unknown placement')
 if r['placement']=='review-yard' and (r['family']!='castle' or r['position']!=[32,32]):raise ValueError('Current review yard supports the fixed castle staging position only')
 if not spec['worldLotAccepted'] and r['placement']=='world':raise ValueError('Castle needs authored stable lot; yard is not geographic approval')
 variant=r['conservation']
 if variant=='seeded':variant=['maintained','weathered'][int(common.sha((c['version']+str(r['seed'])+r['family']).encode())[:8],16)%2]
 return spec,variant

def export_all():
 for family in FAMILIES:
  for variant in ['maintained','weathered']:
   p=BASE/'Architecture'/family/variant;ref.export(p/'Source',p/'Export')
 vegetation_art.export_library(BASE/'Vegetation/Source',BASE/'Vegetation/Export')
 # Preserve the v2 768x192 six-function material library contract.
 src=BASE/'Terrain/Source/terrain-motifs.aseprite';out=BASE/'Terrain/Library';common.refuse(out);out.mkdir(parents=True)
 shutil.copy2(src,out/src.name)
 lua=f'local s=app.open({q(src)});for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs({q(out/"motifs.png")});s:close()'
 runlua(lua,out/'export.lua')
 meta=ref.read(ROOT/'ArtSource/Labs/World2026/WorldStudio04/Library/library.json');meta.update(palette=PALETTES,parentSource=arch.ref(src),author='Aseprite direction09 source export',files={p.name:common.sha(p.read_bytes()) for p in out.iterdir() if p.is_file()})
 write(out/'library.json',meta)
 refresh_catalog()

def refresh_catalog():
 c=ref.read(BASE/'catalog.json')
 c['variationMode']='two authored surface states; seeded selects state, does not invent geometry'
 c['patternSeed']=910209
 for family in FAMILIES:
  spec=c['families'][family];spec['revisions']={}
  for variant in ['maintained','weathered']:
   p=BASE/'Architecture'/family/variant
   spec['revisions'][variant]={'source':arch.ref(p/'Source'/FAMILIES[family][1]),'metadata':arch.ref(p/'Source/house-source.json'),'export':arch.ref(p/'Export/manifest.json'),'artisticStatus':'candidate 09'}
  meta=ref.read(ROOT/FAMILIES[family][0]/'SourceV1/house-source.json')
  spec['groundAnchorPixels']=meta['groundAnchorPixels'];spec['footprintMaster']=meta['footprintMaster'];spec['sourcePPU']=32;spec['conservationIsGeometryChange']=False
 write(BASE/'catalog.json',c)

def build_recipe(recipe_path,output,catalog_path=None):
 catalog_path=Path(catalog_path) if catalog_path else BASE/'catalog.json'
 r=ref.read(recipe_path);spec,variant=validate_recipe(r,ref.read(catalog_path));revision=spec['revisions'][variant]
 for item in revision.values():
  if isinstance(item,dict) and 'sha256' in item and common.sha((ROOT/item['path']).read_bytes())!=item['sha256']:raise ValueError('Catalog revision hash mismatch')
 source=(ROOT/revision['metadata']['path']).parent;exported=(ROOT/revision['export']['path']).parent
 if r['placement']=='world':
  metadata=ref.read(source/'house-source.json');poly=ref.local(metadata['footprintMaster'],metadata)+np.array(r['position']);w,h=ref.read(common.BASE)['size']
  if (poly<.5).any() or (poly[:,0]>w-.5).any() or (poly[:,1]>h-.5).any():raise ValueError('Footprint and safety margin outside WorldRegion')
 if r['placement']=='review-yard':
  import architecture_models
  architecture_models.review_yard(source,exported,output)
 else:ref.build(output,source,exported,r['position'])
 # Explicit recipe selection provenance alongside the unchanged shared contract.
 write(Path(output)/'selection.json',{'schema':'valdoria-architecture-selection/v1','recipe':arch.ref(Path(recipe_path)),'catalog':arch.ref(catalog_path),'variant':variant,'source':revision['source'],'seed':r['seed']})
 region=ref.read(Path(output)/'house.json');region['seed']=r['seed'];region['selectionRef']={'path':'selection.json','sha256':common.sha((Path(output)/'selection.json').read_bytes())};write(Path(output)/'house.json',region)
 manifest=ref.read(Path(output)/'manifest.json');manifest['inputs'].update(catalog=arch.ref(catalog_path),recipe=arch.ref(Path(recipe_path)));manifest['files']={p.name:common.sha(p.read_bytes()) for p in sorted(Path(output).iterdir()) if p.is_file() and p.name!='manifest.json'};write(Path(output)/'manifest.json',manifest)

def board():
 EVIDENCE.mkdir(parents=True,exist_ok=True)
 # Real source pixels; all three architecture images use the same 1:2 display
 # scale, with a 117*1.25px reference hero. Separate enlarged detail sheets below.
 canvas=Image.new('RGB',(2700,1700),'#343e32');d=ImageDraw.Draw(canvas)
 for j,(family,(old,_,_)) in enumerate(FAMILIES.items()):
  for row,variant in enumerate(['maintained','weathered']):
   im=Image.open(BASE/'Architecture'/family/variant/'Export/composite.png').convert('RGBA');im=im.crop(im.getbbox());im=im.resize((im.width//2,im.height//2),Image.Resampling.NEAREST)
   x=j*900+15;y=row*850+45;canvas.paste(im,(x,y),im);d.text((x,row*850+15),family+' / '+variant+' / same 0.5x scale',fill='white')
 canvas.save(EVIDENCE/'architecture-variants-board.png')
 old=ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5';new=BASE/'Vegetation/Export'
 sheet=Image.new('RGB',(1320,1150),'#343e32');d=ImageDraw.Draw(sheet)
 for row,kind in enumerate(['oak','elm','hazel','fern','reeds']):
  d.text((10,row*225+5),kind+'  OLD / NEW - silhouettes 0,1,2; 1x pixels',fill='white')
  for v in range(3):
   for col,src in enumerate([old,new]):
    imgs=[Image.open(src/f'{kind}-v{v}-{part}.png').convert('RGBA') for part in ['shadow','trunk','crown']];im=imgs[0]
    for x in imgs[1:]:im=Image.alpha_composite(im,x)
    if im.height>205:im=im.crop(im.getbbox())
    # Trees native-height > row, allocate species separate sheet as well.
    y=row*225+28;crop=im.crop((0,0,im.width,min(195,im.height)));sheet.paste(crop,(v*435+col*215,y),crop)
  single=Image.new('RGB',(max(1,imgs[0].width)*6,imgs[0].height+28),'#343e32');sd=ImageDraw.Draw(single)
  for v in range(3):
   for col,src in enumerate([old,new]):
    im=Image.open(src/f'{kind}-v{v}-shadow.png').convert('RGBA')
    for part in ['trunk','crown']:im=Image.alpha_composite(im,Image.open(src/f'{kind}-v{v}-{part}.png').convert('RGBA'))
    px=(v*2+col)*im.width;single.paste(im,(px,28),im);sd.text((px+2,5),('old' if col==0 else '09')+f' v{v}',fill='white')
  single.save(EVIDENCE/f'vegetation-{kind}-native.png')
 sheet.save(EVIDENCE/'vegetation-comparison-overview-cropped.png')

def pack():
 for family in FAMILIES:
  p=BASE/'Architecture'/family
  parts=ref.read(p/'maintained/Export/export.json')['parts']
  sizes={s['id']:Image.open(p/'maintained/Export'/s['trimmed']).size for s in parts}
  candidates=[]
  for mode in ['area','height','edge']:
   order=sorted(sizes,key=lambda k:(-(sizes[k][0]*sizes[k][1] if mode=='area' else sizes[k][1] if mode=='height' else max(sizes[k])),k))
   for width in range(768,4097,128):
    if max(w for w,h in sizes.values())+4>width:continue
    free=[(0,0,width,4096)];rects={};maxx=maxy=0
    for key in order:
     w,h=sizes[key];pw,ph=w+4,h+4
     fits=[(min(fw-pw,fh-ph),max(fw-pw,fh-ph),fy,fx) for fx,fy,fw,fh in free if pw<=fw and ph<=fh]
     if not fits:break
     _,_,y,x=min(fits);rects[key]=[x+2,y+2,w,h];maxx=max(maxx,x+pw);maxy=max(maxy,y+ph);nextfree=[]
     for fx,fy,fw,fh in free:
      if x>=fx+fw or x+pw<=fx or y>=fy+fh or y+ph<=fy:nextfree.append((fx,fy,fw,fh));continue
      if x>fx:nextfree.append((fx,fy,x-fx,fh))
      if x+pw<fx+fw:nextfree.append((x+pw,fy,fx+fw-x-pw,fh))
      if y>fy:nextfree.append((fx,fy,fw,y-fy))
      if y+ph<fy+fh:nextfree.append((fx,y+ph,fw,fy+fh-y-ph))
     unique=list(dict.fromkeys(nextfree));free=[a for a in unique if not any(a!=b and a[0]>=b[0] and a[1]>=b[1] and a[0]+a[2]<=b[0]+b[2] and a[1]+a[3]<=b[1]+b[3] for b in unique)]
    if len(rects)==len(sizes):candidates.append((maxx*maxy,maxx,maxy,rects))
  if not candidates:raise ValueError('Atlas needs explicit multipage support')
  _,w,h,rects=min(candidates,key=lambda c:c[0]);out=p/'Atlas';common.refuse(out);out.mkdir()
  for variant in ['maintained','weathered']:
   image=Image.new('RGBA',(w,h))
   for s in parts:
    x,y,pw,ph=rects[s['id']];im=Image.open(p/variant/'Export'/s['trimmed']).convert('RGBA');assert im.size==(pw,ph)
    image.paste(im,(x,y))
   image.save(out/(variant+'.png'))
  write(out/'atlas.json',{'schema':'valdoria-authored-architecture-atlas/v1','size':[w,h],'ppu':32,'padding':2,'resampled':False,'sprites':[{'id':s['id'],'rectPixels':rects[s['id']],'offsetUnits':s['offsetUnits']} for s in parts],'comparisonStandaloneRGBABytes':sum(w*h*4 for w,h in sizes.values()),'atlasRGBABytes':w*h*4,'files':{p.name:common.sha(p.read_bytes()) for p in out.iterdir() if p.is_file()}})

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['author','export','terrain','build','board','pack']);p.add_argument('--recipe');p.add_argument('--output');p.add_argument('--catalog',help='Versioned authored catalog; defaults to direction09');a=p.parse_args()
 if a.command=='author':author()
 elif a.command=='export':export_all()
 elif a.command=='terrain':terrain_materials.generate(BASE/'Recipes/terrain-A.json',BASE/'Terrain/Build',BASE/'Terrain/Library')
 elif a.command=='build':build_recipe(a.recipe,a.output,a.catalog)
 elif a.command=='pack':pack()
 else:board()
