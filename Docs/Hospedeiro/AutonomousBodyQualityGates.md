# Hospedeiro vivo — matriz de validação, benchmarks e gates de release

> **POLÍTICA VIGENTE — 28/10/2026:** o usuário autoriza limpeza destrutiva, descarte de saves, mundos, journals e progressão, recriação do banco de dados e reset total do Hospedeiro quando necessários ao desenvolvimento. Migração sem perda, compatibilidade com dados antigos, backup e restauração do estado anterior são opcionais e não bloqueiam implementação, gates ou release. Registrar a estratégia escolhida (migração ou reset/recriação) e validar o estado resultante. A autorização não exige reset em toda mudança. Persistência, replay/digest e idempotência continuam obrigatórios dentro da versão vigente. Testes continuam locais/isolados; este ajuste documental não executa limpeza, reset, migração, deploy ou acesso ao banco.

> **Status:** critérios a executar no Claude Code; nenhuma linha deste documento indica teste já realizado.  
> **Branch:** `main` · **QA:** exclusivamente local/isolado; reset/recriação de desenvolvimento autorizados; não executar na rotina de QA.

Os requisitos gráficos e animações são detalhados em [VisualInteractionAnimationPlan.md](VisualInteractionAnimationPlan.md): **gates V-G1–V-G12 obrigatórios** para cada intervenção, inclusive sincronização, falhas, desempenho e acessibilidade.

Este documento vincula [AutonomousBodyImplementationPlan.md](AutonomousBodyImplementationPlan.md) ao [ClaudeCodeAutonomousBodyRunbook.md](ClaudeCodeAutonomousBodyRunbook.md).

## 1. Cinco gates obrigatórios para cada funcionalidade

| Gate | Exigência | Comprovação |
|---|---|---|
| G-DET | `Step` puro, replay igual, resultados independentes de ordem de mapas/timing de IA | teste de digest e journal |
| G-CAUS | origem biológica/necessidade válida, estoque e recurso finitos, efeito material real | cenários de mundo sem cliente |
| G-SEC | player não declara dano, cura, contribuição, verdade do mundo ou prêmio | testes API e headless |
| G-UX | UI acessível, não bloqueante, sem alertas duplicados | Godot e browser QA |
| G-MIG | migração ou reset/recriação produz mundo válido, inclusive modo pessoal; dados antigos descartáveis | fixtures locais do caminho escolhido e inicialização/replay da versão vigente |
| G-VIS | intervenção tem animação polida específica, progresso e resultado material legíveis; feedback sincronizado, testado em mobile e reduced-motion | storyboards V01–V16, dois clientes QA, captura antes/depois, profiling e gates V-G1–V-G12 |

Somente promover uma etapa quando seus gates aplicáveis estiverem verdes com comando real registrado em `Docs/Validation`. Um TODO, teste não executado ou GIF bonito não satisfaz gate.

## 2. Invariantes I-01 a I-30

**Core e journal**
- **I-01** Mesmo universo e mesma sequência de comandos produzem o mesmo `State.Digest()` após replay.
- **I-02** Resposta Jev, snapshot de rede ou ordem das goroutines nunca muda `State` fora de um comando autorizado.
- **I-03** Input incorreto não altera estado; comandos duplicados não duplicam resultado.
- **I-04** Uma decisão obsoleta por `world_revision` é descartada/replanejada; nenhuma dupla atribuição por resposta tardia.
- **I-05** `core` não importa rede, banco, Godot, Java ou cliente do Jev.
- **I-06** Falhas de escrita do log não publicam efeitos como concluídos.
- **I-07** Fingerprint diferente exige migração explícita ou descarte/recriação do estado; nunca reinterpretar journal incompatível.

**Agentes e população**
- **I-08** Nenhuma coorte ou NPC importante depende da presença de jogador para trabalhar.
- **I-09** Um NPC nomeado tem ID estável; materialização em Godot não multiplica indivíduos, carga ou recursos.
- **I-10** Toda tarefa possui causa real, necessidade ainda ativa e critérios de resultado; tarefa impossível sai da fila ativa.
- **I-11** Reserva de tarefa/recurso não é concedida simultaneamente além da capacidade.
- **I-12** NPC distante progride logicamente; aproximação não o teleporta nem duplica ações.
- **I-13** Recursos de transporte/reparo/defesa possuem fonte, consumo e limites declarados; sem valores negativos arbitrários.
- **I-14** Falhas geram replanejamento ou estado `blocked` com motivo, sem loop infinito.
- **I-15** Ao menos os papéis de transporte, vigilância, defesa, limpeza, comunicação e reparo têm rotinas independentes verificáveis.
- **I-16** Um NPC pode permanecer inativo/descansando quando apropriado; nenhum sistema obriga eventos cosméticos falsos.

