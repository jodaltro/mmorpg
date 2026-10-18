"""Directed tests for the single authored reference; these do not approve its art."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

import architecture07r_reference as ref

REGION = ref.ROOT / 'ArtSource/Labs/World2026/WorldStudio07R/RegionV1'


class AuthoredReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = Path(tempfile.mkdtemp(prefix='architecture07r-', dir=ref.ROOT / 'Temp'))
        cls.house = ref.read(REGION / 'house.json')
        cls.meta = ref.read(ref.SOURCE / 'house-source.json')
        cls.source_hash = ref.common.sha((ref.SOURCE / 'rural-reference.aseprite').read_bytes())

    def test_01_manifests_and_upstream_inputs(self):
        for folder in [REGION, ref.EXPORT, REGION / 'Vegetation']:
            ref.arch.verify_files(folder)

    def test_02_layer_composite_is_authored_palette_pixels(self):
        im = Image.open(ref.EXPORT / 'composite.png').convert('RGBA')
        expected = Image.open(ref.SOURCE.parent / 'ArtDirection/palette-study-128.png').convert('RGBA')
        self.assertEqual(im.tobytes(), expected.tobytes())
        combined = Image.new('RGBA', im.size)
        for name in self.meta['layers']:
            combined = Image.alpha_composite(combined, Image.open(ref.EXPORT / (name + '.png')).convert('RGBA'))
        self.assertEqual(combined.tobytes(), im.tobytes())
        self.assertLessEqual(len(im.getcolors(im.width * im.height)), 128)

    def test_03_imported_parts_are_exact_exports(self):
        art = ref.ROOT / 'Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture07R'
        for part in ref.read(ref.EXPORT / 'export.json')['parts']:
            self.assertEqual((art / (part['id'] + '.png')).read_bytes(), (ref.EXPORT / part['trimmed']).read_bytes())

    def test_04_footprint_navigation_and_access(self):
        ctx = ref.veg.Context()
        nav = ref.read(REGION / 'navigation.json')
        occupied = ref.arch.mask_polygon(self.house['footprint'], ctx)
        self.assertEqual(occupied.ravel().tolist(), nav['architectureBlocked'])
        walk = np.array(nav['walkable']).reshape(192, 256)
        self.assertFalse(np.any(walk & occupied))
        clearance = distance_transform_edt(walk) * .25
        for x, y in self.house['access']['points']:
            self.assertGreaterEqual(clearance[int(y * 4), int(x * 4)], .57)

    def test_05_door_recalibrated_to_real_protagonist(self):
        actor = ref.read(ref.ROOT / 'Docs/Validation/ValdoriaWorldStudio07/Final/quaternius-scale.json')
        height = self.house['doorHeightUnits']
        self.assertNotEqual(height, 5)
        self.assertGreater(height, actor['visibleBodyHeightUnits'])
        self.assertLess(height / actor['visibleBodyHeightUnits'], 1.12)

    def test_06_existing_destinations_refused(self):
        with self.assertRaises((FileExistsError, ValueError)):
            ref.export(ref.SOURCE, ref.EXPORT)
        with self.assertRaises((FileExistsError, ValueError)):
            ref.build(REGION)

    def test_07_region_repeat_has_identical_semantics_and_pixels(self):
        out = self.work / 'repeated-region'
        result = ref.build(out)
        self.assertEqual(result, self.house)
        for file in ['navigation.json', 'vegetation.json', 'exclusions.json', 'access.png', 'access-render.json']:
            self.assertEqual((out / file).read_bytes(), (REGION / file).read_bytes(), file)
        ref.arch.verify_files(out)
        ref.arch.verify_files(out / 'Vegetation')

    def test_08_export_reads_actual_aseprite_edit_without_redrawing(self):
        copy = self.work / 'edited-source'
        shutil.copytree(ref.SOURCE, copy)
        pixels = np.array(Image.open(ref.EXPORT / 'Door.png').convert('RGBA'))
        y, x = np.argwhere(pixels[:, :, 3] > 200)[0]
        lua = self.work / 'edit.lua'
        lua.write_text('local s=app.open(app.params["source"]);local im=s.layers["Door"]:cel(1).image;'
                       f'local old=im:getPixel({x},{y});im:drawPixel({x},{y},app.pixelColor.rgba(255,0,255,255));'
                       's:saveAs(app.params["source"]);s:close()')
        subprocess.run([r'D:\Aseprite\Aseprite.exe', '-b', '--script-param',
                        'source=' + str(copy / 'rural-reference.aseprite'), '--script', str(lua)], check=True)
        out = self.work / 'edited-export'
        ref.export(copy, out)
        self.assertEqual(Image.open(out / 'Door.png').getpixel((int(x), int(y))), (255, 0, 255, 255))
        self.assertNotEqual((out / 'composite.png').read_bytes(), (ref.EXPORT / 'composite.png').read_bytes())
        self.assertEqual(ref.common.sha((ref.SOURCE / 'rural-reference.aseprite').read_bytes()), self.source_hash)


if __name__ == '__main__':
    unittest.main(verbosity=2)
