# RUNBOOK DO CLAUDE CODE — implementação incremental do Hospedeiro Vivo

> **POLÍTICA VIGENTE — 28/10/2026:** o usuário autoriza limpeza destrutiva, descarte de saves, mundos, journals e progressão, recriação do banco de dados e reset total do Hospedeiro quando necessários ao desenvolvimento. Migração sem perda, compatibilidade com dados antigos, backup e restauração do estado anterior são opcionais e não bloqueiam implementação, gates ou release. Registrar a estratégia escolhida (migração ou reset/recriação) e validar o estado resultante. A autorização não exige reset em toda mudança. Persistência, replay/digest e idempotência continuam obrigatórios dentro da versão vigente. Testes continuam locais/isolados; este ajuste documental não executa limpeza, reset, migração, deploy ou acesso ao banco.

> **Leia primeiro:** [AutonomousBodyImplementationPlan.md](AutonomousBodyImplementationPlan.md) (P0–P16), [AutonomousBodyQualityGates.md](AutonomousBodyQualityGates.md), [LivingWorldConflicts.md](LivingWorldConflicts.md), [JevCognitiveArchitecture.md](JevCognitiveArchitecture.md), `AGENTS.md`.  
> **Branch: sempre `main`**. **Este arquivo é uma fila de execução; nada aqui foi implementado só porque foi escrito.**

**Plano obrigatório de animação e feedback:** [VisualInteractionAnimationPlan.md](VisualInteractionAnimationPlan.md), com storyboards V01–V16, arte procedural, contratos de estado, sincronização, LOD e gates de UX. **Implementar polimento junto de cada nova intervenção**, não como acabamento ao fim.

**Atlas obrigatório de comportamentos:** [AutonomousCellBehaviorAtlas.md](AutonomousCellBehaviorAtlas.md). Implementar os seis primeiros perfis antes de acrescentar famílias novas.

## A. Prompt inicial para colar no Claude Code

> Você é o engenheiro principal de implementação do Hospedeiro. Trabalhe no repositório `jodaltro/mmorpg` na branch `main`. Sua tarefa é implementar integralmente o plano `Docs/Hospedeiro/AutonomousBodyImplementationPlan.md`, respeitando `Docs/Hospedeiro/ClaudeCodeAutonomousBodyRunbook.md`, `Docs/Hospedeiro/AutonomousBodyQualityGates.md`, `AGENTS.md`, `Docs/Architecture.md`, `Docs/Hospedeiro/LivingWorldConflicts.md` e `Docs/Hospedeiro/JevCognitiveArchitecture.md`.  
> **Não tente executar todas as fases num único commit.** Comece por P0 e a menor fatia vertical. Faça auditoria, implemente, teste e registre cada fase; mantenha main funcional a cada commit. O Go determinístico é a única autoridade material, o Godot headless valida combate, Nakama transporta e Jev é conselheiro estruturado assíncrono. Mundo pessoal deve funcionar sem API externa.  
> Não testar em produção, vazar segredos ou alterar `master`. Reset total, descarte de dados legados e recriação do banco estão autorizados quando necessários ao desenvolvimento. Remover a experiência de dungeons após validar conflitos e a progressão nova, por migração ou reset. Faça `git status`, `git pull --ff-only origin main`, identifique SHA/fingerprint e execute as validações locais pertinentes.  
> O produto final deve ter muitos NPCs que trabalham sem jogadores conectados, possuem rotinas/memória e geram pedidos causais de ajuda, com conflitos compartilhados e alertas claros; valide em sessões sem jogadores e replay. Continue pelas etapas autorizadas sem pedir confirmação a cada pequeno commit, e registre o escopo de descarte e a recuperação por correção/reversão de código ou recriação do estado; perda autorizada de dados antigos e ausência de backup não exigem nova confirmação. Informe o commit SHA e testes realmente executados após cada etapa.

## B. Checklist de preparação de cada sessão

```bash
git status --short
git branch --show-current
git pull --ff-only origin main
git rev-parse HEAD
git log -5 --oneline
```

Verifique `main` antes de qualquer leitura ou escrita. Se houver alterações locais, **não dar reset, checkout destrutivo, stash ou limpeza sem entender a origem**. Fazer levantamento e preservar trabalho existente. Ler `AGENTS.md` completo. Não executar comandos de validação contra mundo compartilhado.