**Memória, conhecimento e ajuda**
- **I-17** `Fact` não vira automaticamente `Belief` de todas as células; transmissão tem procedência e causalidade.
- **I-18** Observação recente confirma/corrige boato sem apagar a memória de que houve rumor antigo.
- **I-19** Relação com jogador depende de ato observado/confirmado, não do mero recebimento de quest.
- **I-20** Pedido de ajuda existe somente com necessidade válida e capacidade insuficiente ou motivo social coerente.
- **I-21** Ajuda espontânea sem clique em aceitar altera mundo e memória tanto quanto ajuda aceita.
- **I-22** Pedido desaparece como ativo quando necessidade desaparece; não é reemitido toda revisão.
- **I-23** Memória privada e fatos restritos não vazam em snapshots públicos ou prompts de terceiros.

**Conflitos**
- **I-24** Um mesmo foco/causa não abre instâncias globais duplicadas; frentes coexistentes mantêm causa.
- **I-25** A crise não expira arbitrariamente nem resolve por logout; critério real + estabilização sustentada.
- **I-26** Dois jogadores na mesma instância observam mesmo `conflict_id`, severidade e métricas oficiais.
- **I-27** Contribuição exige evidência servidor, tem dedupe, e participação NPC não vira prêmio falso.
- **I-28** Alertas grandes apenas em transição relevante; reconnect/reordenação não reexibem evento antigo.
- **I-29** Duas ou mais crises podem coexistir sem apagar uma delas por limite de HUD.
- **I-30** Mundo pessoal e MMO mantêm estados/contribuições/journals distintos.

## 3. Cenários de referência — passos e resultados esperados

### QA-01 — Organismo vazio por 30 minutos
1. Criar mundo QA com medula, sangue, pulmão, reservas, coortes e seis NPCs.
2. Iniciar ticks sem player, com Jev OFF; registrar métricas a cada bloco de ticks.
3. Conferir entrega de oxigênio, consumo de suprimentos, vigilância, limpeza, reserva, mudanças e eventuais pedidos NPC-NPC.
4. Após período, verificar contadores físicos, filas de tarefas, últimos estados, memória e causas de ociosidade.
5. Reexecutar o log do zero; hash final igual.

**Falha:** ninguém trabalha sem avatar, estoque negativo, evento duplicado ou criação infinita de NPCs.

### QA-02 — Rubra bloqueada
1. Rubra recebe transporte e encontra via obstruída na rota lógica.
2. A função de navegação tenta passagem alternativa disponível (se houver).
3. Se insuficiente, cria `Need` e `HelpRequest` com causa referenciada; outra célula pode socorrer.
4. Jogador A resolve sem aceitar; adaptador confirma a ação; carga só é entregue após percurso válido.
5. Rubra memoriza o auxílio, altera relação e pode referenciá-lo ao encontrá-lo novamente.
6. Reiniciar QA e confirmar mesma tarefa/memória/identidade.

**Falha:** NPC pede escolta sem bloqueio, a carga chega duas vezes, diálogo inventa solução, relação muda sem evento.

### QA-03 — Neva, Dendra e Macrófago coordenados
1. Dendra observa antígeno e tem crença fundamentada.
2. Comunicação chega a Neva ou ponto de defesa somente pelo mecanismo disponível.
3. Neva decide investigar/defender e Macrófago limpa resíduos.
4. Cada ação gasta tempo/recurso e altera indicador específico.
5. Retirar um recurso e confirmar replanejamento em vez de tarefa impossível.

**Falha:** NPC sabe automaticamente notícia remota, todos atacam mesmo sem capacidade, resultados não mudam estado.

