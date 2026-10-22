#!/usr/bin/env python3
"""Reads one or more playtest logs (the client's telemetry JSONL) and checks the MVP criteria of
Docs/MvpPlan.md section 13 that a log can answer. Usage: playtest_report.py log1.jsonl [log2.jsonl ...]

It never invents what a log does not say: the questions only a person can answer (did they want to
come back? what was the open question?) are listed for the interviewer, not scored."""
import json
import sys

# traces that count as "a hidden secret found" (the client logs `examined` with the sign id)
HIDDEN = {"cenouras-roidas", "marca-bigorna", "lapide-sem-nome", "cancao-alvorada", "brilho-na-pedra", "pegada-branca",
          "laje-do-musgo", "corrente-de-ar", "inscricao-entrada", "inscricao-salao", "selo-brilha", "sussurros-na-noite"}
HIDDEN_PLACES = {"toca"}
NEW_THINGS = {"verb", "discovered", "examined", "mark_seen", "passage", "stigma", "scene", "look_far", "torch"}


def load(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    pass  # a line cut by a crash
    return rows


def report(path):
    rows = load(path)
    if not rows:
        return {"file": path, "error": "empty log"}
    end = max(r["t"] for r in rows)
    verbs = {}
    first_deed = None
    for r in rows:
        if r["kind"] == "verb" and r.get("ok"):
            verbs[r["action"]] = verbs.get(r["action"], 0) + 1
            if first_deed is None:
                first_deed = r["t"]
    examined = {r["sign"] for r in rows if r["kind"] == "examined" and r.get("sign") in HIDDEN}
    places = {r["place"] for r in rows if r["kind"] == "discovered"}
    secrets = sorted(examined | (places & HIDDEN_PLACES))
    # longest stretch with nothing new, and the voluntary pauses inside it
    marks = sorted(r["t"] for r in rows if r["kind"] in NEW_THINGS or r["kind"] == "verb" and r.get("ok"))
    points = [0.0] + marks + [end]
    longest = max((b - a for a, b in zip(points, points[1:])), default=0.0)
    idle = [(r["t"]) for r in rows if r["kind"] == "idle_start"]
    idle_total = 0.0
    start = None
    for r in rows:
        if r["kind"] == "idle_start":
            start = r["t"]
        elif r["kind"] == "idle_end" and start is not None:
            idle_total += r["t"] - start
            start = None
    hints = [r for r in rows if r["kind"] == "hint"]
    hitches = [r for r in rows if r["kind"] == "hitch"]
    acks = sorted(r["ms"] for r in rows if r["kind"] == "ack")
    p95 = acks[min(len(acks) - 1, int(0.95 * len(acks)))] if acks else None
    last = [r for r in rows if r["kind"] == "session_end"]
    q = last[-1]["open_questions"] if last else None
    return {
        "file": path,
        "minutes": round(end / 60.0, 1),
        "first_deed_s": first_deed,
        "distinct_verbs": len(verbs),
        "verbs": sorted(verbs),
        "hidden_secrets_found": secrets,
        "longest_without_anything_new_s": round(longest, 0),
        "voluntary_idle_s": round(idle_total, 0),
        "hints_given": len(hints),
        "hitches_over_50ms": len(hitches),
        "worst_frame_ms": max((r["ms"] for r in hitches), default=0),
        "ack_p95_ms": p95,
        "open_questions_at_end": q,
        "places": sorted(places),
    }


def verdict(r):
    if "error" in r:
        return [("log", False, r["error"])]
    out = []
    full = r["minutes"] >= 55
    out.append(("criterio 1: a primeira missao so depois de um feito (ver o motor)", None, f"primeiro feito aos {r['first_deed_s']} s"))
    out.append(("criterio 2: >= 2 segredos ocultos em 60 min", len(r["hidden_secrets_found"]) >= 2 if full else None,
                f"{len(r['hidden_secrets_found'])}: {', '.join(r['hidden_secrets_found']) or '-'}" + ("" if full else " (sessao curta: nao pontua)")))
    out.append(("criterio 3: >= 6 verbos distintos na primeira hora", r["distinct_verbs"] >= 6 if full else None,
                f"{r['distinct_verbs']}: {', '.join(r['verbs']) or '-'}" + ("" if full else " (sessao curta: nao pontua)")))
    gap = r["longest_without_anything_new_s"] - r["voluntary_idle_s"]
    out.append(("criterio 4: nunca > 3 min sem nada novo (pausa voluntaria nao conta)", gap <= 180,
                f"maior intervalo {r['longest_without_anything_new_s']:.0f} s, pausas {r['voluntary_idle_s']:.0f} s, dicas dadas {r['hints_given']}"))
    out.append(("criterio 5: terminou com uma pergunta em aberto", (r["open_questions_at_end"] or 0) >= 1 if r["open_questions_at_end"] is not None else None,
                f"{r['open_questions_at_end']} perguntas no Caderno (o que a pessoa QUER fazer ao voltar so ela diz)"))
    out.append(("criterio 6: fluidez (ack p95 < 500 ms, sem travadas > 150 ms)", (r["ack_p95_ms"] is None or r["ack_p95_ms"] < 500) and r["worst_frame_ms"] <= 150,
                f"ack p95 {r['ack_p95_ms']} ms, {r['hitches_over_50ms']} quadros > 50 ms (pior {r['worst_frame_ms']} ms)"))
    return out


def main(paths):
    if not paths:
        print(__doc__)
        return 2
    for p in paths:
        r = report(p)
        print(f"\n== {p}")
        for name, ok, detail in verdict(r):
            mark = "?" if ok is None else ("OK " if ok else "FALHOU")
            print(f"  [{mark:6}] {name}\n           {detail}")
    print("\nPara quem entrevista: o que a pessoa descobriu sozinha? qual era a pergunta em aberto? o que quer fazer ao voltar?")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
