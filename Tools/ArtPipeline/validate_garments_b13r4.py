"""R4 result regressions for two calibrated bodies; requires local Aseprite."""
import argparse
import json
import subprocess
import sys
import uuid
from pathlib import Path
from PIL import Image
from generate_garments_b13r3 import load_input

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'ArtSource/Labs/NpcResearch/Marco06B13R4'


def atlas(folder):
    doc = json.loads((folder / 'aseprite.json').read_text())
    image = Image.open(folder / 'spritesheet.png').convert('RGBA')
    return [image.crop((f['frame']['x'], f['frame']['y'], f['frame']['x'] + 64,
                        f['frame']['y'] + 64)) for f in doc['frames']]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aseprite', default='D:/Aseprite/Aseprite.exe')
    args = parser.parse_args()
    temp = ROOT / 'Temp/Marco06B13R4' / ('checks-' + uuid.uuid4().hex)
    temp.mkdir(parents=True)
    generator = ROOT / 'Tools/ArtPipeline/generate_garments_b13r3.py'

    def generate(config, recipe, output):
        subprocess.run([sys.executable, str(generator), '--aseprite', args.aseprite,
                        '--character-config', str(config), '--recipe', str(recipe),
                        '--output', str(output)], capture_output=True, check=True)

    reports = {}
    for character, outfit, recipe_name in [('Mira', 'MiraHealer', 'mira_healer'), ('Orin', 'OrinTracker', 'orin_tracker')]:
        config_path = LAB / 'Calibrations' / (character + '.json')
        config, source_manifest, source, poses = load_input(config_path)
        folder = LAB / 'Results' / outfit
        recipe_path = LAB / 'Recipes' / (recipe_name + '.json')
        repeat = temp / (character + '-repeat')
        generate(config_path, recipe_path, repeat)
        expected, actual = atlas(folder), atlas(repeat)
        assert len(expected) == len(actual) == 44
        assert all(a.tobytes() == b.tobytes() for a, b in zip(expected, actual))
        proc = subprocess.run([sys.executable, str(generator), '--character-config', str(config_path),
                               '--recipe', str(recipe_path), '--output', str(repeat)], capture_output=True)
        assert proc.returncode != 0
        subprocess.run([args.aseprite, '-b', str(source), '--sheet', str(temp / (character + '-base.png')),
                        '--data', str(temp / (character + '-base.json')), '--format', 'json-array',
                        '--sheet-type', 'rows', '--sheet-columns', '8'], capture_output=True, check=True)
        base_image = Image.open(temp / (character + '-base.png')).convert('RGBA')
        base_doc = json.loads((temp / (character + '-base.json')).read_text())
        base = []
        for f in base_doc['frames']:
            r = f['frame']; base.append(base_image.crop((r['x'], r['y'], r['x'] + 64, r['y'] + 64)))
        profile_indices = [i for i, p in enumerate(poses) if p['direction'] in ['west', 'east']]
        protected = feet = 0
        for index in profile_indices:
            for y in range(poses[index]['headBounds'][3], 64):
                for x in range(64):
                    pixel = base[index].getpixel((x, y))
                    if pixel[3] == 255:
                        assert pixel == actual[index].getpixel((x, y)), f'{character} profile body erased: {index}, {x}, {y}'
                        protected += 1
        for index in range(44):
            for y in range(59, 64):
                for x in range(64):
                    pixel = base[index].getpixel((x, y))
                    if pixel[3] == 255:
                        assert pixel == actual[index].getpixel((x, y)), 'Foot pixels changed'
                        feet += 1
        probe = temp / (character + '-backpack')
        generate(config_path, LAB / 'Recipes' / (character.lower() + '_backpack_probe.json'), probe)
        pack = atlas(probe); protected_pack = 0; visibility = {}
        for index in profile_indices:
            for a, b in zip(base[index].get_flattened_data(), pack[index].get_flattened_data()):
                if a[3] == 255:
                    assert a == b, 'Backpack hid arm/body'
                    protected_pack += 1
        for direction in ['north', 'west', 'south', 'east']:
            index = next(i for i, p in enumerate(poses) if p['direction'] == direction)
            visibility[direction] = sum(a != b and (a[3] or b[3]) > 0 for a, b in
                                        zip(base[index].get_flattened_data(), pack[index].get_flattened_data()))
        assert visibility['south'] == 0 and all(visibility[d] > 0 for d in ['north', 'west', 'east'])
        variant = json.loads(recipe_path.read_text())
        variant['name'] = character + 'GeometryCheck'
        variant['components'][0]['length'] -= 4
        variant['components'][2 if character == 'Orin' else 4]['length'] += 6
        variant_path = temp / (character + '-variant.json')
        variant_path.write_text(json.dumps(variant), encoding='utf-8')
        variant_folder = temp / (character + '-variant')
        generate(config_path, variant_path, variant_folder)
        changes = sum(a.getchannel('A').tobytes() != b.getchannel('A').tobytes()
                      for a, b in zip(expected, atlas(variant_folder)))
        assert changes == 44, f'{character}: only {changes} silhouettes changed'
        qa = json.loads((repeat / 'qa.json').read_text())
        assert qa['originalLayersPreserved'] and qa['clippedFragments'] == 0
        assert all(f['duration'] == 125 for f in json.loads((repeat / 'aseprite.json').read_text())['frames'])
        reports[character] = dict(frames=44, clips=8, deterministic=True, canvas=config['canvas'],
            pivot=config['pivot'], feetReference=config['feet'], sourceLayersUnchanged=True,
            originalTimingsPreserved=True, profileFrames=22, profileBodyOpaquePixelsProtected=protected,
            allProfileBackpackOpaquePixelsProtected=protected_pack, backpackVisibility=visibility,
            footPixelsProtectedAcross44Frames=feet, geometryChangedFrames=changes,
            clippedGarmentFragments=0, overwriteRefused=True)
    # Explicit Mira calibration must still reproduce BOTH historical R3 reference recipes.
    legacy = {}
    for recipe_name, historical in [('mira_traveller', 'MiraTravellerCorrected'), ('mira_backpack', 'MiraBackpackFinal')]:
        out = temp / recipe_name
        generate(LAB / 'Calibrations/Mira.json', ROOT / ('Tools/ArtPipeline/garment_recipes/' + recipe_name + '.json'), out)
        a, b = atlas(ROOT / ('ArtSource/Labs/NpcResearch/Marco06B13R3/' + historical)), atlas(out)
        assert len(a) == len(b) == 44 and all(x.tobytes() == y.tobytes() for x, y in zip(a, b))
        legacy[recipe_name] = 44
    a = json.loads((LAB / 'Calibrations/Mira-poses.json').read_text())['poses']
    b = json.loads((LAB / 'Calibrations/Orin-poses.json').read_text())['poses']
    distinct = sum(x['shoulders'] != y['shoulders'] or x['waist'] != y['waist'] for x, y in zip(a, b))
    assert distinct > 0
    # Check malformed calibration fails before any output authoring.
    invalid = json.loads((LAB / 'Calibrations/Orin.json').read_text())
    invalid['pivot'] = [1000, 44]
    invalid_path = temp / 'invalid-config.json'; invalid_path.write_text(json.dumps(invalid))
    try:
        load_input(invalid_path)
        raise RuntimeError('Invalid pivot accepted')
    except AssertionError:
        pass
    report = dict(characters=reports, explicitMiraReproducesHistoricalFrames=legacy,
                  independentlyMeasuredAnchorDifferences=distinct, invalidPivotRejected=True,
                  bodyAnimationGenerated=False, clothSimulation=False, runtimeEquipment=False)
    evidence = ROOT / 'Docs/Validation/Marco06B13R4'
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'generator-checks.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
