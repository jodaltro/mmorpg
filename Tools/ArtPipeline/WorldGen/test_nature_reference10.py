"""Directed delivery checks; no visual approval inferred from these checks."""
import json,sys,unittest,tempfile
from pathlib import Path
import numpy as np
from PIL import Image
import nature_reference10 as n

class NatureReferenceTests(unittest.TestCase):
 def test_unity_pixels_match_authoritative_exports(self):
  art=n.ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaNature10'
  pairs=[(n.BASE/'ExportV3/nature-atlas.png',art/'nature-atlas.png'),(n.BASE/'SurfaceFinal/cliff.png',art/'cliff.png'),(n.BASE/'SurfaceFinal/access.png',art/'access-refined.png')]
  pairs += [(n.BASE/'SurfaceFinal'/(s+'.png'),art/('ground-'+s+'.png')) for s in ('base','transitions','final')]
  for source,imported in pairs:self.assertEqual(source.read_bytes(),imported.read_bytes(),imported.name)
 def test_manifests(self):
  for name in ('ExportV3','SurfaceFinal','PlacementFinal'):
   p=n.BASE/name;m=n.read(p/'manifest.json')
   for f,h in m['files'].items():self.assertEqual(n.common.sha((p/f).read_bytes()),h,f)
   for f,v in m['inputs'].items():self.assertEqual(n.common.sha((n.ROOT/v['path']).read_bytes()),v['sha256'],f)
 def test_lossless_atlas_and_no_border_artifact(self):
  m=n.read(n.BASE/'ExportV3/sprites.json');atlas=Image.open(n.BASE/'ExportV3/nature-atlas.png')
  for s in m['sprites']:
   x,y,w,h=s['rectPixels'];im=Image.open(n.BASE/'ExportV3'/s['file']).crop(s['sourceRect']);self.assertEqual(np.array(atlas.crop((x,y,x+w,y+h))).tolist(),np.array(im).tolist())
  a=np.array(Image.open(n.BASE/'ExportV3/fieldstone-body.png'));self.assertEqual(int(a[:,231,3].sum()),0)
 def test_placement_determinism_and_entrance(self):
  with tempfile.TemporaryDirectory(dir=n.ROOT/'Temp') as p:
   n.placement(Path(p)/'placement');out=Path(p)/'placement'
   for f in ('navigation-before.json','navigation-after.json','placement.json'):
    self.assertEqual((out/f).read_bytes(),(n.BASE/'PlacementFinal'/f).read_bytes())
  r=n.read(n.BASE/'PlacementFinal/placement.json');self.assertEqual(r['beforePlants'],216);self.assertFalse(r['ecologicalPositionsChanged'])
  self.assertEqual(len(r['treeReplacements']),2);self.assertEqual(len(r['rocks']),3)
  for r in r['rocks']:self.assertGreaterEqual(r['siteQA']['minimumRoadDistance'],.7)
 def test_aseprite_repeat_export(self):
  with tempfile.TemporaryDirectory(dir=n.ROOT/'Temp') as p:
   out=Path(p)/'export';n.export(out)
   for f in (n.BASE/'ExportV3').glob('*.png'):self.assertEqual((out/f.name).read_bytes(),f.read_bytes(),f.name)
 def test_surface_patch_matches_global(self):
  with tempfile.TemporaryDirectory(dir=n.ROOT/'Temp') as p:
   rect=[192,1120,768,384];out=Path(p)/'patch';n.compose(out,bounds=rect)
   for name in ('base','transitions','final','cliff'):
    expected=Image.open(n.BASE/'SurfaceFinal'/(name+'.png')).crop((rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3]));actual=Image.open(out/(name+'.png'));self.assertTrue(np.array_equal(np.array(expected),np.array(actual)),name)
if __name__=='__main__':unittest.main(verbosity=2)
