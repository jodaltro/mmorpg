import unittest,json,copy,tempfile,shutil,subprocess,sys,math
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import environment_architecture as a
import architecture_art as art
import environment_vegetation as veg
class ArchitectureTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.root=a.ROOT/'ArtSource/Labs/World2026/WorldStudio07';cls.out=cls.root/'BuildR5';cls.ctx=a.Context();cls.r=a.read(cls.root/'Recipes/region.json');cls.solution=a.read(cls.out/'architecture.json');cls.nav=a.read(cls.out/'navigation.json');cls.vegetation=a.read(cls.out/'vegetation.json')['instances'];cls.parts=a.read(a.LIB/'modules.json')
 def test_contract_and_inputs(self):
  self.assertEqual(self.solution['schema'],'valdoria-architecture/v1');self.assertEqual(len(self.solution['buildings']),3);a.verify_files(self.out)
 def test_invalid_schema(self):
  r=copy.deepcopy(self.r);r['schema']='wrong'
  with self.assertRaises(ValueError):a.validate(r)
 def test_invalid_radius(self):
  r=copy.deepcopy(self.r);r['accessRadius']=.3
  with self.assertRaises(ValueError):a.validate(r)
 def test_duplicate_buildings(self):
  r=copy.deepcopy(self.r);r['sites'][1]['id']=r['sites'][0]['id']
  with self.assertRaises(ValueError):a.validate(r)
 def test_bad_geometry_parameters(self):
  r=copy.deepcopy(self.r);r['sites'][0]['guide'][0]=float('nan')
  with self.assertRaises(ValueError):a.validate(r)
 def test_seed_and_repeated_sites(self):
  x,m=a.sites(self.r,self.ctx);y,n=a.sites(self.r,self.ctx);self.assertEqual(x,y);np.testing.assert_array_equal(m,n)
 def test_explicit_seed_records(self):
  r=copy.deepcopy(self.r);r['seed']+=1;x,_=a.sites(r,self.ctx);self.assertNotEqual(x[0]['seed'],self.solution['buildings'][0]['seed'])
 def test_unbuildable_lot_refused(self):
  r=copy.deepcopy(self.r);r['sites']=[{'id':'no','archetype':'C','guide':[10.,25.],'searchRadius':[.1,.1]}]
  with self.assertRaisesRegex(ValueError,'No stable site'):a.sites(r,self.ctx)
 def test_stable_sites_not_flattened(self):
  for b in self.solution['buildings']:
   self.assertLessEqual(b['siteQA']['maxSlope'],.065);self.assertLessEqual(np.ptp(b['siteQA']['heightRange']),.13);self.assertGreaterEqual(b['siteQA']['minimumWaterDistance'],.75)
 def test_door_scale_and_separate_roof(self):
  for b in self.solution['buildings']:
   self.assertGreaterEqual(b['doorHeight'],5);self.assertGreaterEqual(b['doorWidth'],2);self.assertTrue(any(p['hideWithRoof'] for p in b['parts']));self.assertIn('closed',b['interior'])
 def test_nonrectangular_plan_and_real_variants(self):
  self.assertGreater(len(self.solution['buildings'][0]['footprint']),4);hashes=[]
  for s in 'ABC':hashes.append(a.common.sha((a.LIB/(s+'-roof.png')).read_bytes()))
  self.assertEqual(len(set(hashes)),3)
 def test_road_access_clearance(self):
  walk=np.array(self.nav['walkable']).reshape(self.nav['size'][1],self.nav['size'][0]);clear=distance_transform_edt(walk)*.25
  for b in self.solution['buildings']:
   for p in b['access']['points']:self.assertGreaterEqual(clear[int(p[1]*4),int(p[0]*4)],.57)
   p=b['access']['points'][-1];self.assertLess(veg.scalar(self.ctx.world.roadDistance,*p,1/32),.15)
 def test_access_continuity(self):
  for b in self.solution['buildings']:
   points=b['access']['points'];self.assertLess(max(math.dist(x,y) for x,y in zip(points,points[1:])),.36);self.assertLess(math.dist(points[0],b['approach']),.2)
 def test_closed_diagonal_edge_occupancy(self):
  polygon=[[0.,0.],[2.,0.],[3.,1.],[1.,1.]]
  self.assertTrue(bool(a.inside(polygon,np.array(2.5),np.array(.5))))
  self.assertFalse(bool(a.inside(polygon,np.array(2.501),np.array(.5))))
 def test_navigation_occupancy(self):
  ctx=self.ctx.world;physical=np.zeros_like(ctx.baseWalk)
  for b in self.solution['buildings']:
   physical|=a.mask_polygon(b['footprint'],ctx)
   for p in b['porchPosts']:physical|=(ctx.navX-p['point'][0])**2+(ctx.navY-p['point'][1])**2<=p['radius']**2
  np.testing.assert_array_equal(physical.ravel(),self.nav['architectureBlocked']);walk=ctx.baseWalk&~physical
  for v in self.vegetation:
   rr=v['footprintRadius'];x,y=v['point']
   if rr:walk&=~((ctx.navX-x)**2+(ctx.navY-y)**2<=rr**2)
  np.testing.assert_array_equal(walk.ravel(),self.nav['walkable'])
 def test_vegetation_reservations(self):
  rects=a.read(self.out/'vegetation-exclusions.json')['rectangles']
  for v in self.vegetation:self.assertFalse(any(a.rect_contains(r['rectUnits'],v['point']) for r in rects))
 def test_ecotone_policy(self):
  for v in self.vegetation:
   if v['species']=='reeds':self.assertEqual(v['sourceComposition'],'C')
   elif a.rect_contains(self.r['groveRect'],v['point']):self.assertEqual(v['sourceComposition'],'B')
   else:self.assertEqual(v['sourceComposition'],'A')
 def test_no_deep_water_or_ford_occupation(self):
  for v in self.vegetation:
   sample=self.ctx.world.sample(*v['point']);self.assertLessEqual(sample['depth'],.0025)
   for c in self.ctx.world.hydro['crossings']:self.assertGreater(math.dist(v['point'],c['point']),c['radiusUnits']+.8)
 def test_subconsumer_manifests_and_effects(self):
  for s in 'ABC':veg.verify_manifest(self.out/'Vegetation'/s)
  delta=a.read(self.out/'vegetation-exclusions.json')['consumerEffects'];self.assertTrue(all(v['removedOrRepositionedIDs'] for v in delta.values()))
 def test_art_crops_preserve_offsets_rgba(self):
  for p in self.parts['parts']:
   full=Image.open(a.LIB/p['file']);crop=Image.open(a.LIB/p['trimmedFile']);self.assertEqual(full.mode,'RGBA');self.assertEqual(full.crop(p['sourceRect']).tobytes(),crop.tobytes());self.assertAlmostEqual(p['offsetUnits'][0],(p['sourceRect'][0]-art.ANCHOR[0])/32)
 def test_cropped_access_has_no_full_world_texture(self):
  for p in a.read(self.out/'access-render.json')['surfaces']:
   im=Image.open(self.out/p['file']);self.assertLess(im.width*im.height,2048*1536/4);self.assertEqual(im.mode,'RGBA');self.assertEqual(p['originUnity'],[p['rectPixels'][0]/32,48-p['rectPixels'][3]/32])
 def test_manifest_tamper(self):
  with tempfile.TemporaryDirectory(dir=a.ROOT/'Temp') as tmp:
   out=Path(tmp)/'copy';shutil.copytree(self.out,out);(out/'navigation.json').write_text('{}')
   with self.assertRaisesRegex(ValueError,'hash'):a.verify_files(out)
 def test_destination_refusal(self):
  with self.assertRaises((ValueError,FileExistsError)):a.generate(self.root/'Recipes/region.json',self.out,self.ctx)
 def test_rebuild(self):self.assertTrue(a.verify(self.root/'Recipes/region.json',self.out,self.ctx))
 def test_actual_aseprite_export(self):
  with tempfile.TemporaryDirectory(dir=a.ROOT/'Temp') as tmp:
   out=Path(tmp)/'export';art.export_library(a.LIB,out)
   for p in self.parts['parts']:self.assertEqual((a.LIB/p['trimmedFile']).read_bytes(),(out/p['trimmedFile']).read_bytes())
 def test_opening_module_recombination(self):
  with tempfile.TemporaryDirectory(dir=a.ROOT/'Temp') as tmp:
   out=Path(tmp)/'recomposed';art.assemble(out,modules_source=a.LIB)
   for p in self.parts['parts']:self.assertEqual((a.LIB/p['file']).read_bytes(),(out/p['file']).read_bytes())
 def test_edited_opening_source_changes_only_openings(self):
  with tempfile.TemporaryDirectory(dir=a.ROOT/'Temp') as tmp:
   folder=Path(tmp)/'sources';folder.mkdir()
   for name in ['door-arched','door-square','window-timber']:shutil.copyfile(a.LIB/('module-'+name+'.aseprite'),folder/('module-'+name+'.aseprite'))
   lua=Path(tmp)/'edit.lua';lua.write_text('local s=app.open(app.params["source"]);local im=s.cels[1].image;for y=45,65 do for x=16,35 do im:drawPixel(x,y,Color{r=105,g=76,b=49,a=255}) end end;s:saveAs(app.params["source"]);s:close()')
   subprocess.run([r'D:\Aseprite\Aseprite.exe','-b','--script-param','source='+str(folder/'module-door-arched.aseprite'),'--script',str(lua)],check=True)
   out=Path(tmp)/'edited';art.assemble(out,modules_source=folder)
   self.assertNotEqual((a.LIB/'A-doors.png').read_bytes(),(out/'A-doors.png').read_bytes());self.assertEqual((a.LIB/'A-walls.png').read_bytes(),(out/'A-walls.png').read_bytes());self.assertEqual((a.LIB/'A-roof.png').read_bytes(),(out/'A-roof.png').read_bytes())
 def test_upstream_bytes(self):
  for ref in self.solution['inputs'].values():self.assertEqual(a.common.sha((a.ROOT/ref['path']).read_bytes()),ref['sha256'])
if __name__=='__main__':unittest.main()
