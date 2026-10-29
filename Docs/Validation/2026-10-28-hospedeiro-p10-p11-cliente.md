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

## Atualização — P12.3 a P12.7 e reset completo (28/10/2026, noite)

**Universo (`worldsim validate` ok), tudo no JSON, nada no motor:** 6 células novas (Nefra, Entera, Linfa, Regina, Gliana, Nika; 14 no total), 3 tecidos (`linfonodo`, `cerebro`, `tumor`), 4 populações (néfrons, linfócitos, glia, NK), 4 crises (`sobrecarga-renal`, `reacao-exagerada`, `sofrimento-cerebral`, `tumor-intestinal`), 15 regras, 4 eventos (`mutacao-celular`, `queda-de-oxigenio-cerebral`, `ruptura-de-tolerancia`, `convocacao-em-massa`) e 12 tarefas. Simulação de 6000 ticks sem jogadores: as 14 células trabalham, nenhuma crise fica presa.
**Decisões de equilíbrio descobertas na simulação:** a inflamação do corpo já ficava perto de 100 quase o tempo todo (citocinas da infecção); por isso a crise imune depende da *tolerância* do linfonodo e não só da inflamação, Regina só trabalha com tolerância ≥ 40 (guarda reserva) e o tumor cresce com a inflamação mas Nika elimina 8 por ciclo. Sem isso o tumor e a tempestade imune entravam em espiral sem volta.
**Testes Go (`engine/scenarios/p12_test.go`):** cascata fígado→rim; Nefra encurta a recuperação; Entera salva a flora e passa nutrientes ao sangue; antígeno do baço vira memória no linfonodo; regulação custa tolerância sem zerá-la; cérebro sem oxigênio sofre e a glia acelera; tumor cresce sem NK e some com NK; nove crises ao mesmo tempo, determinísticas, com oito fechadas e nove células creditadas. `go vet` e `go test ./... -count=1` verdes. Testes antigos ajustados porque agora há células que mantêm o corpo saudável: o das cinco crises e o das cadeias de órgãos removem Entera/Nefra/Kupffer onde estudam o órgão nu.
**Cliente:** três regiões novas no mapa (pele, linfonodo, cerebro), seis silhuetas novas (tubo, vilosidade, redonda, coroa, astrócito, assassina) e dois gestos (acalmar, matar), todos como deformação da membrana; textos das quatro crises; massa do tumor desenhada no tecido. Godot: **415 testes, 0 falhas**. Captura real com as 14 células conferida por mim.
**Reset completo:** `scripts/hospedeiro-reset.ps1` arquiva (não apaga) mundo, saves do cliente e banco do Nakama e sobe motor novo. Executado: mundo no tick 0, banco do Nakama arquivado (o supervisor o recria no próximo uso online), 0 saves de personagem no cliente.
**Não feito:** avaliação com jogadores; anemia visível; o banco do Nakama não foi recriado nesta sessão (foco offline); cérebro e linfonodo ainda sem moradores de combate próprios (só as células e as crises).

## Atualização — anemia visível e moradores de pele, linfonodo e cérebro (28/10/2026, noite)

**Anemia no sangue:** `BioTissueMood.set_populations` lê a população `hemacias_sangue` (contagem contra a linha de base do motor). Abaixo de 85% a vênula empalidece e mostra anéis vazios; com metade das hemácias a anemia é total; some aos poucos quando a medula repõe. Só desenho: o número é do motor, nada muda em fatos ou colliders. Teste: `test_anemia_shows_in_the_blood_only_when_the_red_cells_fall`.
**Moradores:** `BioBestiary` ganhou pele (estafilococo, fungo da pele), linfonodo (micobactéria do nódulo, célula metastática) e cérebro (ameba cerebral que se divide, agregado amiloide), cada um com a sua definição em `BioDungeonPlan.enemy`. Teste: `test_the_new_places_have_their_own_wild_things`.
**Godot:** 417 testes, 0 falhas. Não rodei o Go (sem mudança no motor ou no universo).
**Ainda não feito:** avaliação com jogadores, o visual dos novos inimigos não foi visto em captura, e o banco do Nakama segue sem ser recriado (foco offline).

