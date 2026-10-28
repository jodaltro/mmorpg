# Mmorpg — instruções para agentes

> **POLÍTICA VIGENTE — 28/10/2026:** o usuário autoriza limpeza destrutiva, descarte de saves, mundos, journals e progressão, recriação do banco de dados e reset total do Hospedeiro quando necessários ao desenvolvimento. Migração sem perda, compatibilidade com dados antigos, backup e restauração do estado anterior são opcionais e não bloqueiam implementação, gates ou release. Registrar a estratégia escolhida (migração ou reset/recriação) e validar o estado resultante. A autorização não exige reset em toda mudança. Persistência, replay/digest e idempotência continuam obrigatórios dentro da versão vigente. Testes continuam locais/isolados; este ajuste documental não executa limpeza, reset, migração, deploy ou acesso ao banco.

> **PRIORIDADE VIGENTE — 27/10/2026 (Hospedeiro Vivo):** o objetivo do Hospedeiro é uma sociedade celular de NPCs autônomos, trabalhando continuamente enquanto o motor estiver ligado, e conflitos fisiológicos globais em lugar de dungeons instanciadas. Implementar **por fases**, seguindo nesta ordem: [Plano Mestre](Docs/Hospedeiro/AutonomousBodyImplementationPlan.md), [Runbook Claude Code](Docs/Hospedeiro/ClaudeCodeAutonomousBodyRunbook.md), [Quality Gates](Docs/Hospedeiro/AutonomousBodyQualityGates.md), [Visão de Conflitos](Docs/Hospedeiro/LivingWorldConflicts.md) e [Arquitetura Jev](Docs/Hospedeiro/JevCognitiveArchitecture.md). **Vale a autorização de limpeza destrutiva de 28/10/2026 acima; não exigir preservação de dados legados para implementar o Hospedeiro Vivo.** As instruções legadas de masmorras e quests do Hospedeiro devem ser tratadas como histórico até a migração. Não declarar implementado o que é apenas especificação. **Branch main sempre.**

> **PRODUÇÃO VISUAL OBRIGATÓRIA — 27/10/2026:** [VisualInteractionAnimationPlan.md](Docs/Hospedeiro/VisualInteractionAnimationPlan.md) determina salto de qualidade nas interações e animações. Cada tarefa nova do NPC precisa de gesto e silhueta únicos, interação/contato, progresso e feedback de sucesso/falha ligados a eventos confirmados, efeitos que transformam o tecido, sincronização multiplayer sem replay de FX, LOD e performance/acessibilidade mobile. Executar P10V junto de P2–P16, consultar storyboards V01–V16 e gates V-G1–V-G12. **Não encerrar intervenção com NPCs estáticos e partículas genéricas.** Arte procedural no Godot, sem alterar fatos/colliders por VFX; não usar assets sem licença.

> **Catálogo de NPCs:** [AutonomousCellBehaviorAtlas.md](Docs/Hospedeiro/AutonomousCellBehaviorAtlas.md) descreve rotinas, necessidades, sinais e comportamentos emergentes. Usar como referência de testes de vida, sem confundir animação visual com trabalho material.

## Direção vigente (19/10/2026)

O projeto foi refeito a partir do zero como **World Simulation Engine**: um motor de mundo vivo para MMORPG, **agnóstico à interface** (Unity, Unreal, Godot, 2D, 3D, web). Inspiração: *Shangri-La Frontier* e *Overgeared*: história fixa do mundo, cenários únicos que só um jogador conclui, continuações dinâmicas para os demais, missões pessoais e NPCs que agem pelo que sabem. Leitura obrigatória antes de mudar regras: `Docs/GameVision.md` e `Docs/Architecture.md`.

O usuário autorizou **refatoração destrutiva**: pode remover, reescrever e simplificar qualquer parte para chegar à melhor arquitetura, sem compatibilidade com versões anteriores. O projeto Unity 2D/3D, sprites, arte e o backend antigo foram removidos; estão recuperáveis no branch `archive/unity-2026-10-19` e nas tags `archive/valdoria-2d-2026-10-19` e `checkpoint/pre-worldsim-2026-10-19`.

## Repositório

- `jodaltro/mmorpg`, branch de trabalho **`main`** (a padrão da API é `master`: sempre especificar `main`).
- Antes de começar: conferir o worktree e rodar `git pull --ff-only origin main`.
- Ao concluir: commit e push das alterações pertinentes para `main`, informando o SHA. Havendo impedimento, informar sem alegar sucesso.

## Arquitetura (resumo)

