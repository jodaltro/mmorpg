# 2026-10-28 — Hospedeiro P2–P5 (fatia mínima) · sociedade de NPCs autônomos + Jev ao vivo

- Baseline: `main` @ `725015d3` (P6/P7). Apenas testes em memória e `worldsim simulate` local; nenhum mundo real tocado. Go 1.27.2, Windows 10.
- O fingerprint do universo muda de novo (tarefas, entidade `macra`, ação de ajuda): journals antigos do Hospedeiro não abrem com ele (reinício autorizado; não executado aqui).

## Entregue
- `engine/core/npc.go`: `TaskDef`/`StepDef`/`BlockDef` genéricos no `Universe`; `NPCState` (tarefa, passo, fase `idle/travel/blocked/seek_help`, contadores de feitos/falhas/replanejamentos), rota por regiões com duração por trecho e efeitos na chegada, prioridade com preempção só em paradas, reserva exclusiva (`reserve`) com replanejamento, bloqueio com desvio, pedido de ajuda (`HelpRequest`: aberto → respondido → resolvido/expirado) só após espera e com cooldown, `MemoryEpisode` por NPC (limite 16, poda por saliência), `TopMemories`, `View.Society` (cada observador só vê a memória do NPC sobre si).
- Efeitos genéricos novos: `transfer` (move o que existe, sem criar nem perder), `assist` (um feito confirmado responde ao pedido de um NPC). A relação e a memória só mudam quando o pedido fecha como resolvido pelo mundo.
- Universo: Rubra (transporta O₂ pulmão→sangue; capilares obstruídos por carga ≥20 bloqueiam; pede ajuda), Neva (patrulha e defende o pulmão quando sabe do foco, credita `combate`), Dendra (colhe sinais no pulmão e só informa Neva quando se encontram), Macra (macrófago, entidade nova; fagocita e credita `limpeza`); Osteia = `estroma`, já com o objetivo `nutrir-nicho` (sem rotina nova). **Plaquetas não foram implementadas** (dependem de ferida/pele, P12).

## Testes executados (resultado real)
`go vet ./...` limpo; `go test ./... -count=1` todos `ok`.
- `society_test.go`: 900 ticks sem jogador — Rubra 54 entregas, Neva 55, Dendra 43, Macra 77 ciclos; NPCs mudam de região; nada negativo; Macra deixa crédito contra a infecção. Rubra bloqueada: espera ≥4 ticks, 1 pedido só (dedupe), visível a outro jogador na visão, cliente não confirma feito; feitos de p1 abrem o caminho → resolvido uma vez, relação `rubra|p1`=3 e `rubra|p2`=0, memória `ajuda-recebida` com a seq do evento, visível só para p1. Sem ajuda: pedido expira, memória `rota-interrompida`, nenhuma relação muda. Notícia só circula por observação/encontro e crença é corrigida ao olhar de novo. Reserva exclusiva (nunca 2 titulares, ambos têm vez), desvio sem pedido, 8 definições inválidas rejeitadas, replay do log reproduz o digest.
- Ajuste em teste existente: `TestHospedeiroTellingDendraArmsTheDefense` agora espera Dendra voltar ao sangue antes de o jogador falar com ela (ela passou a circular).
- `worldsim validate` ok.

## Jev ao vivo (autorizado)
`worldsim simulate -ticks 150 -players 2 -advisor jev -pace 1s` (modelo e chave do `engine/.env`; 2m30 reais): 205 decisões, todas respondidas pelo Jev (nenhuma caiu no padrão). Latência média por tipo: offer 818 ms, rota 398 ms, world 360 ms, design 670 ms, appearance 807 ms, evolution 377 ms, lineage 374 ms; custo total ≈ US$ 0,0112 (design 0,0083, rota 0,0010, world 0,0008, offer 0,0002). Digest `c63f4a66…27ce`. O diretor com Jev escolheu: febre 1, infecção-pulmonar 1, nenhuma 11, refeição 2, sono 2.
**Limite honesto:** o Jev ainda **não decide nada sobre tarefas de NPC nem conflitos** (P8 JevBatch/P9 deliberação não implementados); ele continua nas decisões já existentes (oferta, mundo, rota, design). Esta rodada valida que o mundo com a sociedade e o conflito roda com o Jev ao vivo sem travar, não que o Jev melhora a sociedade.

## Não executado / pendências
Godot, Nakama, HUD e animação (P10/P10V/P11) não tocados — nenhum NPC é visível no cliente ainda; energia/capacidade do NPC (P2.1) não modelada; roteamento por grafo de passagens com capacidade (hoje tempos fixos por trecho); JevBatch/benchmark A/B 1.13×1.14; migração das dungeons (P13); operação 24/7 e checkpoints (P14); stress 10–180 min e 500 NPCs (P15). Gates P2/P3 parciais (motor local aprovado, sem encarnação Godot).
