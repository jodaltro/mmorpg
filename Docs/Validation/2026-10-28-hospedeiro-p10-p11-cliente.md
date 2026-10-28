# Hospedeiro Vivo — P10/P10V/P11 no cliente Godot (28/10/2026)

Branch `main`. Validação **apenas local** (decisão de 24/10/2026). Registra só o que foi executado nesta sessão.

## O que mudou

**Motor (Go), só campos novos no contrato `/v1` (compatível):**
- `society[]` agora informa `dest` (região do trecho em andamento), `step`, `steps`, `since` e `arrive`. O cliente calcula o progresso real do trecho a partir dos ticks do motor.
- `conflicts.active[]` informa `frontRegions` (região alcançada por cada frente aberta), para o espalhamento só aparecer onde e quando o motor o abriu.

**Cliente (GDScript), antes sem nenhuma leitura de `society`/`conflicts`/`populations`:**
- Domínio puro: `BioLivingModel` (visão → avisos; a primeira visão é histórico; transição velha demais não vira aviso), `BioAlertQueue` (deduplicação por `conflito:revisão:tipo`, prioridade, validade de 20 s, histórico), `BioInteractionState` (notice/approach/anticipate/act/progress/blocked/help/confirmed/cancel/recover), `BioNpcRoles`, `BioConflictFocus`, `BioVisualPrefs`.
- Mundo: `BioNpcPresenter` (um ator por id canônico, posição calculada do progresso do motor, só em regiões vivas, três níveis de detalhe), `BioNpcActor` + `BioNpcFx` (sete silhuetas, oito gestos, tudo procedural, sem nós de partícula), `BioTissueMood` (cor, pulsação, fissuras e névoa por região conforme fase e gravidade).
- Interface: `BioLivingHud` (conflito acompanhado + dois resumos, alerta grande não bloqueante, pedido de ajuda contextual, painel de crises na tecla **L** com filtros, pedidos, avisos e opções visuais/acessibilidade; **H** responde ao pedido), `BioLivingSound` (tons sintetizados, opcional).
- Missões: o cartão e as ofertas da interface principal só mostram a história e os primeiros passos (`STORY_QUESTS`); as demais continuam na janela de missões e continuam sendo confirmadas ao motor.
- "Ajudar" **não declara feito**: aponta a seta até a célula e a crise. Só conta o que o servidor confirma.
- A autoridade headless (`bio_game_server.gd`) não desenha nada (`living_enabled = false`).

## Testes executados

| Verificação | Resultado |
|---|---|
| `gofmt -l .`, `go vet ./...` em `engine/` | limpos |
| `go test ./... -count=1` | todos os pacotes `ok` (inclui o novo `TestSocietyViewCarriesLegProgress`) |
| Godot headless, suíte completa | **409 testes, 0 falhas** (eram 387; 13 novos em `test_living_body.gd`, 9 em `test_living_world.gd`) |
| `test_host.gd::test_view_shows_the_call_…` | alterado de propósito: a oferta usada agora é de uma missão de história |
| Capturas com renderizador real (`tests/capture_living.gd`) | geradas em 1280x720 e 844x390; olhadas por mim, **sem avaliação de jogadores** |

`ERROR: 1 RID allocations … leaked at exit` aparece ao fim da suíte; não investiguei se já existia.

## Desempenho (real, uma máquina, `tests/bench_living.gd`)

Resolução 1280x720, vsync em 60 Hz (linha de base ≈ 16,6 ms). Pior caso: **todas as células empilhadas na tela**, 3 s por caso. Média em ms (p99):

| células | alto | padrão | econômico |
|---|---|---|---|
| 0 | 16,65 (18,5) | 16,65 (17,9) | 16,64 (17,5) |
| 1 | 16,64 (19,2) | 16,64 (17,5) | 16,65 (17,7) |
| 7 | 18,68 (21,7) | 18,96 (25,2) | não medido |
| 20 | 25,46 (30,2) | 22,03 (26,2) | 17,21 (21,3) |
| 50 | 31,97 (43,0) | 28,07 (37,3) | 19,97 (27,6) |
| 100 | 42,39 (53,6) | 37,73 (48,1) | 25,23 (28,8) |

