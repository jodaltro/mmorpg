import copy,json,tempfile,unittest
from pathlib import Path
import numpy as np
from scipy.ndimage import label
import organic_roads as roads
import terrain_agent as terrain


def flat(w=40,h=32):
    n=w*h
    return {'schema':'valdoria-world-region/v1','regionId':'road-test','seed':1,'size':[w,h],'cellSizeUnits':1.,
       'layers':{'walkable':[True]*n,'blocked':[False]*n,'elevationMilli':[400]*n,'slopeMilli':[0]*n,'reserved':[False]*n,'waterCandidate':[False]*n}}

def recipe():
    r=roads.study_recipe('A');r['waypoints']=[[3.5,25.5],[15.5,22.5],[24.5,12.5],[36.5,5.5]];r['protectedAreas']=[]
    return r

class OrganicRoadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.region=terrain.read_json(roads.BASE);cls.r=roads.study_recipe('B');cls.seg,cls.cost,cls.effective=roads.segments(cls.region,cls.r)
        cls.masks=roads.rasterize(cls.seg,cls.r,[0,0,64,48])
    def test_seed_geometry_and_bytes_repeat(self):
        second,_,_=roads.segments(self.region,self.r)
        self.assertEqual(terrain.canonical(second),terrain.canonical(self.seg))
        repeated=roads.rasterize(second,self.r,[0,0,64,48])
        for key,a in self.masks.items():self.assertTrue(np.array_equal(a,repeated[key]))
    def test_seed_variation_is_controlled(self):
        r=copy.deepcopy(self.r);r['seed']+=1;other,_,_=roads.segments(self.region,r)
        self.assertEqual([s['guides'] for s in other],[s['guides'] for s in self.seg])
        self.assertNotEqual(other[0]['samples'],self.seg[0]['samples'])
        self.assertGreaterEqual(min(p[4] for s in other for p in s['samples']),r['width']['min'])
    def test_mandatory_waypoints_and_tangents(self):
        for i,s in enumerate(self.seg):
            np.testing.assert_allclose(s['samples'][0][:2],self.r['waypoints'][i],atol=1e-6)
            np.testing.assert_allclose(s['samples'][-1][:2],self.r['waypoints'][i+1],atol=1e-6)
        for a,b in zip(self.seg,self.seg[1:]):
            u=np.array(a['samples'][-1][:2])-a['samples'][-2][:2];v=np.array(b['samples'][1][:2])-b['samples'][0][:2]
            self.assertGreater(float(np.dot(roads.unit(u),roads.unit(v))),.999)
            self.assertAlmostEqual(a['samples'][-1][3],b['samples'][0][3],places=5)
    def test_minimum_width_and_distance_sampling(self):
        for s in self.seg:
            p=np.array(s['samples']);self.assertGreaterEqual(float(p[:,4].min()),self.r['width']['min'])
            self.assertLessEqual(float(p[:,3].max()),self.r['width']['max'])
            distances=np.linalg.norm(np.diff(p[:,:2],axis=0),axis=1)
            self.assertLessEqual(float(distances.max()),.12501)
            self.assertGreater(float(distances.min()),.12)
            self.assertLess(float(np.max(np.abs(np.diff(p[:,3])))),.04)
    def test_visual_core_and_no_holes(self):
        nav=self.masks['navigable']>0
        self.assertTrue(np.all(self.masks['coverage'][nav]==255))
        self.assertEqual(label(nav)[1],1)
        self.assertEqual(label(self.masks['coverage']>0,structure=np.ones((3,3)))[1],1)
    def test_forbidden_clearance_for_whole_corridor(self):
        for s in self.seg:
            for p in s['samples']:
                self.assertGreaterEqual(self.cost.clearance(np.array(p[:2]))+.00001,p[3]/2+self.r['edges']['amplitude']+self.r['edges']['shoulder'])
        logical=roads.logical_masks(self.seg,self.region,self.cost)['navigable']
        self.assertTrue(all(not occ or not blocked for occ,blocked in zip(logical,self.cost.forbidden.flat)))
    def test_terrain_never_changes(self):
        before=terrain.canonical(self.region);roads.segments(self.region,self.r)
        self.assertEqual(before,terrain.canonical(self.region))
    def test_long_diagonal_has_subcell_edges(self):
        region=flat();r=recipe();r['waypoints']=[[3.5,27.5],[36.5,3.5]]
        seg,_,_=roads.segments(region,r);m=roads.rasterize(seg,r,[0,0,40,32])['coverage']
        # Detect boundaries at all 32 possible subcell offsets, not only cell edges.
        occupied=m>0;left=[]
        for row in occupied:
            indices=np.flatnonzero(row)
            if len(indices):left.append(int(indices[0])%32)
        self.assertGreater(len(set(left)),26)
        self.assertGreater(np.count_nonzero((m>0)&(m<255)),0)
        self.assertEqual(label(occupied)[1],1)
    def test_local_patch_has_bounded_support(self):
        patch={'schema':'valdoria-road-patch/v1','waypointEdits':[{'index':2,'point':[25.5,28.5]}]}
        changed,_,_=roads.segments(self.region,self.r,patch)
        self.assertNotEqual(changed[1]['samples'],self.seg[1]['samples'])
        np.testing.assert_array_equal(np.array(changed[4]['samples'])[np.array(changed[4]['samples'])[:,2]>3.1],np.array(self.seg[4]['samples'])[np.array(self.seg[4]['samples'])[:,2]>3.1])
    def test_adjacent_chunks_match_shared_global_road(self):
        region=flat();r=recipe();seg,_,_=roads.segments(region,r)
        full=roads.rasterize(seg,r,[0,0,40,32]);left=roads.rasterize(seg,r,[0,0,20,32]);right=roads.rasterize(seg,r,[20,0,20,32])
        for key in full:np.testing.assert_array_equal(full[key],np.concatenate([left[key],right[key]],axis=1))
    def test_blocking_wall_is_authoring_error(self):
        region=flat();r=recipe()
        for y in range(32):region['layers']['blocked'][y*40+20]=True;region['layers']['walkable'][y*40+20]=False
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'impossible'
            with self.assertRaises(roads.AuthoringError):roads.build(region,r,out)
            self.assertFalse(out.exists())
    def test_water_requires_explicit_crossing(self):
        region=flat();r=recipe();r['waypoints']=[[3.5,16.5],[36.5,16.5]]
        for y in range(32):region['layers']['waterCandidate'][y*40+20]=True
        with self.assertRaises(roads.AuthoringError):roads.segments(region,r)
        r['constraints']['authorizedCrossingCells']=[y*40+20 for y in range(12,21)]
        self.assertTrue(roads.segments(region,r)[0])
    def test_topography_detours_instead_of_cutting_hill(self):
        region=flat();r=recipe();r['waypoints']=[[3.5,16.5],[36.5,16.5]]
        for y in range(12,21):
            for x in range(17,24):
                i=y*40+x;region['layers']['blocked'][i]=True;region['layers']['walkable'][i]=False;region['layers']['elevationMilli'][i]=950
        seg,cost,_=roads.segments(region,r)
        self.assertGreater(len(seg[0]['guides']),2)
        self.assertTrue(all(cost.clearance(np.array(p[:2]))>=cost.radius-.0001 for p in seg[0]['samples']))
    def test_protected_area_and_slope_are_exclusions(self):
        region=flat();r=recipe();r['protectedAreas']=[{'rect':[17,12,7,9],'allowRoad':False}]
        cost=roads.TerrainCost(region,r);self.assertTrue(cost.forbidden[16,20])
        region['layers']['slopeMilli'][100]=900;self.assertTrue(roads.TerrainCost(region,r).forbidden.flat[100])
    def test_generate_manifest_link_tamper_and_overwrite(self):
        region=flat();r=recipe()
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'road';roads.build(region,r,out)
            self.assertTrue(roads.verify(region,r,out))
            link=terrain.read_json(out/'world-region-linked.json');self.assertEqual(link['schema'],'valdoria-world-region/v2')
            self.assertEqual(link['terrainRef']['sha256'],terrain.digest(roads.canonical(region)))
            with self.assertRaises(FileExistsError):roads.build(region,r,out)
            (out/'coverage.png').write_bytes(b'tamper')
            with self.assertRaises(roads.AuthoringError):roads.verify(region,r,out)
    def test_reject_invalid_width_and_patch(self):
        r=copy.deepcopy(self.r);r['width']['min']=10
        with self.assertRaises(roads.AuthoringError):roads.segments(self.region,r)
        with self.assertRaises(roads.AuthoringError):roads.segments(self.region,self.r,{'schema':'invalid'})
        invalid=copy.deepcopy(self.region);invalid['layers']['walkable'][0]=False
        with self.assertRaises(roads.AuthoringError):roads.segments(invalid,self.r)
        invalid_recipe=copy.deepcopy(self.r);invalid_recipe['protectedAreas']=[{'rect':[-1,0,2,2]}]
        with self.assertRaises(roads.AuthoringError):roads.segments(self.region,invalid_recipe)

    def test_subcell_coverage_avoids_exclusions(self):
        forbidden=np.repeat(np.repeat(self.cost.forbidden,32,axis=0),32,axis=1)
        self.assertTrue(np.all(self.masks['coverage'][forbidden]==0))
        self.assertTrue(np.all(self.masks['shoulders'][forbidden]==0))
    def test_trail_adds_valley_guides_preserving_mandatory_points(self):
        a=roads.study_recipe('A');c=roads.study_recipe('C')
        self.assertTrue(all(p in c['waypoints'] for p in a['waypoints']))
        self.assertEqual(a['seed'],c['seed'])
        s,_,_=roads.segments(self.region,c)
        self.assertEqual(len(s),7)
        self.assertLess(max(span['maxCurvature'] for span in s),c['curve']['maxCurvature'])
