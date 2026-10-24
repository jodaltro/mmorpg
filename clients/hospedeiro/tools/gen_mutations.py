"""Generates the mutation set for both sides from one table, so the engine's cards and the client's rules never disagree:
  - universes/hospedeiro/universe.json  ("mutations")
  - clients/hospedeiro/scripts/domain/bio_gene_catalog.gd
Run from the repository root:  python clients/hospedeiro/tools/gen_mutations.py
Existing mutations keep their id, name, tags and stats; new ones are added, and every class mutation gets a perk that
changes one of its class abilities (a number the ability reads), a visible organelle mark and a trade-off.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
UNIVERSE = ROOT / "universes/hospedeiro/universe.json"
CATALOG = ROOT / "clients/hospedeiro/scripts/domain/bio_gene_catalog.gd"

STAT_LABELS = {
    "speed": "velocidade", "max_membrane": "membrana máx.", "max_atp": "ATP máx.", "atp_regen": "ATP/s",
    "lash_damage": "dano do chicote", "lash_range": "alcance do chicote", "spit_damage": "dano da toxina",
    "spit_cost": "custo da toxina", "dash_cooldown": "recarga do impulso", "nutrient_yield": "ganho de nutrientes",
    "ability_power": "poder das habilidades", "ability_cooldown": "recarga das habilidades",
    "ability_cost": "custo das habilidades", "ability_range": "alcance das habilidades",
}
GD_STAT = {k: k.upper() for k in STAT_LABELS}
PARAM_LABELS = {
    "damage": "dano", "radius": "raio", "reach": "alcance", "range": "alcance", "duration": "duração", "tick": "dano contínuo",
    "slow": "lentidão", "mult": "amplificação", "seconds": "duração", "heal": "cura", "amount": "cura", "count": "unidades",
    "speed": "velocidade", "distance": "distância", "cooldown": "recarga", "cost": "custo", "burst": "explosão",
    "regen_atp": "ATP/s", "regen_membrane": "reparo", "execute_below": "limiar", "execute_mult": "bônus de execução",
    "below": "limiar", "half": "abertura", "width": "largura", "taken": "dano recebido", "knockback": "empurrão", "spread": "abertura", "pct": "fração da vida", "cap": "teto", "drift": "perseguição", "weaken": "enfraquecimento",
}
ABILITY_NAMES = {
    "engolir": "Engolir", "onda_de_pseudopodes": "Onda de Pseudópodes", "lisossomo_acido": "Lisossomo Ácido", "muralha_de_carne": "Muralha de Carne",
    "rede_de_dna": "Rede de DNA", "explosao_neutrofilica": "Explosão Neutrofílica", "netose": "NETose", "degranulacao": "Degranulação",
    "apresentar_antigeno": "Apresentar Antígeno", "dendritos_em_chicote": "Dendritos em Chicote", "chuva_de_esporos": "Chuva de Esporos", "mapa_quimico": "Mapa Químico",
    "anticorpo_y": "Anticorpo Y", "salva_de_anticorpos": "Salva de Anticorpos", "opsonizacao": "Opsonização", "explosao_de_plasmocito": "Explosão de Plasmócito",
    "perforina": "Perforina", "golpe_litico": "Golpe Lítico", "apoptose": "Apoptose", "sinal_de_morte": "Sinal de Morte",
    "chuva_de_granulos": "Chuva de Grânulos", "edema": "Edema", "choque_anafilatico": "Choque Anafilático", "alarme_de_mastocito": "Alarme de Mastócito",
    "granulo_caustico": "Grânulo Cáustico", "nuvem_de_peroxidase": "Nuvem de Peroxidase", "marca_de_ige": "Marca de IgE", "proteina_basica": "Proteína Básica Maior",
    "golpe_natural": "Golpe Natural", "cadeia_letal": "Cadeia Letal", "ausencia_de_mhc": "Ausência de MHC", "explosao_de_interferon": "Explosão de Interferon",
    "supressao_celular": "Supressão Celular", "zona_de_tolerancia": "Zona de Tolerância", "muro_de_tolerancia": "Muro de Tolerância", "silencio_imunologico": "Silêncio Imunológico",
    "citocina_curativa": "Citocina Curativa", "canto_de_citocinas": "Canto de Citocinas", "chamado_a_linfa": "Chamado à Linfa", "febre_dirigida": "Febre Dirigida",
}

# id, name, rarity, tags, lineage, flavour, stats, perks, mark
G = []


def g(id, name, rarity, tags, lineage, flavour, stats, perks=None, mark=None, keep=False):
    G.append(dict(id=id, name=name, rarity=rarity, tags=tags, lineage=lineage, flavour=flavour, stats=stats, perks=perks or {}, mark=mark or {}, keep=keep))


# ---- Generic mutations (any cell) ------------------------------------------------------------
g("flagelo_calejado", "Flagelo Calejado", "incomum", ["combat"], "", "", {"lash_damage": 1.25, "speed": 0.92}, mark={"kind": "microtubules", "color": "#ffc15a", "count": 3}, keep=True)
g("cilios_ageis", "Cílios Ágeis", "comum", ["explore"], "", "", {"speed": 1.18, "max_membrane": 0.9}, mark={"kind": "centriole", "color": "#8fe9ff", "count": 9}, keep=True)
g("membrana_espessa", "Membrana Espessa", "comum", ["endure"], "", "", {"max_membrane": 1.3, "speed": 0.9}, mark={"kind": "droplets", "color": "#6ea8ff", "count": 2}, keep=True)
g("mitocondria_avida", "Mitocôndria Ávida", "incomum", ["metabolism"], "", "", {"atp_regen": 4.0, "max_atp": 0.8}, mark={"kind": "mitochondria", "color": "#ffb347", "count": 3}, keep=True)
g("vesicula_toxica", "Vesícula Tóxica", "incomum", ["combat", "knowledge"], "", "", {"spit_damage": 1.4, "spit_cost": 1.3}, mark={"kind": "vesicles", "color": "#b6ff3a", "count": 3}, keep=True)
g("nucleo_reativo", "Núcleo Reativo", "incomum", ["endure", "explore"], "", "", {"dash_cooldown": 0.65, "max_membrane": 0.92}, mark={"kind": "ribosomes", "color": "#ffffff", "count": 1}, keep=True)
g("cauda_longa", "Cauda Longa", "incomum", ["combat", "explore"], "", "", {"lash_range": 1.3, "lash_damage": 0.9}, mark={"kind": "tubules", "color": "#7fd8ff", "count": 1}, keep=True)
g("enzima_voraz", "Enzima Voraz", "comum", ["metabolism"], "", "", {"nutrient_yield": 1.5, "atp_regen": -2.0}, mark={"kind": "lysosome", "color": "#5cffa0", "count": 2}, keep=True)
g("citoesqueleto_elastico", "Citoesqueleto Elástico", "comum", ["explore", "endure"], "", "A rede interna cede e volta.", {"speed": 1.08, "lash_range": 1.12, "max_membrane": 0.95},
  mark={"kind": "microtubules", "color": "#9fe8ff", "count": 6})
g("receptores_de_quimiotaxia", "Receptores de Quimiotaxia", "incomum", ["explore", "knowledge"], "", "Sente o cheiro do alimento à distância.", {"nutrient_yield": 1.25, "speed": 1.05, "max_atp": 0.92},
  mark={"kind": "tubules", "color": "#d4ff8a", "count": 9})
g("peroxissomos", "Peroxissomos", "incomum", ["endure", "metabolism"], "", "Pequenas fornalhas que limpam a membrana.", {"max_membrane": 1.12, "atp_regen": 2.0, "speed": 0.95},
  mark={"kind": "peroxisome", "color": "#ffb347", "count": 5, "radius": 0.55})
g("espinhos_de_quitina", "Espinhos de Quitina", "incomum", ["combat"], "", "Uma couraça de agulhas.", {"lash_damage": 1.15, "max_membrane": 1.08, "speed": 0.93},
  mark={"kind": "crystal", "color": "#ffd2a0", "count": 12, "long": True})

# ---- Macrófago: o Devorador ------------------------------------------------------------------
g("pseudopodes_gigantes", "Pseudópodes Gigantes", "rara", ["combat", "endure"], "macrofago", "", {"max_membrane": 1.4, "lash_damage": 1.2, "speed": 0.88},
  {"onda_de_pseudopodes": {"radius": 1.15, "knockback": 1.2}}, mark={"kind": "er", "color": "#ff7a9c", "count": 3}, keep=True)
g("lisossomos_acidos", "Lisossomos Ácidos", "incomum", ["combat", "metabolism"], "macrofago", "", {"nutrient_yield": 1.5, "spit_damage": 1.25, "max_atp": 0.9},
  {"lisossomo_acido": {"tick": 1.25}}, mark={"kind": "lysosome", "color": "#c4ff3a", "count": 3}, keep=True)
g("fagossomo_profundo", "Fagossomo Profundo", "rara", ["combat", "metabolism"], "macrofago", "Engole mais fundo e digere melhor.", {"max_atp": 1.1, "speed": 0.95},
  {"engolir": {"heal": 1.5, "range": 1.1}}, {"kind": "vacuole", "color": "#ff7a9c", "count": 3})
g("citoplasma_esponjoso", "Citoplasma Esponjoso", "incomum", ["endure"], "macrofago", "Absorve o impacto como uma esponja.", {"max_membrane": 1.2, "speed": 0.92, "ability_cooldown": 1.05},
  {"muralha_de_carne": {"duration": 1.4, "taken": 0.75}}, {"kind": "vesicles", "color": "#ffb0c4", "count": 8, "radius": 0.7})
g("vacuolo_digestivo", "Vacúolo Digestivo", "incomum", ["combat", "metabolism"], "macrofago", "Um lago de ácido que cresce.", {"nutrient_yield": 1.15, "lash_damage": 0.92},
  {"lisossomo_acido": {"radius": 1.35, "duration": 1.2}}, {"kind": "vacuole", "color": "#b6ff3a", "count": 2})
g("receptor_de_limpeza", "Receptor de Limpeza", "epica", ["combat", "endure"], "macrofago", "O corpo inteiro empurra o que for sujo para longe.", {"ability_power": 1.12, "speed": 0.93},
  {"onda_de_pseudopodes": {"damage": 1.3, "knockback": 1.35}}, {"kind": "autophagosome", "color": "#ff5c8a", "count": 5})

# ---- Neutrófilo: o Armadilheiro ----------------------------------------------------------------
g("rede_de_dna", "Rede de DNA", "rara", ["combat", "explore"], "neutrofilo", "", {"lash_range": 1.35, "speed": 1.15, "max_membrane": 0.85},
  {"rede_de_dna": {"radius": 1.2, "duration": 1.2}}, mark={"kind": "microtubules", "color": "#8fd0ff", "count": 5}, keep=True)
g("nucleo_multilobulado", "Núcleo Multilobulado", "incomum", ["explore", "endure"], "neutrofilo", "", {"dash_cooldown": 0.7, "speed": 1.1, "lash_damage": 0.9},
  {"explosao_neutrofilica": {"cooldown": 0.85}}, mark={"kind": "vesicles", "color": "#ffd0f0", "count": 3}, keep=True)
g("granulos_explosivos", "Grânulos Explosivos", "rara", ["combat"], "neutrofilo", "A armadilha detona com mais força.", {"max_membrane": 0.9, "ability_power": 1.08},
  {"netose": {"burst": 1.4, "radius": 1.15}}, {"kind": "lysosome", "color": "#e8ffff", "count": 9, "radius": 0.6})
g("fibras_pegajosas", "Fibras Pegajosas", "incomum", ["explore", "knowledge"], "neutrofilo", "O que toca a rede não escapa.", {"speed": 1.05, "lash_damage": 0.9},
  {"rede_de_dna": {"slow": 1.4, "tick": 1.3}}, {"kind": "er", "color": "#7fb8ff", "count": 8})
g("flagelo_turbinado", "Flagelo Turbinado", "incomum", ["explore", "combat"], "neutrofilo", "Uma investida mais longa.", {"speed": 1.08, "max_atp": 0.9},
  {"explosao_neutrofilica": {"distance": 1.3, "damage": 1.1}}, {"kind": "tubules", "color": "#bdf6ff", "count": 3})
g("degranulacao_toxica", "Degranulação Tóxica", "epica", ["combat", "metabolism"], "neutrofilo", "As granulações viram veneno denso.", {"max_membrane": 0.88, "ability_cost": 1.1},
  {"degranulacao": {"tick": 1.5, "radius": 1.2, "duration": 1.15}}, {"kind": "droplets", "color": "#cfff5a", "count": 10, "radius": 0.75})

# ---- Célula dendrítica: a Cartógrafa ---------------------------------------------------------
g("dendritos_ramificados", "Dendritos Ramificados", "rara", ["knowledge", "explore"], "dendritica", "", {"nutrient_yield": 1.6, "lash_range": 1.25, "max_membrane": 0.88},
  {"dendritos_em_chicote": {"half": 1.15}}, mark={"kind": "tubules", "color": "#7ff0ff", "count": 3}, keep=True)
g("esporos_de_antigeno", "Esporos de Antígeno", "incomum", ["knowledge", "metabolism"], "dendritica", "", {"atp_regen": 3.0, "spit_damage": 1.2, "speed": 0.9},
  {"chuva_de_esporos": {"regen_atp": 1.3}}, mark={"kind": "vesicles", "color": "#e3c8ff", "count": 4}, keep=True)
g("receptor_de_mapa", "Receptor de Mapa", "rara", ["knowledge", "explore"], "dendritica", "Lê o corpo inteiro de uma vez.", {"speed": 1.05, "max_membrane": 0.92},
  {"mapa_quimico": {"radius": 1.3, "seconds": 1.3}}, {"kind": "golgi", "color": "#6ff2ff", "count": 3})
g("apresentacao_cruzada", "Apresentação Cruzada", "rara", ["knowledge"], "dendritica", "Mostra o inimigo a toda a defesa.", {"ability_power": 1.08, "lash_damage": 0.9},
  {"apresentar_antigeno": {"mult": 1.12, "seconds": 1.3}}, {"kind": "crystal", "color": "#c9a7ff", "count": 4})
g("dendritos_sensores", "Dendritos Sensores", "incomum", ["explore", "combat"], "dendritica", "Fios mais longos e mais finos.", {"ability_cooldown": 1.05, "max_membrane": 0.95},
  {"dendritos_em_chicote": {"range": 1.25, "damage": 1.15}}, {"kind": "microtubules", "color": "#9fe8ff", "count": 6})
g("esporulacao_rapida", "Esporulação Rápida", "incomum", ["metabolism", "knowledge"], "dendritica", "Os esporos nascem e caem em ondas.", {"speed": 0.95, "atp_regen": 1.0},
  {"chuva_de_esporos": {"radius": 1.2, "regen_membrane": 1.5, "duration": 1.2}}, {"kind": "autophagosome", "color": "#e3c8ff", "count": 7, "radius": 0.9})

# ---- Linfócito B: o Anticorpomante -------------------------------------------------------------
g("anticorpos_em_y", "Anticorpos em Y", "rara", ["knowledge", "combat"], "linfocito_b", "", {"spit_damage": 1.6, "spit_cost": 1.2, "max_membrane": 0.9},
  {"anticorpo_y": {"damage": 1.2}}, mark={"kind": "ribosomes", "color": "#ffb8f0", "count": 5}, keep=True)
g("plasmocito", "Plasmócito", "epica", ["knowledge", "metabolism"], "linfocito_b", "", {"atp_regen": 5.0, "spit_damage": 1.3, "speed": 0.75},
  {"explosao_de_plasmocito": {"radius": 1.15}}, mark={"kind": "er", "color": "#ff7ae0", "count": 2}, keep=True)
g("afinidade_aumentada", "Afinidade Aumentada", "rara", ["knowledge", "combat"], "linfocito_b", "O anticorpo gruda melhor e voa mais rápido.", {"max_atp": 0.92, "ability_cost": 1.05},
  {"anticorpo_y": {"damage": 1.3, "speed": 1.2}}, {"kind": "crystal", "color": "#ffb8f0", "count": 5})
g("hipermutacao_somatica", "Hipermutação Somática", "epica", ["knowledge"], "linfocito_b", "Mais variantes por salva.", {"max_membrane": 0.88, "ability_cooldown": 1.08},
  {"salva_de_anticorpos": {"+count": 2, "spread": 1.2, "damage": 1.15}}, {"kind": "ribosomes", "color": "#ff9ee9", "count": 7, "radius": 0.75})
g("memoria_de_longa_vida", "Memória de Longa Vida", "rara", ["knowledge", "endure"], "linfocito_b", "Reconhece e responde mais depressa.", {"ability_cooldown": 0.85, "max_atp": 1.2, "speed": 0.92},
  {"anticorpo_y": {"cooldown": 0.8}}, {"kind": "golgi", "color": "#ffd1f6", "count": 2})
g("ligacao_multivalente", "Ligação Multivalente", "incomum", ["knowledge", "combat"], "linfocito_b", "Cada anticorpo prende em vários pontos.", {"speed": 0.95, "spit_damage": 1.1},
  {"opsonizacao": {"slow": 1.3, "mult": 1.1, "seconds": 1.4}}, {"kind": "centriole", "color": "#ffcaf4", "count": 10})

# ---- Linfócito T citotóxico: o Executor ---------------------------------------------------------
g("granulos_de_perforina", "Grânulos de Perforina", "rara", ["combat", "knowledge"], "t_citotoxico", "", {"lash_damage": 1.45, "spit_damage": 1.15, "max_membrane": 0.85},
  {"perforina": {"damage": 1.15}}, mark={"kind": "lysosome", "color": "#ff5c6e", "count": 4}, keep=True)
g("agulha_litica", "Agulha Lítica", "epica", ["combat", "explore"], "t_citotoxico", "", {"lash_range": 1.5, "lash_damage": 1.3, "spit_cost": 1.2},
  {"perforina": {"range": 1.2}}, mark={"kind": "crystal", "color": "#ffd0d0", "count": 3}, keep=True)
g("receptor_fas", "Receptor Fas", "rara", ["combat", "knowledge"], "t_citotoxico", "Fareja quem já está condenado.", {"max_membrane": 0.9, "ability_cost": 1.08},
  {"apoptose": {"below": 1.3, "range": 1.2, "cooldown": 0.85, "damage": 1.2}}, {"kind": "golgi", "color": "#ff6b7d", "count": 3})
g("sinapse_imunologica", "Sinapse Imunológica", "incomum", ["combat", "knowledge"], "t_citotoxico", "Fica preso ao alvo até o fim.", {"speed": 0.94, "ability_cooldown": 1.05},
  {"sinal_de_morte": {"mult": 1.1, "seconds": 1.3, "range": 1.15}}, {"kind": "centriole", "color": "#ff8c9a", "count": 2})
g("miosina_de_contracao", "Miosina de Contração", "incomum", ["combat", "explore"], "t_citotoxico", "O corpo é um músculo carregado.", {"max_atp": 0.9, "max_membrane": 0.94},
  {"golpe_litico": {"distance": 1.2, "damage": 1.2, "cooldown": 0.9}}, {"kind": "microtubules", "color": "#ff9aa5", "count": 5})
g("granzima_b", "Granzima B", "epica", ["combat"], "t_citotoxico", "Quem está ferido não resiste.", {"ability_cooldown": 1.1, "speed": 0.95},
  {"perforina": {"execute_mult": 1.35, "execute_below": 1.25, "damage": 1.1}}, {"kind": "vesicles", "color": "#ff3b4e", "count": 9, "radius": 0.5})

# ---- Linfócito T auxiliar: o Maestro das Citocinas ----------------------------------------------
g("halo_de_citocinas", "Halo de Citocinas", "rara", ["endure", "metabolism"], "t_auxiliar", "", {"max_membrane": 1.3, "atp_regen": 4.0, "lash_damage": 0.85},
  {"canto_de_citocinas": {"duration": 1.2}}, mark={"kind": "golgi", "color": "#ffe08a", "count": 2}, keep=True)
g("coro_de_interleucinas", "Coro de Interleucinas", "incomum", ["endure", "knowledge"], "t_auxiliar", "", {"nutrient_yield": 1.4, "dash_cooldown": 0.75, "spit_damage": 0.9},
  {"canto_de_citocinas": {"speed": 1.08}}, mark={"kind": "vesicles", "color": "#fff0b0", "count": 4}, keep=True)
g("interferon_gama", "Interferon Gama", "rara", ["endure", "metabolism"], "t_auxiliar", "A cura chega a quem mais precisa.", {"max_atp": 0.92, "lash_damage": 0.9},
  {"citocina_curativa": {"amount": 1.4}}, {"kind": "autophagosome", "color": "#ffe08a", "count": 3})
g("interleucina_2", "Interleucina 2", "epica", ["knowledge", "endure"], "t_auxiliar", "A linfa responde em maior número.", {"speed": 0.93, "ability_cost": 1.08},
  {"chamado_a_linfa": {"+count": 2, "duration": 1.3, "tick": 1.2}}, {"kind": "droplets", "color": "#fff0b0", "count": 6, "radius": 0.85})
g("pirogenio", "Pirogênio", "incomum", ["combat", "metabolism"], "t_auxiliar", "Provoca febre onde o dedo aponta.", {"max_membrane": 0.92, "ability_cooldown": 1.05},
  {"febre_dirigida": {"tick": 1.3, "radius": 1.15, "duration": 1.2}}, {"kind": "mitochondria", "color": "#ff9a4a", "count": 3})
g("regulador_de_resposta", "Regulador de Resposta", "rara", ["endure", "knowledge"], "t_auxiliar", "O ritmo certo do coro, na hora certa.", {"speed": 0.96, "lash_damage": 0.88},
  {"canto_de_citocinas": {"speed": 1.1, "regen_atp": 1.5, "duration": 1.3}}, {"kind": "golgi", "color": "#ffe9a8", "count": 3})

# ---- Mastócito: o Alarmista -------------------------------------------------------------------
g("granulos_de_histamina", "Grânulos de Histamina", "rara", ["combat", "metabolism"], "mastocito", "Mais grânulos, e todos prontos.", {"ability_power": 1.12, "max_membrane": 0.9},
  {"chuva_de_granulos": {"damage": 1.2, "+count": 2}}, {"kind": "lysosome", "color": "#ffb347", "count": 10, "radius": 0.7})
g("heparina", "Heparina", "incomum", ["metabolism", "endure"], "mastocito", "O líquido que sai dos grânulos incha e demora a secar.", {"max_atp": 1.1, "speed": 0.95},
  {"edema": {"radius": 1.2, "duration": 1.2}}, {"kind": "droplets", "color": "#ff8a8a", "count": 6, "radius": 0.8})
g("receptor_de_ige", "Receptor de IgE", "rara", ["knowledge", "combat"], "mastocito", "O alarme dispara com muito menos.", {"ability_cooldown": 0.9, "max_membrane": 0.92},
  {"alarme_de_mastocito": {"mult": 1.1, "seconds": 1.25}}, {"kind": "crystal", "color": "#ffd27a", "count": 5})
g("degranulacao_explosiva", "Degranulação Explosiva", "epica", ["combat"], "mastocito", "Todo o conteúdo de uma vez.", {"max_membrane": 0.85, "ability_cost": 1.1},
  {"choque_anafilatico": {"damage": 1.3, "radius": 1.15}}, {"kind": "vesicles", "color": "#ff9a3a", "count": 9, "radius": 0.6})
g("triptase", "Triptase", "incomum", ["combat", "explore"], "mastocito", "Os grânulos vão mais longe e mais depressa.", {"speed": 1.06, "lash_damage": 0.9},
  {"chuva_de_granulos": {"range": 1.25, "speed": 1.2}}, {"kind": "microtubules", "color": "#ffc15a", "count": 4})
g("citocinas_de_alarme", "Citocinas de Alarme", "incomum", ["knowledge", "metabolism"], "mastocito", "O aviso se espalha e o tecido incha.", {"atp_regen": 2.0, "max_membrane": 0.93},
  {"alarme_de_mastocito": {"radius": 1.2}, "edema": {"slow": 1.15}}, {"kind": "golgi", "color": "#ffb08a", "count": 3})

# ---- Eosinófilo: o Caça-Colossos ----------------------------------------------------------------
g("granulos_de_proteina_basica", "Grânulos de Proteína Básica", "rara", ["combat", "endure"], "eosinofilo", "Grânulos vermelhos que derretem o que tocam.", {"lash_damage": 1.2, "max_membrane": 0.88},
  {"granulo_caustico": {"damage": 1.2, "pct": 1.2}}, {"kind": "lysosome", "color": "#ff5c5c", "count": 9, "radius": 0.65})
g("nucleo_bilobulado", "Núcleo Bilobulado", "incomum", ["explore", "endure"], "eosinofilo", "Dois lobos: a nuvem aprende a perseguir.", {"speed": 1.07, "max_atp": 0.9},
  {"nuvem_de_peroxidase": {"drift": 1.4, "duration": 1.15}}, {"kind": "vesicles", "color": "#ff8a7a", "count": 2})
g("receptor_de_ige_alto", "Receptor de IgE de Alta Afinidade", "rara", ["knowledge", "combat"], "eosinofilo", "Reconhece o parasita de longe.", {"ability_cooldown": 0.9, "speed": 0.94},
  {"marca_de_ige": {"mult": 1.15, "range": 1.2}}, {"kind": "golgi", "color": "#ff9a8a", "count": 3})
g("peroxidase_concentrada", "Peroxidase Concentrada", "epica", ["combat", "metabolism"], "eosinofilo", "A nuvem fica densa e queima de verdade.", {"max_membrane": 0.86, "ability_cost": 1.1},
  {"nuvem_de_peroxidase": {"tick": 1.5, "radius": 1.2}}, {"kind": "droplets", "color": "#ff6a4a", "count": 10, "radius": 0.75})
g("grao_cristalino", "Grão Cristalino", "incomum", ["combat", "endure"], "eosinofilo", "O cristal central dos grânulos explode.", {"lash_damage": 1.1, "speed": 0.92},
  {"proteina_basica": {"damage": 1.2, "radius": 1.1}}, {"kind": "crystal", "color": "#ffb0a0", "count": 7})
g("citotoxina_eosinofilica", "Citotoxina Eosinofílica", "rara", ["combat", "knowledge"], "eosinofilo", "Derrete mais fundo e mais longe.", {"max_atp": 0.92, "ability_power": 1.05},
  {"granulo_caustico": {"cap": 1.5, "range": 1.15}}, {"kind": "autophagosome", "color": "#ff7a6a", "count": 4})

# ---- Célula NK: o Assassino Natural ------------------------------------------------------------
g("receptores_ativadores", "Receptores Ativadores", "rara", ["explore", "combat"], "celula_nk", "Sente o perigo antes de ele chegar.", {"speed": 1.12, "max_membrane": 0.88},
  {"golpe_natural": {"distance": 1.2, "damage": 1.15}}, {"kind": "microtubules", "color": "#8fd0ff", "count": 6})
g("granulos_citoliticos", "Grânulos Citolíticos", "rara", ["combat"], "celula_nk", "Quem já está ferido não resiste.", {"lash_damage": 1.25, "max_membrane": 0.88},
  {"ausencia_de_mhc": {"below": 1.2, "damage": 1.3}}, {"kind": "lysosome", "color": "#a0c8ff", "count": 6, "radius": 0.6})
g("salto_em_cadeia", "Salto em Cadeia", "epica", ["combat", "explore"], "celula_nk", "Mais um elo na sequência.", {"speed": 1.1, "max_atp": 0.9, "ability_cooldown": 1.08},
  {"cadeia_letal": {"+count": 1, "range": 1.2, "damage": 1.15}}, {"kind": "tubules", "color": "#bfe4ff", "count": 4})
g("interferon_gama_nk", "Interferon Gama", "incomum", ["metabolism", "explore"], "celula_nk", "O surto dura mais e rende mais energia.", {"atp_regen": 3.0, "max_membrane": 0.92},
  {"explosao_de_interferon": {"duration": 1.3, "speed": 1.08}}, {"kind": "mitochondria", "color": "#9fd8ff", "count": 3})
g("ligantes_de_estresse", "Ligantes de Estresse", "incomum", ["knowledge", "combat"], "celula_nk", "Reconhece o que está doente a mais distância.", {"nutrient_yield": 1.3, "lash_damage": 1.1, "speed": 0.93},
  {"ausencia_de_mhc": {"range": 1.25, "below": 1.1}}, {"kind": "ribosomes", "color": "#c8dcff", "count": 5})
g("citotoxicidade_natural", "Citotoxicidade Natural", "incomum", ["combat", "endure"], "celula_nk", "Cada golpe é mais afiado e volta mais cedo.", {"ability_power": 1.05, "max_membrane": 0.9},
  {"cadeia_letal": {"damage": 1.2}, "golpe_natural": {"cooldown": 0.9}}, {"kind": "crystal", "color": "#b0d0ff", "count": 4})

# ---- Linfócito T regulador: o Pacificador -------------------------------------------------------
g("foxp3", "FoxP3", "rara", ["endure", "knowledge"], "t_regulador", "O fator que define quem acalma.", {"max_membrane": 1.2, "lash_damage": 0.85},
  {"supressao_celular": {"weaken": 0.85, "seconds": 1.2}}, {"kind": "golgi", "color": "#8fffd8", "count": 3})
g("interleucina_10", "Interleucina 10", "incomum", ["endure", "metabolism"], "t_regulador", "O sinal que apaga o fogo.", {"atp_regen": 2.0, "speed": 0.94},
  {"zona_de_tolerancia": {"radius": 1.2, "duration": 1.2}}, {"kind": "droplets", "color": "#a0ffe0", "count": 6, "radius": 0.8})
g("ctla4", "CTLA-4", "rara", ["knowledge", "endure"], "t_regulador", "Um freio em cada receptor.", {"ability_cooldown": 0.9, "lash_damage": 0.88},
  {"silencio_imunologico": {"weaken": 0.85, "radius": 1.2}}, {"kind": "centriole", "color": "#8ff0d0", "count": 8})
g("tgf_beta", "TGF-β", "incomum", ["endure"], "t_regulador", "Cicatriza o que o conflito abriu.", {"max_membrane": 1.1, "speed": 0.92},
  {"muro_de_tolerancia": {"duration": 1.3, "+count": 1}}, {"kind": "vesicles", "color": "#b0ffe8", "count": 5})
g("contato_celula_a_celula", "Contato Célula a Célula", "epica", ["knowledge", "endure"], "t_regulador", "Quem fica perto fica manso.", {"max_atp": 0.9, "ability_cost": 1.1},
  {"zona_de_tolerancia": {"slow": 1.3, "weaken": 0.85}}, {"kind": "tubules", "color": "#90ffd0", "count": 7})
g("anergia_induzida", "Anergia Induzida", "incomum", ["knowledge", "explore"], "t_regulador", "O alvo para de responder, de longe.", {"nutrient_yield": 1.3, "lash_damage": 0.9},
  {"supressao_celular": {"range": 1.25, "mult": 1.1}}, {"kind": "ribosomes", "color": "#a8ffe4", "count": 5})


def pct(v):
    return "%+d%%" % round((v - 1.0) * 100.0)


def stats_text(stats):
    parts = []
    for k, v in stats.items():
        parts.append("%+d ATP/s" % round(v) if k == "atp_regen" else "%s %s" % (pct(v), STAT_LABELS[k]))
    return ", ".join(parts)


def perks_text(perks):
    out = []
    for ab, params in perks.items():
        bits = []
        for k, v in params.items():
            if k.startswith("+"):
                bits.append("+%d %s" % (v, PARAM_LABELS[k[1:]]))
            else:
                bits.append("%s %s" % (pct(v), PARAM_LABELS[k]))
        out.append("%s: %s" % (ABILITY_NAMES[ab], ", ".join(bits)))
    return "; ".join(out)


def desc(gene, old):
    d = (gene["flavour"] + " " if gene["flavour"] else "") + stats_text(gene["stats"]) + "."
    if gene["perks"]:
        d = d.rstrip() + " " + perks_text(gene["perks"]) + "."
    return d


def hyphen(s):
    return s.replace("_", "-")


def gd_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    return repr(float(v)) if isinstance(v, float) else str(v)


def gd_dict(d):
    return "{" + ", ".join('%s: %s' % (('&"%s"' % k) if not k.startswith("+") else '"%s"' % k, gd_dict(v) if isinstance(v, dict) else gd_value(v)) for k, v in d.items()) + "}"


def apply_balance():
    """Replaces the stats and perks of each mutation with the tuned ones (data/balance.json, from BioBalance)."""
    path = ROOT / "clients/hospedeiro/data/balance.json"
    if not path.exists():
        return
    tuned = json.loads(path.read_text(encoding="utf-8")).get("genes", {})
    for gene in G:
        t = tuned.get(gene["id"])
        if not t:
            continue
        gene["stats"] = {k: float(v) for k, v in t["mods"].items()}
        gene["perks"] = {ab: {k: (int(v) if k.startswith("+") else float(v)) for k, v in params.items()} for ab, params in t["perks"].items()}


def main():
    apply_balance()
    (ROOT / "clients/hospedeiro/data").mkdir(exist_ok=True)
    (ROOT / "clients/hospedeiro/data/gene_rarity.json").write_text(json.dumps({gene["id"]: gene["rarity"] for gene in G}, indent=1), encoding="utf-8")
    raw = UNIVERSE.read_text(encoding="utf-8")
    u = json.loads(raw)
    old = {m["id"]: m for m in u["mutations"]}
    out = []
    for gene in G:
        gid = hyphen(gene["id"])
        prev = old.get(gid, {})
        m = {"id": gid, "name": gene["name"] if not gene["keep"] else prev.get("name", gene["name"]), "rarity": gene["rarity"], "tags": gene["tags"], "desc": desc(gene, prev)}
        if gene["lineage"]:
            m["eligible"] = {"tag": {"e": "$self", "k": "lineage", "v": hyphen(gene["lineage"])}}
        out.append(m)
    u["mutations"] = out
    UNIVERSE.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")

    lines = [
        "class_name BioGeneCatalog",
        "extends RefCounted",
        "## Every mutation. GENERATED by tools/gen_mutations.py from the same table that writes the engine's universe,",
        "## so the cards the engine offers and the rules the client applies never disagree. A gene has stat trade-offs,",
        "## perks (numbers one of the class abilities reads) and a visible mark (an organelle) on the body.",
        "",
        "static var _genes: Dictionary = {}",
        "",
        "",
        "static func get_gene(id: StringName) -> BioGene:",
        "\t_ensure()",
        "\treturn _genes[id]",
        "",
        "",
        "static func all_ids() -> Array:",
        "\t_ensure()",
        "\treturn _genes.keys()",
        "",
        "",
        "## Genes a cell of this class can meet: the generic ones and its own.",
        "static func ids_for(lineage: StringName) -> Array:",
        "\t_ensure()",
        "\treturn _genes.keys().filter(func(id: StringName) -> bool: return _genes[id].requires_lineage == &\"\" or _genes[id].requires_lineage == lineage)",
        "",
        "",
        "static func class_ids(lineage: StringName) -> Array:",
        "\t_ensure()",
        "\treturn _genes.keys().filter(func(id: StringName) -> bool: return _genes[id].requires_lineage == lineage)",
        "",
        "",
        "static func _ensure() -> void:",
        "\tif not _genes.is_empty():",
        "\t\treturn",
    ]
    section = None
    for gene in G:
        if gene["lineage"] != section:
            section = gene["lineage"]
            lines.append("\t# --- %s ---" % (section or "generic"))
        mods = ", ".join("BioGene.%s: %s" % (GD_STAT[k], gd_value(float(v))) for k, v in gene["stats"].items())
        perks = gd_dict(gene["perks"]) if gene["perks"] else "{}"
        mark = gd_dict(gene["mark"]) if gene["mark"] else "{}"
        lines.append('\t_add(&"%s", "%s", {%s}, &"%s", %s, %s)' % (gene["id"], gene["name"], mods, gene["lineage"], perks, mark))
    lines += [
        "",
        "",
        "static func _add(id: StringName, display_name: String, mods: Dictionary, requires_lineage: StringName = &\"\", perks: Dictionary = {}, mark: Dictionary = {}) -> void:",
        "\t_genes[id] = BioGene.new(id, display_name, mods, requires_lineage, perks, mark)",
        "",
    ]
    CATALOG.write_text("\n".join(lines), encoding="utf-8")
    print("genes:", len(G), "generic:", sum(1 for x in G if not x["lineage"]), "class:", sum(1 for x in G if x["lineage"]))


if __name__ == "__main__":
    main()
