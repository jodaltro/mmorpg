"""Shared subcell environmental boundaries; derived from semantic scalars, never image pixels.
Same A-B-C/A-C-D clipping convention as TerrainReliefBuilder.AddContinuous.
"""
import json,math
from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates

def read(path):return json.loads(Path(path).read_text())
def clean(poly):
 result=[]
 for p in poly:
  p=tuple(round(float(v),6) for v in p)
  if not result or p!=result[-1]:result.append(p)
 if len(result)>1 and result[0]==result[-1]:result.pop()
 return result

def clip_triangle(points,values):
 result=[]
 for i in range(3):
  a,b=np.array(points[i]),np.array(points[(i+1)%3]);sa,sb=values[i],values[(i+1)%3]
  if sa>=0:result.append(a)
  if (sa>=0)!=(sb>=0):result.append(a+(b-a)*sa/(sa-sb))
 return clean(result)

def contours(field,step=.25):
 """Union boundary of clipped positive triangles. Rounded micron vertices; no simplification."""
 field=np.asarray(field,float);edges={};H,W=field.shape
 for y in range(H-1):
  for x in range(W-1):
   pts=[(x*step,y*step),((x+1)*step,y*step),((x+1)*step,(y+1)*step),(x*step,(y+1)*step)];s=[field[y,x],field[y,x+1],field[y+1,x+1],field[y+1,x]]
   for ids in [(0,1,2),(0,2,3)]:
    poly=clip_triangle([pts[i] for i in ids],[s[i] for i in ids])
    if len(poly)<3:continue
    for a,b in zip(poly,poly[1:]+poly[:1]):
     if a==b:continue
     if (b,a) in edges:del edges[(b,a)]
     else:edges[(a,b)]=True
 forward={}
 for a,b in edges:forward.setdefault(a,[]).append(b)
 loops=[]
 while edges:
  first=next(iter(edges));start=first[0];p=start;loop=[]
  while True:
   loop.append(p);options=[q for q in forward.get(p,[]) if (p,q) in edges]
   if not options:raise ValueError('Open shared boundary at '+str(p))
   q=sorted(options)[0];del edges[(p,q)];p=q
   if p==start:break
   if len(loop)>200000:raise ValueError('Invalid boundary cycle')
  if len(loop)>2:loops.append([list(p) for p in loop])
 return sorted(loops,key=lambda p:(min(q[1] for q in p),min(q[0] for q in p)))

def signed_area(poly):return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))/2

def contains(loops,x,y):
 """Even-odd occupancy, supports islands/holes, broadcasts arrays."""
 x,y=np.broadcast_arrays(x,y);inside=np.zeros(x.shape,bool)
 for loop in loops:
  for a,b in zip(loop,loop[1:]+loop[:1]):
   if a[1]==b[1]:continue
   crossing=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]);inside^=crossing
 return inside

def sample_triangular(field,x,y,step=.25):
 """Exact scalar interpolation in the same two triangles; NOT bilinear across diagonal."""
 f=np.asarray(field);x,y=np.broadcast_arrays(np.asarray(x)/step,np.asarray(y)/step);ix=np.clip(np.floor(x).astype(int),0,f.shape[1]-2);iy=np.clip(np.floor(y).astype(int),0,f.shape[0]-2);u=np.clip(x-ix,0,1);v=np.clip(y-iy,0,1)
 a,b,c,d=f[iy,ix],f[iy,ix+1],f[iy+1,ix+1],f[iy+1,ix]
 return np.where(v<=u,a+(b-a)*u+(c-b)*v,a+(c-d)*u+(d-a)*v)

def rock_boundary(relief):
 field=np.array(relief['samples'])[:,:,0];loops=contours(field,relief['stepUnits'])
 return {'schema':'valdoria-environment-boundary/v1','coordinates':'top-left-x-east-y-south-world-units','stepUnits':relief['stepUnits'],'sizeUnits':relief['sizeUnits'],'rockLoops':loops,'authority':'shared positive scalar triangle union; presentation, navigation and collider','precisionUnits':.000001,'originalTerrainModified':False,'footprintRevision':'explicit replacement of coarse cell boxes in Hydrology Lab only'}
def positive_overlap(a,b,step=.25):
 """Exact positive-area overlap of two scalar fields on a shared triangular lattice."""
 a,b=np.asarray(a),np.asarray(b)
 for ids in [(0,1,2),(0,2,3)]:
  av=[a[:-1,:-1],a[:-1,1:],a[1:,1:],a[1:,:-1]];bv=[b[:-1,:-1],b[:-1,1:],b[1:,1:],b[1:,:-1]];possible=(np.maximum.reduce([av[i] for i in ids])>0)&(np.maximum.reduce([bv[i] for i in ids])>0)
  for y,x in np.argwhere(possible):
   allpts=[(x*step,y*step),((x+1)*step,y*step),((x+1)*step,(y+1)*step),(x*step,(y+1)*step)];poly=clip_triangle([allpts[i] for i in ids],[av[i][y,x] for i in ids])
   if len(poly)<3 or abs(signed_area(poly))<1e-10:continue
   points=np.array(poly);values=sample_triangular(b,points[:,0],points[:,1],step)
   if values.max()>1e-7:return True
 return False

def intersects_rect(loops,rect):
 x,y,w,h=rect;corners=[(x,y),(x+w,y),(x+w,y+h),(x,y+h)]
 if contains(loops,np.array(corners)[:,0],np.array(corners)[:,1]).any():return True
 def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 for loop in loops:
  if any(x<=p[0]<=x+w and y<=p[1]<=y+h for p in loop):return True
  for a,b in zip(loop,loop[1:]+loop[:1]):
   for c,d in zip(corners,corners[1:]+corners[:1]):
    if max(a[0],b[0])<min(c[0],d[0]) or min(a[0],b[0])>max(c[0],d[0]) or max(a[1],b[1])<min(c[1],d[1]) or min(a[1],b[1])>max(c[1],d[1]):continue
    if cross(a,b,c)*cross(a,b,d)<=0 and cross(c,d,a)*cross(c,d,b)<=0:return True
 return False