### QA-04 — Infecção pulmonar sem intervenção humana
1. Ativar foco por condição real.
2. Criar conflito global uma vez, fase `active`, número de instância estável.
3. Executar 100+ ticks sem jogadores, com coortes NPC reduzindo/contendo ou perdendo a ameaça segundo parâmetros.
4. Garantir propagação/febre somente com limiares reais; se escalar, `conflict-escalated` uma vez.
5. Manter carga alta: não resolver após prazo arbitrário. Reduzir via trabalhos e estabilizar por ticks suficientes: `contained/recovering/resolved`.

**Falha:** a UI inventa resultado, timers fecham crise, crise renasce idêntica a cada cooldown.

### QA-05 — Dois jogadores em crise única
1. Entrar A e B no MMO QA.
2. A e B consultam `ConflictView` do mesmo tick/revisão (considerar sincronização assíncrona).
3. A combate e B transporta/cura/repara; servidor confirma feitos sem confiar em magnitude enviada pelo cliente.
4. Ambos recebem novos indicadores; crédito diferente por contribuição válida, sem prêmios por pvp.
5. Desconectar A: conflito e trabalho NPC continuam; reconectar A: último snapshot correto e nenhuma recompensação duplicada.

**Falha:** duas instâncias de conflito por pessoa, progressos divergentes permanentes, recompensa por e-mail/evento repetido.

### QA-06 — Conflitos concorrentes e recursos escassos
1. Gerar foco pulmonar e lesão de pele com causas independentes.
2. Ambas aparecem no painel; o HUD acompanha apenas uma, mas não encerra outra.
3. Coortes de neutrófilos finitas não podem ocupar simultaneamente as duas frentes além da capacidade.
4. O diretor atribui prioridades e considera tempo de deslocamento; outra classe atua na frente apropriada.
5. Um conflito se resolve; o outro continua ou evolui conforme condições próprias.

**Falha:** painel mostra apenas uma e motor remove outra, recruta célula duplicada, spam de alertas.

### QA-07 — Crença falsa e memória corrigida
1. Criar boato de infecção no rim sem fato real; só NPCs que ouviram acreditam.
2. Um NPC decide inspecionar em vez de afirmar certeza absoluta.
3. Inspeção autorizada encontra falso alarme; crença atual é corrigida, episódio antigo continua como histórico.
4. Jev recebe as duas informações com data/proveniência; opção `informacao_insuficiente` está disponível.
5. Comparar baseline Go, Jev isolated e Jev batch.

**Falha:** boato altera `Fact` global, Jev “confirma” doença sem prova, NPC mantém pedido após correção.

### QA-08 — Jev timeout / lote inválido
1. Usar `httptest` para atraso, HTTP erro, resposta truncada, alternativa desconhecida e confidence fora de faixa.
2. Injetar respostas com 50% das questões válidas; decidir política explícita de parcial por pergunta.
3. Testar JEV OFF; ticks não bloqueiam e fallback prossegue.
4. Se Jev termina após `Due`, não aplicar resultado; se mudança de recursos tornou plano inválido, revalidar/replanejar.
5. Comparar digest de replay do log aceito sem novo acesso de rede.

**Falha:** AI call dentro do lock, panic, comando que altera estado sem journal, duplicação de task.

### QA-09 — Spawn/despawn por região
1. NPC nominado está transitando entre dois vasos do grafo lógico, sem jogador.
2. Jogador entra: cliente materializa aparência e rota atual sem resetar memória.
3. Dois clientes observam o mesmo NPC enquanto na região.
4. Jogador sai: objeto Godot desaparece, mas estado lógico continua.
5. Jogador volta e encontra fase/tarefa atualizadas; nenhum pacote faz spawn duplo.

**Falha:** duplicar oxigênio, NPC regressar ao começo, criar novo ID a cada aproximação.

### QA-10 — Alertas sem saturação
1. Simular uma crise com eventos internos por muitos ticks e duas transições.
2. Acompanhar HUD: um banner por transição relevante, sem banner a cada porcentagem.
3. Enfileirar alerta crítico e pedido NPC no mesmo tick; crítico tem prioridade, pedido continua acessível.
4. Reordenar mensagens de rede, repetir snapshot e reconectar.
5. Tela estreita + movimento de combate: controles continuam.

**Falha:** sobreposição/flash, banner repetido, lock de input, perda de objetivo acompanhado.

