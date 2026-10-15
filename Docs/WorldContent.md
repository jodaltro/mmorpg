# Mundo e conteúdo do Marco 05

Catálogo canônico em `Backend/authority/journey/content.json`, produzido por `AgentScripts/GenerateWorldContent.py`. Go valida IDs, referências, recompensas, condições contraditórias, regiões desconectadas e ilhas de dependências sem entrada. A Unity usa `/v1/content` para apresentação; não replica o motor de consequências.

Contagens da expansão: **5 regiões, 9 criaturas, 12 NPCs, 12 habilidades, 38 itens, 31 oportunidades e 15 pontos de interação**. Arte placeholder reutiliza sprites originais. A cena offline, Mira/Orin, Leitura, amostra, rotas e acontecimentos dos Marcos 01–04 continuam preservados; o mundo expandido é `marco05-expanded`, separado da demonstração `marco05-dev`.

## Criaturas

| ID / criatura | Região | Mecânica | Extração |
|---|---|---|
| `corrupted-wolf` — Lobo Corrompido | Floresta Cinzenta | Persegue de perto; golpe telegrafado permite esquiva/exposição. | Corruption Sample × 1, Wolf Fang × 2, Gray Pelt × 2 |
| `thorn-boar` — Javali de Espinhos | Floresta Cinzenta | Carga forte; após resolver impacto recua distância e exige aproximação. | Boar Tusk × 2 |
| `venom-spider` — Aranha Tóxica | Pântano dos Ecos | Golpes não bloqueados aplicam veneno por três turnos. | Spider Venom × 3 |
| `cave-bat` — Morcego de Cristal | Minas de Kharum | Inicia a distância 2; ataques próximos falham; aproximação/Marca/Impacto aterrissam. | Bat Wing × 3 |
| `stone-sentinel` — Sentinela de Pedra | Minas de Kharum | Reduz ataque físico em 14 até ser fraturada. | Stone Core × 2 |
| `burrow-crawler` — Rastejante Escavador | Minas de Kharum | Oculta-se após agir; ataque não acerta até exposição ou fratura. | Crawler Shell × 2 |
| `echo-wisp` — Eco Errante | Pântano dos Ecos | Recebe apenas um terço de dano físico até purificação/fratura. | Echo Essence × 2 |
| `mire-hydra` — Hidra do Lodo | Pântano dos Ecos | Regenera 6 por turno; queimadura ou fratura interrompem. | Mire Heart × 2 |
| `asterion-guardian` — Guardião de Asterion | Ruínas de Asterion | Proteção frontal recebe um quarto de dano; exposição/fratura abre defesa. | Guardian Fragment × 2 |

Derrota, distância abstrata, vida, turnos e loot pertencem ao Go. Não há comprovação de colisão/movimento real, projéteis físicos ou perseguição espacial no mundo expandido. Essas mecânicas são encontros discretos, distintos da simulação física offline do lobo.

## NPCs

| ID / identidade | Local | Função | Conhecimento inicial (fonte: conversa local) |
|---|---|---|
| `mira` — Mira | Floresta Cinzenta | pesquisa | lore:corruption |
| `orin` — Orin | Floresta Cinzenta | caça | lore:weakness |
| `helena` — Helena | Valdoria | acolhimento | lore:routes |
| `brann` — Brann | Valdoria | forja | lore:armor |
| `lia` — Lia | Valdoria | exploração | lore:stealth |
| `selka` — Selka | Valdoria | alquimia | lore:fire |
| `dorin` — Dorin | Minas de Kharum | mineração | lore:fracture |
| `tessa` — Tessa | Minas de Kharum | arquivo | lore:mines |
| `nera` — Nera | Pântano dos Ecos | ervas | lore:toxin |
| `ivo` — Ivo | Pântano dos Ecos | travessia | lore:marsh |
| `soren` — Soren | Ruínas de Asterion | história | lore:asterion |
| `enya` — Enya | Ruínas de Asterion | ecos ancestrais | lore:ancestors |

Conversas exigem a região correta. Conhecimento inicial é transmitido somente ao personagem que conversa; relação e fonte são privadas. Descobertas oferecidas a um NPC ficam vinculadas a fatos daquele personagem. Não há onisciência automática.

## Oportunidades combináveis

