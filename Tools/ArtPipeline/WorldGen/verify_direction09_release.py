"""Inventory exact artifact bytes and verify what is actually staged for publication."""
import argparse,io,json,subprocess
from pathlib import Path
import visual_unification09 as v

RECEIPTS={'artifact-inventory.json','staged-artifact-qa.json'}
def inventory():
 paths=[]
 for root in [v.BASE,v.ROOT/'Assets/Mmorpg/Art/Experimental/ValdoriaVisual09',v.EVIDENCE]:
  paths.extend(p for p in root.rglob('*') if p.is_file() and p.name not in RECEIPTS)
 files={p.relative_to(v.ROOT).as_posix():v.common.sha(p.read_bytes()) for p in sorted(paths)}
 result={'schema':'valdoria-direction-artifact-inventory/v1','files':files,'pngCount':sum(Path(p).suffix=='.png' for p in files),'excludedReceipts':sorted(RECEIPTS),'artisticStatus':'candidate, no automatic promotion'}
 v.write(v.EVIDENCE/'artifact-inventory.json',result);return {'files':len(files),'pngCount':result['pngCount']}

def staged():
 data=v.ref.read(v.EVIDENCE/'artifact-inventory.json');paths=list(data['files']);queries=''.join(':'+p+'\n' for p in paths).encode()
 result=subprocess.run(['git','cat-file','--batch'],input=queries,capture_output=True,check=True);stream=io.BytesIO(result.stdout);failures=[]
 for path in paths:
  head=stream.readline().decode().strip().split()
  if len(head)!=3 or head[1]!='blob':raise ValueError('Not staged: '+path)
  payload=stream.read(int(head[2]));assert stream.read(1)==b'\n'
  if v.common.sha(payload)!=data['files'][path]:failures.append(path)
 if failures:raise ValueError('Staged bytes mismatch: '+repr(failures))
 receipt={'schema':'valdoria-staged-artifact-qa/v1','verifiedFiles':len(paths),'pngCount':data['pngCount'],'mismatches':failures,'inventorySha256':v.common.sha((v.EVIDENCE/'artifact-inventory.json').read_bytes())}
 v.write(v.EVIDENCE/'staged-artifact-qa.json',receipt);return receipt

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('command',choices=['inventory','staged']);a=p.parse_args();print(json.dumps(inventory() if a.command=='inventory' else staged(),indent=2))
