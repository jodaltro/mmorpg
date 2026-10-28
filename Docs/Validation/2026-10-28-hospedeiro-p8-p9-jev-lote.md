# 2026-10-28 — Hospedeiro P8/P9 · JevBatch e deliberação macro/meso/micro (com Jev ao vivo)

- Baseline: `main` @ `f4cd919b`. Go 1.27.2, Windows 10, Ryzen 7 1700X. Mundos em memória; nenhum mundo real tocado. Chamadas ao Jev reais (liberadas por AGENTS.md), chave de `engine/.env`, nunca registrada.
- O fingerprint do universo muda de novo (deliberação, respostas de conflito, coortes com `baseline`, tarefas novas).

## Entregue
- **Contrato de lote** (`engine/advisor/batch.go`): `BatchAdvisor`/`BatchResult`, `Jev.DecideBatch` — um pedido com N perguntas `choice` (q1..qN), contexto por pergunta, opções opacas, resultado **por pergunta** (uma resposta inválida/ausente só falha a sua), teto `MaxBatch=32`, timeout, probabilidades mapeadas de volta aos ids e custo da chamada dividido entre as perguntas. `Jev.Model` permite o A/B 1.13×1.14; o `Decide` legado continua igual.
- **Deliberação no motor** (`engine/core/deliberation.go`, só com `deliberation` no universo): um NPC ocioso com **≥2 tarefas possíveis** abre uma decisão `npc` (opções = tarefas + `esperar`; padrão = a de maior prioridade) com contexto só das próprias crenças/memórias e dos números públicos; orçamento `maxOpen` de decisões abertas e tempo de silêncio `every` por NPC. Um conflito que começa ou escala abre uma decisão `conflict` com as `responses` declaradas (primeira = padrão); a escolhida aplica efeitos validados — novo efeito `muster` traz membros de uma coorte pagando a reserva real e respeitando a capacidade (`baseline` separa o refil natural do reforço). Resposta obsoleta (NPC não espera mais, conflito mudou de revisão, tarefa inválida) é recusada; no prazo vale o padrão. O Jev nunca é chamado dentro do `Step`.
- **Auditoria**: distribuição de probabilidades vai no evento `decision` (`probs`), modelo/latência/custo/chamada como antes.
- **Runner** (`engine/sim/runner.go`): decisões `npc`/`conflict` vão por `DecideBatch`, com `BatchWindow` opcional para juntar perguntas de ticks próximos; `Stats()` por tipo (perguntas, aplicadas, recusadas, falhas, **mudou-vs-padrão**, latência, custo). CLI: `-advisor jev|jev-single`, `-jev-model`, `-batch-window`.
- **Universo**: `deliberation {every 12, maxOpen 4}`; Dendra ganhou `apresentar-antigenos` (baço) e Macra `patrulhar-sangue`, de modo que Neva, Dendra e Macra têm escolha real (Rubra continua com uma tarefa e nunca é consultada); respostas da infecção pulmonar: manter defesas (padrão) / mobilizar neutrófilos e macrófagos / reforçar transporte; coortes com `baseline` e teto maior.

## Testes locais executados (resultado real)
`gofmt -l` limpo nos arquivos tocados, `go vet ./...` limpo, `go test ./... -count=1` todos `ok`.
- `advisor/batch_test.go` (httptest): 1 chamada com 3 perguntas mapeadas de volta e probabilidades por id; respostas parciais (válida sobrevive; opção desconhecida, ausente e confiança fora da faixa falham só a própria); HTML/modelo errado/HTTP 500/timeout (corta em <250 ms) falham todas; lote vazio e acima de 32; override de modelo e rejeição de modelo divergente; nenhum id interno nem a chave chega ao provedor.
- `scenarios/deliberation_test.go`: só escolha real vira pergunta (Rubra nunca; Neva/Dendra/Macra sim); `maxOpen` respeitado; opção inventada recusada, `esperar` mantém o NPC ocioso, auditoria mostra escolha/padrão/distribuição, segunda resposta recusada; sem Jev o mundo anda e nenhuma decisão passa do prazo; resposta de conflito `mobilizar-defesa` soma +20 neutrófilos gastando a reserva, uma vez só, e com reserva vazia nada aparece; **replay de 1500 ticks com 24 respostas aceitas reproduz o digest**.
- `sim/batch_test.go` (assessor falso): 100 perguntas, todas aplicadas ou recusadas, 13 diferentes do padrão; falha por pergunta e por chamada cai no padrão e Neva continua trabalhando; resposta atrasada (600 ms) não segura os ticks e é contada/recusada; a janela de lote junta perguntas (menos requisições que perguntas).