| ID / oportunidade | Linha / região | Condições | Consumo | Efeito |
|---|---|---|---|
| `forest-sample` — Amostra para Mira | forest / Floresta Cinzenta | talk:mira | Corruption Sample × 1 | Leitura de Fraquezas |
| `forest-observation` — Observar a caçada | forest / Floresta Cinzenta | tracking-confirmed, defeat:corrupted-wolf, talk:orin | — | Leitura de Fraquezas |
| `hunter-mark-training` — Leitura do rastro | forest / Floresta Cinzenta | tracking-confirmed, talk:orin | — | Marca do Caçador |
| `silent-grove-route` — Contornar as raízes | forest / Valdoria | visited:gray-forest, talk:lia | — | Passo Silencioso |
| `silent-marsh-route` — Travessia dos juncos | swamp / Pântano dos Ecos | lore:marsh-memory, talk:ivo | — | Passo Silencioso |
| `counter-training` — Resposta ao preparo | forest / Valdoria | practice:dodge, talk:brann | — | Contra-ataque |
| `guard-training` — Defender o impacto | mines / Valdoria | practice:guard, talk:brann | — | Guarda Reforçada |
| `mining-tools` — Ferramentas de Kharum | mines / Minas de Kharum | talk:dorin | — | Picareta × 1 |
| `fracture-training` — Fraturar sem esmagar | mines / Minas de Kharum | done:mining-tools, talk:dorin | Iron Ore × 1 | Golpe Fraturante |
| `seismic-training` — Vibração das camadas | mines / Minas de Kharum | discovery:crystal-seam, talk:dorin | Basalt × 1 | Impacto Sísmico |
| `seismic-combat-route` — Aprender com a sentinela | mines / Minas de Kharum | defeat:stone-sentinel, talk:tessa | — | Impacto Sísmico |
| `toxin-study` — Estudar o veneno | swamp / Pântano dos Ecos | talk:nera | Toxic Reed × 2 | Resistência Tóxica |
| `toxin-combat-route` — Sobreviver à aranha | swamp / Pântano dos Ecos | defeat:venom-spider, talk:nera | — | Resistência Tóxica |
| `essence-research` — Estabilizar a corrupção | forest / Floresta Cinzenta | investigation-confirmed, talk:mira | Gray Herb × 1 | Extrair Essência |
| `essence-marsh-route` — Ouvir a matéria | swamp / Pântano dos Ecos | defeat:echo-wisp, talk:ivo | Echo Lotus × 1 | Extrair Essência |
| `combustion-training` — Combustão controlada | forest / Valdoria | talk:selka | Sulfur × 1, Ember Seed × 1 | Combustão Alquímica |
| `ancestral-study` — Reconhecer os ecos | asterion / Ruínas de Asterion | lore:inscription, lore:marsh-memory, talk:enya | — | Sentido Ancestral |
| `ancestral-mines-route` — Comparar os registros | asterion / Ruínas de Asterion | lore:miners-seal, talk:soren | Miners Seal × 1 | Sentido Ancestral |
| `purification-training` — Purificar as águas | swamp / Pântano dos Ecos | lore:corruption, lore:lotus, talk:nera | Salt × 1, Pure Water × 1 | Purificação |
| `forge-blade` — Forjar lâmina | mines / Valdoria | talk:brann | Iron Ore × 2, Wolf Fang × 1, Coal × 1 | Lâmina de Ferro × 1 |
| `forge-mail` — Forjar malha | mines / Valdoria | talk:brann | Copper Ore × 2, Crawler Shell × 1, Coal × 1 | Malha Reforçada × 1 |
| `weave-cloak` — Costurar manto | forest / Valdoria | talk:lia | Gray Pelt × 1, Boar Tusk × 1, Bat Wing × 1 | Manto do Caçador × 1 |
| `silver-ward` — Amuleto ressonante | asterion / Ruínas de Asterion | talk:enya | Silver Ore × 1, Quartz × 1, Stone Core × 1 | Amuleto de Prata × 1 |
| `brew-healing` — Preparar infusões | forest / Valdoria | talk:helena | Gray Herb × 2, Pure Water × 1 | Infusão Curativa × 3 |
| `brew-antidote` — Preparar antídotos | swamp / Pântano dos Ecos | talk:nera | Spider Venom × 1, Toxic Reed × 1, Pure Water × 1 | Antídoto × 3 |
| `brew-fire` — Preparar frascos ígneos | forest / Valdoria | talk:selka | Sulfur × 1, Ember Seed × 1, Bat Wing × 1 | Frasco Ígneo × 3 |
| `brew-purifier` — Preparar sais | swamp / Pântano dos Ecos | talk:nera | Echo Lotus × 1, Salt × 1, Echo Essence × 1 | Sal Purificador × 3 |
| `forest-restoration` — Memória contra corrupção | forest / Floresta Cinzenta | lore:marsh-memory, talk:mira | Sal Purificador × 1, Ancient Moss × 1 | region:forest-restored (compartilhado, autoria única) |
| `mines-awakening` — Despertar a ressonância | mines / Minas de Kharum | defeat:stone-sentinel, talk:tessa | Stone Core × 1, Mire Heart × 1 | region:mines-awakened (compartilhado, autoria única); agenda em 2 ações confirmadas |
| `asterion-beacon` — Acender o farol de Asterion | asterion / Ruínas de Asterion | lore:glyph, lore:marsh-memory, talk:soren | Asterion Glyph × 1, Historical Fragment × 1, Guardian Fragment × 1, Echo Essence × 1 | world:asterion-beacon (compartilhado, autoria única) |
| `beacon-attunement` — Ouvir o farol compartilhado | asterion / Ruínas de Asterion | world:asterion-beacon, talk:enya | — | Sentido Ancestral |

A interface exibe no máximo três oportunidades disponíveis por região. A elegibilidade é reavaliada: custos, conhecimento, estado mundial e ignorar/completar podem retirar ou abrir possibilidades. Nem todo ponto/conversa abre oportunidade. As quatro linhas não são campanhas obrigatórias.

O farol `asterion-beacon` exige glifo, memória do pântano e materiais de encontros distintos; transação, lock mundial e UNIQUE garantem uma única ativação/autoria por mundo. Outros personagens ganham uma rota alternativa de Sentido Ancestral, sem copiar inventário ou fatos privados. Para repetir o experimento, criar/seedar outro mundo is_test ou resetar explicitamente o banco de desenvolvimento autorizado; nunca tentar remover só um evento de um mundo confiável.
