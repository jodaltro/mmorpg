"""Verify preservation against the read-only B13 audit; never write personal hashes to evidence."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'Docs/Validation/Marco06B13'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    before=json.loads((EVIDENCE/'official-before.json').read_text(encoding='utf-8-sig'))
    changed=[p for p,h in before.items() if sha(ROOT/p)!=h]
    personal=json.loads((ROOT/'Temp/Marco06B13-personal-before.json').read_text(encoding='utf-8-sig'))
    personal_changed=sum(sha(Path(p))!=h for p,h in personal.items())
    manifest=json.loads((ROOT/'ArtSource/Characters/IronKnight/manifest.json').read_text(encoding='utf-8-sig'))
    sources={f['png']:f['sha256'] for clip in manifest['clips'] for f in clip['frames']}
    source_changed=[p for p,h in sources.items() if sha(ROOT/p)!=h]
    production=(ROOT/'Assets/Mmorpg/Art/Production/IronKnight/IronKnight.asset').read_text(encoding='utf-8-sig')
    clips=len(re.findall(r'^  - action:',production,re.M))
    sprites=re.findall(r'^    - sprite: (.+)$',production,re.M)
    report=dict(officialFilesCompared=len(before),officialFilesChanged=changed,
                approvedSourceFramesCompared=len(sources),approvedSourceFramesChanged=source_changed,
                sourceClips=len(manifest['clips']),productionClips=clips,productionFrameEntries=len(sprites),
                productionUniqueSprites=len(set(sprites)),personalFilesCompared=len(personal),
                personalFilesChanged=personal_changed,personalHashesPublished=False,
                experimentalSceneCreated=(ROOT/'Assets/Mmorpg/Scenes/Marco06B13Npcs.unity').exists())
    (EVIDENCE/'preservation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    assert not changed and not source_changed and personal_changed==0
    assert clips==36 and len(set(sprites))==264 and len(sprites)==324 and len(sources)==264 and not report['experimentalSceneCreated']
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
