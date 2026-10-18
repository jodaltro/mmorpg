import copy,json,tempfile,unittest
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
import terrain_materials as m
import material_refinement as f
SOURCE=m.ROOT/'ArtSource/Labs/World2026/WorldStudio04'
class RefinementTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.ctx=m.Context(library_dir=SOURCE/'Library');cls.r=f.recipe()
 def render(self,r=None,bounds=(700,700,320,240),stage='final'):return np.array(self.ctx.render(r or self.r,bounds,stage))
 def test_invalid_refinement_context_rejected(self):
  for key,value in [('artDirection','scatter'),('clusterSpacing',0),('clusterSpacing',22.5),('pigmentContrast',8)]:
   r=copy.deepcopy(self.r);r[key]=value
   with self.assertRaises(ValueError):self.ctx.render(r,(700,700,96,80),'final')
 def test_seed_reproducibility(self):np.testing.assert_array_equal(self.render(),self.render())
 def test_seed_changes_art_not_road(self):
  before=[(m.ROAD/(k+'.png')).read_bytes() for k in ['coverage','navigable','wear','shoulders']];r=copy.deepcopy(self.r);r['seed']+=1;self.assertFalse(np.array_equal(self.render(),self.render(r)));self.assertEqual(before,[(m.ROAD/(k+'.png')).read_bytes() for k in ['coverage','navigable','wear','shoulders']])
 def test_two_axis_chunk_continuity(self):
  a=self.render(bounds=(440,550,400,300));pieces=[self.render(bounds=b) for b in [(440,550,72,151),(512,550,328,151),(440,701,72,149),(512,701,328,149)]]
  np.testing.assert_array_equal(a,np.concatenate([np.concatenate(pieces[:2],axis=1),np.concatenate(pieces[2:],axis=1)],axis=0))
 def test_joint_network_independent_of_crop_extent(self):
  y,x=np.mgrid[710:830,500:760];a=f.rock_structure(x,y,710202)[0];parts=[]
  for start,end in [(500,612),(612,760)]:
   y,x=np.mgrid[710:830,start:end];parts.append(f.rock_structure(x,y,710202)[0])
  np.testing.assert_array_equal(a,np.concatenate(parts,axis=1))
 def test_local_patch_does_not_bleed(self):
  r=copy.deepcopy(self.r);r['patches']=[{'rectPixels':[730,730,32,32],'toneOffset':1}];a=self.render(stage='base');b=self.render(r,stage='base');mask=np.zeros((240,320),bool);mask[30:62,30:62]=True
  np.testing.assert_array_equal(a[~mask],b[~mask]);self.assertTrue((a[mask]!=b[mask]).any())
 def test_six_functional_motifs_each_distinct(self):
  im=self.ctx.motifs
  for kind in range(6):
   blocks=[im.crop((v*128+48,kind*32,v*128+80,kind*32+32)).tobytes() for v in range(6)];self.assertEqual(len(set(blocks)),6)
 def test_source_is_editable_revision(self):
  lib=m.read(SOURCE/'Library/library.json');parent=m.ROOT/lib['parentSource'];self.assertEqual(lib['parentSha256'],m.sha(parent.read_bytes()));self.assertEqual(lib['allowedTransforms'],['translation']);self.assertEqual(lib['canvas'],[768,192])
 def test_contextual_groups_have_rest_spaces(self):
  points=f.instances(self.ctx,self.r);counts=np.zeros((14,19),int)
  for p in points:counts[min(13,p['y']//112),min(18,p['x']//112)]+=1
  self.assertGreater((counts==0).mean(),.30);self.assertGreater(counts.var()/max(counts.mean(),1),2)
  self.assertGreater(len(set(p['variant'] for p in points if p['kind']==0)),4)
 def test_minimum_distance_between_group_children(self):
  from scipy.spatial import cKDTree
  points=np.array([[p['x'],p['y']] for p in f.instances(self.ctx,self.r)]);d,_=cKDTree(points).query(points,k=2);self.assertGreaterEqual(d[:,1].min(),8)
 def test_used_grass_stays_short(self):
  for p in f.instances(self.ctx,self.r):
   a=f.context_fields(self.ctx,self.r,np.array(p['x']),np.array(p['y']))
   if p['kind']==0 and a[8]>.7:self.assertEqual(p['variant'],0)
 def test_global_arc_does_not_reset_at_joins(self):
  arcs=f.global_arcs(self.ctx);self.assertTrue((np.diff(arcs)>=-1e-4).all());self.assertAlmostEqual(arcs[-1]/32,sum(s['length'] for s in self.ctx.road['segments']),places=4)
 def test_wear_follows_axis_and_varies_laterally(self):
  marks=f.wear_marks(self.ctx,self.r);self.assertGreater(len(marks),100);self.assertGreater(max(p['arcPixels'] for p in marks),1600)
  lateral=[]
  for p in marks:
   (dist,signed,arc,width),tangent=f.road_space(self.ctx,np.array(p['x']),np.array(p['y']));self.assertGreater(abs(np.dot(tangent[0],[p['dx'],p['dy']])),.94);lateral.append(float(signed))
  self.assertGreater(np.std(lateral),8)
 def test_editable_road_alpha_changes_world_appearance(self):
  ctx=copy.copy(self.ctx);ctx.motifs=self.ctx.motifs.copy()
  from PIL import ImageDraw
  ImageDraw.Draw(ctx.motifs).rectangle((0,160,767,191),fill=(0,0,0,0))
  original=self.render(bounds=(700,700,640,512));edited=np.array(ctx.render(self.r,(700,700,640,512),'final'))
  self.assertGreater(np.count_nonzero(np.any(original!=edited,axis=2)),20)
 def test_large_pigment_islands_reduced(self):
  bounds=(500,1020,640,320);new=self.render(bounds=bounds,stage='base')[:,:,:3].mean(axis=2);old=np.array(Image.open(m.ROOT/'ArtSource/Labs/World2026/WorldStudio03/BuildR7/A/base-atlas.png').crop((500,1020,1140,1340)))[:,:,:3].mean(axis=2)
  self.assertLess(gaussian_filter(new,18).std(),gaussian_filter(old,18).std())
 def test_road_camouflage_contrast_reduced(self):
  bounds=(700,700,640,512);new=self.render(bounds=bounds,stage='transitions');old=np.array(Image.open(m.ROOT/'ArtSource/Labs/World2026/WorldStudio03/BuildR7/A/transitions-atlas.png').crop((700,700,1340,1212)));mask=self.ctx.masks['coverage'][700:1212,700:1340]>250
  newL=new[:,:,:3].mean(axis=2)[mask];oldL=old[:,:,:3].mean(axis=2)[mask]
  self.assertLess(np.percentile(newL,95)-np.percentile(newL,5),(np.percentile(oldL,95)-np.percentile(oldL,5))*.6)
 def test_all_stages_opaque(self):
  for stage in ['base','transitions','final']:self.assertTrue((self.render(stage=stage)[:,:,3]==255).all())
 def test_mesh_relief_field_byte_invariant(self):
  for style in 'ABC':self.assertEqual((SOURCE/'BuildR6'/style/'relief-field.json').read_bytes(),(m.ROOT/'ArtSource/Labs/World2026/WorldStudio03/BuildR7/A/relief-field.json').read_bytes())
 def test_refined_local_export_provenance_and_pixels(self):
  with tempfile.TemporaryDirectory() as tmp:
   out=Path(tmp)/'local';m.render_crop(SOURCE/'Recipes/recipe-A.json',out,SOURCE/'Library',[1024,704,96,80])
   manifest=m.read(out/'manifest.json');self.assertEqual(manifest['generator'],f.VERSION)
   with Image.open(out/'patch.png') as patch,Image.open(SOURCE/'BuildR6/A/final-atlas.png') as full:self.assertEqual(patch.tobytes(),full.crop((1024,704,1120,784)).tobytes())
 def test_manifests_and_no_overwrite(self):
  for style in 'ABC':self.assertTrue(m.verify_manifest(SOURCE/'BuildR6'/style))
  with tempfile.TemporaryDirectory() as tmp:
   with self.assertRaises(FileExistsError):m.generate(SOURCE/'Recipes/recipe-A.json',tmp,SOURCE/'Library')
 def test_top_left_slope_lighting_in_rendered_pixels(self):
  yy,xx=np.mgrid[0:48,0:64];tilt=np.clip(xx-14,-4,4)*20+np.clip(yy-10,-4,4)*30
  plus=copy.copy(self.ctx);minus=copy.copy(self.ctx);plus.layers=dict(self.ctx.layers);minus.layers=dict(self.ctx.layers)
  plus.layers['elevationMilli']=700+tilt;minus.layers['elevationMilli']=700-tilt
  plus.rock=minus.rock=np.full((48,64),2.)
  a=np.array(plus.render(self.r,(384,256,128,128),'transitions'))[:,:,:3].astype(float);b=np.array(minus.render(self.r,(384,256,128,128),'transitions'))[:,:,:3].astype(float)
  self.assertGreater((a-b).mean(),10)
 def test_compact_clusters_not_white_noise(self):
  # Direct pixel samples show the grass material has small coherent clusters, no independent per-pixel salt-and-pepper.
  a=self.render(bounds=(800,1100,256,192),stage='base')[:,:,:3].astype(float)
  delta1=np.mean(np.abs(a[:,1:]-a[:,:-1]));delta8=np.mean(np.abs(a[:,8:]-a[:,:-8]));self.assertLess(delta1,delta8*.55)
if __name__=='__main__':unittest.main()
