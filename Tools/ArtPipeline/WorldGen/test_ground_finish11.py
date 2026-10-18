"""Targeted checks of reproducibility, protected inputs and material grammar.
These assertions do not approve artistic quality.
"""
import copy,json,tempfile,unittest,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
import ground_finish11 as g

class GroundFinishTests(unittest.TestCase):
 def test_manifests_and_integrated_pixels(self):
  for name in ('ExportV2','WorldFinal','CourtFinalV2'):
   p=g.BASE/name;meta=g.read(p/'manifest.json');self.assertEqual(meta['schema'],'valdoria-ground-finish-build/v1');g.n.arch.verify_files(p)
  art=g.ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaGround11'
  for name,stages in [('WorldFinal',('base','transitions','final')),('CourtFinalV2',('before','base','transitions','final'))]:
   for stage in stages:self.assertEqual((g.BASE/name/(stage+'.png')).read_bytes(),(art/(name+'-'+stage+'.png')).read_bytes())
 def test_aseprite_export_rebuild(self):
  with tempfile.TemporaryDirectory(dir=g.ROOT/'Temp') as folder:
   out=Path(folder)/'library';g.export(out)
   for name in ('meadow','earth','edge-grammar'):self.assertEqual((out/(name+'.png')).read_bytes(),(g.EXPORT/(name+'.png')).read_bytes())
 def test_same_seed_and_world_patch(self):
  ctx=g.m.Context();cov,paths=g.coverage_world(ctx);r=g.read(g.BASE/'recipe.json');rect=[256,1200,768,336]
  a,masks=g.render(rect,cov,paths,r,True);b,_=g.render(rect,cov,paths,r,True)
  for name in a:
   full=Image.open(g.BASE/'WorldFinal'/(name+'.png')).crop((rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3]));self.assertTrue(np.array_equal(np.array(a[name]),np.array(b[name])),name);self.assertTrue(np.array_equal(np.array(a[name]),np.array(full)),name)
  r=copy.deepcopy(r);r['seed']+=1;c,_=g.render(rect,cov,paths,r,True);self.assertFalse(np.array_equal(np.array(a['final']),np.array(c['final'])))
 def test_road_core_and_unified_entrance(self):
  ctx=g.m.Context();cov,paths=g.coverage_world(ctx);stored=np.array(Image.open(g.BASE/'WorldFinal/coverage-input.png'));self.assertTrue(np.array_equal(cov,stored));alpha=np.array(Image.open(g.BASE/'WorldFinal/visualAlpha.png'));core=ctx.masks['navigable']>0;self.assertTrue(np.all(alpha[core]==255))
  house=g.read(g.n.ref.SOURCE.parent/'RegionV1/house.json')
  for x,y in house['access']['points']:self.assertGreater(cov[round(y*32),round(x*32)],200)
 def test_court_connections_and_junction_wear(self):
  cov,paths,cases=g.court_geometry();self.assertEqual(len(cases),9);self.assertTrue(np.array_equal(cov,np.array(Image.open(g.BASE/'CourtFinalV2/coverage-input.png'))))
  x,y=np.meshgrid(np.arange(310,331),np.arange(990,1011));wear,coherence=g.road_flow(paths,x,y);self.assertLess(float(coherence.mean()),.10)
  case=g.read(g.BASE/'court-network.json');self.assertFalse(case['canonicalWorld'])
  r=g.read(g.BASE/'recipe.json');rect=[1280,400,640,400];a,_=g.render(rect,cov,paths,r);full=Image.open(g.BASE/'CourtFinalV2/final.png').crop((1280,400,1920,800));self.assertTrue(np.array_equal(np.array(a['final']),np.array(full)))
 def test_approved_sources_and_navigation_immutable(self):
  approval=g.read(g.ROOT/'Docs/Art/Approvals/Nature10-2026-10-18.json')
  for file,h in approval['sourceHashes'].items():self.assertEqual(g.n.common.sha((g.ROOT/file).read_bytes()),h,file)
  paths=['Assets/Mmorpg/Scenes/MmorpgWorld.unity','Assets/Mmorpg/Scenes/ValdoriaNatureRefinementLab.unity','ArtSource/Labs/World2026/Nature10/PlacementFinal/navigation-after.json','ArtSource/Labs/World2026/WorldStudio02/RoadsR3/A/road.json','ArtSource/Labs/World2026/WorldStudio02/RoadsR3/A/coverage.png','Assets/Mmorpg/Art/Experimental/ValdoriaNature10/nature-atlas.png']
  for path in paths:
   old=subprocess.check_output(['git','show','c78d81c208d366b2addb6aa798560ff5280d2950:'+path]);now=(g.ROOT/path).read_bytes();self.assertEqual(old.replace(b'\r\n',b'\n'),now.replace(b'\r\n',b'\n'),path)
 def test_reject_geometry_and_invalid_sampling(self):
  r=g.read(g.BASE/'recipe.json');g.validate(r)
  for key,value in [('geometryChange',True),('ppu',16),('seed',False)]:
   bad=copy.deepcopy(r);bad[key]=value
   with self.assertRaises(ValueError):g.validate(bad)
  bad=copy.deepcopy(r);bad['road']['edgeVisualPixels']=64
  with self.assertRaises(ValueError):g.validate(bad)
if __name__=='__main__':unittest.main(verbosity=2)
