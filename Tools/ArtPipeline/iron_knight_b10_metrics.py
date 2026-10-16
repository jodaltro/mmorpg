"""Measure manually identified sole patches against real rendered-root telemetry."""
from pathlib import Path
import json,math,statistics
BASE=Path('Docs/Validation/Marco06B10');tracks=json.load(open('ArtSource/Labs/IronKnight2026/B10/foot-review.json'))['tracks'];names=['south','west','north','east'];vectors=[(0,-1),(-1,0),(0,1),(1,0)]
def dist(a,b):return math.hypot(b[0]-a[0],b[1]-a[1])
report={'method':'Fixed manually identified sole patch per view and explicitly marked stance windows. World=root+(sole-pivot)/32. No alpha-bound tracking. Low-confidence north estimate is not a foot-lock claim. Held-frame root drift and inter-frame changes are separate.','versions':{}}
for version in ['baseline','candidate']:
 p=BASE/version/'foot-trace.json'
 if not p.exists():continue
 rows=json.loads(p.read_text())['rows'];vr={}
 for d,name in enumerate(names):
  trace=[r for r in rows if r['direction']==d and r['state']=='walk' and math.hypot(*r['velocity'])>3.4];track=tracks[name];lo,hi=track['stance'];segments=[];seg=[];held=[];last=None
  for r in trace:
   r['index']=int(r['source'].rsplit('frame',1)[-1]);i=r['index'];point=track['points'][i]
   if point is not None and lo<=i<=hi:
    r['soleWorld']=[r['position'][0]+(point[0]-128)/32,r['position'][1]+(114-point[1])/32]
    if seg and (i<seg[-1]['index'] or r['time']-seg[-1]['time']>.04):segments.append(seg);seg=[]
    seg.append(r)
   elif seg:segments.append(seg);seg=[]
   last=r
  if seg:segments.append(seg)
  allgroups=[];group=[]
  for r in trace:
   if group and (r['index']!=group[-1]['index'] or r['time']-group[-1]['time']>.04):allgroups.append(group);group=[]
   group.append(r)
  if group:allgroups.append(group)
  for g in allgroups:
   if len(g)>1 and g[0]['index']!=trace[0]['index'] and g[-1]['index']!=trace[-1]['index']:held.append({'frame':g[0]['index'],'secondsObserved':g[-1]['time']-g[0]['time'],'rootDriftPx':32*dist(g[0]['position'],g[-1]['position'])})
  measured=[]
  for g in segments:
   if not g or g[0]['index']!=lo or g[-1]['index']!=hi:continue
   first=next((r for r in g if r['index']==lo),g[0]);last=next((r for r in g if r['index']==hi),g[-1]);axis=vectors[d];delta=[(last['soleWorld'][k]-first['soleWorld'][k])*32 for k in [0,1]]
   measured.append({'fromFrame':lo,'toFrame':hi,'seconds':last['time']-first['time'],'rootTravelPx':32*dist(first['position'],last['position']),'soleDisplacementPx':dist(first['soleWorld'],last['soleWorld'])*32,'signedForwardSoleDriftPx':sum(delta[k]*axis[k] for k in [0,1]),'samples':len(g)})
  vr[name]={'confidence':track['confidence'],'stance':track['stance'],'renderSamples':len(trace),'stanceMeasurements':measured,'heldFrameSamples':held,'meanHeldFrameRootDriftPx':statistics.mean([h['rootDriftPx'] for h in held]) if held else None,'maximumHeldFrameRootDriftPx':max([h['rootDriftPx'] for h in held],default=None)}
 report['versions'][version]=vr
(BASE/'cadence-report.json').write_text(json.dumps(report,indent=2))
for version,dirs in report['versions'].items():
 for name,r in dirs.items():print(version,name,'held mean',r['meanHeldFrameRootDriftPx'],'stance',r['stanceMeasurements'])
# Explicit selected-clip clocks derived from captured confirmed progress, using the unchanged animator formula.
ART=Path('ArtSource/Labs/IronKnight2026');manifests={'baseline':json.loads((ART/'manifest.json').read_text()),'candidate':json.loads((ART/'B10/manifest.json').read_text())};clocks=[]
for version,manifest in manifests.items():
    samples={r['name']:r for r in map(json.loads,(BASE/version/'capture-metadata.jsonl').read_text('utf-8-sig').splitlines())}
    for r in samples.values():
        action='attack' if r['state'].startswith('attack') else 'walk' if r['state']=='walk' else 'idle'
        direction={'(0.00, -1.00)':'south','(-1.00, 0.00)':'west','(0.00, 1.00)':'north','(1.00, 0.00)':'east'}[r['visual']]
        clip=next(c for c in manifest['clips'] if c['animation']==action and c['direction']==direction);frames=clip['frames'];selected=action
        if action=='attack' and 'phaseRanges' in manifest and r['phase'] in ['preparation','cut','recovery']:
            lo,hi=manifest['phaseRanges'][direction][r['phase']];duration=sum(f['duration'] for f in frames[lo:hi+1]);clock=r['phaseProgress']*max(0,duration-.00001);selected='attack-'+r['phase']
        elif action=='attack':duration=sum(f['duration'] for f in frames);clock=r['attackProgress']*max(0,duration-.00001)
        else:duration=sum(f['duration'] for f in frames);clock=r['clipTime']%duration if action=='walk' else 0
        clocks.append({'version':version,'capture':r['name'],'unityFrame':r['frame'],'source':r['source'],'selectedClip':selected,'selectedClipSeconds':clock,'clipDurationSeconds':duration,'method':'walk from recorded walk clock; attack derived from recorded confirmed progress and runtime manifest; idle index-zero pose'})
(BASE/'clip-clock-report.jsonl').write_text('\n'.join(json.dumps(r) for r in clocks)+'\n')