**Manutenção dos testes:** substituir expectativas que obriguem conservar saves, runs, genes, progressão, journals ou banco legados por fixtures descartáveis e validação do caminho escolhido. Não remover testes de replay/digest, idempotência, autoridade ou persistência normal da versão vigente. Esta revisão altera a especificação de testes; não modifica testes executáveis.

### QA-11 — Persistência vigente e migração ou reset/recriação
1. Registrar estratégia, escopo e versão/fingerprint de destino; usar fixtures locais descartáveis.
2. Para reset/recriação, inicializar mundo, journal e banco de teste vazios com schema/configuração atuais; backup e fixture legada são opcionais.
3. Confirmar nascimento de personagem, NPCs, conflitos, progressão nova e ausência de referências a runs/IDs descartados ou recompensas duplicadas.
4. Reiniciar a versão vigente e comparar replay/digest, persistência e idempotência; isso continua obrigatório após um reset.
5. Se optar por conversão, testar a transformação declarada e repetição idempotente ou recusa segura; não exigir conservação de toda progressão nem restauração do original.
6. Conferir novo mundo pessoal WASM/save e isolamento em relação ao MMORPG.

**Falha:** estado resultante inválido, fingerprint silenciado, replay divergente na versão vigente ou duplicação de efeitos. Descarte autorizado de dados antigos não é falha.

### QA-12 — Operação sem cliente e após restart
1. Iniciar runner no host de QA e desconectar todos os clientes.
2. Monitorar que ticks e jobs continuam; nenhum listener de sessão é requisito do agendador.
3. Parar serviço de QA controladamente; conferir persistência e registrar política `pause` ou `bounded catch-up`.
4. Reabrir e medir se memórias, recursos, conflitos e tarefas retomam do último tick confirmado.
5. Checar backlog de alertas: mudanças antigas não são apresentadas como crises novas.

**Falha:** o mundo só anda quando cliente entra, replay chama Jev, catch-up cria centenas de popups.

### QA-13 — Simulação biológica de diversas regiões
Criar cenário encadeado de 6 órgãos com transporte finito. Aumento de infecção pulmonar reduz transporte, causa trabalho extra de coortes, muda sinais sistêmicos e pode chegar a outra região após atraso; ações de agentes estabilizam. Verificar que nenhum indicador é “teleportado” sem regra de transporte e que a simulação não diverge sem player.

### QA-14 — Segurança de contribuição
Testar requestId repetido, NPC falso, HP/dano falso, conflito inexistente, ajuda depois da resolução, cliente tentando enviar origin `adapter`, pacote com IDs de jogador de outra sessão e intenção fora de capacidade. Todos rejeitados sem mutar estado canônico.

### QA-15 — Jev e escalabilidade
Executar mesmos snapshots rotulados em variantes: Go puro, Jev 1.13 pergunta única, Jev 1.13 lotes 8/16/32/64, Jev 1.14 lotes 8/16/32/64 **se endpoint realmente suportar**. Medir utilidade/erros, diversidade de papéis, latência, custo e conflitos de recursos. Não publicar ganho estatístico com amostra inadequada.

### QA-16 — Animações polidas e interações celulares (P10V)
1. Instanciar Rubra, Neva, Dendra, Osteia, macrófago e plaqueta em QA; verificar silhuetas e animações específicas que indiquem função **sem texto**.
2. Rubra recebe carga de O2, chega ao bloqueio, pede ajuda, recebe intervenção e entrega ao tecido; comparar estados `anticipate`, `contact`, `progress`, `confirmed`, `cancel`.
3. Macrófago faz fagocitose e plaquetas selam ferida somente quando o resultado é confirmado; mudança do tecido segue indicador autoritativo, com falha visual se não der certo.
4. Jogador e NPC cooperam; os dois clientes veem animação/contato/progresso no mesmo ID canônico. Enviar pacotes duplicados, atrasados e fora de ordem; reconectar no meio da animação.
5. Conferir conflito escalar/recuperar e ambiente reagir; sem flashes repetitivos nem poluição de partículas sobre telegraphs ou controles.
6. Alternar alto/padrão/econômico e reduced-motion, som mudo, tela pequena e touch; a informação importante persiste.
7. Repetir em QA com 1, 20, 50 e 100 NPCs visíveis **como cenários de carga, não metas garantidas**; registrar CPU/GPU, frame-time p95/p99, nós/partículas, alocações, banda e input latency.
8. Capturar antes/depois em mesmo cenário/seed e registrar observações de participantes: compreenderam a ação? Sentiram vontade de intervir? Entenderam se deu certo?

