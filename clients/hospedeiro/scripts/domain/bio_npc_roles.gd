class_name BioNpcRoles
extends RefCounted
## What each named cell looks like and how its work is shown. Purely presentation: the work itself (what changes in the body) is the
## engine's. Each role has its own silhouette and each kind of work its own gesture, so a watcher reads the job without a label.

## Silhouettes: disc (biconcave), lobed (multilobed nucleus and granules), pseudo (pseudopods and vacuoles), branch (dendrites),
## cluster (platelets that stay together), star (stellate sinusoid cell), anchor (stroma attached to the matrix).
const ROLES := {
	"rubra": {"role": "Hemácia", "silhouette": "disc", "radius": 0.55, "core": Color(1.0, 0.25, 0.25), "edge": Color(0.7, 0.05, 0.12), "tint": Color(1.0, 0.35, 0.3)},
	"neva": {"role": "Neutrófilo", "silhouette": "lobed", "radius": 0.6, "core": Color(0.92, 0.95, 1.0), "edge": Color(0.6, 0.7, 0.95), "tint": Color(0.75, 0.85, 1.0)},
	"dendra": {"role": "Dendrítica", "silhouette": "branch", "radius": 0.55, "core": Color(0.75, 0.45, 1.0), "edge": Color(0.45, 0.2, 0.9), "tint": Color(0.8, 0.55, 1.0)},
	"macra": {"role": "Macrófago", "silhouette": "pseudo", "radius": 0.78, "core": Color(1.0, 0.8, 0.4), "edge": Color(0.85, 0.5, 0.2), "tint": Color(1.0, 0.75, 0.35)},
	"placa": {"role": "Plaqueta", "silhouette": "cluster", "radius": 0.34, "core": Color(1.0, 0.85, 0.7), "edge": Color(0.95, 0.55, 0.5), "tint": Color(1.0, 0.7, 0.6)},
	"esplena": {"role": "Macrófago do baço", "silhouette": "pseudo", "radius": 0.7, "core": Color(0.85, 0.5, 0.75), "edge": Color(0.55, 0.2, 0.5), "tint": Color(0.9, 0.55, 0.8)},
	"kupffer": {"role": "Célula de Kupffer", "silhouette": "star", "radius": 0.66, "core": Color(0.7, 1.0, 0.35), "edge": Color(0.3, 0.7, 0.2), "tint": Color(0.75, 1.0, 0.4)},
	"estroma": {"role": "Estroma", "silhouette": "anchor", "radius": 0.75, "core": Color(1.0, 0.75, 0.25), "edge": Color(0.85, 0.5, 0.2), "tint": Color(1.0, 0.8, 0.35)},
}
const FALLBACK := {"role": "Célula", "silhouette": "disc", "radius": 0.55, "core": Color(0.35, 1.0, 0.6), "edge": Color(0.2, 0.45, 1.0), "tint": Color(0.5, 1.0, 0.7)}

## Gestures by task. carry: vesicles ride inside the cell and are handed over; patrol: a sweeping scan; defend: a braced burst at the
## threat; engulf: pseudopods close round the target; detox: a stream of toxin turns into clear fluid; signal: a dendritic vesicle sent
## along a path; sample: filaments sweep and collect; seal: platelets lay fibrin threads in layers.
const GESTURES := {
	"transportar-oxigenio": "carry", "patrulhar-sangue": "patrol", "rondar-baco": "patrol", "rondar-sinusoides": "patrol", "vigiar-pulmao": "patrol",
	"circular-plaquetas": "patrol", "defender-pulmao": "defend", "limpar-alveolos": "engulf", "reciclar-no-baco": "engulf", "limpar-toxinas": "detox",
	"apresentar-antigenos": "signal", "colher-sinais": "sample", "selar-ferida": "seal",
}
const VERBS := {
	"carry": "leva oxigênio", "patrol": "vigia", "defend": "defende", "engulf": "engole detritos", "detox": "filtra toxinas",
	"signal": "avisa os outros", "sample": "colhe sinais", "seal": "sela a brecha", "idle": "descansa",
}


static func role(npc: String) -> Dictionary:
	return ROLES.get(npc, FALLBACK)


static func gesture(task: String) -> String:
	return str(GESTURES.get(task, "idle"))


static func verb(gesture_kind: String) -> String:
	return str(VERBS.get(gesture_kind, "trabalha"))
