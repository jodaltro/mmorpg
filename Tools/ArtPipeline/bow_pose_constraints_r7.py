"""Geometric QA for the inspected humanoid: real head surface and right glove vertices."""
import math
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def weighted_indices(obj,predicate):
 groups={g.index for g in obj.vertex_groups if predicate(g.name)}
 return {v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.5}

class HeadClearance:
 def __init__(self):
  obj=bpy.data.objects['SuperHero_Male'];indices=weighted_indices(obj,lambda n:n.lower()=='head');mesh=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
  assert len(mesh.vertices)==len(obj.data.vertices)
  faces=[tuple(p.vertices) for p in mesh.polygons if all(i in indices for i in p.vertices)]
  self.tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],faces)
  self.glove=bpy.data.objects['Fitted articulated leather gloves'];self.hand=weighted_indices(self.glove,lambda n:n.endswith('_r') and any(n.startswith(p) for p in ['hand','index','middle','ring','pinky','thumb']))
 def measure(self):
  mesh=self.glove.evaluated_get(bpy.context.evaluated_depsgraph_get()).data;assert len(mesh.vertices)==len(self.glove.data.vertices)
  distances=[]
  for i in self.hand:
   p=self.glove.matrix_world@mesh.vertices[i].co;point,normal,face,distance=self.tree.find_nearest(p)
   distances.append(distance if (p-point).dot(normal)>=0 else -distance)
  return dict(minSignedHeadSurfaceDistance=min(distances),penetratingGloveVertices=sum(d<-.001 for d in distances),sampledGloveVertices=len(distances),scope='Right glove vertices against weighted head surface; signed nearest-normal distance, not universal self-collision')

def elbow_angle(shoulder,elbow,wrist):
 a=(Vector(elbow)-Vector(shoulder)).normalized();b=(Vector(wrist)-Vector(elbow)).normalized()
 return math.degrees(math.acos(max(-1,min(1,a.dot(b)))))
