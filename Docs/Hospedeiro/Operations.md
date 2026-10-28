# Operação contínua do Hospedeiro neste PC (P14)

Decisão de 28/10/2026: **o motor fica neste PC**. Isto descreve o que isso garante e o que não garante.

## O que mantém o mundo vivo

| Peça | Papel |
|---|---|
| `scripts\hospedeiro-service.ps1` | Vigia: sobe o motor, olha `/v1/health` a cada 10 s, reinicia se o processo morrer ou ficar `stalled`/sem resposta por 90 s, com espera crescente (2 s a 60 s). Estado em `D:\unity\hospedeiro-run\service-status.json`. Para parar: criar `service.stop` na mesma pasta. |
| `scripts\hospedeiro-install-task.ps1` | Opcional, **não roda sozinho**: registra a tarefa agendada "Hospedeiro Motor", que sobe o vigia ao entrar no Windows. `-KeepAwake` desliga suspensão e hibernação na tomada. `-Remove` desfaz. |
| `scripts\hospedeiro-reset.ps1` | Reset completo (arquiva mundo, saves e banco) e sobe o vigia. |

## O que o PC desligado significa

- **PC desligado, em suspensão, ou sem o vigia: nenhuma simulação acontece.** Não existe processamento em outro lugar.
- **Política de tempo: pausa fiel ao tick** (`pause-and-resume`). Ao voltar, o mundo continua do tick onde parou, **sem corrida para recuperar o tempo perdido** e sem avalanche de efeitos ou alertas. O tempo do mundo só anda enquanto o motor roda. Coberto por `TestTheWorldIsPausedNotCaughtUpWhileTheProcessIsDown`.
- Para serviço realmente contínuo é preciso um servidor ligado 24/7 (ver `CloudHosting.md`). A autoridade não muda: o mesmo binário e o mesmo log.

## Queda, reinício e recuperação (P14.2)

- **A verdade é o log de comandos** (`hospedeiro.jsonl`, gravado com fsync a cada comando; uma última linha rasgada por queda é descartada na abertura).
- **Checkpoint** (`hospedeiro.checkpoint.json`): estado completo verificado, a cada 450 ticks (30 min de mundo) e ao parar com calma. Só atalho: na abertura vale se for da mesma versão do universo, não passar do que o log tem e o digest bater; qualquer dúvida e o log inteiro é reexecutado, com o mesmo resultado. Guarda a geração anterior (`.prev`) e grava por arquivo temporário + renomeação, então uma queda no meio da escrita não deixa o mundo sem checkpoint.
- Após uma queda só se reexecuta a cauda do log depois do último checkpoint (menos de 450 ticks, menos de um segundo).
- `Revive` (core): um estado lido do JSON volta com mapas vazios nulos e o motor escreveria neles; é recriado como o `NewState` faria. O mesmo conserto vale para o cache do mundo pessoal. Sem isso a restauração quebrava.
- **Tick que não consegue ser gravado** (disco cheio, log inacessível): tenta no próximo; após 5 seguidos o processo sai com erro, o vigia o reinicia. Nada avança sem estar gravado.
- Backup é opcional: o `hospedeiro.jsonl` e o checkpoint são arquivos comuns; o reset arquiva em `D:\unity\hospedeiro-data-archive\`.

## Limites de crescimento medidos

- **Log:** cerca de 330 bytes por tick no início, na ordem de 7 MB por dia de mundo (tick de 4 s). Sem compactação ainda: um mês passa de 200 MB. O checkpoint evita que o tamanho vire tempo de abertura, mas o arquivo ainda é lido inteiro.
- **Estado:** não cresce com o tempo. Medido: 238 KB no tick 3000 e 285 KB no 8000, com a lista de eventos no teto de 1000 do universo (`TestStateStaysBoundedOverALongRun`).
- **Tick:** ver a tabela abaixo.

## Orçamentos por tick (P14.3)

Medidos neste PC por `TestTickBudgetForTenHundredAndFiveHundredNamedCells` (células nomeadas com tarefas repetidas do universo real, 300 ticks após aquecer). O tick do Hospedeiro tem 4000 ms. Estes números são onde a máquina estava, não promessa de escala.

| Células nomeadas | Tick médio | p99 | Estado |
|---|---|---|---|
| 14 | 0,35 ms | 9 ms | 163 KB |
| 100 | 0,76 ms | 7 ms | 233 KB |
| 500 | 5,76 ms | 20 ms | 499 KB |

O limite do teste é bem mais folgado que isso (10, 40 e 250 ms) para só acusar regressão. Coortes grandes não custam por indivíduo: são contadores.

## Jev: teto de consultas, custo e fallback (P14.4)

`serve` agora aceita `-max-questions-per-minute` (padrão 120), `-max-cost-per-hour` (padrão US$ 1,00) e `-batch-window`. Passado o teto, a pergunta **não é enviada** e vale o padrão determinístico, sem quebrar a simulação; as de maior prioridade vão primeiro (atenção, depois conflito, depois NPC). Já havia testes dos dois tetos (`sim/batch_test.go`). O que ficou de fora: um teto de tamanho de contexto por pergunta, que continua o do próprio desenho das perguntas.

## Observação (P14.1/P14.3)

- `GET /v1/health`: sempre 200; `status` é `ok`, `starting` (ainda sem tick) ou `stalled` (ticks pararam de chegar), mais `uptimeSeconds` e `lastTickAgeSeconds`.
- `GET /v1/metrics` (só fora do modo público): tick médio/p50/p95/p99/máximo, entradas do log, como o processo abriu (do checkpoint ou do log, quantos comandos reexecutou, em quantos ms), estado do checkpoint, contagens do mundo (entidades, NPCs, NPCs trabalhando, crises vivas, eventos, pedidos de ajuda), contadores e custo do Jev, fila e decisões pendentes. Só contagens: nenhum nome, posição ou dado de jogador.

## Mundo compartilhado e mundos pessoais (P14.5)

O mundo pessoal (`engine/personal`) tem diário próprio e nunca é importado pelo compartilhado. Os dois usam o mesmo mecanismo de atalho verificado e agora o mesmo conserto de restauração. Depois de uma queda o mundo compartilhado volta do log sem inventar eventos perdidos; o custo do Jev após a queda é só o das perguntas que estavam pendentes, que são reenviadas uma vez ao abrir.

## Não coberto

- Compactação ou rotação do log; backup automático; failover para outra máquina.
- Encerramento limpo pelo vigia: ele encerra o motor à força, então a parada comum deixa a cauda a reexecutar (menos de 450 ticks) em vez de um checkpoint novo.
- A tarefa agendada e as opções de energia só valem depois de você rodar o instalador.