## Atualização — P13: masmorras extintas no Hospedeiro (28/10/2026, noite)

**Estratégia:** reset e recriação (política de 28/10/2026). Nada de conversão de saves, runs ou genes antigos. Mapa de equivalência e o que se perdeu de propósito: `Docs/Hospedeiro/DungeonMigration.md`.
**Motor (genérico):** `ConflictDef.rewards` e `rewardMinCredit` pagam, na resolução, quem contribuiu o mínimo (padrão 3); NPCs e quem só assistiu não recebem; paga uma vez por instância; evento privado `conflict-reward`. Universo: removido `dungeons`; as cinco crises (pulmonar, hepática, esplênica, intestinal, renal) pagam pressão, maturidade e o selo do órgão; `filtrar-ureia` passou a contribuir com a crise renal.
**Testes Go (rodados):** `p13_test.go` (o Hospedeiro não tem masmorra nem entrada; cada crise concede o selo certo; o jogador que filtrou toxinas recebe o selo e a pressão, quem assistiu não, um evento privado, nada paga duas vezes). Os cenários de masmorra do motor genérico passaram a rodar no fixture `engine/scenarios/testdata/legacy-dungeons`. `gofmt`, `go vet` e `go test ./... -count=1` verdes. `worldsim validate` ok e `simulate` de 3000 ticks com 3 jogadores sem travar.
**Cliente (Godot):** removidos `BioDungeon`, `BioDungeonPanel`, `BioGate`, `BioHazardPool`, `BioBossSlam`, os portais, o HUD/atlas/toque/tutorial da masmorra, o menu de depuração do granuloma e a sala isolada do servidor autoritativo; `BioDungeonPlan` virou `BioEnemyCatalog` (os selvagens usam). Testes só de masmorra apagados (9 arquivos de teste/e2e/captura, mais `e2e_organs` e `balance_duel`) ou reduzidos. Godot: **381 testes, 0 falhas**, sem `SCRIPT ERROR`. Um teste de travessia falhou uma vez porque rodei o Go ao mesmo tempo e passou sozinho e na suíte completa.
**Reset:** `scripts/hospedeiro-reset.ps1` rodado; mundo novo no ar (arquivo `20261028-154705`), universo sem masmorras.
**Não feito:** os genes raros que as masmorras davam (`rewardPools`) foram descartados; não houve avaliação com jogadores nem partida real do cliente nesta rodada; o catálogo mantém criaturas de chefe e ninho sem uso; o modo online não foi exercitado.

## Atualização — P14: operação contínua neste PC (28/10/2026, noite)

**Decisão:** servidores no PC do usuário; o PC desligado para o mundo (pausa fiel ao tick, sem recuperar). Detalhes em `Docs/Hospedeiro/Operations.md`.
**Motor:** checkpoint verificado (`sim/ops.go`), `Runner.Metrics`, `/v1/health` com status, `/v1/metrics`, `serve` com `-checkpoint-every`, `-max-questions-per-minute`, `-max-cost-per-hour`, `-batch-window`; o tick que não consegue ser gravado derruba o processo em vez de congelar o mundo.
**Defeito achado e corrigido:** um estado lido do JSON volta com mapas vazios nulos e o motor quebrava ao escrever neles (`assignment to entry in nil map` na primeira tarefa de NPC). Criado `World.Revive`; o cache do mundo pessoal (`engine/personal`) tinha o mesmo defeito e foi corrigido (o teste novo falha sem a correção, conferido removendo-a).
**Testes Go (rodados):** reinício pelo checkpoint igual ao replay completo e continuando igual; queda com cauda reexecutada (<150 comandos); checkpoint duvidoso (lixo, digest errado, outra versão, à frente do log) ignorado com o log decidindo; geração anterior cobre escrita rasgada; pausa fiel ao tick; tick sem gravar faz `Run` sair com erro e nada avança; métricas distinguem ok de stalled; estado e eventos limitados em 8000 ticks (238 KB → 285 KB, 1000 eventos); cache pessoal restaurado vive igual ao replay; orçamento de tick para 14/100/500 células.
**Vigia (rodado de verdade, isolado):** o motor morto foi reiniciado e o mundo seguiu do mesmo tick; o arquivo de parada encerrou vigia e motor. Reset rodado com o vigia: mundo novo no ar, `/v1/metrics` respondendo.
**Orçamento medido (este PC):** 14 células 0,35 ms/tick, 100 células 0,76 ms, 500 células 5,76 ms (p99 20 ms); o tick tem 4000 ms.
**Não feito:** compactação do log (cerca de 7 MB por dia); backup automático e failover; parada limpa pelo vigia (ele mata o motor, então a parada comum reexecuta a cauda); a tarefa agendada e as opções de energia não foram instaladas (dependem do usuário); teto de contexto do Jev; escala acima de 500 células e coortes maiores (P15).

