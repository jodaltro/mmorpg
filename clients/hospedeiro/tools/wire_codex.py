"""E2 part 2, engine wiring: codex, secret niches, adaptation and the rota decision. One-off edits; run from anywhere."""
from pathlib import Path

root = Path(__file__).resolve().parents[3] / "engine"


def sub(rel, a, b):
    p = root / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


sub("core/def.go", "	Niches   []NicheDef   `json:\"niches,omitempty\"`\n",
    "	Niches   []NicheDef   `json:\"niches,omitempty\"`\n	// Codex, Exploring: the codex of the body, adaptation and the pace of the rota decision; see codex.go.\n	Codex     []CodexDef    `json:\"codex,omitempty\"`\n	Exploring *ExploringDef `json:\"exploring,omitempty\"`\n")
sub("core/exploration.go", "	// Unique niches reward only the first player to find them.\n	Unique bool `json:\"unique,omitempty\"`\n",
    "	// Unique niches reward only the first player to find them.\n	Unique bool `json:\"unique,omitempty\"`\n	// When makes it a secret: the niche exists for a player only while this holds (a niche that shows only in fever, only in sleep).\n	When *Cond `json:\"when,omitempty\"`\n")
sub("core/exploration.go", "type ExploreView struct {\n	Passages []PassageView `json:\"passages\"`\n	Niches   []NicheView   `json:\"niches\"`\n}",
    "type ExploreView struct {\n	Passages []PassageView `json:\"passages\"`\n	Niches   []NicheView   `json:\"niches\"`\n	Adapted  []string      `json:\"adapted\"`\n	Route    string        `json:\"route,omitempty\"` // the niche the advisor pointed this player to\n}")
sub("core/exploration.go", "	if origin != \"adapter\" || !ok || e.Kind != w.U.PlayerKind || e.Region != n.Region {\n		return reject(\"niche\")\n	}\n",
    "	if origin != \"adapter\" || !ok || e.Kind != w.U.PlayerKind || e.Region != n.Region || n.When != nil && !w.Holds(s, *n.When, Bind{\"self\": p}) {\n		return reject(\"niche\")\n	}\n")
sub("core/exploration.go", "	v := &ExploreView{Passages: []PassageView{}, Niches: []NicheView{}}\n",
    "	pe := s.Entities[p]\n	v := &ExploreView{Passages: []PassageView{}, Niches: []NicheView{}, Adapted: adaptedRegions(pe)}\n	if r := pe.Tag[tagRota]; r != \"\" && hasOption(w.rotaOptions(s, p), r) {\n		v.Route = r\n	}\n")
sub("core/exploration.go", "		found := s.Deeds[p][nicheDeed(n.ID)] > 0\n		nv :=",
    "		found := s.Deeds[p][nicheDeed(n.ID)] > 0\n		if !found && n.When != nil && !w.Holds(s, *n.When, Bind{\"self\": p}) {\n			continue // a secret the body is not showing now\n		}\n		nv :=")
sub("core/view.go", "	Explore   *ExploreView     `json:\"explore,omitempty\"`   // passages (open or closed) and niches\n",
    "	Explore   *ExploreView     `json:\"explore,omitempty\"`   // passages (open or closed) and niches\n	Codex     []CodexView      `json:\"codex,omitempty\"`     // the codex of the body\n")
sub("core/view.go", "Explore: w.exploreView(s, observer)}", "Explore: w.exploreView(s, observer), Codex: w.codexView(s, observer)}")
sub("core/tick.go", "	w.direct(s)\n", "	w.direct(s)\n	w.adaptTick(s, cause)\n	w.rotaTick(s, cause)\n	for _, p := range sortedIDs(s.Entities) {\n		w.codexTick(s, p, cause)\n	}\n")
sub("core/step.go", "	w.findPlace(s, c.Actor, ID(c.Region))\n", "	w.findPlace(s, c.Actor, ID(c.Region))\n	w.codexTick(s, c.Actor, cause)\n")
sub("core/exploration.go", "	w.discover(s, p, cause)\n	return nil\n}\n\nfunc (w *World) exploreView", "	w.discover(s, p, cause)\n	w.codexTick(s, p, cause)\n	return nil\n}\n\nfunc (w *World) exploreView")
sub("core/quest.go", "	case \"dungeon\":\n		if err := w.decideDungeon(s, d, choice, cause); err != nil {\n			return err\n		}\n",
    "	case \"dungeon\":\n		if err := w.decideDungeon(s, d, choice, cause); err != nil {\n			return err\n		}\n	case decisionRota:\n		if err := w.decideRota(s, d, choice, cause); err != nil {\n			return err\n		}\n")
sub("core/quest.go", "d.Kind == \"ability\" || d.Kind == \"dungeon\" {", "d.Kind == \"ability\" || d.Kind == \"dungeon\" || d.Kind == decisionRota {")
sub("core/compile.go", "	v := &validator{w: w, ents: ents}\n", "	v := &validator{w: w, ents: ents}\n	if err := w.compileCodex(v); err != nil {\n		return nil, err\n	}\n")
sub("core/compile.go", "if !isAction && !slices.Contains(builtinDeeds, c.Deeds.Action) ||", "if !isAction && !slices.Contains(builtinDeeds, c.Deeds.Action) && !strings.HasPrefix(c.Deeds.Action, \"nicho:\") ||")
sub("advisor/jev.go", "	\"story\":      \"Choose how",
    "	\"rota\":       \"A cell is exploring the body of its host. Choose the single hidden place to point it to next, judging from how this particular player lives: the genes they express, what they already found, how they play, and the state of the body. Prefer a place that fits who they are or opens a path they have not walked; avoid sending them back over ground they know. Use only the supplied criteria IDs.\",\n	\"story\":      \"Choose how")
print("ok")
