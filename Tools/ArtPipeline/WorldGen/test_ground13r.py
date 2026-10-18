import unittest,tempfile,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
import ground13r as r

class Ground13RTests(unittest.TestCase):
 def test_manifests_and_immutable_water_inputs(self):
  for p in [r.BASE/'ShapeV6',r.BASE/'ExportV4',r.g.BASE/'WaterV2',r.g.BASE/'AtlasV1']:self.assertTrue(r.g.verify(p)['passed'])
 def test_foot_matches_original_segments(self):
  d=r.g.read(r.BASE/'ShapeV6/visual-relief.json');points=np.array(d['groundFeet']);a=np.concatenate([np.array(l) for l in d['physicalLoops']]);b=np.concatenate([np.roll(np.array(l),-1,axis=0) for l in d['physicalLoops']]);mid=(a+b)/2
  ids=cKDTree(mid).query(points,k=8)[1];start=a[ids];delta=b[ids]-start;v=points[:,None,:]-start;t=np.clip((v*delta).sum(2)/np.maximum((delta*delta).sum(2),1e-15),0,1);dist=np.linalg.norm(v-t[:,:,None]*delta,axis=2).min(1);self.assertLess(dist.max(),2e-5)
  self.assertLess(cKDTree(points).query(a)[0].max(),2e-5);self.assertFalse(d['physicalChange']);self.assertTrue(d['heightIsPresentationOnly'])
 def test_mesh_budget_and_sampled_atlas_alpha(self):
  d=r.g.read(r.BASE/'ShapeV6/visual-relief.json');self.assertLessEqual(len(d['groups']),53);im=np.array(Image.open(r.BASE/'ExportV4/top-atlas.png').convert('RGBA'));H,W=im.shape[:2]
  for group in d['groups']:
   self.assertTrue(all(0<=i<len(group['vertices']) for i in group['triangles']))
   if group['kind']=='mixed':
    selector=np.array(group['selector'])[:,0];self.assertEqual(len(selector),len(group['vertices']));uv=np.array(group['uv'])[selector==0];self.assertTrue(((uv>=0)&(uv<=1)).all());xx=np.minimum((uv[:,0]*W).astype(int),W-1);yy=np.minimum(((1-uv[:,1])*H).astype(int),H-1);self.assertTrue((im[yy,xx,3]==255).all())
 def test_rebuild_visual_geometry(self):
  with tempfile.TemporaryDirectory(dir=r.ROOT/'Temp') as tmp:
   out=Path(tmp)/'shape';r.relief(out);self.assertEqual((out/'visual-relief.json').read_bytes(),(r.BASE/'ShapeV6/visual-relief.json').read_bytes())
 def test_vertex_compaction_preserves_every_gpu_corner(self):
  before=r.g.read(r.BASE/'ShapeV5/visual-relief.json');after=r.g.read(r.BASE/'ShapeV6/visual-relief.json');self.assertEqual(len(before['groups']),len(after['groups']))
  for a,b in zip(before['groups'],after['groups']):
   def expanded(g):return np.column_stack([np.array(g[k],np.float32) for k in ['vertices','uv','colors','selector']])[g['triangles']].tobytes()
   self.assertEqual(expanded(a),expanded(b));self.assertEqual((a['row'],a['kind']),(b['row'],b['kind']))
  self.assertLess(after['vertexCompaction']['after'],after['vertexCompaction']['before'])
 def test_aseprite_reexport_authority(self):
  with tempfile.TemporaryDirectory(dir=r.ROOT/'Temp') as tmp:
   out=Path(tmp)/'export';r.export(out);self.assertEqual((out/'top-atlas.png').read_bytes(),(r.BASE/'ExportV4/top-atlas.png').read_bytes())
 def test_source_context_recipe_hashes(self):
  source=r.g.read(r.BASE/'SourceV2/composition.json')
  for ref in source['inputs'].values():self.assertEqual(r.g.e.n.common.sha((r.ROOT/ref['path']).read_bytes()),ref['sha256'])

if __name__=='__main__':unittest.main()