**Go core (local, dentro de `engine/`):**
```bash
gofmt -l .
go vet ./...
go test ./...
```
**Godot (ajustar executável ao ambiente conforme AGENTS):**
```bash
# Exemplo para Windows/Git Bash; conferir o caminho local
G="/d/tools/godot/bin/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path clients/hospedeiro --import
"$G" --headless --path clients/hospedeiro --script res://tests/run_tests.gd
```
Verificar também `SCRIPT ERROR` e `ERROR` do Godot, não apenas total de asserts. Rodar browser/Nakama somente na configuração QA isolada descrita em `Docs/Hospedeiro/Nakama.md`; não executar bateria web contra domínio publicado nem instância real.

**Universo Go:** após mudar `universes/hospedeiro/universe.json`, executar `worldsim validate` e `worldsim simulate` em modo local isolado (descobrir uso exato com `worldsim --help` do binário compilado, não inventar flags). Qualquer mudança altera fingerprint; escolher migração explícita ou reset/recriação, sem reinterpretar journal incompatível.

## C. Regras de commit e relatório

Cada pacote de trabalho termina com:
1. `git diff --check`, verificação de segredos/dados gerados, leitura do diff, `git status`;
2. testes unitários/integração/e2e proporcionais (registrar os ausentes explicitamente);
3. relatório `Docs/Validation/YYYY-MM-DD-<feature>.md` com baseline SHA, paths, comandos, ambiente, resultado, métricas, bugs e regressões conhecidos;
4. commit na `main` com mensagem `feat(hospedeiro): ...`, `test(hospedeiro): ...` ou `docs(hospedeiro): ...`, e push depois de validar.
5. Reabrir `main` e conferir SHA remoto/arquivos. Se erro no push, **não alegar publicação**.

Evitar conflitos: no máximo um agente de Claude edita `engine/core/state.go`/ `engine/core/tick.go`/ `universe.json` por vez. Subagentes de programação podem fazer auditorias e testes paralelos sem escrever na mesma área.

## D. Backlog executável por incremento

Todos os IDs abaixo correspondem a entregas de código e testes. Marcadores `[ ]` são pendentes até que um commit testado seja registrado; não marcá-los concluídos sem evidência.

### FASE P0 — Radiografia
- [ ] **P0.1** Gerar relatório de baseline (SHA, API, Go, Godot, universo, estado de quests/dungeons/NPCs, fingerprint).
- [ ] **P0.2** Inventariar `agents`, `entities`, `rules`, `happenings`, `quests` no `universe.json`; mapear a função de Rubra/Neva/Dendra/Osteia e o que o Godot encarna.
- [ ] **P0.3** Criar benchmark inicial `engine/core/*_bench_test.go` ou `engine/scenarios/*_bench_test.go` isolado sem alterar produção; medir número crescente de entidades.
- [ ] **P0.4** Documentar rotas entre regiões, `passages`/ `spots`, tabela de recursos e órgãos já implementados, duração de tick e comportamento sem players.
- [ ] **P0.5** Inventariar código legacy dungeon e impacto de fingerprints/saves; registrar migração ou descarte planejado (P0 não executa limpeza).
**Gate:** relatório baseline honesto; Go e testes do cliente anteriores mantêm comportamento.

### FASE P1 — Estado de população e fisiologia
- [ ] **P1.1** Adicionar tipos de coorte e estado de população em arquivos pequenos (`engine/core/population.go` proposto), adicionar campo a `State` e `Clone`/ `Digest` usando padrões existentes.
- [ ] **P1.2** Declarar `populations` opcional e papéis biológicos em `Universe`; novos campos devem validar `kind`, IDs, locais e números finitos/não negativos.
- [ ] **P1.3** Construir processo de produção, consumo, entrega, perdas e reposição por regras declarativas. Cada recurso tem origem/sumidouro rastreado.
- [ ] **P1.4** Instanciar coortes iniciais de hemácias, plaquetas, neutrófilos, macrófagos, dendríticas e suporte. Evitar simular um objeto por célula do corpo.
- [ ] **P1.5** Adicionar testes de conservação, ausência de jogador e replay.
**Gate:** tick simula distribuição de recursos em mundo vazio, sem resultados negativos ou duplicados.

