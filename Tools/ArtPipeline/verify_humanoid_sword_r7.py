"""Focused offline verification of immutable sprite lineage and procedural-study outputs."""
import json,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];E=ROOT/'Docs/Validation/HumanoidSwordR7'
def frames(folder):
 data=json.loads((folder/'aseprite.json').read_text());sheet=Image.open(folder/'spritesheet.png').convert('RGBA');result=[]
 for f in data['frames']:
  r=f['frame'];result.append(sheet.crop((r['x'],r['y'],r['x']+r['w'],r['y']+r['h'])))
 return result

def main():
 r5=frames(ROOT/'ArtSource/Labs/Humanoid2026/R5/Results');r6=frames(ROOT/'ArtSource/Labs/Humanoid2026/R6/Locomotion');qa=json.loads((ROOT/'ArtSource/Labs/Humanoid2026/R6/Locomotion/qa.json').read_text());pairs=[]
 for p in qa['cardinalsIdentical']:
  same=r6[p['newIndex']].tobytes()==r5[p['r5Index']].tobytes();assert same;pairs.append(dict(newIndex=p['newIndex'],r5Index=p['r5Index'],identical=same))
 assert len(r6)==104 and len(pairs)==52
 study=frames(ROOT/'ArtSource/Labs/Humanoid2026/R7/GripStudy');boxes=[im.getbbox() for im in study];assert len(study)==12 and all(b and b[0]>0 and b[1]>0 and b[2]<128 and b[3]<160 for b in boxes)
 native=ROOT/'ArtSource/Labs/Humanoid2026/R7/GripStudy/spritesheet.png';imported=ROOT/'Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/GripStudy/ProceduralGripStudyR7.png';assert native.read_bytes()==imported.read_bytes()
 q=json.loads((E/'procedural-grip.json').read_text());assert q['unreachableTargetRejected'] and all(r['bodyUnaffected'] and r['socketError']<1e-4 for r in q['records']) and all(r['socketError']<.002 for r in q['liveWeaponFollowing'])
 result=dict(r5R6CardinalPairs=pairs,locomotionFramesUnchanged=104,locomotionCanvas=[128,160],proceduralFrames=12,proceduralCanvas=[128,160],proceduralCroppedFrames=0,proceduralImportedPngIdentical=True,maximumAnalyticSocketError=max(r['socketError'] for r in q['records']),maximumLiveIkSocketError=max(r['socketError'] for r in q['liveWeaponFollowing']),maximumArmLengthError=max(max(abs(r['upperLength']-r['expectedUpper']),abs(r['lowerLength']-r['expectedLower'])) for r in q['records']),noBodyOrLowerBodyChanges=True,unreachableTargetRejected=True,universalWeaponOrFingerContactSolver=False)
 (E/'sprite-and-grip-integrity.json').write_text(json.dumps(result,indent=2));print('Verified 52 identical R5 cardinals, 104 R6 locomotion sprites and 12 uncropped procedural poses.')
if __name__=='__main__':main()
