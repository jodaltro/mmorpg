import unittest,json,struct
from pathlib import Path
import numpy as np
from PIL import Image
import village02_anime_art as art
import village02_integration as base

class AnimeContract(unittest.TestCase):
 def test_sources_exports_and_single_frame_canvases(self):
  catalog=art.read(art.BASE/'ExportV2/catalog.json')
  self.assertEqual(15,len(catalog['assets']))
  for a in catalog['assets']:
   source=art.ROOT/a['source'];self.assertEqual(a['sourceSHA256'],art.sha(source));self.assertEqual(a['compositeSHA256'],art.sha(art.ROOT/a['composite']))
   header=source.read_bytes()[:16];self.assertEqual((0xA5E0,1,*a['canvas']),struct.unpack_from('<HHHH',header,4))
   native=source.parent/'native-authority.png';self.assertEqual(Image.open(native).tobytes(),Image.open(art.ROOT/a['composite']).tobytes())
   self.assertEqual({0,255},set(np.unique(np.array(Image.open(native))[:,:,3])))
 def test_actual_registered_lower_silhouettes(self):
  # Actual exported pixel coverage catches accidental numbered-PNG sequence
  # loading that changes canvas width before the source is uniformly resized.
  for id,r in art.read(art.BASE/'registration.json').items():
   if id=='fountain':continue
   reference=np.array(Image.open(art.OLD/'ExportV1'/id/'composite.png'))[:,:,3]>0
   actual=np.array(Image.open(art.BASE/'ExportV2'/id/'composite.png'))[:,:,3]>0
   px,py,_,_=r['padding'];h,w=reference.shape;actual=actual[py:py+h,px:px+w];weights=np.where(np.arange(h)[:,None]>h*.55,4.,.3)
   iou=np.sum(weights*(actual&reference))/np.sum(weights*(actual|reference));self.assertGreater(iou,.90,(id,iou))
 def test_opaque_partitions_recompose_without_pixel_changes(self):
  d=art.read(art.BASE/'IntegrationV2/layout.json')
  for piece in d['pieces']:
   im=Image.new('RGBA',tuple(piece['canvas']))
   for p in piece['parts']:im.alpha_composite(Image.open(art.BASE/'IntegrationV2/DepthArt'/piece['id']/(p['id']+'.png')))
   self.assertEqual(im.tobytes(),Image.open(art.BASE/'ExportV2'/piece['id']/'composite.png').tobytes())
 def test_new_conical_slate_has_opaque_ownership(self):
  records=art.read(art.BASE/'IntegrationV2/ownership-corrections.json')
  for r in records:
   self.assertEqual(0,r['unassignedCapSlatePixels']);self.assertTrue(r['rgbAndAlphaUnchanged'])
  self.assertGreater(next(r for r in records if r['id']=='castle-compound')['ownershipPixelsChanged'],0)
 def test_original_geometry_and_new_garden_are_explicit(self):
  d=art.read(art.BASE/'IntegrationV2/layout.json');old=art.read(base.BASE/'IntegrationV2/layout.json');self.assertEqual(old['physical'],d['physical'][:120]);self.assertEqual(123,len(d['physical']));self.assertEqual(3,len(d['garden']));self.assertEqual(14,len(d['flowers']))
  self.assertEqual(art.read(art.BASE/'IntegrationV1/layout.json')['physical'],d['physical'])
  for item in d['garden']:self.assertEqual(item['polygon'],next(p['polygon'] for p in d['physical'] if p['id']==item['id']))
 def test_garden_keeps_all_destinations_and_bridge_required(self):
  d=art.read(art.BASE/'IntegrationV2/layout.json');self.assertTrue(base.nav(d)[1]['allConnected']);self.assertFalse(any(base.nav(d,True)[1]['targets'].values()))
 def test_garden_flower_source_matches_export(self):
  a=art.BASE/'GardenSourceV1/daisies/native-authority.png';b=art.BASE/'GardenExportV1/daisies/composite.png';self.assertEqual((64,48),Image.open(b).size);self.assertEqual(Image.open(a).tobytes(),Image.open(b).tobytes())

if __name__=='__main__':unittest.main()