- A primeira medição deu 24,6 ms só no `_process` do apresentador com 100 células: `BioAnatomy.region_def` reconstrói a definição do corpo a cada chamada. Foi corrigido guardando centro e raio de cada região; sem isso 20 células caíam para ≈ 27–37 ms.
- O corpo deformável completo (`BioCellBody`) é a parte cara; só as células mais próximas o recebem (12/8/4 por preset). As demais viram silhueta leve ou ponto, e nada é desenhado fora da tela.
- O mundo real tem 7 células nomeadas. Os números de 20–100 são para a escala futura, não para o que existe hoje.
- **Não medido:** aparelho móvel, GPU-alvo, memória, tráfego com vários jogadores.

## Motor local reiniciado

`worldsim-living2.exe` (porta 8096, `-advisor jev`, mundo preservado, retomou no tick 1660), Nakama 7350 (health 200) e a autoridade Godot foram reiniciados para carregar os scripts novos. Conferido por HTTP que a visão real traz `dest/step/steps/since/arrive` e as populações; no momento não havia crise ativa.

## Limitações conhecidas (não declaradas como feitas)

- **P10.6 não feito:** dois clientes reais via Nakama não foram executados; só dois apresentadores sobre a mesma visão em teste.
- Não foi jogado por pessoas: legibilidade e prazer dos gestos são uma primeira passada, sem avaliação. Rótulos pequenos podem se sobrepor quando as células ficam juntas; os braços do macrófago são retos e pouco orgânicos.
- Osteia (estroma) ainda não tem tarefa no universo, então não há V07.
- O motor ainda não envia um `interaction_id`; a deduplicação usa os contadores `done`/`failed`.
- O espalhamento visual só aparece para frentes que o motor abriu; as outras quatro crises não têm frentes.
- Layout de toque conferido só por resolução pequena em desktop; vibração, controles móveis e web não foram testados em aparelho.
- Há um objeto achatado de cor oliva ao lado do jogador no pulmão nas capturas; não é um dos atores novos (confirmado pelos deslocamentos dos quatro atores), não foi identificado.
- Não foram feitos: P12 (outros órgãos), P13 (migração das masmorras), P14 (operação 24/7), P15 (estresse), avaliação cega do Jev.

## Atualização — Osteia, P12.2 e corpo orgânico (28/10/2026, mais tarde)

**Correção:** o "objeto oliva" das capturas era meu: eram as bolhas de bactéria do `BioTissueMood` desenhadas com raio de 50 px (`rad*0.025`). Reduzidas para ≈ 9 px. Não havia objeto desconhecido (a afirmação anterior de que "não era dos atores novos" estava certa, mas a origem era o tecido).

**Universo (`worldsim validate` ok):** Osteia (`estroma`) ganhou as tarefas `nutrir-nicho-medular` (reserva da medula, credita a crise) e `rondar-nicho`; nova crise `medula-esgotada` (reserva ≤ 15, resolve ≥ 55) com resposta `reforcar-nicho`; happening `convocacao-em-massa` (esvazia 48 da reserva); Esplena devolve 6 de ferro por ciclo em vez de 3 (com 3, a congestão do baço não fechava em 4500 ticks neste mundo).

**Testes Go:** `TestOsteiaFeedsTheMarrowNicheWithoutPlayers`, `TestMarrowExhaustionOpensEscalatesAndRecoversOnlyWithTheStroma`, `TestSpleenIronMarrowReserveChain`; `go vet` e `go test ./... -count=1` verdes. Três testes antigos foram ajustados porque a nova vida muda a sequência do diretor: o de revisão passou a ignorar `conflict-attention` (não é transição), o do pulmão sem defensores remove Osteia, e o de cinco crises roda 4500 ticks.

**Cliente:** no PC o jogo é offline por padrão (Nakama só com `--online`). A célula agora é **uma só membrana**: braços, garras, espinhos, raízes e bocas são lóbulos da própria membrana, a cor é um gradiente (centro → borda → ponta de cada extensão) e o corpo todo se move (inclina para o trabalho, junta-se antes dele, estica na direção do movimento e arrasta ao andar). Cada extensão é uma mola própria com ritmo e fase próprios e cada célula tem seu andamento (`BioNpcMotion`). Godot: **413 testes, 0 falhas**.

**Desempenho do corpo orgânico (pior caso, todas na tela), média em ms:** 7 células: alto 19,8 / padrão 19,4 / econômico 16,6; 20: 28,9 / 19,4 / 16,7; 100: 59,2 / 26,9 / 29,5. O preset alto com 20 células empilhadas passa de 28 ms; o mundo real tem 8 células nomeadas.

**Não feito:** avaliação com jogadores; anemia visível no sangue; P12.3–P12.7.
