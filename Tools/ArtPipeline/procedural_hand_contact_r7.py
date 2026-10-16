"""Contact-aware hand authoring: real finger-chain socket, cylindrical wrap and cord pinch.
These solvers rotate bones only; they do not scale anatomy or declare artistic acceptance.
"""
import math
import bpy
from mathutils import Vector,Quaternion

def circle(a,b,c):
 u=(b-a).normalized();n=(b-a).cross(c-a).normalized();v=n.cross(u);d=(b-a).length;x=(c-a).dot(u);y=(c-a).dot(v)
 if abs(y)<1e-6:raise ValueError('Finger chain cannot define a grip circle')
 return a+u*d*.5+v*(((c-a).length_squared-d*x)/(2*y))

def local_socket(rig,mats,side,kind):
 hand=mats['hand_'+side]
 if kind=='pinch':
  points=[]
  for finger in ['index','thumb']:
   name=finger+'_03_'+side;points.append(mats[name]@Vector((0,rig.data.bones[name].length,0)))
  center=(points[0]+points[1])*.5
 else:
  centers=[]
  for finger in ['index','middle','ring','pinky']:
   points=[mats[finger+'_'+str(i).zfill(2)+'_'+side].translation for i in [1,2,3]];centers.append(circle(*points))
  center=sum(centers,Vector())/len(centers)
 return hand.inverted()@center

def fingertip(rig,name):
 b=rig.pose.bones[name];return rig.matrix_world@b.tail

def ccd(rig,finger,side,target,iterations=45):
 chain=[rig.pose.bones[finger+'_'+str(i).zfill(2)+'_'+side] for i in [1,2,3]];end=chain[-1].name;lengths=[(rig.matrix_world@b.tail-rig.matrix_world@b.head).length for b in chain]
 if (target-rig.matrix_world@chain[0].head).length>sum(lengths)+.001:raise ValueError('Finger target outside anatomical reach')
 for _ in range(iterations):
  if (fingertip(rig,end)-target).length<.0005:break
  for bone in reversed(chain):
   origin=rig.matrix_world@bone.head;a=fingertip(rig,end)-origin;b=target-origin
   if min(a.length,b.length)<1e-6:continue
   q=a.normalized().rotation_difference(b.normalized())
   if q.angle>math.radians(18):q=Quaternion(q.axis,math.radians(18))
   old=rig.matrix_world@bone.matrix;world=(q@old.to_quaternion()).to_matrix().to_4x4();world.translation=origin;bone.matrix=rig.matrix_world.inverted()@world;bpy.context.view_layer.update()
 return dict(error=(fingertip(rig,end)-target).length,maxLengthChange=max(abs((rig.matrix_world@b.tail-rig.matrix_world@b.head).length-l) for b,l in zip(chain,lengths)),tip=list(fingertip(rig,end)),target=list(target))

def conform_hand(rig,side,center,axis,radius,kind):
 axis=axis.normalized();rows=[]
 if kind=='pinch':
  rows.append(dict(finger='index',**ccd(rig,'index',side,center+axis*radius)))
  rows.append(dict(finger='thumb',**ccd(rig,'thumb',side,center-axis*radius)))
 else:
  for finger in ['index','middle','ring','pinky']:
   root=rig.matrix_world@rig.pose.bones[finger+'_01_'+side].head;radial=root-center-axis*(root-center).dot(axis)
   # The professional C-shaped seed supplies bend direction; radius changes the contact target.
   target=center+axis*(root-center).dot(axis)+Quaternion(axis,math.radians(-205 if side=='l' else 205))@radial.normalized()*(radius+.005)
   rows.append(dict(finger=finger,**ccd(rig,finger,side,target)))
  b=rig.pose.bones['thumb_03_'+side];tip=rig.matrix_world@b.tail;radial=tip-center-axis*(tip-center).dot(axis);target=center+axis*.018+radial.normalized()*(radius+.004);rows.append(dict(finger='thumb',**ccd(rig,'thumb',side,target)))
 return dict(kind=kind,contacts=rows,maxContactError=max(r['error'] for r in rows),maxFingerLengthChange=max(r['maxLengthChange'] for r in rows))
