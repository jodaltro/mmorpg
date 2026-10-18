"""Vegetation ecology, immutable dependencies, footprints, navigation and editable art."""
import copy,json,tempfile,unittest,subprocess,sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import label,distance_transform_edt
import environment_vegetation as v
import environment_geometry as g
import world_hydrology as common
LIB=v.LIB;BUILD=v.ROOT/'ArtSource/Labs/World2026/WorldStudio06/BuildR6'
class VegetationTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.ctx=v.Context();cls.solutions={s:v.solve(v.recipe(s),cls.ctx) for s in 'ABC'};cls.meta=g.read(LIB/'sprites.json')
 def test_seed_repeat(self):self.assertEqual(common.canonical(v.solve(v.recipe('A'),self.ctx)),common.canonical(self.solutions['A']))
 def test_other_seed_changes_positions_only(self):
  r=v.recipe('A');r['seed']+=10;s=v.solve(r,self.ctx);self.assertNotEqual([p['point'] for p in s['instances']],[p['point'] for p in self.solutions['A']['instances']]);self.assertEqual(s['sizeUnits'],self.solutions['A']['sizeUnits'])
 def test_compositions_share_inputs_and_seed(self):
  for s in 'ABC':
   build=g.read(BUILD/s/'vegetation.json');self.assertEqual(build['seed'],710206);self.assertEqual(build['inputs']['region']['sha256'],common.sha(common.BASE.read_bytes()));self.assertEqual(build['inputs']['geometry']['sha256'],common.sha((v.HYDRO/'geometry.json').read_bytes()))
 def test_invalid_recipes(self):
  for update in [{'schema':'bad'},{'seed':True},{'composition':'AA'},{'actorClearanceUnits':.01}]:
   r=v.recipe('A');r.update(update)
   with self.assertRaises(ValueError):v.validate(r)
  r=v.recipe('A');r['profiles']['oak']['radius']=0
  with self.assertRaises(ValueError):v.validate(r)
 def test_finite_focus_and_counts(self):
  r=v.recipe('A');r['habitatFocus']['center'][0]=float('nan')
  with self.assertRaises(ValueError):v.validate(r)
  r=v.recipe('A');r['speciesCounts']['oak']=-1
  with self.assertRaises(ValueError):v.validate(r)
 def test_all_anchors_valid_habitat(self):
  for style,s in self.solutions.items():
   for p in s['instances']:self.assertIsNotNone(self.ctx.permitted(v.recipe(style),p['species'],*p['point']),p['id'])
 def test_tree_disks_and_actor_clearance(self):
  for s in self.solutions.values():
   for p in s['instances']:
    if not p['footprintRadius']:continue
    x,y=p['point'];radius=p['footprintRadius']+.45
    for angle in np.linspace(0,2*np.pi,32,endpoint=False):
     xx=x+radius*np.cos(angle);yy=y+radius*np.sin(angle);self.assertLess(g.sample_triangular(self.ctx.rock,xx,yy),0);self.assertLess(g.sample_triangular(self.ctx.water,xx,yy),0)
 def test_no_roads_protected_or_ford_occupancy(self):
  for style,s in self.solutions.items():
   for p in s['instances']:
    h=p['habitat'];self.assertFalse(h['reserved']);self.assertGreater(h['roadDistance'],v.recipe(style)['profiles'][p['species']]['road']);x,y=p['point'];self.assertGreater(np.hypot(x-12,y-27.5),1.85+p['footprintRadius'])
 def test_no_deep_water_and_only_reeds_in_shallow(self):
  for s in self.solutions.values():
   for p in s['instances']:
    if p['habitat']['surfaceWater']:self.assertEqual(p['species'],'reeds');self.assertLessEqual(p['habitat']['depth'],.0025)
 def test_ecological_separation(self):
  s=self.solutions['C'];reeds=[p for p in s['instances'] if p['species']=='reeds'];dry=[p for p in s['instances'] if p['species']=='drygrass'];self.assertTrue(all(p['habitat']['waterDistance']<=.78 for p in reeds));self.assertGreater(sum(p['habitat']['surfaceWater'] for p in reeds),5);self.assertTrue(all(p['habitat']['waterDistance']>=3 for p in dry));self.assertGreater(np.mean([p['habitat']['moisture'] for p in reeds]),np.mean([p['habitat']['moisture'] for p in dry]))
 def test_same_species_spacing(self):
  for style,s in self.solutions.items():
   for kind in v.SPECIES:
    pts=np.array([p['point'] for p in s['instances'] if p['species']==kind]);d=np.linalg.norm(pts[:,None,:]-pts[None,:,:],axis=2);np.fill_diagonal(d,np.inf);self.assertGreaterEqual(d.min(),v.recipe(style)['profiles'][kind]['spacing']-1e-6)
 def test_tree_competition(self):
  for s in self.solutions.values():
   trees=[p for p in s['instances'] if p['footprintRadius']]
   for i,a in enumerate(trees):
    for b in trees[i+1:]:self.assertGreaterEqual(np.linalg.norm(np.array(a['point'])-b['point']),max(a['spacing'],b['spacing']))
 def test_hierarchical_parents_and_no_duplicate_ids(self):
  for s in self.solutions.values():
   ids=[p['id'] for p in s['instances']];self.assertEqual(len(ids),len(set(ids)));parents=[p['parentCluster'] for p in s['instances'] if p['species']=='oak'];self.assertGreater(len(set(parents)),3);self.assertGreater(len(parents),len(set(parents)))
 def test_navigation_preserves_components(self):
  for s in self.solutions.values():self.assertEqual(s['navigation']['componentCount'],self.ctx.baseComponents)
 def test_navigation_matches_physical_disks(self):
  for s in self.solutions.values():
   disks=np.zeros(self.ctx.navX.shape,bool)
   for p in s['instances']:
    if p['footprintRadius']:disks|=(self.ctx.navX-p['point'][0])**2+(self.ctx.navY-p['point'][1])**2<=p['footprintRadius']**2
   np.testing.assert_array_equal(np.array(s['navigation']['walkable']).reshape(disks.shape),self.ctx.baseWalk&~disks)
 def test_ford_actor_clearance_after_vegetation(self):
  for s in self.solutions.values():
   walk=np.array(s['navigation']['walkable']).reshape(self.ctx.baseWalk.shape);clear=distance_transform_edt(walk)*.25>=.45;components,_=label(clear);a=components[int(25*4),12*4];b=components[int(30.5*4),12*4];self.assertGreater(a,0);self.assertEqual(a,b)
 def test_all_species_and_real_silhouettes(self):
  self.assertEqual(len(self.meta['species']),8)
  for kind in v.SPECIES:
   masks=[Image.open(LIB/f'{kind}-v{i}-crown.png').getchannel('A').tobytes() for i in range(3)];self.assertEqual(len(set(masks)),3,kind)
 def test_tree_collider_smaller_than_canopy(self):
  for s in self.meta['species']:
   if s['footprintRadius']:self.assertLess(s['footprintRadius'],s['canopyRadius']/4)
 def test_trim_offsets_reconstruct_source_anchor(self):
  for s in self.meta['sprites']:
   species=next(k for k in self.meta['species'] if k['id']==s['species']);r=s['sourceRect'];self.assertEqual(s['offsetUnits'],[(r[0]-species['groundAnchor'][0])/32,(species['groundAnchor'][1]-r[3])/32])
 def test_atlas_crops_match_part_pixels(self):
  atlas=Image.open(LIB/'vegetation-atlas.png')
  for s in self.meta['sprites']:
   x,y,w,h=s['rectPixels'];part=Image.open(LIB/(s['id']+'.png')).crop(s['sourceRect']);np.testing.assert_array_equal(np.array(part),np.array(atlas.crop((x,y,x+w,y+h))))
 def test_manifest_tampering_refused(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp);(p/'a').write_text('wrong');common.write(p/'manifest.json',{'schema':'valdoria-vegetation-build/v1','files':{'a':common.sha(b'correct')},'inputs':{}})
   with self.assertRaises(ValueError):v.verify_manifest(p)
 def test_existing_destination_refused(self):
  with tempfile.TemporaryDirectory() as tmp:
   with self.assertRaises(ValueError):v.generate(v.ROOT/'ArtSource/Labs/World2026/WorldStudio06/Recipes/recipe-A.json',tmp,self.ctx)
 def test_published_reconstruction_all_styles(self):
  for s in 'ABC':self.assertTrue(v.verify(v.ROOT/f'ArtSource/Labs/World2026/WorldStudio06/Recipes/recipe-{s}.json',BUILD/s,self.ctx))
 def test_no_upstream_mutation(self):
  self.assertEqual(common.sha(common.BASE.read_bytes()),'cf43e4d5e6a2834d300b851b2f11e3a66bb6701b727432ebc72cec95c1bc5eb1');common.verify_manifest(v.HYDRO)
 def test_exclusion_patch_consumed(self):
  r=v.recipe('A');p=self.solutions['A']['instances'][0]['point'];r['patches']=[{'id':'clearing','rectUnits':[p[0]-1,p[1]-1,2,2]}];s=v.solve(r,self.ctx);self.assertNotIn(p,[a['point'] for a in s['instances']]);self.assertEqual(common.sha(common.BASE.read_bytes()),'cf43e4d5e6a2834d300b851b2f11e3a66bb6701b727432ebc72cec95c1bc5eb1')
if __name__=='__main__':unittest.main()
