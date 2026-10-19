"""Regression checks for enlargement, blocked basin and enclosure access."""
import unittest
from pathlib import Path
from PIL import Image
import village02_royal_gardens as g

class RoyalGardens(unittest.TestCase):
 def test_native_area_and_fountain_size(self):
  d=g.read(g.OUT/'dimensions.json');self.assertGreater(d['newEnclosedArea'],7500);self.assertGreater(d['areaRatio'],5);self.assertEqual(d['newFountainDiameter'],12.8);self.assertEqual(d['fountainDiameterRatio'],4)
  with Image.open(g.OUT/'Export/fountain/composite.png') as im:self.assertEqual(im.size,(649,432))
 def test_original_physics_preserved_except_relocated_fountain(self):
  old={p['id']:p for p in g.read(g.OLD/'layout.json')['physical']};new={p['id']:p for p in g.read(g.OUT/'layout.json')['physical']}
  for id,p in old.items():
   if id!='court-fountain':self.assertEqual(new[id],p,id)
  self.assertEqual(len(new),172)
 def test_open_routes_and_bridge_essential(self):
  d=g.read(g.OUT/'navigation-proof.json');self.assertTrue(d['open']['allConnected']);self.assertFalse(any(d['closed']['targets'].values()))
 def test_only_royal_entrance_connects_inside(self):
  d=g.read(g.OUT/'layout.json');d['physical'].append(dict(id='test-entrance-closure',polygon=g.base.rect(175,173,189,177)));d['spawn']=[182,180];d['targets']=[dict(id='outside',point=[116.6,103])];self.assertFalse(g.base.nav(d)[1]['targets']['outside'])
 def test_export_pixels_and_file_hashes(self):
  for f,h in g.read(g.OUT/'manifest.json')['files'].items():self.assertEqual(g.sha(g.OUT/f),h,f)
  for id in ['fountain','garden-floor']:
   with Image.open(g.OUT/'Source'/id/'native-authority.png') as a,Image.open(g.OUT/'Export'/id/'composite.png') as b:self.assertEqual(a.tobytes(),b.tobytes())

if __name__=='__main__':unittest.main()
