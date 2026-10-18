import unittest,tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
import ground13 as g

class Ground13Tests(unittest.TestCase):
 def test_manifests(self):
  for folder in ['ExportV2','AtlasV1','ReliefV3','WaterV2']:self.assertTrue(g.verify(g.BASE/folder)['passed'])
 def test_atlas_preserves_sampled_pixels(self):
  data=g.read(g.BASE/'AtlasV1/atlas.json');atlas=Image.open(g.BASE/'AtlasV1/plants-shared.png').convert('RGBA')
  for source,entry in data['entries'].items():
   old=Image.open(g.ROOT/source).convert('RGBA')
   if 'identityForProtectedRects' in entry:
    for x,y,w,h in entry['identityForProtectedRects']:self.assertEqual(old.crop((x,y,x+w,y+h)).tobytes(),atlas.crop((x,y,x+w,y+h)).tobytes())
   else:
    x,y,w,h=entry['rect'];self.assertEqual(old.crop(entry['sourceRect']).tobytes(),atlas.crop((x,y,x+w,y+h)).tobytes(),source)
 def test_visual_wall_feet_match_physical_contours(self):
  data=g.read(g.BASE/'ReliefV3/visual-relief.json');old=np.concatenate(data['physicalLoops']);new=np.array(data['groundFeet']);self.assertLess(cKDTree(new).query(old)[0].max(),1e-5);self.assertLess(cKDTree(old).query(new)[0].max(),1e-5);self.assertFalse(data['physicalChange'])
 def test_water_masks_and_loop(self):
  data=g.read(g.BASE/'WaterV2/water.json');changes=[]
  for chunk in data['chunks']:
   frames=[]
   for name in chunk['frames']:
    old=np.array(Image.open(g.e.HYDRO/name));new=np.array(Image.open(g.BASE/'WaterV2'/name));self.assertTrue(np.array_equal(old[:,:,3],new[:,:,3]));frames.append(new[:,:,:3].astype(float))
   differences=[float(np.abs(frames[(i+1)%4]-frames[i]).mean()) for i in range(4)];self.assertLess(max(differences),1.5);changes.append(differences)
  self.assertGreater(max(max(v) for v in changes),0)
  self.assertEqual(data['durationMs'],180)
 def test_bank_and_road_preservation(self):
  old=np.array(Image.open(g.e.BASE/'BuildV2/ground-bank.png'));new=np.array(Image.open(g.BASE/'WaterV2/bank-ground.png'));influence=np.array(Image.open(g.BASE/'WaterV2/bank-influence.png'));self.assertTrue(np.array_equal(old[influence==0],new[influence==0]));coverage=g.m.Context().masks['coverage'];self.assertTrue(np.array_equal(old[coverage>0],new[coverage>0]))
 def test_rebuild_determinism(self):
  with tempfile.TemporaryDirectory(dir=g.ROOT/'Temp') as tmp:
   for name,fun in [('export',g.export),('atlas',g.atlas),('relief',g.relief),('water',g.water)]:
    out=Path(tmp)/name;fun(out);expected=g.BASE/{'export':'ExportV2','atlas':'AtlasV1','relief':'ReliefV3','water':'WaterV2'}[name]
    for file in expected.iterdir():
     if file.suffix=='.png' or file.name in ['visual-relief.json','water.json','atlas.json']:self.assertEqual(file.read_bytes(),(out/file.name).read_bytes(),file.name)

if __name__=='__main__':unittest.main()
