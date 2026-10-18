import tempfile
import unittest
from pathlib import Path
import numpy as np
from PIL import Image
import environment_finish12 as e

class Environment12Tests(unittest.TestCase):
 def test_manifests(self):
  for name in ('ExportV1','BuildV2'):self.assertTrue(e.verify(e.BASE/name)['passed'])
 def test_bank_only_and_approved_road_preserved(self):
  a=np.array(Image.open(e.g.BASE/'WorldFinal/final.png').convert('RGBA'));b=np.array(Image.open(e.BASE/'BuildV2/ground-bank.png').convert('RGBA'));mask=np.array(Image.open(e.BASE/'BuildV2/bank-influence.png'))
  self.assertTrue(np.array_equal(a[mask==0],b[mask==0]));self.assertTrue(np.array_equal(a[:,:,3],b[:,:,3]))
  c=e.m.Context();self.assertTrue(np.array_equal(a[c.masks['coverage']>0],b[c.masks['coverage']>0]))
 def test_water_alpha_and_phase_counts_preserved(self):
  render=e.read(e.HYDRO/'water-render.json')
  self.assertEqual(len(render['chunks']),6)
  for chunk in render['chunks']:
   self.assertEqual(len(chunk['frames']),4)
   for name in chunk['frames']:
    a=np.array(Image.open(e.HYDRO/name));b=np.array(Image.open(e.BASE/'BuildV2'/name));self.assertTrue(np.array_equal(a[:,:,3],b[:,:,3]),name)
 def test_world_sampling_crop_and_seed(self):
  im=Image.open(e.BASE/'ExportV1/sandstone-planes.png');y,x=np.mgrid[0:64,0:128];a=e.painting(im,x,y,910212);b=e.painting(im,x[:,37:99],y[:,37:99],910212);self.assertTrue(np.array_equal(a[:,37:99],b));self.assertFalse(np.array_equal(a,e.painting(im,x,y,910213)))
 def test_sources_rebuild_exports(self):
  with tempfile.TemporaryDirectory(dir=e.ROOT/'Temp') as tmp:
   out=Path(tmp)/'fresh';e.export(out)
   for file in (e.BASE/'ExportV1').glob('*.png'):self.assertEqual(file.read_bytes(),(out/file.name).read_bytes(),file.name)
 def test_build_determinism(self):
  with tempfile.TemporaryDirectory(dir=e.ROOT/'Temp') as tmp:
   out=Path(tmp)/'fresh';e.build(out)
   for file in (e.BASE/'BuildV2').glob('*.png'):self.assertEqual(file.read_bytes(),(out/file.name).read_bytes(),file.name)

if __name__=='__main__':unittest.main()