- `engine/core`: **só biblioteca padrão**, puro e determinístico (`Step(state, command)`). Nada de rede, banco, engine gráfica, combate ou gênero. O teste `TestCoreHasNoInfrastructureImports` garante isso.
- Regras específicas de um jogo ficam **no universo JSON** (`universes/<id>/universe.json`), validado por `core.Compile`. Não codificar conteúdo no motor.
- **A verdade do mundo é separada das crenças.** Objetivos de NPC usam `knows`; a autoridade valida contra a verdade.
- **Jev é consultivo e assíncrono:** escolhe entre opções já validadas, a resposta é revalidada e, no prazo, vale o padrão determinístico. Nunca colocar chamada de IA dentro do lock ou do `Step`.
- Clientes enviam **intenções** (`player`); o servidor de jogo envia **acontecimentos confirmados** (`adapter`). Nunca aceitar dano, HP ou inventário declarados pelo cliente.
- O log de comandos é a fonte da verdade; o replay precisa reproduzir o `Digest`. Mudança que quebre o determinismo é defeito.

## Engenharia

- Go 1.23+ (validado com 1.27.2 em `D:\tools\go\bin`; pode não estar no PATH). Rodar `gofmt -l .`, `go vet ./...` e `go test ./...` em `engine/` antes de commitar.
- Todo comportamento novo do motor precisa de teste em `engine/scenarios` (sobre universos reais) ou no pacote correspondente.
- **Registrar só testes realmente executados**, em `Docs/Validation/`. Nunca declarar como aprovado o que não rodou.
- **Validação apenas local** (decisão do usuário em 24/10/2026): não executar testes online nem contra o servidor publicado. Evitar repetir verificações já aprovadas sem mudança relevante; economizar tokens e chamadas.
- Universo novo ou alterado: `worldsim validate` e um `worldsim simulate` para conferir que a história não trava.
- Preferir contratos pequenos e versionados. Mudança incompatível no contrato HTTP exige nova versão (`/v2`).

## Segurança e segredos

- Nunca versionar segredos, `.env`, logs de mundo (`data/`), executáveis ou caches. A chave do Jev fica em `engine/.env` (ignorado) ou na variável `OPENROUTER_API_KEY`.
- **Chamadas ao Jev estão liberadas** (decisão do usuário em 19/10/2026: o Jev é um dos corações do sistema e precisa ser validado de verdade). Os testes automáticos usam `httptest`; os ao vivo rodam com `JEV_LIVE=1` ou `simulate -advisor jev`. Registrar latência, custo e taxa de resolução no prazo em `Docs/Validation/`.
- **Hospedeiro online com Nakama autorizado em 24/10/2026.** Entrada de convidado só pelo nome; sessão técnica automática por dispositivo, sem senha/cadastro. Nakama cuida de sessões/transporte, Godot headless executa combate compartilhado e só o servidor confirma acontecimentos no motor. Ver `Docs/Hospedeiro/Nakama.md`.
- O `serve` de desenvolvimento só escuta em loopback, porque a origem ainda vem no corpo. Antes de expor em rede: autenticação que derive `player`/`adapter` da credencial.
- Segredos e materiais do projeto antigo estão fora do repositório, em `D:\unity\Mmorpg-archive-2026-10-19` (inclui `secrets/`). Não apagar sem pedido do usuário.
- Respeitar licenças de assets e bases de engine; não redistribuir conteúdo com licença restritiva neste repositório público.

## Ambiente

- Unreal 5.8 instalada em `C:\Program Files\Epic Games\UE_5.8`; projeto de teste em `D:\UnrealProjects\WorldSimDemo` (fora do repositório). Ver a skill `.claude/skills/unreal`.
- **C: quase sem espaço**: projetos, downloads de assets (`D:\UnrealDownloads`) e caches grandes ficam no D: (exFAT: sem junctions/symlinks; copiar em vez de linkar).
- Shell: Git Bash e PowerShell 5.1. Heredocs muito longos podem falhar no Bash; dividir em blocos.

## Hospedeiro (MMORPG dentro de um corpo humano)

- Pesquisa e plano de intensificação cognitiva do Jev em `Docs/Hospedeiro/JevCognitiveArchitecture.md` (27/10/2026): Jev como avaliador estruturado por lotes, memória filtrada com procedência, comparação 1.13/1.14 em QA, `Step` continua autoridade. Não mudar modelo, custo nem contratos sem benchmarks e teste de replay.

### Conflitos globais persistentes — decisão 26/10/2026

