"""Wires the balance table into the ability catalog and the mutation generator (one-off edits)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def sub(path, a, b):
    p = root / path
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (path, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


# abilities: defaults in code, tuned numbers in data/balance.json
sub("scripts/domain/bio_ability_catalog.gd", "static func _a(id: StringName,", """## The tuned numbers live in data/balance.json (written by tests/balance_tune.gd from BioBalance); they replace the defaults above.
static func _apply_balance() -> void:
	var path := "res://data/balance.json"
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data as Dictionary).has("abilities"):
		return
	for id in data["abilities"]:
		var key := StringName(str(id))
		if _defs.has(key):
			for param in data["abilities"][id]:
				_defs[key][str(param)] = data["abilities"][id][param]


static func _a(id: StringName,""")
sub("scripts/domain/bio_ability_catalog.gd", '	_a(&"febre_dirigida", &"t_auxiliar", "zone", Color(1.0, 0.55, 0.25), 24, 12.0, {"style": "heat", "reach": 4.5, "radius": 2.8, "duration": 5.0, "tick": 9.0, "slow": 0.6})\n', '	_a(&"febre_dirigida", &"t_auxiliar", "zone", Color(1.0, 0.55, 0.25), 24, 12.0, {"style": "heat", "reach": 4.5, "radius": 2.8, "duration": 5.0, "tick": 9.0, "slow": 0.6})\n	_apply_balance()\n')

# generator: reads the tuned genes, always writes stats text from the numbers, writes the rarity table for the tuner
sub("tools/gen_mutations.py", """def desc(gene, old):
    if gene["keep"]:
        d = old.get("desc", "")
        cuts = [d.find(" " + n + ":") for n in ABILITY_NAMES.values() if d.find(" " + n + ":") >= 0]
        if cuts:  # idempotent: drop the perk text a previous run appended
            d = d[:min(cuts)]
    else:
        d = (gene["flavour"] + " " if gene["flavour"] else "") + stats_text(gene["stats"]) + "."""", """def desc(gene, old):
    d = (gene["flavour"] + " " if gene["flavour"] else "") + stats_text(gene["stats"]) + "."""")
sub("tools/gen_mutations.py", "def main():\n", """def apply_balance():
    \"\"\"Replaces the stats and perks of each mutation with the tuned ones (data/balance.json, from BioBalance).\"\"\"
    path = ROOT / "clients/hospedeiro/data/balance.json"
    if not path.exists():
        return
    tuned = json.loads(path.read_text(encoding="utf-8")).get("genes", {})
    for gene in G:
        t = tuned.get(gene["id"])
        if not t:
            continue
        gene["stats"] = {k: (float(v) if k != "atp_regen" else float(v)) for k, v in t["mods"].items()}
        gene["perks"] = {ab: {k: (int(v) if k.startswith("+") else float(v)) for k, v in params.items()} for ab, params in t["perks"].items()}


def main():
    apply_balance()
    rarity = {gene["id"]: gene["rarity"] for gene in G}
    (ROOT / "clients/hospedeiro/data").mkdir(exist_ok=True)
    (ROOT / "clients/hospedeiro/data/gene_rarity.json").write_text(json.dumps(rarity, indent=1), encoding="utf-8")
""")
print("ok")
