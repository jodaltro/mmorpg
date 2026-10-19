import copy
import unittest
import village02_blockout as v

class Village02Tests(unittest.TestCase):
    def test_compile_does_not_mutate_authored_recipe(self):
        recipe=v.recipe();saved=copy.deepcopy(recipe)
        first=v.compile_plan(recipe);second=v.compile_plan(recipe)
        self.assertEqual(recipe,saved);self.assertEqual(first,second)

    def test_moved_house_cannot_silently_keep_old_door_access(self):
        recipe=v.recipe();recipe['lots'][0]['anchor'][0]+=20
        with self.assertRaisesRegex(ValueError,'door approach'):
            v.compile_plan(recipe)

    def test_bridge_cut_disconnects_every_interior_target(self):
        d=v.compile_plan(v.recipe());_,opened=v.navigation(d);_,closed=v.navigation(d,True)
        self.assertTrue(opened['allConnected']);self.assertFalse(any(closed['targets'].values()))

    def test_building_resize_updates_geometry_and_physics_together(self):
        a=v.recipe();b=copy.deepcopy(a);b['lots'][0]['width']+=2
        aa=v.compile_plan(a);bb=v.compile_plan(b)
        for d in (aa,bb):
            volume=next(x for x in d['volumes'] if x['id']=='H1')
            physical=next(x for x in d['physical'] if x['id']=='H1')
            self.assertEqual(volume['footprint'],physical['polygon'])
        self.assertNotEqual(aa['volumes'][0]['faces'],bb['volumes'][0]['faces'])

    def test_gate_spans_never_create_ground_blockers(self):
        d=v.compile_plan(v.recipe());ids={p['id'] for p in d['physical']}
        for span in [x for x in d['volumes'] if x['kind']=='span']:
            self.assertNotIn(span['id'],ids);self.assertGreaterEqual(span['height'],7)

    def test_ids_and_repeatability(self):
        self.assertEqual(v.compile_plan(v.recipe()),v.compile_plan(v.recipe()))
        for key in ['volumes','physical','roads']:
            ids=[x['id'] for x in v.compile_plan(v.recipe())[key]];self.assertEqual(len(ids),len(set(ids)))

    def test_lots_do_not_overlap_building_footprints(self):
        from PIL import Image,ImageDraw
        import numpy as np
        masks=[]
        for s in v.recipe()['lots']:
            im=Image.new('1',(v.W*4,v.H*4));ImageDraw.Draw(im).polygon([(round(x*4),round(y*4)) for x,y in v.footprint(s)],fill=1)
            mask=np.array(im)
            for old in masks:self.assertFalse(np.any(mask&old),s['id'])
            masks.append(mask)

if __name__=='__main__':unittest.main()