**Falha:** todos os NPCs usam mesma aura ou pose, a conclusão aparece antes do servidor, animacao reinicia ao reaparecer, FX afetam colisão/dano, UI trava controles ou preset baixo esconde informação vital.

## 4. Tabela de carga e métricas obrigatórias

| Cenário | Variação | Observar |
|---|---|---|
| Headless sem player | 10/30/60/180 min de tempo simulado | NPCs ativos, tarefas concluídas, conflitos, recursos, memória |
| Core — NPCs nomeados | 10/100/500 (QA) | p50/p95/p99 tick, heap, GC, custo por tick |
| Coortes | 10/100/1.000 agregados (QA) | custo da simulação, conservação e observabilidade |
| JevBatch | 1/8/16/32/64 perguntas | p50/p95/p99, custo por questão útil, timeout, taxa de invalidação |
| Rede | 1/2/4/16/32/64 clientes simulados QA | banda, snapshots, drops, reconciliação, autoridade |
| Mundo | 1/2/3/5 conflitos relacionados/independentes | dedupe, encadeamento, qualidade de prioridade, UI |
| Persistência | 100/1.000/10.000 comandos em log QA | fsync, tamanho, replay, checkpoint, digest |
| Visual e animação celular | 1/20/50/100 NPCs visíveis QA; alto/padrão/econômico | frame-time p95/p99, CPU/GPU, nós/FX ativos, clareza, coerência de sincronização e responsividade |

Valores são **eixos de teste**, não capacidade prometida. Não usar 64 clientes reais em produção para aferir limite. Se performance piorar versus baseline, registrar e corrigir antes de ampliar volume.

### Métricas de qualidade (não só velocidade)
- `valid_decision_rate`: decisões Jev aplicadas sem violar regras.
- `useful_action_rate`: ações NPC que avançaram trabalho ou produziram informação útil.
- `task_replan_rate`: replanejamentos; muitas trocas podem indicar indecisão.
- `npc_idle_with_unmet_need`: NPCs ociosos quando há tarefa compatível sem explicação.
- `conflict_duration_by_phase`, `conflict_recurrence`, `time_to_containment`.
- `help_request_resolve_rate` e pedidos emitidos por necessidade real.
- `rumor_false_positive` e `belief_correction_delay`.
- `duplicate_alerts`, `duplicate_rewards`, `unauthorized_adapter_events` (idealmente zero).
- `jev_prompt_bytes`, `batch_questions`, `jev_timeout`, `fallback_reason`, `jev_cost`.
- `replay_digest_mismatch` na versão vigente e estado inválido após migração/reset (**zero tolerância**). Descarte legado previsto na estratégia não é `migration_data_loss` bloqueante.
- `visual_false_confirmations` (**zero tolerância**), `duplicate_completion_vfx`, `interaction_visual_latency`, `active_fx_nodes`, `npc_visual_frame_p95`, `npc_telegraph_readability`.

Definir metas quantitativas de latência/CPU/custo depois do baseline real, por classe de hardware. Gate estrito de correção pode ser 100% nos testes determinísticos e zero duplicações, mas nenhuma percentagem de “inteligência correta” é universal sem conjuntos rotulados.

## 5. Experimentos de qualidade dos agentes

O revisor compara sem saber qual variante é IA vs baseline:

| Dimensão | Pergunta do revisor | Nota sugerida |
|---|---|---|
| Plausibilidade | Uma hemácia executou um papel relacionado a transporte? | 0–4 |
| Causalidade | A tarefa nasceu de evidência real e causou mudança observável? | 0–4 |
| Autonomia | Ela agiu sem jogador e replanejou diante do mundo? | 0–4 |
| Memória | Mudou comportamento por experiência relevante, sem onisciência? | 0–4 |
| Cooperação | Compartilhou função sem duplicar recursos ou virar cópia de outra célula? | 0–4 |
| Legibilidade | O jogador entende necessidade, risco e contribuição? | 0–4 |
| Robustez | Funciona sem Jev e após perda de rede/restart? | 0–4 |

