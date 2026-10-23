"""Assigns each mutation the organelle that fits it (kind names of BioOrganelles) in gen_mutations.py, then regenerates."""
import re
from pathlib import Path

KIND = {
    # general
    "flagelo_calejado": "microtubules", "cilios_ageis": "centriole", "membrana_espessa": "droplets", "mitocondria_avida": "mitochondria",
    "vesicula_toxica": "vesicles", "nucleo_reativo": "ribosomes", "cauda_longa": "tubules", "enzima_voraz": "lysosome",
    "citoesqueleto_elastico": "microtubules", "receptores_de_quimiotaxia": "tubules", "peroxissomos": "peroxisome", "espinhos_de_quitina": "crystal",
    # macrophage
    "pseudopodes_gigantes": "er", "lisossomos_acidos": "lysosome", "fagossomo_profundo": "vacuole", "citoplasma_esponjoso": "vesicles",
    "vacuolo_digestivo": "vacuole", "receptor_de_limpeza": "autophagosome",
    # neutrophil
    "rede_de_dna": "microtubules", "nucleo_multilobulado": "vesicles", "granulos_explosivos": "lysosome", "fibras_pegajosas": "er",
    "flagelo_turbinado": "tubules", "degranulacao_toxica": "droplets",
    # dendritic
    "dendritos_ramificados": "tubules", "esporos_de_antigeno": "vesicles", "receptor_de_mapa": "golgi", "apresentacao_cruzada": "crystal",
    "dendritos_sensores": "microtubules", "esporulacao_rapida": "autophagosome",
    # B cell
    "anticorpos_em_y": "ribosomes", "plasmocito": "er", "afinidade_aumentada": "crystal", "hipermutacao_somatica": "ribosomes",
    "memoria_de_longa_vida": "golgi", "ligacao_multivalente": "centriole",
    # cytotoxic T
    "granulos_de_perforina": "lysosome", "agulha_litica": "crystal", "receptor_fas": "golgi", "sinapse_imunologica": "centriole",
    "miosina_de_contracao": "microtubules", "granzima_b": "vesicles",
    # helper T
    "halo_de_citocinas": "golgi", "coro_de_interleucinas": "vesicles", "interferon_gama": "autophagosome", "interleucina_2": "droplets",
    "pirogenio": "mitochondria", "regulador_de_resposta": "golgi",
}

p = Path(__file__).resolve().parent / "gen_mutations.py"
s = p.read_text(encoding="utf-8")
done = 0
for gid, kind in KIND.items():
    pat = re.compile(r'(g\("%s".*?\{"kind": ")([a-z]+)(")' % gid, re.S)
    m = pat.search(s)
    assert m, gid
    s = s[:m.start()] + m.group(1) + kind + m.group(3) + s[m.end():]
    done += 1
p.write_text(s, encoding="utf-8")
print("assigned", done)
