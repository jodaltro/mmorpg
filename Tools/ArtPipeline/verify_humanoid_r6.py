"""Verify the R6 partial delivery, including failed gates rather than masking them."""
import json,hashlib,subprocess,tempfile
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];E=ROOT/'Docs/Validation/HumanoidCombat8Dir2026';R6=ROOT/'ArtSource/Labs/Humanoid2026/R6'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 frozen=json.loads((E/'protected-files.json').read_text());assert all(sha(ROOT/p)==h for p,h in frozen.items())
 saves=json.loads((ROOT/'Temp/HumanoidR6/personal-before.json').read_text());assert all(sha(Path(p))==h for p,h in saves.items())
 manifest=json.loads((R6/'Locomotion/manifest.json').read_text());qa=json.loads((R6/'Locomotion/qa.json').read_text());assert len(manifest['clips'])==16 and len(qa['frameHashes'])==104 and len(qa['cardinalsIdentical'])==52
 with tempfile.TemporaryDirectory(dir=ROOT/'Temp/HumanoidR6') as temp:
  for folder,doc,count in [('Locomotion','Locomotion8Dir',104),('CombatCandidate','CombatCandidate',160)]:
   sheet=Path(temp)/(folder+'.png');data=Path(temp)/(folder+'.json');subprocess.run(['D:/Aseprite/Aseprite.exe','-b',str(R6/folder/(doc+'.aseprite')),'--sheet',str(sheet),'--data',str(data),'--list-tags','--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
   image=Image.open(sheet).convert('RGBA');meta=json.loads(data.read_text());original=Image.open(R6/folder/'spritesheet.png').convert('RGBA');assert len(meta['frames'])==count and image.tobytes()==original.tobytes()
 gate=json.loads((E/'locomotion-gameplay/qa.json').read_text());assert gate['eightDirections']==8 and gate['idleDiagonalPreserved'] and gate['angularHysteresis'] and gate['saveLoad'];assert len(gate['directions'])==8
 combat=json.loads((E/'combat-candidate/near-sweep-failure.json').read_text());assert combat['actualHitCount']==0 and combat['actualDamage']==0 and not combat['passed']
 poses=json.loads((E/'locomotion-pose-integrity.json').read_text());assert poses['maxWorldBoneMatrixDifferenceFromR5']==0
 report=dict(protectedFiles=len(frozen),frozenFilesIdentical=True,personalSaves=len(saves),personalSavesUnchanged=True,locomotionFrames=104,cardinalR5FramesIdentical=52,diagonalFrames=52,walkFrames=96,idleFrames=8,asepriteRoundtripFrames=264,locomotionGatePassed=True,combatGatePassed=False,combatCandidateNotReleased=True,rollAndDeathPending=True,completeMilestone=False)
 (E/'integrity.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
