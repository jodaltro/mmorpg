"""E3 (the next organs): the spleen (baço, with the germinal centre), the intestine (with the deep crypts) and the kidney (with the nephrons).
Each has its region, passage, spots, a unique niche, a vital, two verbs, rules that tie it to the other organs, two quests, codex entries and a
procedural dungeon. Idempotent. Run from the repo root (or anywhere: the path is relative to this file)."""
import json
from pathlib import Path

PACE = 3  # tools/tune_pacing.py: dungeon maturity = base x PACE
p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def upsert(items, item):
    items[:] = [x for x in items if x["id"] != item["id"]] + [item]


num = lambda e, k, op, v: {"num": {"e": e, "k": k, "op": op, "v": v}}
adj = lambda e, k, d, **kw: {"op": "adjust", "e": e, "k": k, "d": d, **kw}
emit = lambda ev, text: {"op": "emit", "event": ev, "public": True, "text": text}

# the marrow keeps the iron the spleen recycles
medula = next(e for e in u["entities"] if e["id"] == "medula")
medula["num"]["ferro"] = medula["num"].get("ferro", 0)

ORGANS = {
    "baco": {
        "entity": {"id": "baco", "kind": "tecido", "name": "Baço", "num": {"hemacias": 30, "antigenos": 20}},
        "passage": {"id": "arteria_esplenica", "from": "aorta", "to": "baco", "name": "Artéria esplênica"},
        "spots": [
            {"id": "polpa-vermelha", "region": "baco", "name": "Polpa vermelha, onde as hemácias velhas são desfeitas", "near": ["polpa-branca"]},
            {"id": "polpa-branca", "region": "baco", "name": "Polpa branca, onde os linfócitos esperam o antígeno", "near": ["polpa-vermelha"]},
        ],
        "niche": {"id": "centro-germinativo-oculto", "region": "baco", "name": "Centro germinativo oculto", "gene": "nucleo-reativo", "unique": True,
            "hint": "Na polpa branca, um folículo pulsa em silêncio: linfócitos se dividem e se corrigem ali, longe de qualquer olhar.",
            "text": "No folículo, os linfócitos erram de propósito e só os que acertam sobrevivem. Você leva dali o núcleo reativo: responder depressa, sem pensar duas vezes."},
        "vital": {"id": "hemacias", "label": "Hemácias velhas (baço)", "e": "baco", "k": "hemacias", "min": 0, "max": 100, "low": 0, "high": 75},
        "actions": [
            {"id": "reciclar-hemacia", "title": "Reciclar hemácia", "tags": ["metabolism", "endure"],
             "effects": [adj("baco", "hemacias", -4, min=0), adj("medula", "ferro", 1), adj("$self", "maturidade", 1), adj("$self", "pressao", 1)]},
            {"id": "capturar-antigeno", "title": "Capturar antígeno", "tags": ["knowledge", "combat"],
             "effects": [adj("baco", "antigenos", 4, max=100), adj("$self", "maturidade", 1), adj("$self", "pressao", 1)]},
        ],
        "rules": [
            {"id": "hemacias-envelhecem", "every": 5, "when": num("baco", "hemacias", "<", 100), "effects": [adj("baco", "hemacias", 2, max=100)]},
            {"id": "baco-congestionado", "every": 6, "when": num("baco", "hemacias", ">=", 80),
             "effects": [adj("corpo", "inflamacao", 2, max=100), emit("baco-congestionado", "O baço congestiona de hemácias velhas e o corpo inflama.")]},
            {"id": "antigenos-decaem", "every": 8, "when": num("baco", "antigenos", ">", 0), "effects": [adj("baco", "antigenos", -1, min=0)]},
            {"id": "baco-apresenta", "every": 6, "when": num("baco", "antigenos", ">=", 60),
             "effects": [adj("baco", "antigenos", -10, min=0), adj("corpo", "inflamacao", -2, min=0),
                         emit("baco-apresenta", "O baço apresenta antígenos aos linfócitos: a defesa do corpo se organiza.")]},
            {"id": "medula-usa-ferro", "every": 6, "when": num("medula", "ferro", ">=", 5),
             "effects": [adj("medula", "ferro", -5, min=0), adj("medula", "reserva", 4, max=100),
                         emit("medula-usa-ferro", "A medula usa o ferro reciclado e fabrica hemácias novas.")]},
        ],
        "quests": [
            {"id": "polpa-limpa", "title": "Polpa limpa", "objective": "Na polpa vermelha, recicle 8 hemácias velhas antes que o baço congestione.",
             "desc": "Osteia explica: o baço desfaz as hemácias velhas e devolve o ferro à medula.", "action": "reciclar-hemacia", "n": 8},
            {"id": "mostrar-o-inimigo", "title": "Mostrar o inimigo", "objective": "No baço, capture 8 antígenos: é assim que os linfócitos aprendem quem atacar.",
             "desc": "Osteia insiste: sem antígeno apresentado, a defesa não sabe quem é o inimigo.", "action": "capturar-antigeno", "n": 8},
        ],
        "codex": [
            {"id": "cx-baco", "kind": "regiao", "title": "O baço", "when": "visit",
             "text": "O baço é um filtro de sangue e uma escola de defesa: a polpa vermelha desfaz hemácias velhas e guarda ferro; a polpa branca reúne linfócitos que aprendem a reconhecer o que invade."},
            {"id": "cx-hemacias", "kind": "fisiologia", "title": "Hemácias velhas", "when": {"deeds": {"action": "reciclar-hemacia", "op": ">=", "v": 1}},
             "text": "Uma hemácia vive uns 120 dias. Depois, macrófagos do baço a engolem e devolvem o ferro à medula, que fabrica hemácias novas."},
            {"id": "cx-germinativo", "kind": "segredo", "title": "O centro germinativo", "when": {"deeds": {"action": "nicho:centro-germinativo-oculto", "op": ">=", "v": 1}},
             "text": "Nos folículos, os linfócitos B mutam de propósito (hipermutação somática) e só sobrevivem os que se ligam melhor ao antígeno. Uma seleção tão dura que, quando falha, nasce um clone maligno."},
        ],
        "dungeon": {
            "id": "centro-germinativo", "name": "O Centro Germinativo", "skills": [
                {"id": "selo-do-baco", "name": "Selo do Baço", "desc": "Você limpou o centro germinativo uma vez: seu corpo guarda a lembrança de como a defesa aprende.", "rarity": "rara"},
                {"id": "primeira-selecao", "name": "Primeira Seleção", "desc": "Foi a primeira célula a limpar o Centro Germinativo. O corpo inteiro lembra.", "rarity": "epica"}],
            "desc": "Um folículo perdeu a seleção: linfócitos que deveriam morrer se multiplicam, e um clone maligno os comanda. Se ninguém entrar, o baço vira um tumor.",
            "maturity": 18,
            "rooms": [
                {"id": "zona-do-manto", "name": "A zona do manto", "desc": "Linfoblastos em patrulha na borda do folículo: pequenos, rápidos e frágeis.", "kind": "guard"},
                {"id": "clone-maligno", "name": "O clone maligno", "desc": "Um linfócito que escapou da seleção e agora comanda os outros.", "kind": "boss"},
            ],
            "pool": [
                {"id": "cordoes-de-billroth", "name": "Os cordões de Billroth", "desc": "Centroblastos grandes e macrófagos da polpa, com linfoblastos por perto.", "kind": "wall"},
                {"id": "zona-escura", "name": "A zona escura", "desc": "Aqui os linfoblastos se dividem sem parar; focos de ativação os aceleram.", "kind": "core"},
                {"id": "selecao-negativa", "name": "A seleção negativa", "desc": "O folículo se fecha e os clones caem sobre quem entra, todos de uma vez.", "kind": "ambush"},
                {"id": "zona-clara", "name": "A zona clara", "desc": "Células apresentadoras formam colunas; plasmoblastos atiram de trás delas.", "kind": "pillars"},
                {"id": "foliculo-hiperplasico", "name": "O folículo hiperplásico", "desc": "Um folículo inchado que gera linfoblasto atrás de linfoblasto até ser rompido.", "kind": "nest"},
                {"id": "polpa-vermelha-sangrenta", "name": "A polpa encharcada", "desc": "Poças de sangue represado queimam a membrana; blastos em mitose se escondem entre elas.", "kind": "hazard"},
            ],
            "depth": [3, 4],
            "modifiers": [
                {"id": "hipermutacao", "name": "Hipermutação", "desc": "Os clones erram e se corrigem depressa: andam mais rápido.", "tags": ["combat", "knowledge"]},
                {"id": "selecao-rigida", "name": "Seleção rígida", "desc": "Só os mais fortes sobreviveram: cada inimigo aguenta mais.", "tags": ["combat", "endure"]},
                {"id": "tolerancia", "name": "Tolerância", "desc": "A defesa já os conhece: os inimigos aguentam menos.", "tags": ["knowledge", "explore"], "eligible": num("baco", "antigenos", ">=", 40)},
                {"id": "baco-congestionado", "name": "Baço congestionado", "desc": "O sangue represado queima: a membrana escorre aos poucos.", "tags": ["endure", "metabolism"], "eligible": num("baco", "hemacias", ">=", 55)},
                {"id": "polpa-limpa", "name": "Polpa limpa", "desc": "Sem hemácias velhas, o ATP volta mais depressa.", "tags": ["metabolism", "explore"], "eligible": num("baco", "hemacias", "<", 40)},
            ],
            "rewards": [adj("$self", "pressao", 10), adj("$self", "maturidade", 6), adj("baco", "hemacias", -35, min=0), adj("baco", "antigenos", 15, max=100),
                        adj("corpo", "inflamacao", -10, min=0), {"op": "grant", "v": "selo-do-baco"},
                        emit("centro-limpo", "O centro germinativo foi limpo: o baço volta a ensinar a defesa.")],
            "first": {"skill": "primeira-selecao", "text": "foi a primeira a limpar o Centro Germinativo."},
            "retry": 6,
        },
    },
    "intestino": {
        "entity": {"id": "intestino", "kind": "tecido", "name": "Intestino", "num": {"alimento": 30, "microbiota": 60}},
        "passage": {"id": "arteria_mesenterica", "from": "aorta", "to": "intestino", "name": "Artéria mesentérica"},  # (the portal vein is only told in a rule: a closed ring of vessels would leave a hole in the body's membrane)
        "spots": [
            {"id": "vilosidades", "region": "intestino", "name": "Vilosidades, onde os nutrientes atravessam a parede", "near": ["cripta-profunda"]},
            {"id": "cripta-profunda", "region": "intestino", "name": "Cripta profunda, o berço das células da parede", "near": ["vilosidades"]},
        ],
        "niche": {"id": "cripta-de-lieberkuhn", "region": "intestino", "name": "Cripta de Lieberkühn", "gene": "enzima-voraz", "unique": True,
            "hint": "No fundo de uma cripta, as células-tronco da parede se renovam em silêncio, e algo ali sabe quebrar qualquer coisa.",
            "text": "A cripta lhe empresta o apetite das células da parede: a enzima voraz, que extrai muito de pouco, ao preço de uma energia menos estável."},
        "vital": {"id": "microbiota", "label": "Microbiota (intestino)", "e": "intestino", "k": "microbiota", "min": 0, "max": 100, "low": 20, "high": 100},
        "actions": [
            {"id": "nutrir-microbiota", "title": "Nutrir a microbiota", "tags": ["metabolism", "endure"],
             "effects": [adj("intestino", "microbiota", 4, max=100), adj("$self", "maturidade", 1)]},
            {"id": "repelir-invasor", "title": "Repelir invasor", "tags": ["combat", "endure"],
             "effects": [adj("intestino", "microbiota", 2, max=100), adj("$self", "maturidade", 1), adj("$self", "pressao", 1)]},
        ],
        "rules": [
            {"id": "intestino-recebe", "every": 5, "when": num("intestino", "alimento", "<", 100), "effects": [adj("intestino", "alimento", 3, max=100)]},
            {"id": "intestino-despeja", "every": 6, "when": num("intestino", "alimento", ">=", 50),
             "effects": [adj("intestino", "alimento", -25, min=0), adj("figado", "glicogenio", 6, max=100), adj("figado", "toxina", 3, max=100),
                         emit("intestino-despeja", "O intestino despeja nutrientes (e toxinas) no fígado pela veia porta.")]},
            {"id": "microbiota-cai", "every": 6, "when": num("intestino", "microbiota", ">", 0), "effects": [adj("intestino", "microbiota", -1, min=0)]},
            {"id": "disbiose", "every": 6, "when": num("intestino", "microbiota", "<", 15),
             "effects": [adj("corpo", "inflamacao", 2, max=100), emit("disbiose", "Sem microbiota, o intestino inflama o corpo.")]},
        ],
        "quests": [
            {"id": "jardim-do-intestino", "title": "O jardim do intestino", "objective": "No intestino, nutra a microbiota 8 vezes: ela é a primeira defesa da parede.",
             "desc": "Osteia explica: as bactérias boas ocupam o lugar das ruins e treinam a defesa.", "action": "nutrir-microbiota", "n": 8},
            {"id": "guarda-da-parede", "title": "Guarda da parede", "objective": "Repila 8 invasores na parede do intestino, antes que a microbiota se desfaça.",
             "desc": "Osteia teme o que entra com a comida: sem guarda, a parede deixa passar.", "action": "repelir-invasor", "n": 8},
        ],
        "codex": [
            {"id": "cx-intestino", "kind": "regiao", "title": "O intestino", "when": "visit",
             "text": "Tubo de muitos metros dobrado em vilosidades: é onde o alimento vira nutriente. Abriga a maior colônia de bactérias do corpo, e a maior parte da defesa."},
            {"id": "cx-microbiota", "kind": "fisiologia", "title": "A microbiota", "when": {"deeds": {"action": "nutrir-microbiota", "op": ">=", "v": 1}},
             "text": "Trilhões de bactérias vivem no intestino: fermentam fibras, fabricam vitaminas e ocupam o espaço das que fazem mal. Sem elas, a parede inflama."},
            {"id": "cx-lieberkuhn", "kind": "segredo", "title": "As criptas de Lieberkühn", "when": {"deeds": {"action": "nicho:cripta-de-lieberkuhn", "op": ">=", "v": 1}},
             "text": "No fundo de cada cripta ficam as células-tronco da parede, que a renovam a cada poucos dias. É um dos tecidos que mais se refazem no corpo."},
        ],
        "dungeon": {
            "id": "criptas-profundas", "name": "As Criptas Profundas", "skills": [
                {"id": "selo-do-intestino", "name": "Selo do Intestino", "desc": "Você limpou as criptas uma vez: seu corpo guarda a lembrança do que vive na parede.", "rarity": "rara"},
                {"id": "primeira-muralha", "name": "Primeira Muralha", "desc": "Foi a primeira célula a limpar as Criptas Profundas. O corpo inteiro lembra.", "rarity": "epica"}],
            "desc": "A microbiota perdeu o equilíbrio: um biofilme tomou as criptas, bactérias e parasitas fundaram ninhos e uma colônia mãe sufoca a parede. Se ninguém entrar, o intestino adoece.",
            "maturity": 20,
            "rooms": [
                {"id": "lume-vigiado", "name": "O lume vigiado", "desc": "Bactérias entéricas patrulham o centro do tubo: pequenas, rápidas e frágeis.", "kind": "guard"},
                {"id": "a-tenia", "name": "A tênia", "desc": "Um parasita enrolado nas criptas há muito tempo, e que agora não cabe mais nelas.", "kind": "boss"},
            ],
            "pool": [
                {"id": "parede-intestinal", "name": "A parede intestinal", "desc": "Vermes e cistos de giárdia entre as dobras, com bactérias por perto.", "kind": "wall"},
                {"id": "criptas-do-fundo", "name": "As criptas do fundo", "desc": "O biofilme é denso: focos de toxina aceleram as bactérias.", "kind": "core"},
                {"id": "lume-em-emboscada", "name": "O lume em emboscada", "desc": "O tubo se contrai e as bactérias descem todas juntas.", "kind": "ambush"},
                {"id": "vilosidades-altas", "name": "As vilosidades altas", "desc": "Vilosidades como colunas escondem esporos que atiram à distância.", "kind": "pillars"},
                {"id": "biofilme", "name": "O biofilme", "desc": "Uma crosta viva que gera bactéria atrás de bactéria até ser rompida.", "kind": "nest"},
                {"id": "muco-acido", "name": "O muco ácido", "desc": "Poças de muco ácido queimam a membrana; amebas se escondem entre elas.", "kind": "hazard"},
            ],
            "depth": [3, 4],
            "modifiers": [
                {"id": "disbiose-ativa", "name": "Disbiose ativa", "desc": "Os invasores se multiplicam enquanto você demora.", "tags": ["combat", "endure"]},
                {"id": "peristaltismo", "name": "Peristaltismo", "desc": "O tubo se contrai sem parar: os inimigos andam mais depressa.", "tags": ["combat", "explore"]},
                {"id": "microbiota-forte", "name": "Microbiota forte", "desc": "As bactérias boas enfraquecem os inimigos antes de você chegar.", "tags": ["knowledge", "metabolism"], "eligible": num("intestino", "microbiota", ">=", 50)},
                {"id": "refeicao-farta", "name": "Refeição farta", "desc": "A parede está cheia de nutrientes: o ATP volta mais depressa.", "tags": ["metabolism", "explore"], "eligible": num("intestino", "alimento", ">=", 40)},
                {"id": "jejum", "name": "Jejum", "desc": "Sem alimento, a vida escorre mais depressa.", "tags": ["endure"], "eligible": num("intestino", "alimento", "<", 20)},
            ],
            "rewards": [adj("$self", "pressao", 10), adj("$self", "maturidade", 6), adj("intestino", "microbiota", 25, max=100), adj("figado", "toxina", -10, min=0),
                        adj("corpo", "inflamacao", -10, min=0), {"op": "grant", "v": "selo-do-intestino"},
                        emit("criptas-limpas", "As criptas foram limpas: a microbiota volta a se reequilibrar.")],
            "first": {"skill": "primeira-muralha", "text": "foi a primeira a limpar as Criptas Profundas."},
            "retry": 6,
        },
    },
    "rim": {
        "entity": {"id": "rim", "kind": "tecido", "name": "Rim", "num": {"ureia": 25, "sodio": 50}},
        "passage": {"id": "arteria_renal", "from": "aorta", "to": "rim", "name": "Artéria renal"},
        "spots": [
            {"id": "glomerulo", "region": "rim", "name": "Glomérulo, o novelo onde o sangue é filtrado", "near": ["tubulo"]},
            {"id": "tubulo", "region": "rim", "name": "Túbulo contorcido, onde o que serve volta ao sangue", "near": ["glomerulo"]},
        ],
        "niche": {"id": "glomerulo-oculto", "region": "rim", "name": "Glomérulo oculto", "gene": "membrana-espessa", "unique": True,
            "hint": "Num novelo de capilares esquecido, uma membrana deixa passar a água e segura as proteínas, sem nunca errar.",
            "text": "A membrana do glomérulo deixa passar só o que deve. Você leva dali uma membrana espessa e seletiva, mais firme e um pouco mais lenta."},
        "vital": {"id": "ureia", "label": "Ureia (rim)", "e": "rim", "k": "ureia", "min": 0, "max": 100, "low": 0, "high": 70},
        "actions": [
            {"id": "filtrar-ureia", "title": "Filtrar ureia", "tags": ["metabolism", "endure"],
             "effects": [adj("rim", "ureia", -4, min=0), adj("$self", "maturidade", 1), adj("$self", "pressao", 1)]},
            {"id": "equilibrar-sal", "title": "Equilibrar o sal", "tags": ["metabolism", "explore"],
             "effects": [adj("rim", "sodio", -4, min=0), adj("$self", "maturidade", 1)]},
        ],
        "rules": [
            {"id": "rim-sodio-sobe", "every": 5, "when": num("rim", "sodio", "<", 100), "effects": [adj("rim", "sodio", 2, max=100)]},
            {"id": "figado-vira-ureia", "every": 10, "when": num("figado", "toxina", ">=", 40),
             "effects": [adj("figado", "toxina", -2, min=0), adj("rim", "ureia", 2, max=100)]},
            {"id": "rim-filtra-sozinho", "every": 8, "when": num("rim", "ureia", ">", 0), "effects": [adj("rim", "ureia", -1, min=0)]},
            {"id": "rim-sobrecarregado", "every": 6, "when": num("rim", "ureia", ">=", 80),
             "effects": [adj("aorta", "pressao", 3, max=100), adj("corpo", "inflamacao", 2, max=100),
                         emit("rim-sobrecarregado", "O rim não dá conta da ureia: a pressão na artéria sobe.")]},
        ],
        "quests": [
            {"id": "filtro-do-corpo", "title": "O filtro do corpo", "objective": "No rim, filtre 8 cristais de ureia antes que a pressão suba.",
             "desc": "Osteia explica: o fígado transforma o que envenena em ureia, e só o rim a tira do sangue.", "action": "filtrar-ureia", "n": 8},
            {"id": "sal-na-medida", "title": "Sal na medida", "objective": "Equilibre o sal do rim 8 vezes: sal demais prende água e aperta as artérias.",
             "desc": "Osteia lembra: quem controla o sal controla a pressão.", "action": "equilibrar-sal", "n": 8},
        ],
        "codex": [
            {"id": "cx-rim", "kind": "regiao", "title": "O rim", "when": "visit",
             "text": "Cada rim tem um milhão de néfrons: novelos de capilares que filtram o sangue e túbulos que devolvem o que ainda serve. Ele regula a água, o sal e a pressão do corpo."},
            {"id": "cx-ureia", "kind": "fisiologia", "title": "A ureia", "when": {"deeds": {"action": "filtrar-ureia", "op": ">=", "v": 1}},
             "text": "O fígado transforma a amônia, que é tóxica, em ureia, que o rim tira do sangue e manda para a urina. Se o rim falha, a ureia sobe e o corpo inteiro sofre."},
            {"id": "cx-glomerulo", "kind": "segredo", "title": "A barreira do glomérulo", "when": {"deeds": {"action": "nicho:glomerulo-oculto", "op": ">=", "v": 1}},
             "text": "A parede do glomérulo tem três camadas e poros tão finos que deixam passar água e sais, e seguram proteínas e células."},
        ],
        "dungeon": {
            "id": "nefrons", "name": "Os Néfrons", "skills": [
                {"id": "selo-do-rim", "name": "Selo do Rim", "desc": "Você limpou os néfrons uma vez: seu corpo guarda a lembrança do que o rim segura.", "rarity": "rara"},
                {"id": "primeiro-calculo", "name": "Primeiro Cálculo", "desc": "Foi a primeira célula a limpar os Néfrons. O corpo inteiro lembra.", "rarity": "epica"}],
            "desc": "Cristais se acumularam nos túbulos e uma pedra coraliforme bloqueia o rim por dentro. Se ninguém entrar, a pressão do corpo não volta ao normal.",
            "maturity": 22,
            "rooms": [
                {"id": "capsula-de-bowman", "name": "A cápsula de Bowman", "desc": "Cristais de urato rolam na entrada do glomérulo: pequenos, duros e rápidos.", "kind": "guard"},
                {"id": "o-calculo", "name": "O cálculo", "desc": "A pedra que cresceu nos túbulos até virar o rim por dentro.", "kind": "boss"},
            ],
            "pool": [
                {"id": "cortex-renal", "name": "O córtex", "desc": "Cilindros hialinos e cálculos pequenos, com cristais por perto.", "kind": "wall"},
                {"id": "glomerulo-entupido", "name": "O glomérulo entupido", "desc": "Cristais em cadeia: focos de ácido úrico os aceleram.", "kind": "core"},
                {"id": "alca-de-henle", "name": "A alça de Henle", "desc": "O túbulo se estreita e os cristais descem todos juntos.", "kind": "ambush"},
                {"id": "tubulo-contorcido", "name": "O túbulo contorcido", "desc": "Dobras de túbulo como colunas escondem espículas que atiram de longe.", "kind": "pillars"},
                {"id": "foco-de-pielonefrite", "name": "O foco de pielonefrite", "desc": "Uma infecção que gera bacilo atrás de bacilo até ser rompida.", "kind": "nest"},
                {"id": "medula-concentrada", "name": "A medula concentrada", "desc": "Poças de urina concentrada queimam a membrana; cristais que racham se escondem entre elas.", "kind": "hazard"},
            ],
            "depth": [3, 4],
            "modifiers": [
                {"id": "cristalizacao", "name": "Cristalização", "desc": "O núcleo e a pedra soltam cristais enquanto você demora.", "tags": ["combat", "endure"]},
                {"id": "pressao-alta", "name": "Pressão alta", "desc": "A pressão sobe e empurra os inimigos: andam mais depressa.", "tags": ["combat", "explore"], "eligible": num("aorta", "pressao", ">=", 60)},
                {"id": "ureia-alta", "name": "Ureia alta", "desc": "O corpo está intoxicado de ureia: a membrana escorre aos poucos.", "tags": ["endure", "metabolism"], "eligible": num("rim", "ureia", ">=", 50)},
                {"id": "rim-limpo", "name": "Rim limpo", "desc": "O filtro está em dia: o ATP volta mais depressa.", "tags": ["metabolism", "explore"], "eligible": num("rim", "ureia", "<", 40)},
                {"id": "diurese", "name": "Diurese", "desc": "A urina arrasta os cristais: cada inimigo aguenta menos.", "tags": ["knowledge"], "eligible": num("rim", "sodio", "<", 50)},
            ],
            "rewards": [adj("$self", "pressao", 10), adj("$self", "maturidade", 6), adj("rim", "ureia", -35, min=0), adj("aorta", "pressao", -10, min=0),
                        adj("corpo", "inflamacao", -10, min=0), {"op": "grant", "v": "selo-do-rim"},
                        emit("nefrons-limpos", "Os néfrons foram limpos: o rim volta a filtrar e a pressão cai.")],
            "first": {"skill": "primeiro-calculo", "text": "foi a primeira a limpar os Néfrons."},
            "retry": 6,
        },
    },
}

