"""Blender entry: inspect baked V4 source at quarter-frame samples, no rendering."""
import bpy,json,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Tools/ArtPipeline'))
from bow_pose_constraints_r7 import HeadClearance,elbow_angle

def main():
 source=ROOT/'ArtSource/Labs/Humanoid2026/R7/BowGripStudyV4.blend'
 bpy.ops.wm.open_mainfile(filepath=str(source),use_scripts=False,load_ui=False)
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and 'upperarm_r' in o.pose.bones);head=HeadClearance();rows=[]
 for i in range(145):
  f=1+i/4;bpy.context.scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  shoulder=rig.matrix_world@rig.pose.bones['upperarm_r'].head;elbow=rig.matrix_world@rig.pose.bones['lowerarm_r'].head;wrist=rig.matrix_world@rig.pose.bones['hand_r'].head
  rows.append(dict(frame=f,head=head.measure(),elbowAngle=elbow_angle(shoulder,elbow,wrist),elbow=list(elbow)))
 result=dict(samples=len(rows),minimumSampledHeadDistance=min(r['head']['minSignedHeadSurfaceDistance'] for r in rows),penetratingSamples=sum(r['head']['penetratingGloveVertices']>0 for r in rows),maximumElbowFlexion=max(r['elbowAngle'] for r in rows),rows=rows)
 assert result['penetratingSamples']==0 and result['minimumSampledHeadDistance']>=.015 and result['maximumElbowFlexion']<=125,result
 (ROOT/'Docs/Validation/HumanoidSwordR7/bow-v4-baked-geometry.json').write_text(json.dumps(result,indent=2))
 print('BOW_BAKED_QA',json.dumps({k:v for k,v in result.items() if k!='rows'}))
if __name__=='__main__':main()
