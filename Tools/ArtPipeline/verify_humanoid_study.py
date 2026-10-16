"""Source integrity and Aseprite roundtrip checks for the larger-body study."""
import hashlib
import json
import struct
import subprocess
import tempfile
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
LAB=ROOT/'ArtSource/Labs/Humanoid2026'


def main():
    provenance=json.loads((LAB/'provenance.json').read_text())
    for record in provenance['files']:
        assert hashlib.sha256((LAB/record['file']).read_bytes()).hexdigest()==record['sha256']
    raw=(LAB/'Sources/Animations/UAL1_Standard.glb').read_bytes()
    size=struct.unpack_from('<I',raw,12)[0];animations=json.loads(raw[20:20+size])
    names=[a['name'] for a in animations['animations']]
    required=['Idle_Loop','Walk_Loop','Sword_Attack','Roll','Hit_Chest','Death01']
    assert len(names)==43 and all(name in names for name in required)
    results={}
    with tempfile.TemporaryDirectory(dir=ROOT/'Temp/HumanoidResearch') as work:
        for sex in ['Male','Female']:
            source=json.loads((LAB/f'Sources/BaseModels/Superhero_{sex}_FullBody.gltf').read_text())
            joints=[source['nodes'][i]['name'] for i in source['skins'][0]['joints']]
            assert len(joints)==65 and all(j in [n.get('name') for n in animations['nodes']] for j in joints)
            sheet=Path(work)/(sex+'.png');meta=Path(work)/(sex+'.json')
            subprocess.run(['D:/Aseprite/Aseprite.exe','-b',str(LAB/f'Preview/{sex}/{sex}.aseprite'),'--sheet',str(sheet),'--list-tags','--data',str(meta),'--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
            image=Image.open(sheet).convert('RGBA');doc=json.loads(meta.read_text());expected=json.loads((LAB/'Preview/qa.json').read_text())[sex]
            assert len(doc['frames'])==52 and len(doc['meta']['frameTags'])==8
            for i,f in enumerate(doc['frames']):
                r=f['frame'];frame=image.crop((r['x'],r['y'],r['x']+128,r['y']+160))
                assert hashlib.sha256(frame.tobytes()).hexdigest()==expected['frameHashes'][i]
            results[sex]=dict(joints=65,matchedAnimationJoints=65,frames=52,clips=8,asepriteRoundtripPixelsIdentical=True)
    report=dict(sourceFilesVerified=len(provenance['files']),sourceBytesUnchanged=True,
                availableProfessionalAnimations=43,requiredClipNamesFound=required,characters=results,
                productionMigration=False,largerBodiesTestedInUnity=False)
    (LAB/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
