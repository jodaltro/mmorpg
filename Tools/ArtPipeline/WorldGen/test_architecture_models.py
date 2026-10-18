"""Reference integrity and review-yard circulation; not artistic approval."""
import tempfile
import unittest
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import architecture07r_reference as ref
import architecture_models as models

ROOT=ref.ROOT/'ArtSource/Labs/World2026/WorldStudio08'


class ArchitectureModelsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work=Path(tempfile.mkdtemp(prefix='architecture-models-',dir=ref.ROOT/'Temp'))

    def test_01_signed_art_sources_and_builds(self):
        for kind,build in [('Barn','RegionV1'),('Castle','ReviewV1')]:
            for folder in [ROOT/kind/'ExportV1',ROOT/kind/build]:ref.arch.verify_files(folder)
        ref.arch.verify_files(ROOT/'Barn/RegionV1/Vegetation')

    def test_02_exact_editable_layer_recomposition(self):
        for kind in ['Barn','Castle']:
            folder=ROOT/kind;meta=ref.read(folder/'SourceV1/house-source.json')
            im=Image.new('RGBA',tuple(meta['canvas']))
            for name in meta['layers']:im=Image.alpha_composite(im,Image.open(folder/'ExportV1'/(name+'.png')).convert('RGBA'))
            self.assertEqual(im.tobytes(),Image.open(folder/'SourceV1/native-palette.png').convert('RGBA').tobytes())
            self.assertEqual(im.tobytes(),Image.open(folder/'ExportV1/composite.png').convert('RGBA').tobytes())
            self.assertLessEqual(len(im.getcolors(im.width*im.height)),128)

    def test_03_unity_uses_exact_exported_parts(self):
        for kind in ['Barn','Castle']:
            for part in ref.read(ROOT/kind/'ExportV1/export.json')['parts']:
                asset=ref.ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08'/kind/(part['id']+'.png')
                self.assertEqual(asset.read_bytes(),(ROOT/kind/'ExportV1'/part['trimmed']).read_bytes())

    def test_04_repeated_barn_preserves_geometry_and_ecology(self):
        expected=ref.read(ROOT/'Barn/RegionV1/house.json');out=self.work/'barn'
        self.assertEqual(ref.build(out,ROOT/'Barn/SourceV1',ROOT/'Barn/ExportV1',position=expected['position']),expected)
        for file in ['navigation.json','vegetation.json','exclusions.json','access.png']:
            self.assertEqual((out/file).read_bytes(),(ROOT/'Barn/RegionV1'/file).read_bytes())

    def test_05_repeated_castle_review_and_open_gate(self):
        expected=ref.read(ROOT/'Castle/ReviewV1/house.json');out=self.work/'castle'
        self.assertEqual(models.review_yard(ROOT/'Castle/SourceV1',ROOT/'Castle/ExportV1',out),expected)
        nav=ref.read(out/'navigation.json');walk=np.array(nav['walkable']).reshape(320,320)
        yy,xx=np.mgrid[:320,:320];blocked=np.zeros_like(walk)
        for poly in expected['footprints']:blocked|=ref.arch.inside(poly,(xx+.5)*.25,(yy+.5)*.25)
        self.assertTrue(np.array_equal(~walk,blocked))
        clear=distance_transform_edt(walk)*.25
        for a,b in zip(expected['courtyardRoute'],expected['courtyardRoute'][1:]):
            for t in np.linspace(0,1,50):
                x,y=np.array(a)*(1-t)+np.array(b)*t;self.assertGreaterEqual(clear[int(y*4),int(x*4)],.57)
        self.assertFalse(expected['siteQA']['worldLotAccepted'])
        self.assertEqual(len(expected['depthGroups']),5)

    def test_06_human_door_scale_and_overwrite_guards(self):
        actor=4.5703125
        for kind,build in [('Barn','RegionV1'),('Castle','ReviewV1')]:
            h=ref.read(ROOT/kind/build/'house.json')['doorHeightUnits']
            self.assertGreater(h,actor);self.assertLess(h/actor,1.12)
            with self.assertRaises((FileExistsError,ValueError)):ref.export(ROOT/kind/'SourceV1',ROOT/kind/'ExportV1')
            with self.assertRaises((FileExistsError,ValueError)):models.prepare(ROOT/kind/'design.json',ROOT/kind/'SourceV1')


if __name__=='__main__':unittest.main(verbosity=2)
