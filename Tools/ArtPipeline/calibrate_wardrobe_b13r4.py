"""Measure the two existing LPC outfits independently; never author body pixels."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'ArtSource/Labs/NpcResearch/Marco06B13R4'


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(data, indent=2) + '\n')


def measure(character, outfit):
    source = ROOT / f'ArtSource/Labs/NpcResearch/Marco06B13R2/Wardrobe/{outfit}.aseprite'
    manifest_path = source.with_suffix('.json')
    manifest = json.loads(manifest_path.read_text())
    poses = []
    for clip in manifest['clips']:
        for index in range(clip['first'] - 1, clip['last']):
            parts = {part['layer']: part for part in manifest['frames'][index]['parts']}
            images = {}
            for layer in ['Head', 'Body', 'Shirt', 'Pants', 'Boots']:
                part = parts[layer]
                images[layer] = Image.open(ROOT / part['path']).convert('RGBA').crop(
                    (part['x'], part['y'], part['x'] + 64, part['y'] + 64))
            bounds = {name: list(image.getbbox()) for name, image in images.items()}
            head, body = bounds['Head'], bounds['Body']
            cx = (head[0] + head[2]) / 2
            if character == 'Mira':
                # Preserve the reviewed R3 attachment calibration, measured again on this base.
                shoulder = dict(x=cx, y=head[3] - 1)
                waist = dict(x=cx, y=head[3] + 11)
            else:
                # Orin's shoulder row is measured on his own shirt; waist on his pants.
                rows = []
                for y in range(bounds['Shirt'][1], head[3] + 3):
                    xs = [x for x in range(64) if images['Shirt'].getpixel((x, y))[3]]
                    if len(xs) >= 10:
                        rows.append((y, xs))
                y, xs = rows[0]
                shoulder = dict(x=(min(xs) + max(xs) + 1) / 2, y=y)
                pants = bounds['Pants']
                waist = dict(x=(pants[0] + pants[2]) / 2, y=pants[1] + 1)
            pose = dict(direction=clip['name'].split('_')[-1], action=clip['name'].split('_')[0],
                        sourceFrame=index, head=dict(x=cx, y=head[1] + 5), shoulders=shoulder,
                        waist=waist, headBounds=head, bodyBounds=body,
                        measuredBounds=bounds, measuredBootBottom=bounds['Boots'][3], feet=dict(x=32, y=62),
                        groundPivot=dict(x=32, y=44))
            assert 60 <= pose['measuredBootBottom'] <= 64
            assert body[1] - 2 <= shoulder['y'] < waist['y'] < body[3]
            poses.append(pose)
    assert len(poses) == 44
    relative = lambda path: path.relative_to(ROOT).as_posix()
    anchor_path = LAB / 'Calibrations' / (character + '-poses.json')
    write_new(anchor_path, dict(character=character, poses=poses,
                              measurement='Own source layers; Mira R3-reviewed landmarks; Orin shirt/pants landmarks'))
    config = dict(schema='wardrobe-character-v1', character=character, source=relative(source),
                  sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  poseManifest=relative(manifest_path), poseManifestSha256=hashlib.sha256(json.dumps(manifest,sort_keys=True,separators=(',',':')).encode()).hexdigest(),
                  anchors=relative(anchor_path), canvas=[64, 64], pivot=[32, 44], feet=[32, 62], ppu=32,
                  anatomicalLayers=['Body', 'Pants', 'Boots', 'Shirt', 'Head', 'Hair'],
                  license='OGA-BY-3.0; preserve LPC Revised credits')
    write_new(LAB / 'Calibrations' / (character + '.json'), config)
    return dict(character=character, source=config['source'], sourceSha256=config['sourceSha256'],
                poses=len(poses), shoulderRange=sorted(set(p['shoulders']['y'] for p in poses)),
                waistRange=sorted(set(p['waist']['y'] for p in poses)),
                bodyLayerSource=manifest['recipe']['base'])


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    print(json.dumps([measure('Mira', 'MiraIvory'), measure('Orin', 'OrinForest')], indent=2))


if __name__ == '__main__':
    main()
