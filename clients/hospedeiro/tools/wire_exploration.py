"""E2 (exploration), engine wiring: passages and niches in the universe definition, the view, the move check and the verb.
One-off edits; run from anywhere."""
from pathlib import Path

root = Path(__file__).resolve().parents[3] / "engine/core"


def sub(name, a, b):
    p = root / name
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (name, a[:60])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


sub("def.go", "	Vitals []VitalDef `json:\"vitals,omitempty\"`\n",
    "	Vitals []VitalDef `json:\"vitals,omitempty\"`\n	// Passages and Niches: exploring the body; see exploration.go.\n	Passages []PassageDef `json:\"passages,omitempty\"`\n	Niches   []NicheDef   `json:\"niches,omitempty\"`\n")
sub("view.go", "	Vitals    []VitalView      `json:\"vitals,omitempty\"`    // the public numbers of the body\n",
    "	Vitals    []VitalView      `json:\"vitals,omitempty\"`    // the public numbers of the body\n	Explore   *ExploreView     `json:\"explore,omitempty\"`   // passages (open or closed) and niches\n")
sub("view.go", "Vitals: w.vitalsView(s)}", "Vitals: w.vitalsView(s), Explore: w.exploreView(s, observer)}")
sub("step.go", "	case actEvolve:\n		return w.chooseMutation(s, origin, actor, args, cause)\n",
    "	case actEvolve:\n		return w.chooseMutation(s, origin, actor, args, cause)\n	case actFindNiche:\n		return w.findNiche(s, origin, actor, args, cause)\n")
sub("step.go", "	if ent.Region == c.Region {\n		if ent.Tag[\"spot\"]",
    "	if ps, ok := w.passageBetween(ent.Region, c.Region); ok && ent.Region != c.Region && ent.Kind == w.U.PlayerKind && !w.passageOpen(s, c.Actor, ps) {\n		return reject(\"passage\") // the way is closed to a cell without the key\n	}\n	if ent.Region == c.Region {\n		if ent.Tag[\"spot\"]")
sub("compile.go", "	if err := w.compileVitals(ents); err != nil {\n		return nil, err\n	}\n",
    "	if err := w.compileVitals(ents); err != nil {\n		return nil, err\n	}\n	if err := w.compileExploration(ents); err != nil {\n		return nil, err\n	}\n")
print("ok")
