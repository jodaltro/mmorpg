# Habilidades do Marco 05

As 12 técnicas abaixo têm regras e efeitos na autoridade Go do protótipo por turnos. A cena `Marco05World.unity` envia as intenções e apresenta seus resultados; não são 12 habilidades do combate físico de `OfflineClearing.unity`, que permanece com Leitura de Fraquezas. [Validação](Validation/Marco05.md).

Cooldown usa turnos/ações confirmados do personagem, nunca movimento ou relógio informado pelo cliente. Ativas exigem personagem vivo, encontro ativo, desbloqueio e cooldown vencido; validação específica está na tabela. Passivas não aceitam ativação manual. Não há níveis ou XP.

| ID / habilidade | Efeito e condição | Cooldown | Rotas de descoberta |
|---|---|---|---|
| `weakness-reading` — Leitura de Fraquezas | Passiva: +10 em ataque durante exposição. | 0 turnos | forest-sample, forest-observation |
| `counterattack` — Contra-ataque | Ativa no preparo: 25 de dano, interrupção e exposição; impede o golpe inimigo. | 2 turnos | counter-training |
| `fracturing-strike` — Golpe Fraturante | Ativa em alcance próximo: 18 de dano; remove proteção de armadura/escavação. | 3 turnos | fracture-training |
| `silent-step` — Passo Silencioso | Ativa: aproxima, abre exposição e evita resposta naquele turno; também permite extrair musgo do bosque. | 3 turnos | silent-grove-route, silent-marsh-route |
| `toxic-resistance` — Resistência Tóxica | Passiva: dano periódico do veneno cai de 6 para 2. | 0 turnos | toxin-study, toxin-combat-route |
| `extract-essence` — Extrair Essência | Capacidade de extrair essência estabilizada após derrota verificada do eco. | 0 turnos | essence-research, essence-marsh-route |
| `seismic-impact` — Impacto Sísmico | Ativa: 22 de dano, aproxima/aterrissa, fratura e interrompe o preparo. | 4 turnos | seismic-training, seismic-combat-route |
| `hunter-mark` — Marca do Caçador | Ativa: aterra/aproxima; ataques seguintes +5 naquele encontro. | 3 turnos | hunter-mark-training |
| `alchemical-combustion` — Combustão Alquímica | Ativa com estojo equipado: 8 de impacto e três aplicações de 10 de queimadura; impede regeneração. | 3 turnos | combustion-training |
| `reinforced-guard` — Guarda Reforçada | Ativa no preparo: bloqueia o golpe, registra defesa validada. | 2 turnos | guard-training |
| `ancestral-sense` — Sentido Ancestral | Capacidade de revelar/obter glifo nas ruínas; sem bônus bruto de combate. | 0 turnos | ancestral-study, ancestral-mines-route, beacon-attunement |
| `purification` — Purificação | Ativa: remove veneno, cura 5, fratura; 12 de dano, ou 30 contra eco etéreo. | 4 turnos | purification-training |

As rotas incluem investigação/entrega, observação de combate, rastreamento, treinamento por defesa/esquiva, mineração, estudo alquímico, comparação de inscrições e consequência histórica compartilhada. Ignorar uma oportunidade não bloqueia uma rota alternativa. Equipar o amuleto reduz veneno; armadura e manto reduzem dano. Nenhuma técnica concede recompensa por um `CreatureDefeated` enviado pelo cliente.
