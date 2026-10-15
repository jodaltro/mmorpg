"""Fast artifact QA only; does not run gameplay test suites."""
from pathlib import Path
from collections import Counter
import json,hashlib
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
inventory=json.loads((ROOT/'Docs/Art/Audit/inventory.json').read_text())
manifest=json.loads((ROOT/'Assets/Mmorpg/Art/Processed/manifest.json').read_text())
report={'originals':[], 'frames':len(manifest['entries']), 'by_actor':dict(Counter(e['actor'] for e in manifest['entries'])),'failures':[],'walk_feet':{}}
for r in inventory:
    match=hashlib.sha256((ROOT/r['file']).read_bytes()).hexdigest()==r['sha256']
    report['originals'].append({'file':r['file'],'sha256_unchanged':match})
    if not match:report['failures'].append('Original modified: '+r['file'])
for e in manifest['entries']:
    im=Image.open(ROOT/e['output']);a=np.asarray(im)[:,:,3]
    if im.mode!='RGBA' or list(im.size)!=e['canvas'] or e['clipped']:report['failures'].append('Canvas '+e['name'])
    if not im.getbbox():report['failures'].append('Empty '+e['name'])
    if any(p<0 or p>1 for p in e['pivot']):report['failures'].append('Pivot '+e['name'])
    if np.any((a>0)&(a<=7)):report['failures'].append('Low alpha noise '+e['name'])
    if e['actor']=='Hero' and e['animation']=='walk':report['walk_feet'][e['name']]=e['bounds'][3]-e['anchor'][1]
if set(report['walk_feet'].values())!={1}:report['failures'].append('Hero feet baseline differs')
report['notes']=['Foot metric uses bottom exclusive of reviewed body-only bounds.','Prepared creature expansion is not approved by this structural QA.','Original SHA baseline is from the initial audit, not regenerated here.']
(ROOT/'Docs/Art/Audit/processed-qa.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
raise SystemExit(bool(report['failures']))