### FASE P2 — Agentes individuais com vida e trabalho
- [ ] **P2.1** Tipar `NPCState` com tarefa/caminho/energia/capacidade/posição lógica/último tick/etapa.
- [ ] **P2.2** Reutilizar `AgentDef`/`GoalDef` e `routines` existentes; ampliar sem quebrar Valdoria (compatibilidade é obrigatória).
- [ ] **P2.3** Implementar planner determinístico simples com prioridades, lock/reserva de tarefa, cooldown e timeout.
- [ ] **P2.4** Implementar roteamento lógico em grafo a partir de regiões/passagens/fluxo; movimentos realistas por duração e transição.
- [ ] **P2.5** Criar a primeira rotina completa: **Rubra sai do transporte disponível, carrega oxigênio, segue percurso, entrega e retorna; obstrução provoca busca de desvio/pedido**.
- [ ] **P2.6** Criar segunda: **Neva patrulha, percebe sinais, migra, defende, chama reforços e retorna à vigilância**.
- [ ] **P2.7** Criar terceira: **Dendra observa, acumula conhecimento, comunica informação ao local adequado**.
- [ ] **P2.8** Criar quarta: **Osteia cuida do nicho/produção e conserva reservas**.
- [ ] **P2.9** Criar quinta: **Macrófago limpa resíduos e responde a lesões ou infecções**.
- [ ] **P2.10** Criar sexta: **Plaquetas reagem a lesões e tentam fechar a brecha**.
**Gate:** ao menos seis papéis distintos trabalham sozinhos e de modo causal, com armazenamento persistente.

### FASE P3 — Tarefas e cooperação real
- [ ] **P3.1** Criar detectores de `Need` e estado `Task` com causa e condição de cancelamento.
- [ ] **P3.2** Reservar capacidades e materiais, impedindo dupla alocação.
- [ ] **P3.3** Implementar cooperação NPC-NPC no primeiro conflito: Dendra sinaliza, Neva investiga e Macrófago limpa; resultado altera indicador real.
- [ ] **P3.4** Se rotina falhar, plano muda: bloqueio, objetivo resolvido por outro, insumo acabou, alvo escapou, rota mudou.
- [ ] **P3.5** Anti-starvation/fairness e capacidade de recusar tarefas biológica ou materialmente impossíveis.
**Gate:** sem jogador, tarefas geram resultados concretos, não só eventos decorativos.

### FASE P4 — Memória, aprendizado e relações
- [ ] **P4.1** Criar `MemoryEpisode` com `event_id`, tipo, `source`, recência, validade, escopo e índice; inicializar entidades novas com defaults; conversão de entidades antigas é opcional.
- [ ] **P4.2** Incorporar observação, memória e comunicação no processamento de NPCs, respeitando `Belief` versus `Fact`.
- [ ] **P4.3** Relação com jogador só muda após evidência confirmada. Ajudar Rubra gera memória de quem ajudou; ignorar não equivale a culpa automática.
- [ ] **P4.4** Boatos/rede de comunicação levam tempo e respeitam alcance, encontros e especialização.
- [ ] **P4.5** Expor seletor `topRelevantMemories` com filtros por entidade/região/conflito e defesa contra memória obsoleta.
- [ ] **P4.6** Compactação, limite de uso de memória, índices reconstruíveis e proteção de dados privados.
**Gate:** observações passadas modificam escolhas futuras plausivelmente; não há onisciência.

### FASE P5 — Pedidos espontâneos de ajuda
- [ ] **P5.1** Criar `HelpRequest` de necessidade real sem depender de quest ativa.
- [ ] **P5.2** Regras de alvo para desconhecidos/conhecidos/reputação e opção de pedir NPCs antes.
- [ ] **P5.3** Reconhecer ajuda livre (com ou sem aceite) a partir de evento validado.
- [ ] **P5.4** Gerar fala por templates vinculados ao estado, sem inventar fatos.
- [ ] **P5.5** Cancelar pedido quando risco some; limitar repetição por NPC e jogador.
- [ ] **P5.6** API/visão pessoal para mostrar quem chama, o quê, por quê, onde, até quando; nunca transferir autoridade ao cliente.
**Gate:** Rubra pede socorro por obstrução real; outro NPC ou jogador pode resolver; ela lembra.

### FASE P6 — Conflitos como sistema genérico do motor
- [ ] **P6.1** Adicionar `ConflictDef` opcional em `Universe`; validar referência/regra e fingerprint.
- [ ] **P6.2** Criar `ConflictState`, `ConflictView`, fase e timestamps em ticks, IDs e dedupe.
- [ ] **P6.3** Implementar `conflictTick` em ordem correta de `tick.go`: documentar se antes/depois de trabalho NPC e efeitos; garantir uma iteração por tick sem dupla aplicação.
- [ ] **P6.4** Criar contrato de eventos públicos por transição com revisão e dedupe.
- [ ] **P6.5** Implementar histerese/condição sustentada para contenção/resolução e possibilidade de recidiva.
- [ ] **P6.6** Criar frentes e regiões afetadas sem duplicar conflito.
- [ ] **P6.7** Garantir várias crises simultâneas e mecanismo de seleção de destaque sem excluir conflitos reais.
**Gate:** modelo é genérico, Go puro, não quebra outros universos e conflito persiste após logout.

