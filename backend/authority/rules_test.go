package authority

import (
	"encoding/base64"
	"encoding/json"
	"testing"
)

func TestValidatedEncounterRequiresPreparationAndServerDamage(t *testing.T) {
	e := Encounter{HP: 60, Phase: "ready"}
	hp := 100
	if _, _, _, err := ResolveEncounter(e, hp, "dodge", false); err == nil {
		t.Fatal("free dodge accepted")
	}
	for i := 0; i < 3; i++ {
		var err error
		var defeated bool
		e, hp, defeated, err = ResolveEncounter(e, hp, "attack", false)
		if err != nil {
			t.Fatal(err)
		}
		if i < 2 {
			if defeated || e.Phase != "preparing" {
				t.Fatal("phase")
			}
			e, hp, _, err = ResolveEncounter(e, hp, "dodge", false)
			if err != nil || e.Phase != "exposed" {
				t.Fatal("dodge")
			}
		} else if !defeated || e.HP != 0 {
			t.Fatal("defeat")
		}
	}
	if hp != 100 {
		t.Fatal("valid dodge took damage")
	}
	if _, _, _, err := ResolveEncounter(e, hp, "attack", false); err == nil {
		t.Fatal("dead encounter attack")
	}
}
func TestEncounterPunishesAttackingIntoPreparationAndBoundsWeakness(t *testing.T) {
	e := Encounter{HP: 60, Phase: "preparing"}
	e, hp, _, err := ResolveEncounter(e, 100, "attack", true)
	if err != nil || hp != 85 || e.HP != 60 {
		t.Fatal("server counterattack")
	}
	e.Phase = "exposed"
	e, _, _, err = ResolveEncounter(e, hp, "attack", true)
	if err != nil || e.HP != 30 {
		t.Fatal("weakness functional effect")
	}
	if _, _, _, err = ResolveEncounter(e, 0, "attack", true); err == nil {
		t.Fatal("dead character accepted")
	}
	if _, _, _, err = ResolveEncounter(e, 100, "CreatureDefeated", true); err == nil {
		t.Fatal("client defeat accepted")
	}
}
func TestDevelopmentImportIsBoundedAndReferencesExistingFacts(t *testing.T) {
	in := DevelopmentImport{Version: 1, SourceVersion: 3, SourceActor: "player", SourceWorld: "offline-clearing", SourceChecksum: base64.StdEncoding.EncodeToString(make([]byte, 32)), Facts: []ImportFact{{ID: "event", Kind: "TraceExamined", Payload: json.RawMessage(`{}`)}}, Knowledge: []ImportKnowledge{{NPCID: "orin", FactID: "event"}}, Abilities: []string{"weakness-reading"}, Inventory: map[string]int{"corruption-sample": 1}}
	if in.Validate() != nil {
		t.Fatal("valid dev import")
	}
	in.Knowledge[0].FactID = "missing"
	if in.Validate() == nil {
		t.Fatal("bad source")
	}
	in.Knowledge[0].FactID = "event"
	in.Inventory["corruption-sample"] = -1
	if in.Validate() == nil {
		t.Fatal("negative inventory")
	}
	delete(in.Inventory, "corruption-sample")
	in.Abilities = []string{"invented"}
	if in.Validate() == nil {
		t.Fatal("invented ability")
	}
}
