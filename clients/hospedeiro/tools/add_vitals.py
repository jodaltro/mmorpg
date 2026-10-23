"""E1 (living body): adds the body's vital signs, the lung infection chain (infection -> inflammation -> fever -> hypoxia) and the
hormones to the Hospedeiro universe. Idempotent: ids already present are replaced. Run from anywhere."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def num(e, k, op, v):
    return {"num": {"e": e, "k": k, "op": op, "v": v}}


def fact(pred, s):
    return {"fact": {"p": pred, "s": s}}


def adj(e, k, d, lo=None, hi=None):
    out = {"op": "adjust", "e": e, "k": k, "d": d}
    if lo is not None:
        out["min"] = lo
    if hi is not None:
        out["max"] = hi
    return out


def emit(event, text, reveals=None):
    out = {"op": "emit", "event": event, "public": True, "text": text}
    if reveals:
        out["reveals"] = reveals
    return out


if "corpo" not in u["kinds"]:
    u["kinds"].append("corpo")
if not any(e["id"] == "corpo" for e in u["entities"]):
    u["entities"].append({"id": "corpo", "kind": "corpo", "name": "O Hospedeiro",
                          "num": {"temperatura": 370, "inflamacao": 0, "adrenalina": 0, "cortisol": 0, "insulina": 20}})

febre_cond = {"any": [{"all": [fact("foco", "sangue"), num("sangue", "carga", ">=", 30)]},
                      {"all": [fact("foco", "pulmao"), num("corpo", "inflamacao", ">=", 30)]}]}

rules = [
    {"id": "pulmao-cresce", "every": 3, "when": fact("foco", "pulmao"), "effects": [adj("pulmao", "carga", 4, 0, 100)]},
    {"id": "citocinas-sobem", "every": 2, "when": {"any": [fact("foco", "pulmao"), fact("foco", "sangue")]},
     "effects": [adj("corpo", "inflamacao", 6, 0, 100)]},
    {"id": "inflamacao-cai", "every": 3, "when": {"all": [{"not": fact("foco", "pulmao")}, {"not": fact("foco", "sangue")}]},
     "effects": [adj("corpo", "inflamacao", -4, 0, 100)]},
    {"id": "hipoxia-pulmao", "every": 2, "when": num("pulmao", "carga", ">=", 30), "effects": [adj("pulmao", "oxigenio", -4, 40, 100)]},
    {"id": "ar-volta", "every": 2, "when": num("pulmao", "carga", "<", 30), "effects": [adj("pulmao", "oxigenio", 3, 0, 100)]},
    {"id": "febre-age-pulmao", "every": 2, "when": {"all": [fact("febre", "sangue"), num("pulmao", "carga", ">", 0)]},
     "effects": [adj("pulmao", "carga", -3, 0)]},
    {"id": "foco-pulmao-extinto", "every": 2, "when": {"all": [num("pulmao", "carga", "<=", 0), fact("foco", "pulmao")]},
     "effects": [{"op": "retract", "fact": {"p": "foco", "s": "pulmao"}},
                 emit("cura-pulmao", "O foco de infecção nos alvéolos se apaga.", {"p": "foco", "s": "pulmao"})]},
    {"id": "temperatura-sobe", "every": 1, "when": fact("febre", "sangue"), "effects": [adj("corpo", "temperatura", 3, 0, 395)]},
    {"id": "temperatura-desce", "every": 1, "when": {"not": fact("febre", "sangue")}, "effects": [adj("corpo", "temperatura", -2, 370, 420)]},
    {"id": "adrenalina-sobe", "every": 2, "when": num("corpo", "inflamacao", ">=", 30), "effects": [adj("corpo", "adrenalina", 6, 0, 100)]},
    {"id": "adrenalina-cai", "every": 2, "when": num("corpo", "inflamacao", "<", 30), "effects": [adj("corpo", "adrenalina", -4, 0, 100)]},
    {"id": "cortisol-sobe", "every": 3, "when": num("corpo", "adrenalina", ">=", 50), "effects": [adj("corpo", "cortisol", 4, 0, 100)]},
    {"id": "cortisol-cai", "every": 3, "when": num("corpo", "adrenalina", "<", 50), "effects": [adj("corpo", "cortisol", -2, 0, 100)]},
    {"id": "insulina-cai", "every": 3, "when": num("corpo", "insulina", ">", 20), "effects": [adj("corpo", "insulina", -3, 20, 100)]},
    {"id": "pulso-acelera", "every": 2, "when": {"any": [num("corpo", "adrenalina", ">=", 30), num("corpo", "temperatura", ">", 375)]},
     "effects": [adj("coracao", "pulso", 3, 0, 130)]},
    {"id": "pulso-repousa", "every": 2, "when": {"all": [num("corpo", "adrenalina", "<", 30), num("corpo", "temperatura", "<=", 375)]},
     "effects": [adj("coracao", "pulso", -3, 62, 130)]},
]
by_id = {r["id"]: r for r in u["rules"]}
for r in rules:
    by_id[r["id"]] = r
u["rules"] = list(by_id.values())

hap = {h["id"]: h for h in u["happenings"]}
hap["infeccao-pulmonar"] = {
    "id": "infeccao-pulmonar", "title": "Bactérias nos alvéolos",
    "desc": "Uma infecção começa no pulmão: inflamação, citocinas no sangue e febre em seguida.",
    "intensity": 2, "cooldown": 45,
    "when": {"all": [{"not": fact("foco", "pulmao")}, {"not": fact("febre", "sangue")}, num("pulmao", "carga", "<=", 0)]},
    "effects": [{"op": "assert", "fact": {"p": "foco", "s": "pulmao"}}, adj("pulmao", "carga", 25, 0, 100),
                emit("infeccao-pulmonar", "Bactérias chegam aos alvéolos: o pulmão se inflama e as citocinas começam a subir.",
                     {"p": "foco", "s": "pulmao"})],
}
hap["febre"]["when"] = {"all": [{"not": fact("febre", "sangue")}, febre_cond]}
hap["febre"]["desc"] = "O corpo esquenta para conter a infecção: o corpo todo acelera, os vírions ficam lentos."
hap["refeicao"]["effects"] = [e for e in hap["refeicao"]["effects"] if not (e.get("k") == "insulina")]
hap["refeicao"]["effects"].insert(1, adj("corpo", "insulina", 40, 0, 100))
u["happenings"] = list(hap.values())

u["vitals"] = [
    {"id": "temperatura", "label": "Temperatura", "e": "corpo", "k": "temperatura", "min": 360, "max": 410, "low": 365, "high": 375},
    {"id": "pulso", "label": "Pulso", "e": "coracao", "k": "pulso", "min": 50, "max": 140, "low": 60, "high": 90},
    {"id": "oxigenio", "label": "Oxigênio", "e": "pulmao", "k": "oxigenio", "min": 0, "max": 100, "low": 70, "high": 100},
    {"id": "glicose", "label": "Glicose", "e": "sangue", "k": "glicose", "min": 0, "max": 100, "low": 30, "high": 80},
    {"id": "inflamacao", "label": "Inflamação", "e": "corpo", "k": "inflamacao", "min": 0, "max": 100, "low": 0, "high": 30},
    {"id": "adrenalina", "label": "Adrenalina", "e": "corpo", "k": "adrenalina", "min": 0, "max": 100, "low": 0, "high": 50},
    {"id": "cortisol", "label": "Cortisol", "e": "corpo", "k": "cortisol", "min": 0, "max": 100, "low": 0, "high": 50},
    {"id": "insulina", "label": "Insulina", "e": "corpo", "k": "insulina", "min": 0, "max": 100, "low": 10, "high": 70},
]
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(u["rules"]), "rules", len(u["happenings"]), "happenings", len(u["vitals"]), "vitals")