### FASE P7 — Primeira crise real: infecção pulmonar
- [ ] **P7.1** Usar foco/carga já existentes em `universe.json`, ajustando regras de forma versionada para criar crise persistente.
- [ ] **P7.2** Sem player: Neva, Macrófago e coortes respondem segundo recursos e capacidade; podem atrasar, conter ou perder a frente.
- [ ] **P7.3** Ligar indicadores: carga, oxigenação, integridade, inflamação; sintomas globais derivam de fatos, não do texto do alerta.
- [ ] **P7.4** Evidência de jogador validada por adapter contribui de modo causal e idempotente, assim como trabalho NPC.
- [ ] **P7.5** Sintomas e ajuda se espalham por órgãos apenas com regras causais; febre pode coexistir como efeito sem disparar cópias infinitas.
- [ ] **P7.6** Após contenção/resolução, abrir trabalho de recuperação; nova crise poderá surgir por novas condições.
**Gate:** demonstração completa de crise real compartilhada, inclusive com 0 jogadores.

### FASE P8 — JevBatch e avaliação do modelo
- [ ] **P8.1** Contrato versionado separado de `Decide` (legado): `BatchQuestion`, `BatchRequest`, `BatchAnswer`.
- [ ] **P8.2** Testar `choice`, probabilidades, respostas parciais, tipos alternativos realmente suportados por API e 1.13/1.14; não presumir formatos.
- [ ] **P8.3** Perguntas sobre uma coorte no mesmo snapshot: ação de Neva, necessidade de Rubra, encaminhamento de Dendra, chamada de reforço e priorização da crise.
- [ ] **P8.4** Batching por região/conflito/revisão; teste isolado 8/16/32/64; limite por custo, latência e tamanho.
- [ ] **P8.5** Armazenar distribuição de probabilidades/metadados para auditoria; resolução validada via comandos no log.
- [ ] **P8.6** Timeouts e fallback por pergunta; rejeitar resultado obsoleto, opção inválida ou conflito de recurso.
- [ ] **P8.7** Comparação cega A/B: Go puro, 1.13 isolado, 1.13 batch, 1.14 batch. Registrar resultados, versões e custo. Troca de modelo somente após gate.
**Gate:** batch não quebra replay e melhora qualidade demonstravelmente.

### FASE P9 — Deliberação macro/meso/micro
- [ ] **P9.1** Macro: escolher qual crise elegível merece atenção e onde sinais indicam escalada coerente.
- [ ] **P9.2** Meso: planejar recursos do órgão, com limite de pessoal/tarefas e reserva.
- [ ] **P9.3** Micro: influenciar ação de NPC nomeado considerando suas próprias crenças e memória filtrada.
- [ ] **P9.4** Scheduler por importância/novidade, sem consultar Jev a cada tick por NPC.
- [ ] **P9.5** Batch de perguntas e fallback quando indisponível; sem IA em `Step`, Go sem dependência de rede.
- [ ] **P9.6** Medir quantas decisões aplicadas alteraram comportamento realmente; evitar “IA decorativa”.
**Gate:** 1 hora simulada mostra deliberação adaptativa sem travamento e custo limitado.

