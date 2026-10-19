"""Describe existing, unmodified captures for the project's ReviewLite pipeline."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "Docs/Validation/Action3DFoundation"
images = []
for name, record, state in (
    ("play-arena.png", "capture-arena.json", "Play real, inimigo ataca Ellen; vida4/5; sem dispositivos sinteticos"),
    ("play-combat.png", "capture-after-qa.json", "Play real apos QA; passagem aberta; camera proxima do limite fisico"),
):
    camera = json.loads((EVIDENCE / "QA" / record).read_text())
    camera.update({"projection": "perspective", "captureResolution": [1280, 720],
                   "samplingNote": "Metadados lidos na chamada CLI seguinte a captura; camera movel, nao e par antes/depois"})
    images.append(dict(original="Original/" + name, scene="Assets/Mmorpg/Scenes/ValdoriaAction3D.unity",
                       state=state, comparison=name, camera=camera, integral=True))
smoke = EVIDENCE / "Standalone/smoke.json"
if smoke.exists():
    data = json.loads(smoke.read_text())
    images.append(dict(original="Original/standalone-movement.png", scene="Assets/Mmorpg/Scenes/ValdoriaAction3D.unity",
                       state="Build Windows Development; movimento por Input System; inimigo desativado somente no smoke",
                       comparison="standalone", integral=True,
                       camera={"projection":"perspective", "fov":55, "actorScale":[1,1,1], "captureResolution":[1280,720],
                               "trace":"Standalone/smoke.json", "frame":data["frameEnd"]}))
(EVIDENCE / "QA/capture-index.json").write_text(json.dumps({"images":images},ensure_ascii=False,indent=2),encoding="utf-8")
