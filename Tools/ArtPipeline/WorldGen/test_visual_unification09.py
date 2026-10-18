"""Targeted direction09 contract/pixel invariants, not artistic approval."""
import copy,json,subprocess,tempfile,unittest
from pathlib import Path
import numpy as np
from PIL import Image
import visual_unification09 as v

class VisualDirection09Tests(unittest.TestCase):
 def test_catalog_constraints(self):
  for family in v.FAMILIES:
   recipe=v.ref.read(v.BASE/'Recipes'/f'{family}.json')
   spec,variant=v.validate_recipe(recipe)
   self.assertEqual(variant,'weathered');self.assertTrue(spec['partsAreNotIndependentGeometry'])
   for key,value in [('roof','flat'),('orientation','north'),('dimensionsProjectedUnits',[10,8]),('openings','moved'),('annex','none'),('decoration','new-chimney'),('materials','pink'),('catalogVersion','2'),('unknown',True),('seed',True),('position',[float('nan'),3])]:
    bad=copy.deepcopy(recipe);bad[key]=value
    with self.assertRaises(ValueError,msg=family+'/'+key):v.validate_recipe(bad)

 def test_seeded_selection(self):
  for family in v.FAMILIES:
   r=v.ref.read(v.BASE/'Recipes'/f'{family}.json');r['conservation']='seeded'
   self.assertEqual([v.validate_recipe(r)[1] for _ in range(10)],[v.validate_recipe(r)[1]]*10)
   variants=set()
   for seed in range(20):r['seed']=seed;variants.add(v.validate_recipe(r)[1])
   self.assertEqual(variants,{'maintained','weathered'})

 def test_castle_not_world_placement(self):
  r=v.ref.read(v.BASE/'Recipes/castle.json');r['placement']='world'
  with self.assertRaisesRegex(ValueError,'stable lot'):v.validate_recipe(r)

 def test_approved_sources_unchanged(self):
  paths=[v.ROOT/folder/'SourceV1'/filename for folder,filename,_ in v.FAMILIES.values()]
  paths+=[v.ROOT/'Assets/Mmorpg/Scenes/MmorpgWorld.unity',v.ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5/source.json']
  for path in paths:
   old=subprocess.run(['git','show','HEAD:'+path.relative_to(v.ROOT).as_posix()],capture_output=True,check=True).stdout
   current=path.read_bytes()
   if path.suffix=='.unity':current=current.replace(b'\r\n',b'\n');old=old.replace(b'\r\n',b'\n')
   self.assertEqual(v.common.sha(current),v.common.sha(old),str(path))

 def test_architecture_alpha_anchors_and_door_scale(self):
  for family,(folder,_,_) in v.FAMILIES.items():
   parent=v.ROOT/folder;meta=v.ref.read(parent/'SourceV1/house-source.json');base=Image.open(parent/'ExportV1/composite.png').convert('RGBA')
   height=(meta['doorOpeningMasterPixels']['foot'][1]-meta['doorOpeningMasterPixels']['head'][1])*meta['scaleFromPaintedMaster']/32
   self.assertTrue(4.7<height<5.0)
   for variant in ['maintained','weathered']:
    p=v.BASE/'Architecture'/family/variant
    new=Image.open(p/'Export/composite.png').convert('RGBA');self.assertEqual(new.size,base.size)
    self.assertTrue(np.array_equal(np.array(new)[:,:,3],np.array(base)[:,:,3]))
    m=v.ref.read(p/'Source/house-source.json')
    for key in ['groundAnchorPixels','footprintMaster','doorOpeningMasterPixels','frontGroundMaster','canvas','layers']:self.assertEqual(m[key],meta[key])
    v.arch.verify_files(p/'Export')

 def test_variants_have_real_pixels(self):
  result={}
  for family in v.FAMILIES:
   p=v.BASE/'Architecture'/family
   a=np.array(Image.open(p/'maintained/Export/composite.png'));b=np.array(Image.open(p/'weathered/Export/composite.png'))
   changed=np.any(a[:,:,:3]!=b[:,:,:3],axis=2)&(a[:,:,3]>0)
   fraction=float(changed.sum()/max(1,(a[:,:,3]>0).sum()));self.assertGreater(fraction,.01);result[family]=fraction
  v.write(v.EVIDENCE/'variant-pixel-coverage.json',result)

 def test_vegetation_alpha_and_uvs(self):
  old=v.ROOT/'ArtSource/Labs/World2026/WorldStudio06/LibraryR5';new=v.BASE/'Vegetation/Export'
  self.assertEqual(v.ref.read(old/'sprites.json'),v.ref.read(new/'sprites.json'))
  for kind in ['oak','elm','hazel','fern','reeds']:
   for variant in range(3):
    for part in ['shadow','trunk','crown']:
     name=f'{kind}-v{variant}-{part}.png';a=np.array(Image.open(old/name));b=np.array(Image.open(new/name))
     self.assertTrue(np.array_equal(a[:,:,3],b[:,:,3]),name)
     if part=='crown':self.assertFalse(np.array_equal(a,b),name)

 def test_atlas_lossless_no_overlap(self):
  for family in v.FAMILIES:
   root=v.BASE/'Architecture'/family;meta=v.ref.read(root/'Atlas/atlas.json');occupied=np.zeros(tuple(reversed(meta['size'])),bool)
   for part in meta['sprites']:
    x,y,w,h=part['rectPixels'];self.assertFalse(occupied[y:y+h,x:x+w].any());occupied[y:y+h,x:x+w]=True
    for variant in ['maintained','weathered']:
     atlas=Image.open(root/'Atlas'/f'{variant}.png');src=Image.open(root/variant/'Export'/(part['id']+'-trim.png'))
     self.assertTrue(np.array_equal(np.array(src),np.array(atlas.crop((x,y,x+w,y+h)))))

 def test_world_geometry_ecology_invariant(self):
  for family,(folder,_,region) in v.FAMILIES.items():
   root=v.BASE/'Architecture'/family/'Region';old=v.ROOT/folder/region
   for file in ['navigation.json','vegetation.json','exclusions.json']:
    if (old/file).exists():self.assertEqual(v.ref.read(old/file),v.ref.read(root/file),family+'/'+file)
   v.arch.verify_files(root)
  self.assertEqual((v.BASE/'Terrain/Build/relief-field.json').read_bytes(),(v.ROOT/'ArtSource/Labs/World2026/WorldStudio04/BuildR6/A/relief-field.json').read_bytes())
  v.terrain_materials.verify_manifest(v.BASE/'Terrain/Build')

 def test_aseprite_reexport_pixels(self):
  with tempfile.TemporaryDirectory() as tmp:
   for family in v.FAMILIES:
    source=v.BASE/'Architecture'/family/'weathered';out=Path(tmp)/family
    v.ref.export(source/'Source',out)
    for p in (source/'Export').glob('*.png'):self.assertTrue(np.array_equal(np.array(Image.open(p)),np.array(Image.open(out/p.name))),str(p))
   v.vegetation_art.export_library(v.BASE/'Vegetation/Source',Path(tmp)/'vegetation')
   self.assertEqual((Path(tmp)/'vegetation/vegetation-atlas.png').read_bytes(),(v.BASE/'Vegetation/Export/vegetation-atlas.png').read_bytes())

 def test_rebuild_region_recipe(self):
  # One full rebuild is enough: shared geometry engine unchanged; all three
  # manifests and all authored variants are independently verified above.
  with tempfile.TemporaryDirectory(dir=v.ROOT/'Temp') as tmp:
   out=Path(tmp)/'region';v.build_recipe(v.BASE/'Recipes/house.json',out)
   original=v.BASE/'Architecture/house/Region'
   for name in ['house.json','selection.json','navigation.json','vegetation.json','exclusions.json','access.png','manifest.json']:self.assertEqual((original/name).read_bytes(),(out/name).read_bytes(),name)

 def test_actual_rejected_lots(self):
  ctx=v.ref.veg.Context();p=v.BASE/'Architecture/house/weathered';meta=v.ref.read(p/'Source/house-source.json');centroid=v.ref.local(meta['footprintMaster'],meta).mean(axis=0)
  samples=[]
  for label,mask in [('water',ctx.water>=0),('rock',ctx.rock>=0),('road',ctx.roadDistance<.3)]:
   # Context world sampling retains precise subcell water/road occupancy.
   where=np.argwhere(mask)
   self.assertGreater(len(where),0,label)
   y,x=where[len(where)//2];step=1/32 if label=='road' else .25;point=[float(x*step),float(y*step)]
   position=(np.array(point)-centroid).tolist()
   with tempfile.TemporaryDirectory(dir=v.ROOT/'Temp') as tmp:
    with self.assertRaises(ValueError) as error:v.ref.build(Path(tmp)/'invalid',p/'Source',p/'Export',position)
   samples.append({'target':label,'position':position,'rejection':str(error.exception)})
  v.write(v.EVIDENCE/'lot-rejections.json',samples)

if __name__=='__main__':unittest.main(verbosity=2)
