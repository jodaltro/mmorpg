"""Acquire only CC0 model/animation data, never execute third-party repository scripts.

Author licensing is verified separately. Pinned public mirror is used because the
official free itch.io download failed locally (browser timeout / HTTP 429).
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
from urllib.parse import quote, unquote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'ArtSource/Labs/Humanoid2026'
REPO = 'NafisRayan/Animate-Rigged-Humanoid-No-Blender'
COMMIT = '5821923af517ac5fdc82505faa92a0d575fc1b1a'
PREFIX = 'Universal Base Characters[Standard]/Universal Base Characters[Standard]/'
MODELS = PREFIX + 'Base Characters/Godot - UE/'
ANIM = 'Universal Animation Library[Standard]/Universal Animation Library[Standard]/'


def fetch(path):
    request = Request('https://raw.githubusercontent.com/' + REPO + '/' + COMMIT + '/' + quote(path),
                      headers={'User-Agent': 'Mmorpg-CC0-asset-study'})
    with urlopen(request, timeout=45) as response:
        return response.read()


def main():
    with urlopen(Request('https://api.github.com/repos/' + REPO + '/git/trees/' + COMMIT + '?recursive=1',
                         headers={'User-Agent': 'Mmorpg-CC0-asset-study'}), timeout=30) as response:
        tree = {p['path']: p for p in json.load(response)['tree'] if p['type'] == 'blob'}
    records = []

    def acquire(remote, local):
        blob = fetch(remote)
        git_hash = hashlib.sha1(b'blob ' + str(len(blob)).encode() + b'\0' + blob).hexdigest()
        assert git_hash == tree[remote]['sha'], 'Mirror blob integrity mismatch'
        destination = LAB / local
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            assert destination.read_bytes() == blob, 'Refusing to replace edited source'
        else:
            destination.write_bytes(blob)
        return dict(file=local, mirrorPath=remote, gitBlob=git_hash,
                    sha256=hashlib.sha256(blob).hexdigest(), bytes=len(blob))

    dependencies = {}
    for sex in ['Male', 'Female']:
        filename = 'Superhero_' + sex + '_FullBody.gltf'
        records.append(acquire(MODELS + filename, 'Sources/BaseModels/' + filename))
        doc = json.loads((LAB / 'Sources/BaseModels' / filename).read_text())
        for resource in doc.get('buffers', []) + doc.get('images', []):
            name = unquote(resource['uri'])
            assert Path(name).name == name
            remote = MODELS + name
            if remote not in tree:
                # Known author-export filename suffix issue; store the alias without modifying the glTF.
                remote = MODELS + name.replace('_png.png', '.png')
            assert remote in tree, 'Missing source dependency: ' + name
            dependencies['Sources/BaseModels/' + name] = remote
    dependencies['Sources/Animations/UAL1_Standard.glb'] = ANIM + 'Unreal-Godot/UAL1_Standard.glb'
    dependencies['Sources/License-BaseCharacters.txt'] = PREFIX + 'License_Standard.txt'
    dependencies['Sources/License-Animations.txt'] = ANIM + 'License.txt'
    with ThreadPoolExecutor(max_workers=4) as pool:
        records += list(pool.map(lambda pair: acquire(pair[1], pair[0]), dependencies.items()))
    provenance = dict(license='CC0-1.0', author='Quaternius',
        officialModels='https://quaternius.itch.io/universal-base-characters',
        officialAnimations='https://quaternius.itch.io/universal-animation-library',
        retrieval='Pinned public mirror; official browser download timed out and HTTP returned 429',
        mirror='https://github.com/' + REPO, mirrorCommit=COMMIT,
        changes='Model/animation blobs unchanged; missing _png normal-map URI aliases copied from matching original textures',
        files=sorted(records, key=lambda r: r['file']))
    (LAB / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(files=len(records), bytes=sum(r['bytes'] for r in records),
                          mirrorCommit=COMMIT, license='CC0-1.0')))


if __name__ == '__main__':
    main()