### FASE P10 — Encarnar agentes no mapa
- [~] **P10.1** Extender `bio_game_server.gd`, `bio_world.gd` e apresentação com NPCs canônicos persistentes. *(parcial, 28/10/2026: `BioNpcPresenter`/`BioNpcActor` desenham as 7 células canônicas a partir da visão do motor, uma por id; a autoridade headless não desenha. Sem física de NPC no servidor.)*
- [x] **P10.2** Animações procedurais diferentes por função (carregar, patrulhar, sinalizar, reparar, reciclar), sem imitar diretamente personagens protegidos de Cells at Work. *(28/10/2026: sete silhuetas e oito gestos próprios; ver `Docs/Validation/2026-10-28-hospedeiro-p10-p11-cliente.md`. Sem avaliação com jogadores.)*
- [~] **P10.3** Separar física de NPC próximo e movimento lógico distante; reconciliar ambas. *(parcial: a posição visual vem do progresso da etapa informado pelo motor; não há física de NPC próximo a reconciliar.)*
- [x] **P10.4** Snapshot por proximidade/revisão, sem gerar entidades duplicadas em reconexão. *(28/10/2026: só regiões vivas ganham nó; reconectar não duplica nem repete efeito. Testado com `BioWorld` real.)*
- [x] **P10.5** Nível de detalhe por performance de mobile, sem deixar coortes pararem de produzir resultados fora de câmera. *(28/10/2026: 3 níveis de detalhe, corpo completo só nos mais próximos, nada fora da tela; medido, ver relatório.)*
- [ ] **P10.6** Teste real com dois clientes QA no mesmo mundo e NPCs visíveis. *(NÃO feito: dois clientes reais via Nakama não foram executados; só dois apresentadores sobre a mesma visão em teste.)*
**Gate:** trabalho NPC é visível, sincronizado e materialmente efetivo.

### FASE P10V — Produção audiovisual polida (execução paralela às fases funcionais)
Consultar [VisualInteractionAnimationPlan.md](VisualInteractionAnimationPlan.md) antes de editar qualquer script de renderização.

- [~] **P10V.1** Baseline de arte e performance: prints/capturas comparáveis, FPS/frame time, nodes/partículas/CPU/GPU e controles mobile no estado anterior. *(parcial: benchmark de quadros por preset; sem capturas antes/depois do estado anterior nem hardware móvel.)*
- [~] **P10V.2** Definir linguagem visual de hemácias, neutrófilos, macrófagos, dendríticas, plaquetas e estroma; contrastar silhuetas e movimento, preservar aparência procedural Jev. *(parcial: silhuetas distintas para hemácia, neutrófilo, macrófago, dendrítica, plaqueta, Kupffer e estroma; sem revisão artística.)*
- [x] **P10V.3** Implementar `BioInteractionCatalog`/apresentador/máquina de estados equivalentes: orientação, antecipação, contato, progresso real, confirmação, falha e recuperação. *(28/10/2026: `BioInteractionState` com notice/approach/anticipate/act/progress/blocked/help/confirmed/cancel/recover.)*
- [~] **P10V.4** Integrar IDs e revisões de eventos autoritativos; dois clientes veem a mesma ação; pacote tardio, duplicado ou reconexão não reexecutam efeitos de conclusão. *(parcial: deduplicação por contadores `done`/`failed` do motor e primeira visão como histórico; o motor ainda não envia `interaction_id` próprio.)*
- [~] **P10V.5** Criar biblioteca procedural de sinais químicos, vesículas, pseudópodes, filamentos, material de tecido, deformações, som opcional e feedback acessível — sem "mesma aura em cores diferentes". *(parcial: gestos procedurais sem nós de partícula; faltam sinais químicos entre células e pooling medido.)*
- [~] **P10V.6** Rubra storyboard V01 e pedido V02: carregar, mover, obstruir, pedir ajuda, jogador ajudar, entregar e ambiente responder; sucesso APENAS após ACK. *(parcial: Rubra leva e entrega O2, bloqueio, pedido e agradecimento; falta o jogador desobstruir com efeito conjunto no mundo.)*
- [~] **P10V.7** Neva V04, Dendra V05, macrófago V03, plaqueta V06, Osteia V07: animações polidas e diferenciadas, em tarefas reais. *(parcial: Neva, Dendra, macrófago e plaqueta têm gesto; Osteia ainda não tem tarefa no universo.)*
- [x] **P10V.8** Reatividade por órgão e fase de conflito V13: inflamação, dano, cura, fluxo, recuperação com interpolação/LOD. *(28/10/2026: `BioTissueMood` — inflamação, fissuras, contenção e recuperação gradual por região, frentes só onde o motor abriu.)*
- [~] **P10V.9** Implementar presets visual alto/padrão/econômico, reduced-motion, redução de flash/shake/partículas, mobile sem perder controles. *(parcial: presets alto/padrão/econômico, menos movimento, menos brilho, som opcional, texto 100/125/150%; vibração não testada em aparelho.)*
- [ ] **P10V.10** Ampliar V08–V12 e V14–V16 conforme novos órgãos/cooperação; revisão de animação, microinterações e áudio. *(não feito: V08–V12 e V14–V16 dependem de novos órgãos e tarefas.)*
- [~] **P10V.11** Medir 1/20/50/100 NPCs visíveis em QA no hardware-alvo; otimizar FX/pooling/batching somente após profiling e registrar p95/p99. *(parcial: 0/1/7/20/50/100 células em uma máquina; sem hardware-alvo.)*
- [~] **P10V.12** Registrar QA visual: testes headless, golden captures/vídeos antes/depois, avaliação de legibilidade/prazer e limitações no relatório `Docs/Validation`. *(parcial: testes headless e capturas reais desta sessão; sem golden captures versionadas nem avaliação de prazer.)*
**Gate:** intervenção tem forma e gesto próprios, progresso material, conclusão/falha fiéis ao servidor, qualidade e acessibilidade mobile; nenhuma fase pode ser marcada concluída com NPC estático e partículas genéricas.

