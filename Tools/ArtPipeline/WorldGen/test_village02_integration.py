import copy,unittest
import numpy as np
import village02_integration as v
from PIL import Image

class IntegrationContract(unittest.TestCase):
 def test_outer_curtain_has_no_alternative_gate_gap(self):
  d=v.read(v.BASE/'IntegrationV2/layout.json');d['physical'].append(dict(id='test-close-town-gate',polygon=v.rect(112,93,121,104),kind='test'))
  targets=v.nav(d)[1]['targets'];self.assertFalse(targets['common']);self.assertFalse(targets['castle-court'])
  for id in v.HOUSES:self.assertFalse(targets[id],id)
 def test_castle_gate_seals_the_private_court(self):
  d=v.read(v.BASE/'IntegrationV2/layout.json');d['physical'].append(dict(id='test-close-castle-gate',polygon=v.rect(175,211,184,219),kind='test'))
  targets=v.nav(d)[1]['targets'];self.assertTrue(targets['common']);self.assertFalse(targets['castle-court'])
 def test_final_revision_adds_only_four_solid_leaves(self):
  base=v.read(v.OUT/'layout.json');final=v.read(v.BASE/'IntegrationV2/layout.json');before={p['id']:p for p in base['physical']};after={p['id']:p for p in final['physical']}
  self.assertEqual(4,len(after)-len(before))
  for id,p in before.items():self.assertEqual(p,after[id])
  self.assertTrue(v.nav(final)[1]['allConnected']);self.assertFalse(any(v.nav(final,True)[1]['targets'].values()))
 def test_final_gate_depth_sources_remain_pixel_identical(self):
  root=v.BASE/'IntegrationV2'
  for id in ['gate','castle-compound']:
   meta=v.read(root/'DepthArt'/id/'provenance.json');original=Image.open(v.E/'ExportV1'/id/'composite.png');result=Image.new('RGBA',original.size)
   for p in meta['parts']:result.alpha_composite(Image.open(root/'DepthArt'/id/(p['id']+'.png')))
   self.assertEqual(result.tobytes(),original.tobytes())
 def test_baked_outputs_match_authored_geometry_and_hashes(self):
  d=v.read(v.OUT/'layout.json');expected=v.compile_layout();d.pop('groundChunks');self.assertEqual(expected,d)
  manifest=v.read(v.OUT/'manifest.json')
  for path,expectedHash in manifest['files'].items():self.assertEqual(expectedHash,v.sha(v.OUT/path),path)
 def test_depth_partitions_preserve_every_approved_pixel(self):
  for id,spec in v.specs().items():
   original=Image.open(v.E/'ExportV1'/id/'composite.png');recombined=Image.new('RGBA',original.size)
   for p in spec['parts']:recombined.alpha_composite(Image.open(v.OUT/'DepthArt'/id/(p['id']+'.png')))
   self.assertEqual(original.tobytes(),recombined.tobytes(),id)
 def test_bridge_is_required_for_every_destination(self):
  d=v.compile_layout();self.assertTrue(v.nav(d)[1]['allConnected']);self.assertFalse(any(v.nav(d,True)[1]['targets'].values()))
 def test_ground_annotation_and_painted_pixels_share_placement(self):
  d=v.compile_layout()
  for b in d['buildings']:
   if b.get('prop'):continue
   for src,dst in zip(v.HOUSES[b['id']]['polygons'],b['polygons']):
    reconstructed=np.array(dst)*[32,-32]-np.array(b['position'])*[32,-32]+b['anchorPixels']
    self.assertTrue(np.allclose(src,reconstructed),b['id'])
 def test_planning_does_not_change_approved_sources(self):
  before={p:v.sha(p) for p in (v.E/'SourceV1').rglob('*.aseprite')};a=v.compile_layout();b=v.compile_layout();self.assertEqual(a,b);self.assertEqual(before,{p:v.sha(p) for p in before})
 def test_bridge_rails_match_the_inner_water_opening(self):
  d=v.compile_layout();bridge=next(p for p in d['pieces'] if p['id']=='bridge');left=next(p for p in bridge['parts'] if p['id']=='left-rail')['polygons'][0];right=next(p for p in bridge['parts'] if p['id']=='right-rail')['polygons'][0];water_left=next(p for p in d['physical'] if p['id']=='water-west');water_right=next(p for p in d['physical'] if p['id']=='water-east')
  self.assertAlmostEqual(max(p[0] for p in left),max(p[0] for p in water_left['polygon']));self.assertAlmostEqual(min(p[0] for p in right),min(p[0] for p in water_right['polygon']))

if __name__=='__main__':unittest.main()