- A direção vigente de gameplay está em `Docs/Hospedeiro/LivingWorldConflicts.md`: **NPCs vivos e conflitos globais persistentes** em vez de masmorras instanciadas no Hospedeiro. O conteúdo de dungeon nos documentos antigos é legado e deverá ser migrado, não replicado em novas features.
- NPCs precisam trabalhar, perceber, pedir/aceitar ajuda e manter relações e memória pelo motor; participação em conflitos é livre, sem exigir aceitar uma missão. O HUD prioriza um conflito acompanhado e pedidos contextuais, com alertas grandes porém deduplicados.
- **Masmorras removidas do Hospedeiro (P13, 28/10/2026):** o universo não tem mais `dungeons`; as cinco crises equivalentes pagam pressão, maturidade e selo a quem contribuiu (`ConflictDef.rewards`). Ver `Docs/Hospedeiro/DungeonMigration.md`. `engine/core/dungeon.go` fica como serviço genérico, testado em `engine/scenarios/testdata/legacy-dungeons`; não reintroduzir portais ou salas no Hospedeiro.
- Continuar usando o motor Go puro/determinístico, Godot autoritativo, Nakama e Jev assíncrono; Java não deve introduzir outra fonte de verdade.

Segundo jogo sobre o motor: o mundo é um único corpo humano anônimo, compartilhado por todos. Visão em `Docs/Hospedeiro/BiologicalVersion.md`, estrutura em `Docs/Hospedeiro/GameStructure.md`, dados científicos em `Docs/Hospedeiro/HostScience.md`. Ler antes de mudar regras do Hospedeiro.

- Universo `universes/hospedeiro/universe.json` (Medula e Sangue). Cliente Godot 4.7 em `clients/hospedeiro/`: conecta ao motor em `127.0.0.1:8096` (porta própria, para não colidir com Valdoria na 8095) e, sem motor, joga em **modo offline**.
- **No PC o cliente joga offline por padrão** (decisão de 28/10/2026): fala só com o motor local em `127.0.0.1:8096`, sem Nakama; o modo online é opt-in com `--online` ou `HOSPEDEIRO_ONLINE=1`. Foco atual: experiência offline no PC.
- **Reset completo = `scripts\hospedeiro-reset.ps1`** (28/10/2026): para tudo e arquiva em `D:\unity\hospedeiro-data-archive\<data>` o mundo, os personagens salvos do cliente (`%APPDATA%\Godot\app_userdata\Hospedeiro\hospedeiro_*.json`) e o banco do Nakama (`D:\unity\hospedeiro-nakama-db`), e sobe o motor novo. `-Online` recria o banco pelo supervisor, mas esse usa o `engine\.env`: conferir que não aponta para o banco remoto antes de usar.
- **Sem missões, uma crise por vez, sem névoa (28/10/2026, pedido do usuário):** o Hospedeiro não tem missões nem arcos de história (`quests`/`arcs` saíram do universo; as provas de classe viraram `learn` das habilidades, aprendidas fazendo). O universo limita as crises que pedem atenção ao mesmo tempo (`limits.maxLiveConflicts: 1`, com `liveConflictPatience` para que uma crise presa não trave o mundo; crises contidas ou em recuperação são calmas e não ocupam a vaga). Todo órgão está aberto a toda célula (passagens sem gene ou linhagem) e o mapa é inteiro desde o início, com a crise atual marcada. Ajudar é um gesto só: derrotar os invasores do órgão da crise (ou tocar nos brilhos dele; na medula, absorver nutrientes). O cartão "O QUE FAZER" e a seta do guia vêm da crise atual. Não reintroduzir missões nem ofertas.
- **Operação contínua (P14, 28/10/2026):** o motor fica neste PC, vigiado por `scripts\hospedeiro-service.ps1` (o reset já o sobe). PC desligado ou suspenso = mundo parado, sem recuperar o tempo perdido. Detalhes, limites e orçamentos em `Docs/Hospedeiro/Operations.md`. O instalador da tarefa agendada (`hospedeiro-install-task.ps1`) só roda quando o usuário pedir.
- **Sempre reiniciar o mundo e os dados por completo** ao subir o backend (pedido do usuário, 28/10/2026): arquivar `D:\unity\hospedeiro-data` em `D:\unity\hospedeiro-data-archive\<data>` e subir com mundo novo.
- **Organismo, sempre:** braços, garras, armas e qualquer extremidade são deformação da própria membrana (nunca peças coladas) e a cor muda por gradiente dentro da célula; cada extremidade se move sozinha e o corpo inteiro também (ver `BioNpcMotion`).
- O usuário só abre o cliente. **O agente mantém o backend do Hospedeiro rodando** (`serve` na 8096, `-advisor jev`, dados em `D:\unity\hospedeiro-data`) e passa comandos em **PowerShell**.
- O supervisor online também inicia `scripts/hospedeiro-nakama.ps1`: Nakama HTTP/WS 7350, Godot headless e PostgreSQL local 55432. Chaves/configuração em `D:\unity\hospedeiro-nakama`, banco em `D:\unity\hospedeiro-nakama-db`. `-LocalTest` usa Nakama 7352, motor 8198 e banco/mundo QA separados. Executar testes em QA local/isolado; reset da instância real pode integrar uma mudança de desenvolvimento necessária, fora da rotina de testes e com escopo registrado.
- Reset global temporário de teste habilitado em 24/10/2026: supervisor com `-TestReset -ReuseTunnel`, executável atual em `D:\unity\hospedeiro-run\worldsim-nakama-v2.exe`. O botão do jogo exige confirmação. Usar `httptest`/mundos locais isolados na validação; a confirmação do botão é comportamento do produto, não exigência de nova autorização para limpeza de desenvolvimento já autorizada.
- `scripts/domain`: regras puras (`RefCounted`, sem Node). `scripts/runtime`: Nodes, física, input, apresentação. `tests/`: runner headless próprio.
- Estética bioluminescente procedural, tom sombrio-onírico. Hitbox lógica separada do corpo deformável. Biologia é base, não lei.
- Sem níveis nem XP: progressão por diferenciação, genes, epigenética, memória e linhagem.
- Testes (Godot em `D:\tools\godot\bin`). O runner não captura erros de script: conferir `SCRIPT ERROR`/`ERROR` na saída além da contagem.

