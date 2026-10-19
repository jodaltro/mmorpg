import unittest, json, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
import playable_village01 as village

class VillageTests(unittest.TestCase):
    def test_layout_deterministic(self):
        self.assertEqual(village.layout(),village.layout())
    def test_unique_ids(self):
        data=village.layout()
        for key in ('physical','props','buildings'):
            ids=[v['id'] for v in data[key]];self.assertEqual(len(ids),len(set(ids)))
    def test_gate_and_bridge_only_access(self):
        data=village.layout();_,opened=village.navigation(data);_,closed=village.navigation(data,False)
        self.assertTrue(opened['connected']);self.assertFalse(closed['connected'])
    def test_sources_untouched_and_manifest(self):
        out=village.BASE/'BuildV4';manifest=village.read(out/'manifest.json')
        for name,sha in manifest['files'].items():self.assertEqual(village.sha(out/name),sha,name)
        for b in village.read(out/'layout.json')['buildings']:
            source=village.read(village.ROOT/b['export'])['source']
            self.assertEqual(village.sha(village.ROOT/source['path']),source['sha256'])
    def test_water_alpha_stable_and_loop_has_motion(self):
        out=village.BASE/'BuildV4';frames=[np.array(Image.open(out/f'river-{f}.png')) for f in range(4)]
        for image in frames:self.assertTrue(np.array_equal(image[:,:,3],frames[0][:,:,3]))
        self.assertEqual(len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}),4)
    def test_physical_coverage_river_extremities(self):
        data=village.layout();water=[p for p in data['physical'] if p['kind']=='water']
        self.assertEqual(min(x for p in water for x,y in p['polygon']),0)
        self.assertEqual(max(x for p in water for x,y in p['polygon']),village.W)
        self.assertEqual(data['bridgeClearance'][0:3:2],[53,59])
    def test_ground_chunk_coverage(self):
        data=village.read(village.BASE/'BuildV4/layout.json');area=sum(c['rect'][2]*c['rect'][3] for c in data['groundChunks'])
        self.assertEqual(area,village.W*village.H*32*32)
        for c in data['groundChunks']:
            with Image.open(village.BASE/'BuildV4'/c['file']) as im:self.assertEqual(im.size,tuple(c['rect'][2:]))
    def test_buildings_do_not_share_physical_occupancy(self):
        from PIL import ImageDraw
        data=village.layout();masks=[]
        for b in data['buildings']:
            image=Image.new('1',(448,576));d=ImageDraw.Draw(image)
            for p in data['physical']:
                if p['id'].startswith(b['id']+'-'):d.polygon([(round(x*4),round(y*4)) for x,y in p['polygon']],fill=1)
            mask=np.array(image)
            for old in masks:self.assertFalse(np.any(old&mask),b['id'])
            masks.append(mask)
    def test_contextual_stamp_iteration_matches_ground11(self):
        from PIL import ImageDraw
        import ground_finish11 as g
        coverage=Image.new('L',(256,128));ImageDraw.Draw(coverage).rectangle((0,40,255,88),fill=255);c=np.array(coverage)
        sd=g.distance_transform_edt(c>127)-g.distance_transform_edt(c<=127);recipe=village.read(village.ROOT/'ArtSource/Labs/World2026/Ground11/recipe.json')
        a=Image.new('RGBA',(90,80),(90,110,50,255));b=a.copy();bounds=[80,20,90,80]
        g.stamps(a,bounds,c,sd,recipe,False,sites=[]);village.local_stamps(b,bounds,c,sd,recipe,False,sites=[])
        self.assertTrue(np.array_equal(a,b))
    def test_aseprite_reexport_pixels(self):
        import tempfile
        import village_structures01 as s
        with tempfile.TemporaryDirectory() as folder:
            out=Path(folder)/'fresh';s.export(out)
            for p in out.glob('*.png'):
                with Image.open(p) as a,Image.open(village.BASE/'ExportStructuresV2'/p.name) as b:self.assertTrue(np.array_equal(a,b),p.name)

if __name__=='__main__':unittest.main()
