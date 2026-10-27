# RUNBOOK DO CLAUDE CODE — implementação incremental do Hospedeiro Vivo

> **Leia primeiro:** [AutonomousBodyImplementationPlan.md](AutonomousBodyImplementationPlan.md) (P0–P16), [AutonomousBodyQualityGates.md](AutonomousBodyQualityGates.md), [LivingWorldConflicts.md](LivingWorldConflicts.md), [JevCognitiveArchitecture.md](JevCognitiveArchitecture.md), `AGENTS.md`.  
> **Branch: sempre `main`**. **Este arquivo é uma fila de execução; nada aqui foi implementado só porque foi escrito.**

**Atlas obrigatório de comportamentos:** [AutonomousCellBehaviorAtlas.md](AutonomousCellBehaviorAtlas.md). Implementar os seis primeiros perfis antes de acrescentar famílias novas.

## A. Prompt inicial para colar no Claude Code

> Você é o engenheiro principal de implementação do Hospedeiro. Trabalhe no repositório `jodaltro/mmorpg` na branch `main`. Sua tarefa é implementar integralmente o plano `Docs/Hospedeiro/AutonomousBodyImplementationPlan.md`, respeitando `Docs/Hospedeiro/ClaudeCodeAutonomousBodyRunbook.md`, `Docs/Hospedeiro/AutonomousBodyQualityGates.md`, `AGENTS.md`, `Docs/Architecture.md`, `Docs/Hospedeiro/LivingWorldConflicts.md` e `Docs/Hospedeiro/JevCognitiveArchitecture.md`.  
> **Não tente executar todas as fases num único commit.** Comece por P0 e a menor fatia vertical. Faça auditoria, implemente, teste e registre cada fase; mantenha main funcional a cada commit. O Go determinístico é a única autoridade material, o Godot headless valida combate, Nakama transporta e Jev é conselheiro estruturado assíncrono. Mundo pessoal deve funcionar sem API externa.  
> Nunca resetar mundo real, testar em produção, vazar segredos ou alterar `master`. Não apagar dungeons até haver migração e progressão equivalente. Faça `git status`, `git pull --ff-only origin main`, identifique SHA/fingerprint e execute as validações locais pertinentes.  
> O produto final deve ter muitos NPCs que trabalham sem jogadores conectados, possuem rotinas/memória e geram pedidos causais de ajuda, com conflitos compartilhados e alertas claros; valide em sessões sem jogadores e replay. Continue pelas etapas autorizadas sem pedir confirmação a cada pequeno commit, mas **pare e reporte qualquer risco de perda de dados do servidor real ou impossibilidade de garantir rollback**. Informe o commit SHA e testes realmente executados após cada etapa.

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

**Universo Go:** após mudar `universes/hospedeiro/universe.json`, executar `worldsim validate` e `worldsim simulate` em modo local isolado (descobrir uso exato com `worldsim --help` do binário compilado, não inventar flags). Qualquer mudança altera fingerprint; seguir roteiro de migração.

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
- [ ] **P0.5** Inventariar código legacy dungeon e risco de fingerprints/saves; nenhum delete agora.
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
- [ ] **P4.1** Criar `MemoryEpisode` com `event_id`, tipo, `source`, recência, validade, escopo e índice; migrar entidades antigas com defaults.
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
- [ ] **P10.1** Extender `bio_game_server.gd`, `bio_world.gd` e apresentação com NPCs canônicos persistentes.
- [ ] **P10.2** Animações procedurais diferentes por função (carregar, patrulhar, sinalizar, reparar, reciclar), sem imitar diretamente personagens protegidos de Cells at Work.
- [ ] **P10.3** Separar física de NPC próximo e movimento lógico distante; reconciliar ambas.
- [ ] **P10.4** Snapshot por proximidade/revisão, sem gerar entidades duplicadas em reconexão.
- [ ] **P10.5** Nível de detalhe por performance de mobile, sem deixar coortes pararem de produzir resultados fora de câmera.
- [ ] **P10.6** Teste real com dois clientes QA no mesmo mundo e NPCs visíveis.
**Gate:** trabalho NPC é visível, sincronizado e materialmente efetivo.

### FASE P11 — HUD e alertas
- [ ] **P11.1** Criar painel `Conflitos do Hospedeiro` e componente de evento global; preservar responsividade mobile.
- [ ] **P11.2** Foco em um conflito + até dois resumos; detalhes dos demais no painel.
- [ ] **P11.3** Alerta grande por início, escalada, contenção, término; animação e áudio opcionais; sem bloquear movimento.
- [ ] **P11.4** Deduplicação por `conflict_id+revision`, fila por prioridade e ACK de exibição local, histórico de alertas.
- [ ] **P11.5** Pedido NPC contextual no HUD sem forçar missão aceita e sem competir com emergência.
- [ ] **P11.6** Remover da interface principal o ruído de listas de quests repetitivas; preservar tutoriais e história.
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
- [ ] **P13.2** Mecanismo de migração com backups, fingerprint e fixture legada, preservando dado real intacto.
- [ ] **P13.3** Remover portais, `bio_dungeon_panel.gd`, apresentações e controle específico só após migração comprovada; manter `engine/core/dungeon.go` se algum outro universo usa.
- [ ] **P13.4** Atualizar testes e docs, conferir saves antigos, mundo pessoal e avatar que estava em uma run.
**Gate:** nenhum progresso antigo perdido; mundo novo só tem conflitos abertos.

### FASE P14 — Hospedagem contínua e confiabilidade
- [ ] **P14.1** Definir serviço/ticker 24/7 e monitoramento operacional. Enquanto PC hospeda, desligar PC interrompe simulação; registrar isso até migrar para host always-on.
- [ ] **P14.2** Checkpoint + journal replay, backup, política de catch-up ou pausa, crash recovery, healthcheck e limite de eventos.
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
**Gate:** arquivo de qualidade preenchido com resultados verdadeiros, sem regressões severas.

### FASE P16 — Release, limpeza, demonstração
- [ ] **P16.1** Revisar docs legados e atualizar README/AGENTS para direção atual.
- [ ] **P16.2** Plano de migração/rollback aprovado localmente; não fazer deploy sem segurança dos dados.
- [ ] **P16.3** Demonstrar sequência ponta a ponta: mundo vazio trabalhando → surge crise → NPC age → pede ajuda → jogador auxilia → conflito escala/contém → jogador sai → mundo continua → jogador volta → NPC lembra e alertas não repetem.
- [ ] **P16.4** Especificar requisitos de servidor always-on para autonomia 24h.
- [ ] **P16.5** Entregar relatório final com commits, métricas e pendências reais.
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
| HUD | `bio_hud.gd`, `bio_dungeon_panel.gd` | painel global e notificação NPC |
| Testes | `engine/scenarios`, `clients/hospedeiro/tests` | novos cenários de autonomia e conflitos |
| Migração | `engine/store/filelog.go`, docs de deployment | ferramenta de migração e relatório de reversão |

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
Migração necessária? <sim/não; plano e backup>
Impacto em mundos pessoais/online: <descrever>
Riscos/pendências e próximo item: <exatos>
```

**Não transformar este runbook em registro de sucesso automático.** Seu valor é guiar a implementação, os testes e o release etapa por etapa.