## Correção — reset do cliente e minimapa do PC (28/10/2026, noite)

**Erro meu no reset:** `scripts/hospedeiro-reset.ps1` nunca arquivou os saves do cliente: o `-Include` sem curinga no caminho não filtra nada, e as pastas `client` dos arquivos ficaram vazias. O relato anterior de "0 saves de personagem" estava errado. Efeito visível: o save antigo (classe dendrítica, habilidades e identidade de sessões passadas) continuou valendo e a célula já nascia com a forma evoluída. Corrigido o filtro e o script agora avisa quando sobra save. Os 15 saves foram arquivados à mão em `D:\unity\hospedeiro-data-archive\20261028-165942-client`; restam 0.
**Cuidado:** com o jogo aberto, ele pode regravar os saves ao fechar; o reset só vale com o cliente fechado (o script já o fecha).
**Minimapa:** só existia nos controles de toque, então no PC não aparecia. Agora há um no canto superior direito (150 px), com o corpo inteiro, a célula, a rota e um anel nas crises; o clique abre o atlas. Teste: `test_the_pc_has_a_minimap_that_opens_the_atlas`. Godot: 382 testes, 0 falhas.
**Não verificado:** a aparência inicial depois do reset não foi vista na tela; a célula nova não deveria vir de save nem do motor (a aparência só chega depois de 20 gestos).

## Atualização — o corpo trabalhando à vista e balões de fala (28/10/2026, noite)

**Queixa do usuário:** os NPCs só andavam de lá para cá, sem nada para tratar no mapa; faltavam os que combatem os vírus; o mapa parecia vazio.
**Causa:** o motor contava os grupos (40 neutrófilos no pulmão, 40 hepatócitos...) mas só os 14 NPCs nomeados eram desenhados, e nenhum deles agia sobre o que existia no mapa (vírions, toxinas, hemácias velhas, cristais). Não era falta de coisas no mapa: era falta de trabalho sobre elas.
**Agora (só apresentação, nenhum número do corpo muda):**
- `BioWorkCrowd`: de cada população de um órgão vivo perto do jogador aparece uma parte (25% da contagem do motor, até 10/7/3 por grupo e 48/28/12 no total, conforme o preset). Defensores (neutrófilos, macrófagos, NK, plaquetas, glia) caçam os invasores do órgão e os derrotam; hepatócitos comem toxinas, o baço recicla hemácias velhas, os néfrons filtram cristais de ureia, a flora come bactérias boas, as hemácias descem a corrente. Competem com o jogador pelas mesmas coisas do mapa; **uma morte causada por eles não paga o jogador**.
- Os NPCs nomeados também agem sobre o que está ao alcance: Neva e os outros viram-se para o invasor e golpeiam, Kupffer pega toxinas, Esplena e Macra engolem.
- `BioSpeech` e `BioSpeechBubble`: balões pequenos com falas curtas sobre a tarefa (as 27 tarefas têm falas), enquanto trabalham, pedem ajuda ou concluem; no máximo 4/3/1 balões por vez (preset), nunca a mesma fala duas vezes seguidas; os trabalhadores também falam, perto do jogador.
**Testes Godot (rodados):** fração do grupo desenhada e limites; trabalhador vai ao alvo, trabalha e conclui; passeia sem atravessar a parede; defensores matam um invasor e o jogador não recebe nada; hepatócitos limpam a toxina; célula nomeada fala sobre a própria tarefa e o limite de balões; toda tarefa tem falas. Suíte inteira: **390 testes, 0 falhas**.
**Não feito:** ninguém viu na tela (o equilíbrio entre quantos invasores sobram para o jogador e quantos os defensores matam precisa de olho humano); os grupos não são persistentes nem têm identidade (são só uma amostra visual); o custo de desenho com 48 trabalhadores não foi medido.

