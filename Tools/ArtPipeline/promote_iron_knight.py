"""Prepare an official manifest from approved B10/B11 sources; no redraw."""
from pathlib import Path
import copy, hashlib, json

root=Path('ArtSource/Characters/IronKnight')
if root.exists():raise FileExistsError('Refusing to overwrite official art sources')
paths=[Path('ArtSource/Labs/IronKnight2026/B10/manifest.json'),Path('ArtSource/Labs/IronKnight2026/B11/manifest.json')]
b10,b11=[json.loads(p.read_text(encoding='utf-8')) for p in paths]
assert b11['userArtisticApproval']['newStates']['status']=='approved'
manifest=copy.deepcopy(b10)
manifest.update(schema='iron-knight-production-v1',id='IronKnight',status='official protagonist; B10 and B11 artwork approved by user',clips=copy.deepcopy(b10['clips']+b11['clips']))
manifest.pop('baseCharacterSet',None)
manifest['productionProvenance']=[{'manifest':p.as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
manifest['newStatesApproval']=b11['userArtisticApproval']['newStates']
manifest['timingPolicy']=b11['timingPolicy']
manifest['sourcePolicy']='Approved PNGs and Aseprite documents remain in immutable review directories. Official runtime sheets are independently imported; no experimental asset dependency.'
assert len(manifest['clips'])==24
for c in manifest['clips']:
 assert Path(c['sheet']).is_file()
 for f in c['frames']:
  assert Path(f['png']).is_file()
  if 'sha256' in f:assert hashlib.sha256(Path(f['png']).read_bytes()).hexdigest()==f['sha256']
root.mkdir(parents=True)
(root/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode('utf-8'))
print('Official manifest: 24 authored clips plus 12 shared phase clips, unchanged approved data.')
