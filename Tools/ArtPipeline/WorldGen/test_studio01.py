import unittest, copy
import studio01 as studio
import terrain_agent as terrain
from PIL import Image

class StudioTests(unittest.TestCase):
    def test_thermal_conserves_mass_and_reduces_peak(self):
        h=[[0.,0.,0.],[0.,1.,0.],[0.,0.,0.]]
        out=terrain.thermal_erode(h,[[False]*3 for _ in range(3)],8,.05)
        self.assertAlmostEqual(sum(map(sum,out)),1.)
        self.assertLess(out[1][1],1.)
        self.assertGreaterEqual(min(map(min,out)),0)
    def test_thermal_respects_reservations(self):
        h=[[0.,0.,0.],[0.,1.,0.],[0.,0.,0.]]; fixed=[[False]*3 for _ in range(3)];fixed[1][1]=True
        self.assertEqual(terrain.thermal_erode(h,fixed,8,.05),h)
    def test_compact_patch_and_neighbour_halo(self):
        r=studio.recipe('A');r['thermalErosion']['iterations']=0
        before=terrain.generate(r);patch={'schema':'valdoria-terrain-patch/v1','operations':[{'kind':'raise','center':[45,10],'radius':4,'strength':.2}]}
        after=terrain.generate(r,patch);self.assertNotEqual(before,after)
        for i,(a,b) in enumerate(zip(before['layers']['elevationMilli'],after['layers']['elevationMilli'])):
            if (i%64-45)**2+(i//64-10)**2>16:self.assertEqual(a,b)
    def test_all_candidates_routes_have_actor_clearance(self):
        for v in 'ABC':
            r=studio.recipe(v);out=studio.decorate(terrain.generate(r));self.assertTrue(out['navigation']['routeConnected'])
            self.assertEqual(len(out['presentation']['tileIndices']),3072)
            self.assertTrue(all(0<=i<140 for i in out['presentation']['tileIndices']))
            # Cell centres on route polyline have >=1 cell of blocked-cell clearance.
            for i,blocked in enumerate(out['layers']['blocked']):
                if blocked:
                    distance=min(terrain.segment_distance(i%64,i//64,a,b) for a,b in zip(r['route']['points'],r['route']['points'][1:]))
                    self.assertGreater(distance,r['route']['halfWidth'])
    def test_material_variant_joins(self):
        for kind in studio.PALETTES:
            for v in range(4):
                im=studio.tile(kind,v);other=studio.tile(kind,(v+1)%4)
                self.assertEqual([im.getpixel((31,q)) for q in range(32)],[other.getpixel((0,q)) for q in range(32)])
                self.assertEqual([im.getpixel((q,31)) for q in range(32)],[other.getpixel((q,0)) for q in range(32)])
    def test_no_full_region_texture(self):
        # Fixed material library does not grow with region area.
        import pathlib
        p=studio.SOURCE/'Materials/surfaces.png'
        with Image.open(p) as im:self.assertEqual(im.size,(512,288))
    def test_candidate_refuses_destination(self):
        with self.assertRaises(FileExistsError):studio.build(studio.SOURCE/'Regions')