### FASE P11 — HUD e alertas
- [~] **P11.1** Criar painel `Conflitos do Hospedeiro` e componente de evento global; preservar responsividade mobile. *(28/10/2026: painel de Crises (tecla L) e alerta global; layout conferido em 1280x720 e 844x390, mas não em aparelho com toque.)*
- [x] **P11.2** Foco em um conflito + até dois resumos; detalhes dos demais no painel. *(28/10/2026: um conflito acompanhado + dois resumos.)*
- [x] **P11.3** Alerta grande por início, escalada, contenção, término; animação e áudio opcionais; sem bloquear movimento. *(28/10/2026: alerta grande não bloqueante por transição; sem som obrigatório.)*
- [x] **P11.4** Deduplicação por `conflict_id+revision`, fila por prioridade e ACK de exibição local, histórico de alertas. *(28/10/2026: deduplicação por `conflito:revisão:tipo`, fila por prioridade com validade e histórico.)*
- [x] **P11.5** Pedido NPC contextual no HUD sem forçar missão aceita e sem competir com emergência. *(28/10/2026: pedido contextual só para a região do jogador; "Ajudar" não declara feito.)*
- [x] **P11.6** Remover da interface principal o ruído de listas de quests repetitivas; preservar tutoriais e história. *(28/10/2026: o cartão de missão e as ofertas só mostram história e primeiros passos; as demais seguem na janela de missões.)*
**Gate:** tela clara com várias crises; nenhum spam após reconnect.

### FASE P12 — Outros sistemas do organismo
- [ ] **P12.1** Pele/plaquetas/feridas e reparo.
- [ ] **P12.2** Baço/ferro/hemácias velhas/produção medular.
- [ ] **P12.3** Fígado/rim/toxina/depuração.
- [ ] **P12.4** Intestino/microbiota e fluxos de nutrientes.
- [ ] **P12.5** Linfonodos e sinalização/memória imunológica.
- [ ] **P12.6** Cérebro/glia/sinais, mais tumores no mapa global.
- [ ] **P12.7** Testes de cascata entre órgãos, cooperação entre linhagens e conflitos concomitantes.
**Gate:** variedade fisiológica, mesmos contratos, nenhum sistema hardcoded por órgão no motor genérico.

### FASE P13 — Migrar e extinguir runs de dungeon do Hospedeiro
- [ ] **P13.1** Mapa de equivalência dungeon→conflito/exploração/recompensa.
- [ ] **P13.2** Escolher e testar migração ou reset/recriação de saves, journals, mundos, progressão e banco; fingerprint válido no destino, sem backup obrigatório.
- [ ] **P13.3** Remover portais, `bio_dungeon_panel.gd`, apresentações e controle específico após substituição por conflitos validada, com migração ou reset; manter `engine/core/dungeon.go` se algum outro universo usa.
- [ ] **P13.4** Atualizar testes e docs, validar inicialização do mundo novo/pessoal e avatar após reset; substituir testes que exijam preservação legada por fixtures descartáveis, mantendo replay/digest e persistência vigente; conferir saves antigos apenas se optar por conversão.
**Gate:** mundo novo válido, só com conflitos abertos e progressão nova funcional; progresso antigo pode ser descartado.

### FASE P14 — Hospedagem contínua e confiabilidade
- [ ] **P14.1** Definir serviço/ticker 24/7 e monitoramento operacional. Enquanto PC hospeda, desligar PC interrompe simulação; registrar isso até migrar para host always-on.
- [ ] **P14.2** Checkpoint + journal replay da versão vigente, backup opcional, política de catch-up ou pausa, crash recovery, healthcheck e limite de eventos.
- [ ] **P14.3** Métricas e orçamentos para 10/100/500 NPCs nomeados e grandes coortes.
- [ ] **P14.4** Taxa máxima de consultas Jev, custo máximo por período, cap de contexto e fila; fallback automático.
- [ ] **P14.5** Distintos dados compartilhados/pessoais; recovery e custo após queda de serviço.
**Gate:** testes controlados de restart/crash e tick contínuo sem cliente.