## Atualização — células do corpo bem desenhadas e mapa mais cheio (28/10/2026, noite)

**Queixa:** as células sem nome estavam feias e o mapa ainda parecia vazio, sem interações.
**Causa vista numa captura real do PC** (`tests/capture_crowd.gd`): o mapa é enorme (o pulmão tem 4000 px de lado) e quase preto, as coisas estavam espalhadas por ele inteiro e as células tinham uns 17 px, apagadas e feitas de um polígono simples.
**Células (`BioCellArt`):** uma só membrana que respira e se deforma onde a célula alcança, gradiente do núcleo claro à borda escura, borda iluminada, brilho e halo suave; cada função com forma própria: neutrófilo com núcleo em lóbulos, macrófago e glia com pseudópodes e processos como deformações da membrana, NK com frente pontuda e grânulos vermelhos, hepatócito poligonal com dois núcleos e glicogênio, célula tubular alongada com borda em escova, hemácia bicôncava que gira na corrente, bactéria da flora em bastão com flagelo, linfócito quase só núcleo, plaqueta pequena com espinhos. Conferido na captura.
**Mapa:** o que há para fazer está perto do jogador (65% do que nasce, num raio de 24 unidades) e há 1,6 vez mais brilhos, toxinas e invasores (9 por padrão); a pele, o linfonodo e o cérebro ganharam coisas à deriva (fibrina, antígenos e resíduos neurais) que o jogador toca para ajudar a crise de lá e que plaquetas, linfócitos e glia comem; os grupos (até 16, 10 ou 5 por grupo, 72, 44 ou 18 no total) ficam onde o jogador pode ver, as células que ficam longe renascem na borda do que se vê, e as hemácias circulam pelo sangue, o coração e a aorta. O minimapa saiu de cima do texto de atalhos.
**Testes Godot:** suíte inteira rodada; ajustei três que dependiam dos números antigos (9 invasores, 40% do grupo).
**Não feito:** o equilíbrio (quantos invasores sobram ao jogador) e o custo de desenhar 72 células com detalhe não foram medidos; o texto "REINICIAR MUNDO" ainda se sobrepõe ao aviso do canto superior esquerdo.

## Combate das células anônimas e correção do desenho (28/10/2026)

- Erro `Invalid polygon data, triangulation failed` em `bio_cell_art.gd`: os polígonos fechavam repetindo o primeiro ponto. Agora o anel não repete o ponto, o gradiente é feito com camadas de polígonos e a bactéria em bastão não duplica as pontas. Captura real de `capture_crowd.gd` sem nenhum `ERROR`.
- Cada papel tem PV, dano e postura (`BioWorkerRoles.COMBAT`): lutadores (neutrófilo, macrófago, NK), os que revidam (hepatócito, glia, linfócito, etc.) e os indefesos (plaqueta, flora, hemácia), que fogem e pedem ajuda. Invasores móveis vão atrás da célula mais próxima (`BioCellActor.lure`) e batem nela; ao zerar o PV a célula cai e volta após 16 s. Só apresentação: contagens do motor não mudam.
- Barras de PV nos feridos (células e invasores), flash de dano e reação do corpo do invasor.
- Godot: 393 testes, 0 falhas (2 novos). Não medido: equilíbrio da luta com o jogador por perto.

### Execução real por todos os órgãos (`tests/soak_regions.gd`)

Jogo de verdade (renderizador real, offline, invasores padrão), 8 s em cada um dos 12 órgãos com os 12 tipos de célula, log lido. Achou `Trying to assign invalid previously freed instance` em `bio_work_crowd.gd` (alvo já liberado atribuído a variável `Node2D`), que a suíte não pegava; corrigido. Depois: 0 `ERROR` nos 12 órgãos e suíte Godot verde.

## Chamados: a classe vem da necessidade da crise (motor, 28/10/2026)

