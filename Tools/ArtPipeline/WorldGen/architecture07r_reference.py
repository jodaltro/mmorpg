"""07R: exports ONE authored Aseprite reference; never redraws its pixels or expands a library."""
import argparse,json,math,subprocess,copy
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import distance_transform_edt,binary_dilation
import environment_architecture as arch
import environment_vegetation as veg
import world_hydrology as common
ROOT=common.ROOT;SOURCE=ROOT/'ArtSource/Labs/World2026/WorldStudio07R/SourceV1';EXPORT=ROOT/'ArtSource/Labs/World2026/WorldStudio07R/ExportV1'

def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def export(source,output):
 source=Path(source);out=common.refuse(output);out.mkdir(parents=True);meta=read(source/'house-source.json');filename=meta.get('sourceFile','rural-reference.aseprite');lua='local s=app.open(app.params["source"]);assert(s.width=='+str(meta['canvas'][0])+' and s.height=='+str(meta['canvas'][1])+' and #s.frames==1 and #s.layers=='+str(len(meta['layers']))+',"Authored house source contract");local root=app.params["root"]\n';parts=[]
 for i,name in enumerate(meta['layers']):
  lua+='for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers['+json.dumps(name)+'].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/'+name+'.png")\n';parts.append({'id':name,'file':name+'.png','role':meta.get('roles',{}).get(name,'roof' if name in ['Roof','Eaves','Chimney'] else 'ground' if name in ['Shadow','Foundation'] else 'wall')})
 lua+='for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()\n';(out/'export.lua').write_text(lua);subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','source='+str(source/filename),'--script-param','root='+str(out.resolve()).replace('\\','/'),'--script',str(out/'export.lua')],check=True)
 valid=[]
 for part in parts:
  im=Image.open(out/part['file']);rect=im.getbbox()
  if rect is None:continue
  part.update({'rect':list(rect),'offsetUnits':[(rect[0]-meta['groundAnchorPixels'][0])/32,(meta['groundAnchorPixels'][1]-rect[3])/32],'trimmed':part['id']+'-trim.png'});im.crop(rect).save(out/part['trimmed']);valid.append(part)
 common.write(out/'export.json',{'schema':'valdoria-authored-house-export/v1','source':arch.ref(source/filename),'sourceMetadata':arch.ref(source/'house-source.json'),'ppu':32,'canvas':meta['canvas'],'parts':valid,'artisticStatus':'candidate'});common.write(out/'manifest.json',{'schema':'valdoria-authored-house-art-build/v1','files':{p.name:common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()},'inputs':{'source':arch.ref(source/filename),'metadata':arch.ref(source/'house-source.json')}});return valid

def local(points,meta):return (np.array(points)*meta['scaleFromPaintedMaster']-np.array(meta['groundAnchorPixels']))/32

