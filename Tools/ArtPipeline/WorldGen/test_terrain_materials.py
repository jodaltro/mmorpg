import copy,json,tempfile,unittest
from pathlib import Path
import numpy as np
from PIL import Image
import terrain_materials as m
SOURCE=m.ROOT/'ArtSource/Labs/World2026/WorldStudio03'
class MaterialTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.ctx=m.Context(library_dir=SOURCE/'LibraryV2');cls.r=m.recipe()
 def render(self,r=None,bounds=(800,690,128,96),stage='final'):return np.array(self.ctx.render(r or self.r,bounds,stage))
 def test_seed_byte_repeat(self):np.testing.assert_array_equal(self.render(),self.render())
 def test_seed_changes_appearance(self):
  r=copy.deepcopy(self.r);r['seed']+=1;self.assertFalse(np.array_equal(self.render(),self.render(r)))
 def test_contract_rejects_invalid(self):
  for key,value in [('schema','wrong'),('ppu',16),('seed','x'),('light','lower-right'),('detailDensity',20),('style',None)]:
   r=copy.deepcopy(self.r);r[key]=value
   with self.assertRaises(ValueError):m.validate(r,self.ctx.region)
 def test_rgba_no_holes_all_stages(self):
  for stage in ['base','transitions','final']:
   a=self.render(stage=stage);self.assertEqual(a.shape,(96,128,4));self.assertTrue((a[:,:,3]==255).all())
 def test_chunks_exact_both_axes(self):
  full=self.render(bounds=(440,440,180,180));pieces=[self.render(bounds=b) for b in [(440,440,72,81),(512,440,108,81),(440,521,72,99),(512,521,108,99)]]
  np.testing.assert_array_equal(full,np.concatenate([np.concatenate(pieces[:2],axis=1),np.concatenate(pieces[2:],axis=1)],axis=0))
 def test_local_regeneration(self):
  r=copy.deepcopy(self.r);r['patches']=[{'rectPixels':[820,710,16,20],'toneOffset':1}];a=self.render(stage='base');b=self.render(r,stage='base')
  mask=np.zeros((96,128),bool);mask[20:40,20:36]=True
  np.testing.assert_array_equal(a[~mask],b[~mask]);self.assertTrue((a[mask]!=b[mask]).any())
 def test_topography_and_road_invariant(self):
  paths=[m.BASE,m.ROAD/'road.json']+[m.ROAD/(k+'.png') for k in ['coverage','navigable','wear','shoulders']];before=[p.read_bytes() for p in paths];self.render();self.assertEqual(before,[p.read_bytes() for p in paths])
 def test_stages_have_independent_appearance(self):
  a=self.render(bounds=(1020,740,160,130),stage='base');b=self.render(bounds=(1020,740,160,130),stage='transitions');c=self.render(bounds=(1020,740,160,130),stage='final');self.assertFalse(np.array_equal(a,b));self.assertFalse(np.array_equal(b,c))
 def test_context_not_tile_locked(self):
  im=self.render(bounds=(800,700,192,192),stage='base');self.assertFalse(np.array_equal(im[:32,:32],im[:32,32:64]));self.assertFalse(np.array_equal(im[32:64,:32],im[:32,:32]))
 def test_subcell_material_boundary(self):
  y,x=np.mgrid[0:1536:8,0:2048:8];materials,*_=self.ctx.weights(self.r,x,y)
  self.assertGreaterEqual(len(np.unique(materials)),3)
  changed=np.where(np.diff(materials,axis=1)!=0)[1]*8
  self.assertGreater(len(np.unique(changed%32)),2)
 def test_eight_neighbour_and_triple_junction(self):
  # Synthetic diagonal rock wedge, moist lower half, grass upper half.
  ctx=copy.copy(self.ctx);yy,xx=np.mgrid[0:48,0:64];ctx.rock=(xx+yy-62).astype(float);ctx.layers=dict(ctx.layers);ctx.layers['moistureMilli']=np.where(yy>24,700,450)
  y,x=np.mgrid[600:1000:4,750:1350:4];mat,*_=ctx.weights(self.r,x,y)
  self.assertTrue({0,2,3}.issubset(set(np.unique(mat))))
  # Smooth scalar field sees diagonals, with no four-neighbour bit mask.
  a=ctx.sample(ctx.rock,np.array([1023,1024,1025]),np.array([900,900,900]));self.assertLess(np.max(np.abs(np.diff(a))),.04)
 def test_library_editable_and_no_flips(self):
  lib=m.read(SOURCE/'LibraryV2/library.json');self.assertEqual(lib['allowedTransforms'],['translation']);self.assertEqual(lib['canvas'],[384,192]);self.assertGreater((SOURCE/'LibraryV2/terrain-motifs.aseprite').stat().st_size,1000)
 def test_aseprite_roundtrip_alpha(self):
  a=np.array(Image.open(SOURCE/'LibraryV2/motifs.png'));b=np.array(Image.open(SOURCE/'LibraryV2/motifs-preview.png'));np.testing.assert_array_equal(a,b);self.assertTrue((a[:,:,3]==0).any());self.assertTrue((a[:,:,3]==255).any())
 def test_variants_have_distinct_pixel_content(self):
  im=Image.open(SOURCE/'LibraryV2/motifs.png')
  for row in range(6):
   blocks=[im.crop((v*128+48,row*32,v*128+80,row*32+32)).tobytes() for v in range(3)]
   self.assertEqual(len(set(blocks)),3)
 def test_shoulder_appearance_does_not_change_geometry(self):
  ctx=copy.copy(self.ctx);ctx.masks=dict(ctx.masks);ctx.masks['shoulders']=np.zeros_like(ctx.masks['shoulders'])
  before=self.render(bounds=(1020,740,160,130),stage='transitions');after=np.array(ctx.render(self.r,(1020,740,160,130),'transitions'))
  self.assertFalse(np.array_equal(before,after));np.testing.assert_array_equal(ctx.masks['navigable'],self.ctx.masks['navigable'])
 def test_inclination_reduces_nonrock_details(self):
  ctx=copy.copy(self.ctx);ctx.layers=dict(ctx.layers);ctx.layers['slopeMilli']=np.full((48,64),200)
  a=self.render(bounds=(800,690,256,192));b=np.array(ctx.render(self.r,(800,690,256,192),'final'));self.assertFalse(np.array_equal(a,b))
 def test_atlas_chunk_rectangles_cover(self):
  c=m.read(SOURCE/'BuildR7/A/composition.json');w,h=c['sizePixels'];mask=np.zeros((h,w),np.uint8)
  for chunk in c['chunks']:
   x,y,a,b=chunk['rectPixels'];mask[y:y+b,x:x+a]+=1
  self.assertTrue((mask==1).all())
 def test_local_cli_artifact_manifest_and_refusal(self):
  with tempfile.TemporaryDirectory() as tmp:
   out=Path(tmp)/'local';bounds=[1024,704,96,80]
   m.render_crop(SOURCE/'Recipes/recipe-A.json',out,SOURCE/'LibraryV2',bounds)
   im=Image.open(out/'patch.png');full=Image.open(SOURCE/'BuildR7/A/final-atlas.png')
   self.assertEqual(im.tobytes(),full.crop((1024,704,1120,784)).tobytes())
   manifest=m.read(out/'manifest.json');self.assertEqual(manifest['files']['patch.png'],m.sha((out/'patch.png').read_bytes()))
   with self.assertRaises(FileExistsError):m.render_crop(SOURCE/'Recipes/recipe-A.json',out,SOURCE/'LibraryV2',bounds)
 def test_no_overwrite(self):
  with tempfile.TemporaryDirectory() as tmp:
   with self.assertRaises(FileExistsError):m.generate(SOURCE/'Recipes/recipe-A.json',tmp,SOURCE/'LibraryV2')
 def test_manifest_tamper(self):
  source=SOURCE/'BuildR7/A'
  self.assertTrue(m.verify_manifest(source))
  with tempfile.TemporaryDirectory() as tmp:
   import shutil
   for p in source.iterdir():shutil.copyfile(p,Path(tmp)/p.name)
   p=Path(tmp)/'base-atlas.png';p.write_bytes(p.read_bytes()+b'x')
   with self.assertRaises(ValueError):m.verify_manifest(tmp)
 def test_no_32px_line_peaks_without_details(self):
  im=self.ctx.render(self.r,(400,400,640,512),'base');metrics=m.seam_metrics(im)
  for direction in metrics.values():
   self.assertLess(direction['boundaryRatio'],1.6);self.assertGreater(direction['boundaryRatio'],.4)
 def test_cliff_world_mapping_not_periodic(self):
  a=np.array(m.cliff_texture(self.r,[256,192]));self.assertFalse(np.array_equal(a[:,:-32],a[:,32:]));self.assertTrue((a[:,:,3]==255).all())
if __name__=='__main__':unittest.main()