## Jev ao vivo (reais, faturados; amostra pequena, sem verdade rotulada)
**Comparação sobre as mesmas 76 decisões reais de NPC/conflito** (`JEV_LIVE=1 go test ./scenarios -run TestLiveJevBatchComparison`, 16 s):

| Variante | válidas | igual ao padrão | lote×individual iguais | latência | custo |
|---|---|---|---|---|---|
| 1.13 individual ×16 | 16/16 | 10 | — | p50 339 ms | US$ 0,000439 |
| 1.13 lote ×8 | 8/8 | 7 | 5/8 | 348 ms total (43,5 ms/pergunta) | US$ 0,000136 |
| 1.13 lote ×16 | 16/16 | 13 | 11/16 | 377 ms (23,6) | US$ 0,000261 |
| 1.13 lote ×32 | 32/32 | 32 | 10/16 | 391 ms (12,2) | US$ 0,000512 |
| 1.14 individual ×16 | 16/16 | 14 | — | p50 340 ms | US$ 0,000439 |
| 1.14 lote ×8 | 8/8 | 7 | 7/8 | 373 ms (46,6) | US$ 0,000136 |
| 1.14 lote ×16 | 16/16 | 13 | 13/16 | 369 ms (23,1) | US$ 0,000261 |
| 1.14 lote ×32 | 32/32 | 32 | 14/16 | 410 ms (12,8) | US$ 0,000512 |

O endpoint aceitou lotes de até 32 perguntas e o modelo `typesafe/jev-1.14`; o tempo de parede quase não cresce de 8 a 32 e o custo por pergunta cai ~40% em lote. A concordância lote×individual foi maior no 1.14 (7/8, 13/16, 14/16) que no 1.13 (5/8, 11/16, 10/16); com 16 perguntas e sem gabarito **isso não é prova de qualidade**. O lote de 32 igualou o padrão em 32/32, indício de viés para a primeira opção em lotes grandes que merece rotulagem antes de adotar 32. Tamanho 64 não foi testado (limite do runner = 32).

**Mundo ao vivo, 240 ticks, pace 1 s, 2 jogadores** (4 processos em paralelo; padrão determinístico, 1.13 individual, 1.13 lote com janela de 600 ms, 1.14 lote):

| Variante | NPC perguntas/aplicadas/diferentes do padrão | conflito | latência média por chamada | custo total |
|---|---|---|---|---|
| determinístico | 9/9/0 | 1/1/0 | 0 | 0 |
| 1.13 individual | 3/3/1 | 1/1/0 | 409 ms | US$ 0,0190 |
| 1.13 lote | 2/2/1 | 1/1/1 | 483 ms | US$ 0,0192 |
| 1.14 lote | 1/1/1 | 0/0/0 | 456 ms | US$ 0,0192 |

Nenhuma pergunta falhou nem foi recusada nas decisões cognitivas; nenhuma passou do prazo. **Limites honestos:** (1) a amostra de decisões de NPC no mundo é minúscula (1–3 por variante) porque o silêncio por NPC é de 12 ticks e `esperar` reduz perguntas futuras; não há conclusão sobre qualidade; (2) `batches=0` no mundo ao vivo — decisões de NPC raramente coincidem, então o ganho real do lote só foi exercitado na comparação sintética e no assessor falso; (3) o custo total é dominado pelas decisões antigas de design/rota (~US$ 0,0188), não pelas novas; (4) mundos divergem a cada variante (Jev muda o rumo), então os digests diferem por construção; (5) o A/B cego com revisores (QA-15) e a medida "o Jev melhora o corpo" **não foram feitos** — só validade, latência, custo e taxa de mudança.

## Não executado / pendências
Teste de 64 perguntas; rotulagem e A/B cego com revisores; scheduler por urgência/novidade/anti-starvation além de `every`+`maxOpen`; macro entre conflitos concorrentes (só há um conflito definido); limite de custo por período e fila (P14.4); Godot/Nakama/HUD. Gate P8: **parcial** (contrato, validação por pergunta, fallback e replay aprovados; ganho de qualidade sobre o baseline **não demonstrado**). Gate P9: **parcial** (deliberação limitada e adaptativa funcionando e medida; hora simulada com muitos NPCs e conflitos concorrentes não testada).