Registrar número de casos, distribuição, critérios, divergência entre avaliadores e exemplos concretos. Evitar “nota 10” subjetiva sem evidência.

## 6. Gates antes de desligar masmorras

**NÃO DESLIGAR** `bio_dungeon_panel`, portais e `dungeonTick` do Hospedeiro até confirmar:
- [ ] jogador tem conflito permanente e objetivo visível ao nascer;
- [ ] ao menos duas fontes de progressão antes exclusivas de dungeon têm equivalente justo;
- [ ] caminho escolhido (migração ou reset/recriação) testado, incluindo inicialização do modo pessoal;
- [ ] recuperação reproduzível em QA por correção/reversão de código ou recriação; backup/restauração de dados opcionais;
- [ ] duas pessoas participam da mesma crise, sem cena instanciada;
- [ ] nenhum requisito de `engine/core/dungeon.go` em Valdoria ou outros universos foi alterado inadvertidamente.

Depois da substituição validada, com migração ou reset, eliminar gradualmente o legado de UI/cliente, nunca com exclusão ampla de código sem busca por referências.

## 7. Template de relatório real em Docs/Validation

```markdown
# <Data> — Hospedeiro Pn <módulo>
- Branch/SHA início:
- Commit final:
- SO, Go/Godot/Nakama/IA e configurações QA:
- Mundo QA / fingerprint antes e depois:
- Arquivos alterados:
- Testes de Go executados:
- Testes de Godot executados:
- Testes web/Nakama QA executados:
- Cenários QA usados:
- Digest antes/depois do replay:
- Benchmarks (mediana/p95/p99; amostra; hardware):
- Jev (modelo, lote, latência, fallback, custo medido):
- Visuais / logs sem segredos:
- Defeitos encontrados e corrigidos:
- Testes não executados e justificativa:
- Estratégia e resultado de migração ou reset/recriação; backup/restauração opcionais:
- Pendências e gate aprovado/reprovado:
```

**Nunca preencher testes ou números fictícios.** Valores de mock, estado ilustrativo e testes de laboratório precisam ser rotulados como tais.

## 8. Critério de conclusão final (demo obrigatória)

A entrega só é considerada completa após todos estes resultados serem observados numa demonstração QA reproduzível:

1. Corpo vazio processa trabalho celular independente de cliente por longo período.
2. Pelo menos seis papéis biológicos distintos têm comportamentos e impactos materiais.
3. Dois jogadores veem o mesmo NPC e mesmo conflito global, cada um pode contribuir sem quest.
4. Rubra sofre bloqueio, pede ajuda, uma ação a ajuda e ela registra/recupera essa memória.
5. Neva e Dendra coordenam defesa por informação que realmente circulou.
6. Infecção pulmonar abre, escala, recebe esforços e estabiliza por limiares fisiológicos.
7. Outra crise pode coexistir, com limite de alerta e sem duplicação.
8. A visibilidade e o desmaterializar de NPCs não reiniciam seu trabalho.
9. Jev 1.13/1.14 (conforme variante vencedora) demonstra valor sobre baseline medido; Jev indisponível não paralisa.
10. Reiniciar Go QA restaura mesmo mundo, e replay reproduz digest.
11. Mundo compartilhado e pessoal iniciam válidos após migração ou reset/recriação; saves legados podem ser descartados.
12. Nenhum novo portal de dungeon instanciada no loop final; recompensas e progressão novas funcionam sem exigir conservação do legado.
13. Carga documentada, orçamento Jev, alertas mobile e anti-cheat demonstrados.
14. Documentar a diferença entre serviço realmente 24/7 e simulação pausada quando computador de hospedagem estiver desligado.
15. Demonstrar animações polidas de transporte de Rubra, patrulha e defesa de Neva, sinais de Dendra, limpeza por macrófago, reparo por plaquetas e suporte de Osteia. Mudanças ambientais, falha/confirmação, reduced-motion, baixa qualidade mobile e sincronização em 2 clientes devem cumprir V-G1–V-G12.

**Sem essas evidências, a palavra correta é “parcialmente implementado”, e não “concluído”.**
