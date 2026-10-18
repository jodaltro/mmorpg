"""Hydrology contract, drainage, shared boundary and rendered pixel regressions."""
import copy,json,tempfile,unittest
from pathlib import Path
import numpy as np
from PIL import Image
import world_hydrology as w
import environment_geometry as g
import water_art as art
ROOT=w.ROOT;LIB=ROOT/'ArtSource/Labs/World2026/WorldStudio05/Library';BUILD=ROOT/'ArtSource/Labs/World2026/WorldStudio05/BuildR4'
class HydrologyTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.recipe=w.recipe();cls.before=w.BASE.read_bytes();cls.solution=w.solve(cls.recipe);cls.fields=cls.solution['geometry']['waterFields'];cls.region=g.read(w.BASE);cls.relief=g.read(w.RELIEF)
 def test_version_and_nonfinite(self):
  for change in [{'schema':'wrong'},{'seed':True},{'wetMarginUnits':float('nan')},{'stepUnits':1}]:
   r=copy.deepcopy(self.recipe);r.update(change)
   with self.assertRaises(ValueError):w.validate_recipe(r)
 def test_invalid_feature_and_patch(self):
  r=copy.deepcopy(self.recipe);r['rivers'][0]['minWidth']=5
  with self.assertRaises(ValueError):w.validate_recipe(r)
  with self.assertRaises(ValueError):w.apply_patch(self.recipe,{'schema':'valdoria-hydrology-patch/v1','edits':[{'kind':'terrain-carve'}]})
 def test_depression_spill_and_lake(self):
  l=self.solution['lake'];self.assertLess(l['floorScalar'],l['waterLevelScalar']);self.assertLess(l['waterLevelScalar'],l['spillScalar']);self.assertGreater(l['maxDepthScalar'],.01);self.assertGreater(l['areaVertexEstimateUnits2'],15)
 def test_uphill_lake_seed_rejected(self):
  r=copy.deepcopy(self.recipe);r['lake']['seedPoint']=[22,15]
  with self.assertRaisesRegex(ValueError,'depression'):w.solve(r)
 def test_drainage_acyclic_lexicographic(self):
  d=self.solution['drainage'];p=np.array(d['parentYX']);f=np.array(d['filledElevation']);rank=np.array(d['rank']);y,x=np.nonzero(p[:,:,0]>=0);py,px=p[y,x].T
  self.assertTrue(np.all((f[py,px]<f[y,x]-1e-9)|((abs(f[py,px]-f[y,x])<1e-9)&(rank[py,px]<rank[y,x]))))
 def test_priority_flood_does_not_modify_input(self):
  z=np.array([[5,5,5,5],[5,0,1,5],[5,2,1,5],[5,5,5,4]],float);before=z.copy();filled,parent,rank=w.priority_flood(z);np.testing.assert_array_equal(z,before);self.assertGreater(filled[1,1],z[1,1])
 def test_river_reaches_lake_and_descends_spill_surface(self):
  r=self.solution['rivers'][0];self.assertEqual(r['toLake'],self.recipe['lake']['id']);self.assertLessEqual(r['maxFilledUphill'],1e-9);self.assertGreater(r['lengthUnits'],10);self.assertLess(r['maxOriginalUphill'],.001)
 def test_width_profile_is_variable_and_bounded(self):
  a=np.array(self.solution['rivers'][0]['samples']);self.assertGreater(np.ptp(a[:,3]),.2);self.assertGreaterEqual(a[:,3].min(),self.recipe['rivers'][0]['minWidth']);self.assertLessEqual(a[:,3].max(),self.recipe['rivers'][0]['maxWidth'])
 def test_seed_repeat_geometry_exact(self):
  other=w.solve(copy.deepcopy(self.recipe));self.assertEqual(w.canonical(self.solution),w.canonical(other))
 def test_seed_changes_width_not_terrain_or_drainage(self):
  r=copy.deepcopy(self.recipe);r['seed']+=1;s=w.solve(r);self.assertEqual(s['lake'],self.solution['lake']);self.assertEqual(s['drainage'],self.solution['drainage']);self.assertNotEqual(s['rivers'][0]['samples'],self.solution['rivers'][0]['samples']);self.assertEqual(self.before,w.BASE.read_bytes())
 def test_protected_area_rejects_water(self):
  r=copy.deepcopy(self.recipe);r['protectedAreas']=[{'id':'protected','rectUnits':[5,22,4,5]}]
  with self.assertRaisesRegex(ValueError,'intersects'):w.solve(r)
 def test_world_and_road_hashes_unchanged(self):
  self.assertEqual(self.before,w.BASE.read_bytes());self.assertEqual(w.sha(self.before),'cf43e4d5e6a2834d300b851b2f11e3a66bb6701b727432ebc72cec95c1bc5eb1');self.assertEqual(w.sha((w.ROAD/'road.json').read_bytes()),'edd9072ffa8db50f5a97f201a8867c1112f8010e1c63fff4263b7d1bd6eb54a7')
 def test_rock_loops_match_exact_visual_triangle_field(self):
  rng=np.random.default_rng(55);x=rng.uniform(0,64,3000);y=rng.uniform(0,48,3000);s=g.sample_triangular(np.array(self.relief['samples'])[:,:,0],x,y);inside=g.contains(self.solution['geometry']['rockLoops'],x,y);np.testing.assert_array_equal(inside[abs(s)>1e-5],(s>=0)[abs(s)>1e-5])
 def test_water_polygon_matches_surface_and_blocked_triangles(self):
  rng=np.random.default_rng(56);x=rng.uniform(0,20,3000);y=rng.uniform(19,33,3000)
  for field,loops in [('surface','waterLoops'),('blocked','waterBlockedLoops')]:
   scalar=g.sample_triangular(self.fields[field],x,y);inside=g.contains(self.solution['geometry'][loops],x,y);np.testing.assert_array_equal(inside[abs(scalar)>1e-5],(scalar>=0)[abs(scalar)>1e-5])
 def test_navigation_uses_same_shared_fields(self):
  n=self.solution['navigation'];y,x=np.mgrid[.125:48:.25,.125:64:.25];solid=g.sample_triangular(np.array(self.relief['samples'])[:,:,0],x,y)>=0;blocked=g.sample_triangular(self.fields['blocked'],x,y)>=0;np.testing.assert_array_equal(np.array(n['walkable']).reshape(y.shape),~(solid|blocked))
 def test_masks_depth_and_crossings(self):
  masks=w.rasterize(self.solution,[128,640,512,384]);self.assertTrue(np.all(~masks['blocked']|masks['surface']));self.assertTrue(np.all((masks['depth']>0)==masks['surface']));self.assertTrue(masks['shallow'].any());self.assertTrue(masks['wetland'].any());self.assertLess(g.sample_triangular(self.fields['blocked'],12,27.5),0)
 def test_water_avoids_actual_road_pixels_and_reserves(self):
  masks=w.rasterize(self.solution);road=np.array(Image.open(w.ROAD/'coverage.png'));self.assertFalse(np.any(masks['surface']&(road>0)));res=np.repeat(np.repeat(np.array(self.region['layers']['reserved']).reshape(48,64),32,axis=0),32,axis=1);self.assertFalse(np.any(masks['surface']&res))
 def test_water_connected(self):
  from scipy.ndimage import label
  wet=w.rasterize(self.solution)['surface'];labels,n=label(wet);self.assertEqual(n,1)
 def test_two_axis_crop_masks_identical(self):
  box=[128,640,512,384];full=w.rasterize(self.solution,box)
  for key in full:
   top=np.concatenate([w.rasterize(self.solution,[128,640,256,192])[key],w.rasterize(self.solution,[384,640,256,192])[key]],axis=1);bottom=np.concatenate([w.rasterize(self.solution,[128,832,256,192])[key],w.rasterize(self.solution,[384,832,256,192])[key]],axis=1);np.testing.assert_array_equal(full[key],np.concatenate([top,bottom],axis=0))
 def test_finite_width_patch_locality(self):
  p={'schema':'valdoria-hydrology-patch/v1','edits':[{'kind':'river-width','riverId':'brook-west','arcRange':[2,4],'factor':1.12}]};patched=w.solve(w.apply_patch(self.recipe,p));self.assertEqual(patched['lake'],self.solution['lake']);self.assertEqual(patched['drainage'],self.solution['drainage']);a=np.array(self.solution['rivers'][0]['samples']);b=np.array(patched['rivers'][0]['samples']);np.testing.assert_array_equal(a[:,:3],b[:,:3]);self.assertTrue(np.any(a[:,3]!=b[:,3]));outside=(a[:,2]<2)|(a[:,2]>4);np.testing.assert_array_equal(a[outside],b[outside]);np.testing.assert_array_equal(w.rasterize(self.solution,[64,704,160,192])['surface'],w.rasterize(patched,[64,704,160,192])['surface'])
 def test_art_four_distinct_frames_and_rgba(self):
  images=art.render_chunk(self.solution,LIB,[256,768,256,256]);self.assertEqual(len(images),4);self.assertTrue(all(i.mode=='RGBA' for i in images));self.assertEqual(len({i.tobytes() for i in images}),4)
 def test_art_crop_continuity_all_channels(self):
  whole=art.render_chunk(self.solution,LIB,[128,720,384,256]);left=art.render_chunk(self.solution,LIB,[128,720,192,256]);right=art.render_chunk(self.solution,LIB,[320,720,192,256]);top=art.render_chunk(self.solution,LIB,[128,720,384,128]);bottom=art.render_chunk(self.solution,LIB,[128,848,384,128])
  for i in range(4):np.testing.assert_array_equal(np.array(whole[i]),np.concatenate([np.array(left[i]),np.array(right[i])],1));np.testing.assert_array_equal(np.array(whole[i]),np.concatenate([np.array(top[i]),np.array(bottom[i])],0))
 def test_editable_source_pixels_consumed(self):
  with tempfile.TemporaryDirectory() as tmp:
   path=Path(tmp)
   for i in range(4):
    im=Image.open(LIB/f'water-frame-{i}.png').convert('RGBA');a=np.array(im);a[34,7,:3]=[80,30,100];Image.fromarray(a).save(path/f'water-frame-{i}.png')
   original=art.render_chunk(self.solution,LIB,[128,704,192,192])[0];edited=art.render_chunk(self.solution,path,[128,704,192,192])[0];self.assertNotEqual(original.tobytes(),edited.tobytes())
 def test_refuse_existing_output_and_manifest_tampering(self):
  with tempfile.TemporaryDirectory() as tmp:
   with self.assertRaisesRegex(ValueError,'Refuse'):w.generate(ROOT/'ArtSource/Labs/World2026/WorldStudio05/Recipes/recipe.json',tmp,LIB)
   p=Path(tmp);(p/'a.txt').write_text('changed');w.write(p/'manifest.json',{'schema':'valdoria-hydrology-build/v1','inputs':{},'files':{'a.txt':w.sha(b'expected')}})
   with self.assertRaisesRegex(ValueError,'hash'):w.verify_manifest(p)
 def test_overlap_between_vertices_is_detected(self):
  a=np.array([[1,-.1],[-.1,-.1]]);b=np.array([[-.1,1],[-.1,-.1]]);self.assertFalse(np.any((a>0)&(b>0)));self.assertTrue(g.positive_overlap(a,b,1));self.assertFalse(g.positive_overlap(a,-np.ones((2,2)),1))
 def test_tiny_protected_area_inside_water_rejected(self):
  r=copy.deepcopy(self.recipe);r['protectedAreas']=[{'id':'tiny','rectUnits':[6.33,23.33,.03,.03]}]
  with self.assertRaisesRegex(ValueError,'protected'):w.solve(r)
 def test_cli_explicit_inputs(self):
  import subprocess,sys
  with tempfile.TemporaryDirectory() as tmp:
   out=Path(tmp)/'crop';subprocess.run([sys.executable,str(ROOT/'Tools/ArtPipeline/WorldGen/world_hydrology.py'),'crop','--recipe',str(ROOT/'ArtSource/Labs/World2026/WorldStudio05/Recipes/recipe.json'),'--region',str(w.BASE),'--road',str(w.ROAD),'--relief',str(w.RELIEF),'--bounds','[480,768,32,32]','--output',str(out)],check=True,capture_output=True)
   self.assertEqual(g.read(out/'manifest.json')['regionSha256'],w.sha(w.BASE.read_bytes()))
 def test_published_build_source_hashes(self):
  m=w.verify_manifest(BUILD);self.assertEqual(m['generator'],w.VERSION);self.assertGreater(len(m['files']),25)
if __name__=='__main__':unittest.main()