def build(output,source=SOURCE,exported=EXPORT,position=None):
 out=common.refuse(output);source=Path(source);exported=Path(exported);arch.verify_files(exported);meta=read(source/'house-source.json');filename=meta.get('sourceFile','rural-reference.aseprite');ctx=veg.Context();polyLocal=local(meta['footprintMaster'],meta);point=np.array(position if position is not None else meta.get('regionPosition',[29.,41.]));poly=(polyLocal+point).tolist();occupied=arch.mask_polygon(poly,ctx);buffered=binary_dilation(occupied,iterations=2);samples=[ctx.sample(x,y) for x,y in zip(ctx.navX[buffered],ctx.navY[buffered])]
 if any(v['solid'] or v['surfaceWater'] or v['reserved'] or v['roadDistance']<.7 or v['slope']>.065 for v in samples):
  failures={k:sum(v[k] for v in samples) for k in ['solid','surfaceWater','reserved']};failures.update({'minRoad':min(v['roadDistance'] for v in samples),'maxSlope':max(v['slope'] for v in samples)});raise ValueError('Authored site rejected '+str(failures))
 height=[v['height'] for v in samples]
 if max(height)-min(height)>.13:raise ValueError('Unstable authored lot')
 frontLocal=local(meta['frontGroundMaster'],meta);doorX=local([meta['doorOpeningMasterPixels']['foot']],meta)[0,0];t=(doorX-frontLocal[0,0])/(frontLocal[1,0]-frontLocal[0,0]);entryLocal=frontLocal[0]+t*(frontLocal[1]-frontLocal[0]);tangent=frontLocal[1]-frontLocal[0];normal=np.array([-tangent[1],tangent[0]]);normal/=np.linalg.norm(normal);entry=entryLocal+point;approach=entry+normal*.95;walk=ctx.baseWalk&~occupied
 road=np.array([[veg.scalar(ctx.roadDistance,x,y,1/32) for x in ctx.navX[0]] for y in ctx.navY[:,0]]);access=arch.route(approach.tolist(),walk,road,ctx,.7);exclusions=[{'id':'reference-house-volume','rectUnits':arch.bbox(poly,2.2)}]+[{'id':'reference-access-'+str(i),'rectUnits':[p[0]-1.05,p[1]-1.05,2.1,2.1]} for i,p in enumerate(access)]
 out.mkdir(parents=True);vr=veg.recipe('A');vr['protectedAreas']+=exclusions;common.write(out/'vegetation-recipe.json',vr);new=veg.generate(out/'vegetation-recipe.json',out/'Vegetation',ctx);baseTrees=new['instances'];c=arch.read(ROOT/'ArtSource/Labs/World2026/WorldStudio06/BuildR6/C/vegetation.json')['instances'];b=arch.read(ROOT/'ArtSource/Labs/World2026/WorldStudio06/BuildR6/B/vegetation.json')['instances'];plants=[]
 for label,items in [('A',baseTrees),('B',b),('C',c)]:
  for v in items:
   if label=='A' and (v['species']=='reeds' or arch.rect_contains([2,12,10,8],v['point'])):continue
   if label=='B' and (v['species']=='reeds' or not arch.rect_contains([2,12,10,8],v['point'])):continue
   if label=='C' and v['species']!='reeds':continue
   if any(arch.rect_contains(r['rectUnits'],v['point']) for r in exclusions):continue
   if any(math.dist(v['point'],a['point'])<max(.3,v['footprintRadius']+a['footprintRadius']+.65) for a in plants):continue
   p=copy.deepcopy(v);p['id']=label+'/'+v['id'];plants.append(p)
 final=walk.copy()
 for v in plants:
  if v['footprintRadius']:final&=~((ctx.navX-v['point'][0])**2+(ctx.navY-v['point'][1])**2<=v['footprintRadius']**2)
 clear=distance_transform_edt(final)*.25
 if any(clear[int(y*4),int(x*4)]<.57 for x,y in access):raise ValueError('Ecology blocks the authored access')
 original=read(ROOT/'ArtSource/Labs/World2026/WorldStudio06/BuildR6/A/vegetation.json')['instances'];old={v['id']:v for v in original};newMap={v['id']:v for v in baseTrees};same=sum(k in old and old[k]==v for k,v in newMap.items())
 refs={k:arch.ref(p) for k,p in ctx.paths.items()};refs.update({'art':arch.ref(exported/'manifest.json'),'source':arch.ref(source/filename),'metadata':arch.ref(source/'house-source.json'),'banksC':arch.ref(ROOT/'ArtSource/Labs/World2026/WorldStudio06/BuildR6/C/manifest.json'),'groveB':arch.ref(ROOT/'ArtSource/Labs/World2026/WorldStudio06/BuildR6/B/manifest.json')})
 result={'schema':'valdoria-authored-house-region/v1','id':meta['id'],'seed':meta.get('seed',710207),'sizeUnits':[64,48],'position':point.tolist(),'footprint':poly,'frontGround':(frontLocal+point).tolist(),'entry':entry.tolist(),'approach':approach.tolist(),'access':{'radius':.7,'points':access},'siteQA':{'heightRange':[min(height),max(height)],'maximumSlope':max(v['slope'] for v in samples),'minimumWaterDistance':min(v['waterDistance'] for v in samples)},'doorHeightUnits':(meta['doorOpeningMasterPixels']['foot'][1]-meta['doorOpeningMasterPixels']['head'][1])*meta['scaleFromPaintedMaster']/32,'sourceAuthority':'Aseprite pixels, not a geometric facade generator','inputs':refs};common.write(out/'house.json',result);common.write(out/'vegetation.json',{'schema':'valdoria-vegetation/v1','sizeUnits':[64,48],'instances':plants});common.write(out/'exclusions.json',{'rectangles':exclusions,'vegetationA':{'before':len(original),'after':len(baseTrees),'identicalInstances':same,'removedOrChangedIDs':[k for k,v in old.items() if k not in newMap or newMap[k]!=v]},'note':'A regenerated once, B/C consumed as immutable selections; no terrain/road/water changes'});common.write(out/'navigation.json',{'schema':'valdoria-architecture-navigation/v1','size':[256,192],'stepUnits':.25,'architectureBlocked':occupied.ravel().tolist(),'walkable':final.ravel().tolist(),'actorClearanceIncluded':False})
 im=Image.new('RGBA',(2048,1536));d=ImageDraw.Draw(im);pts=[tuple(round(n*32) for n in p) for p in access];d.line(pts,fill='#a08c6d',width=34,joint='curve')
 for x,y in pts:d.ellipse((x-17,y-17,x+17,y+17),fill='#a08c6d')
 rect=im.getbbox();im.crop(rect).save(out/'access.png');common.write(out/'access-render.json',{'originUnity':[rect[0]/32,48-rect[3]/32],'rectPixels':list(rect)});common.write(out/'manifest.json',{'schema':'valdoria-authored-house-region-build/v1','inputs':refs,'files':{p.name:common.sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file()}});return result

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['export','build','verify']);p.add_argument('--source',default=str(SOURCE));p.add_argument('--exported',default=str(EXPORT));p.add_argument('--output',required=True);p.add_argument('--position',help='Explicit geographic [x,y] lot override');a=p.parse_args()
 if a.command=='export':print(len(export(a.source,a.output)))
 elif a.command=='build':print(build(a.output,a.source,a.exported,json.loads(a.position) if a.position else None)['siteQA'])
 else:arch.verify_files(a.output);print('hashes valid')
