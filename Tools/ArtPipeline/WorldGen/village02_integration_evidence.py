"""Assemble receipts without rewriting captured images or raw test outcomes."""
from pathlib import Path
import json, hashlib, subprocess, sys

ROOT=Path(__file__).resolve().parents[3]
E=ROOT/'Docs/Validation/ValdoriaVillage02-Integration'
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(name,v):
 p=E/'QA'/name
 if p.exists():raise FileExistsError(p)
 p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
 images=[]
 for index in sorted(E.rglob('capture-index.json')):
  folder=index.parent.parent
  prefix=folder.relative_to(E).as_posix()
  if prefix=='.':prefix='interrupted-v1'
  for original in read(index)['images']:
   row=dict(original)
   name=Path(row['original']).stem
   pair=name.removesuffix('-before').removesuffix('-after')
   row['original']=(folder/row['original']).relative_to(E).as_posix()
   row['reviewName']=prefix.replace('/','-')+'-'+name+'.png'
   row['comparison']=prefix+':'+pair
   row['validationRun']=prefix
   images.append(row)
 assert len(images)==len(list(E.rglob('Original/*.png')))
 write('all-capture-index.json',{'images':images})
 raw=read(E/'FinalV2/QA/play-qa.json')
 corrections={r['id']:r for r in read(E/'ContactCorrections/QA/result.json')['results']}
 cardinal={r['id']:r for r in read(E/'ContactCardinalReplay/QA/result.json')['results']}
 statuses=[]
 for r in raw['results']:
  if r['pass']:status='passed-original'
  elif corrections[r['id']]['pass']:
   status='replayed-target' if corrections[r['id']]['directTargetContact'] else 'blocked-by-adjacent-solid'
  elif cardinal.get(r['id'],{}).get('pass'):status='cardinal-replay-passed-diagonal-target-unresolved'
  else:status='unresolved'
  statuses.append({'id':r['id'],'status':status})
 write('coverage-summary.json',{'initialResults':len(raw['results']),'initialPassed':sum(r['pass'] for r in raw['results']),'rawAllExecutedPassed':raw['allExecutedPassed'],'framesAdvanced':raw['framesAdvanced'],'seconds':raw['seconds'],'statuses':statuses,'counts':{k:sum(s['status']==k for s in statuses) for k in sorted(set(s['status'] for s in statuses))},'originalExcluded':raw['excluded'],'statement':'No root-inside-solid or excessive penetration was observed. Adjacent-blocked faces and two diagonal dodge target fixtures remain explicit coverage limits; cardinal replays are not diagonal approvals. Raw false receipts are retained.'})
 catalog=read(ROOT/'ArtSource/World/PlayableVillage02/ArtProductionV1/ExportV1/catalog.json')
 art=[{'id':a['id'],'sourceUnchanged':sha(ROOT/a['source'])==a['sourceSHA256'],'compositeUnchanged':sha(ROOT/a['composite'])==a['compositeSHA256']} for a in catalog['assets']]
 assert all(a['sourceUnchanged'] and a['compositeUnchanged'] for a in art)
 paths=['Assets/Mmorpg/Scenes/ValdoriaPlayableVillage01.unity','Assets/Mmorpg/Scenes/MmorpgWorld.unity','ProjectSettings/EditorBuildSettings.asset','ArtSource/World/PlayableVillage02/ArtProductionV1']
 unchanged=subprocess.run(['git','diff','--exit-code','HEAD','--',*paths],cwd=ROOT,capture_output=True).returncode==0
 assert unchanged
 write('source-integrity.json',{'approvedArt':art,'protectedPathsUnchanged':paths,'verifiedByGitDiff':unchanged,'nativePPU':32,'world':[282,335],'placementScale':2.2,'actorVisualScale':1.25,'finalPhysicalPolygons':120,'generatorV2Matches':sha(ROOT/'Tools/ArtPipeline/WorldGen/village02_integration.py')==read(ROOT/'ArtSource/World/PlayableVillage02/IntegrationV2/manifest.json')['generatorSHA256'],'archivedV1ProducerMatches':sha(ROOT/'ArtSource/World/PlayableVillage02/IntegrationV1/generator-at-bake-v1.py')==read(ROOT/'ArtSource/World/PlayableVillage02/IntegrationV1/manifest.json')['generatorSHA256']})
 result=subprocess.run([sys.executable,'-m','unittest','discover','-s','Tools/ArtPipeline/WorldGen','-p','test_village02_integration.py','-v'],cwd=ROOT,capture_output=True,text=True)
 write('offline-tests.json',{'command':result.args,'returnCode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
 if result.returncode:raise RuntimeError('Offline tests failed')
 print(json.dumps({'captures':len(images),'coverage':read(E/'QA/coverage-summary.json')['counts']}))

if __name__=='__main__':main()