### FASE P15 — Stress, segurança, balanceamento
- [ ] **P15.1** Testar 10/30/60/180 minutos de simulação sem jogadores; produzir tabelas de tarefas, conflitos, recursos, pedidos e resultados.
- [ ] **P15.2** Verificar 10/100/500 NPCs nomeados e coortes maiores em QA; registrar limites em vez de prometer escala.
- [ ] **P15.3** QA de dois conflitos simultâneos disputando recursos e reputação; evitar duplicação e starvation.
- [ ] **P15.4** Cliente tenta forjar dano, contribuição, saúde, resultado e mensagem de NPC: tudo rejeitado.
- [ ] **P15.5** Jev lento/offline/alucinado: replay e comportamento continuam.
- [ ] **P15.6** Benchmark do HUD com alertas grandes, tela móvel e acessibilidade.
- [ ] **P15.7** QA visual: 6 papéis, 16 storyboards progressivos, input→feedback→confirmação, 2 clientes, reordenação, falha, mobile em presets, desempenho e acessibilidade conforme plano V.
**Gate:** arquivo de qualidade preenchido com resultados verdadeiros, sem regressões severas.

### FASE P16 — Release, limpeza, demonstração
- [ ] **P16.1** Revisar docs legados e atualizar README/AGENTS para direção atual.
- [ ] **P16.2** Estratégia de migração ou reset/recriação validada localmente; recuperação operacional definida, sem exigir conservação/restauração dos dados antigos.
- [ ] **P16.3** Demonstrar sequência ponta a ponta: mundo vazio trabalhando → surge crise → NPC age → pede ajuda → jogador auxilia → conflito escala/contém → jogador sai → mundo continua → jogador volta → NPC lembra e alertas não repetem.
- [ ] **P16.4** Especificar requisitos de servidor always-on para autonomia 24h.
- [ ] **P16.5** Entregar relatório final com commits, métricas e pendências reais.
- [ ] **P16.6** Apresentar vídeo/capturas QA com Rubra transportando, pedindo e recebendo ajuda; Neva, Dendra, macrófago e plaquetas cooperando; tecido e ambiente reagindo, inclusive falhas e recuperação; testar mobile e reduced motion.
**Gate:** todos os critérios em `AutonomousBodyQualityGates.md` comprovados.

## E. Sequência de execução de cada fase

Para cada fase Pn:
1. **Ler código** e enumerar contracts exatos; confirmar que arquivos candidatos existem.
2. **Escrever teste que falha** pela ausência da funcionalidade quando viável; evitar testes frágeis que dependem de textos cosméticos.
3. **Implementar o mínimo vertical** (tipos, regra, estado, API, apresentação), reusar infraestrutura existente.
4. **Rodar testes locais e simulação**, comparar `State.Digest`/journal.
5. **Exercitar falhas:** timeout Jev, reconexão, duplicação, ausência de jogadores e cenário de pouco recurso.
6. **Registrar evidência quantitativa** e comportamento visual em `Docs/Validation`.
7. **Commit/push `main`** e só então começar próximo incremento.
8. **Auditar escopo legado** (dungeons, quests e saves) antes de mudar dependências compartilhadas.

## F. Estratégia de subagentes Claude Code sem conflitos

- **Agente Arquitetura/Core**: contratos Go, invariantes, estado, `Step`, replay e Compiler; é o único a editar `engine/core` durante cada integração.
- **Agente Biologia/Conteúdo**: pesquisa fisiológica e proposta do JSON; entrega patch sugerido, mas integração do arquivo `universe.json` fica com único responsável.
- **Agente Jev/Benchmark**: `engine/advisor/`, contratos do batch, fakes, latência e resultados; não altera o esquema do core sem coordenação.
- **Agente Godot/Nakama**: cliente, servidor, snapshots e UI, sem atribuir autoridade a clientes.
- **Agente Arte/Animação/UX**: catálogo V01–V16, procedimentos de movimento/contato, atlas material, VFX e testes visuais/performance; trabalha em arquivos Godot isolados e integra com responsável Godot.
- **Agente QA/Red Team**: testes de exploração, dados ruins, rollback, scripts de QA e validação; escreve em arquivos próprios.
- **Agente Documentação/Release**: guias, matriz de migração, métricas e relatório; revisa alegações de teste.