```bash
G="/d/tools/godot/bin/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path clients/hospedeiro --import
"$G" --headless --path clients/hospedeiro --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|ERROR|----"
"$G" --path clients/hospedeiro   # jogar
```

## Atualização — sem missões, uma crise por vez, mapa sem névoa (28/10/2026, noite)

**Pedido do usuário:** não estava claro como interagir com o que acontecia no mundo, havia coisas demais ao mesmo tempo, as missões deviam acabar e o mapa não devia esconder nada, já que os eventos podem ocorrer em qualquer lugar.
**Descoberta que explica a confusão:** nas regiões da pele, do pulmão, da medula, do linfonodo e do cérebro o jogador **não tinha nenhum gesto que ajudasse a crise**, e o pulmão e a aorta só abriam com um gene ou classe. Agora ajudar é um gesto só: derrotar os invasores do órgão da crise (a pele, o pulmão, o linfonodo, o cérebro, o baço e o intestino), tocar nos brilhos (fígado, baço, intestino, rim) ou, na medula, absorver nutrientes. Três ações novas (`acalmar-reacao-linfonodo`, `amparar-neuronios-cerebro`, `nutrir-nicho-medular`), `repelir-invasor` também enfraquece o tumor, e as dez crises pagam pressão e maturidade a quem ajudou.
**Motor:** `Limits.MaxLiveConflicts` e `LiveConflictPatience` (genéricos, opcionais; outros universos não mudam). Só ocupa a vaga uma crise ativa ou crítica e só por 450 ticks no Hospedeiro; sem essa paciência a "reação exagerada", presa porque a inflamação só cai quando a infecção que esperava na fila termina, travava o mundo (achado pelo teste).
**Universo:** `quests` (37) e `arcs` removidos; os 10 `prova-*` viraram `learn` das habilidades de classe (a mesma condição, sem a missão). Perdidos de propósito: as recompensas de gene permanente das missões e o título da primeira lembrança. Passagens do pulmão e da aorta abertas a todos.
**Cliente:** painel do sistema sem missões, ofertas e quadro; `BioHostSync`, guia (`BioJourney`), tutorial e toque sem missão; o guia aponta primeiro para a crise atual; cartão "O QUE FAZER" com onde ir e o que fazer; botão "Crises do corpo" no lugar de "Missões"; atlas e minimapa sem névoa, com anel nas crises que pedem ajuda (toque no anel mostra o que fazer).
**Testes Go (rodados):** nunca mais de uma crise pedindo atenção, determinismo e cada causa que ainda vale tem sua vez; a que espera abre quando a vaga livra; nenhuma missão aparece e a classe aprende pela prática; toda crise tem um gesto do jogador no seu órgão; o jogador no cérebro ajuda e é pago; nenhuma passagem exige gene. Os testes de missões e de passagens com gene rodam no fixture congelado. `go vet` e `go test ./... -count=1` verdes. Simulação natural de 12000 ticks segue ciclando sem travar.
**Testes Godot:** suíte inteira; os testes do quadro de missões foram removidos e os do guia, tutorial, toque e atlas reescritos.
**Não feito:** ninguém jogou para ver se o cartão e a seta bastam; as crises calmas (contidas ou recuperando) ainda aparecem no painel; o atlas ainda guarda código de descoberta que não faz mais nada.
