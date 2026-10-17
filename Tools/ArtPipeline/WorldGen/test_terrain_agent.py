"""Contract tests for the offline Terrain Agent. Run with unittest discover."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("terrain_agent.py")
SPEC = importlib.util.spec_from_file_location("terrain_agent", SCRIPT)
terrain = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(terrain)
ROOT = Path(__file__).resolve().parents[3]
RECIPE = ROOT / "ArtSource/Labs/World2026/WorldGen/Recipes/valdoria-highlands-pilot.json"
PATCH = ROOT / "ArtSource/Labs/World2026/WorldGen/Recipes/valdoria-highlands-edit.example.json"


class TerrainAgentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = json.loads(RECIPE.read_text(encoding="utf-8"))
        cls.patch = json.loads(PATCH.read_text(encoding="utf-8"))

    def test_contract_and_materials(self):
        region = terrain.generate(self.recipe)
        w, h = region["size"]
        self.assertEqual((w, h), (64, 48))
        self.assertEqual(set(region["layers"]["material"]) - set(terrain.MATERIALS), set())
        for layer in region["layers"].values():
            self.assertEqual(len(layer), w * h)
        self.assertGreater(region["summary"]["walkable"], 0)

    def test_repeatability_and_seed(self):
        a = terrain.generate(self.recipe)
        b = terrain.generate(self.recipe)
        self.assertEqual(terrain.canonical(a), terrain.canonical(b))
        changed = dict(self.recipe, seed=self.recipe["seed"] + 1)
        self.assertNotEqual(a["layers"]["elevationMilli"], terrain.generate(changed)["layers"]["elevationMilli"])

    def test_protected_route_is_walkable(self):
        r = terrain.generate(self.recipe)
        self.assertTrue(all(w for w, reserved in zip(r["layers"]["walkable"], r["layers"]["reserved"]) if reserved))
        w = self.recipe["size"][0]
        self.assertTrue(r["layers"]["reserved"][35 * w + 6])

    def test_patch_changes_only_requested_kind(self):
        before = terrain.generate(self.recipe)
        after = terrain.generate(self.recipe, self.patch)
        self.assertNotEqual(before["layers"]["elevationMilli"], after["layers"]["elevationMilli"])
        self.assertIn("rock", after["layers"]["material"])
        self.assertEqual(before["size"], after["size"])

    def test_generate_verify_refuse_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "region"
            m = terrain.write_output(self.recipe, None, out)
            self.assertEqual(terrain.main(["verify", "--recipe", str(RECIPE), "--output", str(out)]), 0)
            self.assertEqual(set(m["outputs"]), set(terrain.OUTPUTS))
            with self.assertRaises(FileExistsError):
                terrain.write_output(self.recipe, None, out)
            (out / "region.json").write_text("tampered", encoding="utf-8")
            self.assertEqual(terrain.main(["verify", "--recipe", str(RECIPE), "--output", str(out)]), 1)

    def test_reject_invalid_recipe_and_patch(self):
        with self.assertRaises(ValueError):
            terrain.generate(dict(self.recipe, size=[0, 0]))
        with self.assertRaises(ValueError):
            terrain.generate(self.recipe, {"schema": "valdoria-terrain-patch/v1", "operations":
                                          [{"kind": "paint", "center": [10, 10], "radius": 3, "material": "lava"}]})


if __name__ == "__main__":
    unittest.main()