Isso é uma proposta de organização de trabalho para implementação. Os NPCs do jogo terão autonomia própria, não serão instâncias do Claude Code.

## G. Primeiro experimento que deve funcionar antes do resto

```text
1. Preparar mundo QA com origem de infecção pulmonar.
2. Rodar simulação SEM JOGADORES; observar Neva e Macrófagos tentarem contê-la e
   Rubra continuar tarefas de transporte sob recursos limitados.
3. Provocar obstrução real; Rubra tenta desviar e gera pedido se não conseguir.
4. Entrar como jogador A; receber snapshot do conflito e assistir à tarefa.
5. Jogador B entra; vê a mesma crise e os mesmos NPCs/indicadores.
6. Jogador A ajuda SEM aceitar missão; Godot confirma; motor registra crédito e relação.
7. Infecção aumenta; alerta crítico UMA vez e cadeia fisiológica modifica estado real.
8. Ações de jogadores/NPCs reduzem carga; fase muda para contido, depois recuperação.
9. Jogador sai, depois volta; Rubra o reconhece e alerta antigo não reaparece.
10. Parar Jev em QA; agentes continuam pelas regras determinísticas.
11. Reiniciar motor QA por journal; digest, conflito e relações permanecem idênticos.
12. Capturar métricas, reexecutar e documentar os resultados.
13. Capturar visualmente começo/contato/progresso/confirmação/falha das intervenções de Rubra/Neva/Dendra, comparando antes/depois com qualidade mobile e estado autoritativo.
14. Repetir com dois clientes e rede/reconexão; nenhum efeito ou recompensa de conclusão pode reaparecer como novo.
```

**Proibir atalhos:** não satisfazer o teste disparando `conflict-resolved` manualmente, emitindo apenas uma animação de NPC, inventando efeito Jev ou manipulando diretamente o HUD.

## H. Arquivos propostos por fase e cuidado com legados

| Etapa | Locais centrais existentes | Novos arquivos a considerar |
|---|---|---|
| Core de população | `engine/core/def.go`, `state.go`, `tick.go`, `compile.go` | `population.go`, testes |
| Autonomia NPC | `engine/core/tick.go`, `mind.go`, `place.go` | `npc_state.go`, `tasks.go`, `memory.go` |
| Conflitos | `engine/core/director.go`, `state.go`, `view.go` | `conflicts.go`, `contributions.go`, testes |
| Jev | `engine/advisor/jev.go`, `engine/sim/runner.go` | `jev_batch.go`, `batch_scheduler.go`, `*_test.go` |
| Conteúdo | `universes/hospedeiro/universe.json` | fixtures de testes, possível versão de schema |
| Comunicação | `engine/api/http.go`, `engine/api/nakama.go` | rotas versionadas se indispensável |
| Jogo | `bio_world.gd`, `bio_game_server.gd`, `bio_engine_link.gd` | visual NPC e sync de conflitos |
| Animação/interação | `bio_cell_body.gd`, `bio_cell_forms.gd`, `bio_fx.gd`, `bio_art.gd` | catálogo de gestos, presenter, shaders/FX, animações V01–V16, testes visuais |
| HUD | `bio_hud.gd`, `bio_dungeon_panel.gd` | painel global e notificação NPC |
| Testes | `engine/scenarios`, `clients/hospedeiro/tests` | novos cenários de autonomia e conflitos |
| Migração | `engine/store/filelog.go`, docs de deployment | caminho de migração ou reset/recriação e relatório de inicialização |

A tabela é **mapa de partida**, não ordem para criar todos os arquivos. Confirmar interfaces reais e evitar duplicar mecanismos preexistentes.

## I. Protocolo de reporte ao usuário após cada bloco

```text
Etapa: Pn — <nome>
Branch: main
Antes: <SHA>
Depois: <SHA do commit (ou não realizado)>
Alterações: <arquivos e decisões importantes>
Comportamento demonstrável: <exemplo reproduzível>
Testes executados: <comandos e resultados reais>
Testes não executados: <quais e por quê>
Estratégia de dados: <migração ou reset/recriação; escopo descartado, validação e recuperação; backup opcional>
Impacto em mundos pessoais/online: <descrever>
Riscos/pendências e próximo item: <exatos>
```

**Não transformar este runbook em registro de sucesso automático.** Seu valor é guiar a implementação, os testes e o release etapa por etapa.