for oid, o in ORGANS.items():
    upsert(u["entities"], o["entity"])
    for passage in o["passage"] if isinstance(o["passage"], list) else [o["passage"]]:
        upsert(u["passages"], passage)
    for spot in o["spots"]:
        upsert(u["spots"], spot)
    upsert(u["niches"], o["niche"])
    upsert(u["vitals"], o["vital"])
    here = {"in": {"e": "$self", "region": oid}}
    for a in o["actions"]:
        upsert(u["actions"], {"id": a["id"], "title": a["title"], "by": ["adapter"], "requires": here, "tags": a["tags"], "effects": a["effects"]})
    for r in o["rules"]:
        upsert(u["rules"], r)
    visited = {"fact": {"p": "visitou", "s": "$self", "o": oid, "private": True}}
    for q in o["quests"]:
        upsert(u["quests"], {"id": q["id"], "giver": "estroma", "rank": "E", "title": q["title"], "desc": q["desc"], "objective": q["objective"],
            "reward": "Pressão evolutiva +3", "tags": ["metabolism", "explore"],
            "eligible": {"all": [visited, {"deeds": {"action": q["action"], "op": "<", "v": q["n"]}}]},
            "goal": {"deeds": {"action": q["action"], "op": ">=", "v": q["n"]}},
            "rewards": [adj("$self", "pressao", 3), adj("$self", "maturidade", 3), {"op": "relate", "e": "estroma", "to": "$self", "d": 1, "min": -10, "max": 10}]})
    for c in o["codex"]:
        entry = {k: v for k, v in c.items() if k != "when"}
        entry["when"] = visited if c["when"] == "visit" else c["when"]
        upsert(u["codex"], entry)
    d = o["dungeon"]
    for s in d["skills"]:
        upsert(u["skills"], s)
    upsert(u["dungeons"], {
        "id": d["id"], "name": d["name"], "desc": d["desc"], "region": oid, "eligible": num("$self", "maturidade", ">=", d["maturity"] * PACE),
        "rooms": d["rooms"], "pool": d["pool"], "depth": d["depth"], "modifiers": d["modifiers"], "rewards": d["rewards"],
        "firstClear": [{"op": "grant", "v": d["first"]["skill"]}], "firstText": d["first"]["text"], "retry": d["retry"]})

u["passages"] = [x for x in u["passages"] if x["id"] != "veia_porta"]
with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print("organs:", list(ORGANS), "dungeons:", [d["id"] for d in u["dungeons"]])
