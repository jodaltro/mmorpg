"""Measure capsule regions from actual Unity SweepSampled endpoints, at equivalent root positions."""
import json,re,math
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];E=ROOT/'Docs/Validation/HumanoidSwordR7'
def vec(s):return [float(v) for v in re.findall(r'[-+]?\d*\.?\d+(?:[Ee][-+]?\d+)?',s)]
def local(r):
 root=vec(r['root']);h=vec(r['origin']);t=vec(r['tip']);return ((h[0]-root[0],h[1]-root[1]),(t[0]-root[0],t[1]-root[1]))
def distance(p,a,b):
 dx=b[0]-a[0];dy=b[1]-a[1];u=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
 return math.hypot(p[0]-a[0]-u*dx,p[1]-a[1]-u*dy)
def main():
 legacy=[json.loads(x) for x in (E/'legacy-official/actual-sweep.jsonl').read_text().splitlines()]
 old=[local(r) for r in legacy if r['range']==1.25 and vec(r['direction'])[0]>.99]
 new=[local(r) for r in json.loads((E/'matrix-basic.json').read_text())[3]['sweep']]
 heavy=[local(r) for r in json.loads((E/'matrix-heavy.json').read_text())[3]['sweep']]
 failed=json.loads((E/'r6-reproduced-before-change.json').read_text())['samples'];r6=[((r['hand'][0]+2.75,r['hand'][1]),(r['tip'][0]+2.75,r['tip'][1])) for r in failed]
 def radius(samples):return max(math.hypot(*p) for pair in samples for p in pair)+.08
 # Point probes compare capsule coverage only; not collider-vs-wall or damage acceptance.
 cells=[(x*.05,y*.05) for x in range(-40,41) for y in range(-40,61)]
 a={p for p in cells if math.hypot(*p)<=1.41 and any(distance(p,*s)<=.08 for s in old)};b={p for p in cells if math.hypot(*p)<=1.41 and any(distance(p,*s)<=.08 for s in new)}
 result=dict(source='Actual SweepSampled; capsule geometry normalized to actor root. Grid is diagnostic, not an authority/hit test.',gridSpacing=.05,capsuleWidth=.16,segmentLengths={'basic':1,'heavy':1.4},rawCapsuleMaximumRootRadius={'legacyBasicEast':radius(old),'r7BasicEast':radius(new),'r7HeavyEast':radius(heavy),'r6FailedBasicEast':radius(r6)},pointCoverageApproxAreaWithRootDistanceGate={'legacy':len(a)*.0025,'r7':len(b)*.0025,'newRootCentredCellsWithinExistingDistanceGate':len(b-a)*.0025,'removedProjectedGripCells':len(a-b)*.0025},note='The regions are not identical/subsets: changing the origin changes near-root coverage. R7 removes projected-hand displacement and uses root offset zero, with no radius/width/range increase. Target collider extent still affects center-to-center hit distance. Existing root-distance gate range+0.16 and both LOS checks remain.',rootRadiusR7Bound={'basic':1.08,'heavy':1.48},rangeConstantsUnchanged=True)
 assert radius(new)<1.081 and radius(heavy)<1.481
 (E/'reach-region-comparison.json').write_text(json.dumps(result,indent=2))
 image=Image.new('RGB',(1200,470),'#202b31');draw=ImageDraw.Draw(image)
 for i,(name,segments,color) in enumerate([('Iron Knight / LegacyGrip',old,'#64c8ff'),('R6 failed / projected hand',r6,'#f58393'),('R7 / physical root',new,'#55ed9b')]):
  ox=i*400+135;oy=360;scale=90
  def xy(p):return (round(ox+p[0]*scale),round(oy-p[1]*scale))
  for j in range(-2,4):draw.line((i*400,oy-j*scale,(i+1)*400,oy-j*scale),fill='#334047')
  for h,t in segments:draw.line((xy(h),xy(t)),fill=color,width=14)
  draw.ellipse((ox-4,oy-4,ox+4,oy+4),fill='white');tx,ty=xy((.85,0));draw.rectangle((tx-.325*scale,ty-.55*scale,tx+.325*scale,ty+.55*scale),outline='#ffe18a',width=2)
  draw.text((i*400+8,12),name,fill='white');draw.text((i*400+8,430),'Actual samples / width 0.16 / root white',fill='white')
 image.save(E/'previews/physical-region-comparison.png');print(json.dumps(result['rawCapsuleMaximumRootRadius']))
if __name__=='__main__':main()