- Motor (`engine/core/calling.go`, genérico): `UniverseDef.Callings` (classe situacional: papel + forma) e `ConflictDef.Needs` (papéis e quantos jogadores cada um pede). Quem está numa crise recebe até 3 opções, de papéis diferentes, com o papel mais faltante primeiro e, dentro do papel, o chamado que menos gente tem; escolhe com a ação `assumir` (só `player`, revalidada contra a oferta recalculada). O chamado vira tags (`calling`, `role`, `form`), é solto ao sair da crise ou quando ela termina, e quem preenche um papel que ninguém cobria ganha 1 de crédito extra (`lacuna`) a cada contribuição. A visão do jogador traz `calling`.
- Universo do Hospedeiro: 10 chamados sobre as linhagens existentes (5 papéis: combate, limpeza, cura, controle, marcação) e `needs` nas 10 crises.
- Testes Go novos (`scenarios/calling_test.go`): a oferta segue a necessidade e muda quando o papel já está coberto; recusa fora de crise, fora da oferta e por origem `adapter`; soltar ao sair/terminar; toda crise oferece ao menos dois papéis e todos têm chamado; replay com o mesmo digest. `gofmt`, `go vet` e `go test ./... -count=1` verdes.
- Ainda não feito: a tela do cliente para escolher o chamado e aplicar a forma; recompensas/ranking por papel; o Jev ainda não desempata a oferta.

### Chamados no cliente (28/10/2026)

- Cliente: `BioCallingRules` (domínio), `BioCallingPanel` (cartões com as opções, "Agora não", e uma etiqueta "CHAMADO: ..." com "trocar"), `apply_engine_calling` no mundo (veste a forma do chamado, empresta até 2 habilidades da classe e devolve tudo ao soltar). Eventos `calling-assumed` e `calling-released` são silenciosos no feed.
- Testes: Godot 397 testes, 0 falhas (4 novos em `test_calling.gd`); Go `gofmt`, `go vet`, `go test ./... -count=1` verdes.
- Execução real (`tests/soak_calling.gd`, motor isolado em 127.0.0.1:8198 com tick de 150 ms, 0 `ERROR` no log): no linfonodo a crise ofereceu `t-regulador` e `linfocito-b`; escolhido o primeiro pelo próprio sinal do painel, o motor confirmou (papel controle), a célula vestiu `t_regulador` e a etiqueta apareceu; ao ir para o sangue o chamado foi solto e a forma base voltou.
- Backend de uso normal reiniciado do zero com o universo novo (`hospedeiro-reset.ps1`, mundo antigo e saves arquivados em `D:\unity\hospedeiro-data-archive\20261028-201658`).
- Não feito: recompensas e ranking por papel/temporada; desempate da oferta pelo Jev; ver se as habilidades emprestadas fazem sentido jogando.

### Corpo que virava agulha ao andar (28/10/2026)

- Relato: depois de voltar à forma normal o personagem piscava e se distorcia. Causa achada filmando o corpo (um quadro a cada 2 s) numa caminhada real por 12 órgãos contra um motor isolado: com ou sem chamado, em corredores e artérias o corpo virava agulha ou panqueca. As molas de esticar e de inchar (`BioCellBody._step_elastic`) eram integradas em um passo só; num quadro lento (troca de forma, corredor) passavam do limite de estabilidade e oscilavam até os extremos. Agora são integradas em passos de até 16 ms. Teste novo (`test_a_long_frame_does_not_throw_the_body_into_a_needle`): falha sem a correção (estica 1,4, inchaço 1,8) e passa com ela; a mesma caminhada depois não mostrou mais nenhuma agulha.
- Todas as 10 formas de chamado vestidas e devolvidas no renderizador real (`tests/capture_calling_forms.gd`): limpas na volta.
- A oferta do chamado só aparece depois de 2,5 s dentro da crise, para não pipocar a cada corredor atravessado.
- O log do Godot da sessão do usuário já tinha sido apagado (ele guarda os 5 últimos), então a causa vem da reprodução, não do log dele. Godot: 399 testes, 0 falhas.
- Novos scripts: `soak_walk.gd` (caminhada contínua por todos os órgãos, registra cada troca de região, chamado e forma, e salva uma tira de quadros), `capture_calling.gd`, `capture_calling_live.gd`, `capture_calling_forms.gd`.
