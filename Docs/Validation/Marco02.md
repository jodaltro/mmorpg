# Validação executada — Marco 02

Executada em 13/10/2026 no Editor conectado Unity 6000.6.5f1, CLI 1.0.0-beta.13, Pipeline 0.8.0-exp.1. Todos os comandos de Editor usaram `--caller plugin --skill unity-pipeline`. Nenhum commit foi criado.

| Verificação final | Resultado | Evidência |
|---|---|---|
| Compilação + polling de recompile_status | Completed; sem falha ou erros | [m02-compile.json](m02-compile.json) |
| EditMode, filtro Mmorpg.Tests | **19/19 passaram**; 0 falhas/skips | [m02-editmode.json](m02-editmode.json) |
| PlayMode, filtro Mmorpg.Tests | **12/12 passaram**; 0 falhas/skips | [m02-playmode.json](m02-playmode.json) |
| Reexecução da autoria | No-op; cena já estendida | `AddForestStory.Run` retornou `Forest story already authored; no changes` |
| Gameplay adicional pelas APIs reais | Três ataques: HP 60→40→20→0; técnica somente na derrota válida após rastros/Orin | [hit1](m02-gameplay-hit1.json), [hit2](m02-gameplay-hit2.json), [hit3](m02-gameplay-hit3.json) |
| Coleta, conversa/entrega e diário no Editor | 9 fatos, 1 técnica, A/B concluídas, confiança Mira=1/Orin=1 | [finish](m02-gameplay-finish.json), [diário](m02-journal.png) |
| Frames avançando em Play | 5056 no término do fluxo → 7515 na leitura posterior da mesma sessão | [finish](m02-gameplay-finish.json), [frame](m02-frame-final.json) |
| Inspeção visual | Cena, placeholders, texto dos rastros, diálogos e diário inspecionados em PNGs 1280×720 | [cena](m02-scene.png), [diário](m02-journal.png) |

Os **11 testes anteriores** continuam passando: cinco `CombatStateTests` e seis `OfflineSceneTests`. Foram adicionados **20 testes**: 14 `JourneyTests` e seis `JourneySceneTests`. Os JSONs registram o nome e resultado de cada teste.

EditMode cobriu: idempotência por eventId e encontro, IDs reservados de consequências, isolamento de cópias de memória, rotas A/B e segunda recompensa não duplicada, precondições, fonte/payload/versão inválidos, entrega única, conhecimento dos NPCs e interação repetida, resposta inválida da política, replay íntegro, save com evidência pendente, backup/temporário e corrupção, cooldown/alcance/expiração da técnica e bônus limitado/consumido somente no acerto.

PlayMode cobriu: fatos reais de combate (incluindo ataque errado sem fato), drop/coleta/entrega e restore da consequência de morte, rastros/Orin antes de combate, novo encontro após Mira com confiança e técnica única, Q pelo teclado e bônus em ataque confirmado, bloqueio por parede, E/Tab/N pelo teclado, nova jornada e rejeição espacial da interação. Os testes existentes ainda verificam movimento/colisão, ataque, esquiva, morte, restart com persistência isolada, parede/orientação, comportamento do lobo e Input System.

Na primeira execução, dois testes de persistência falharam devido à serialização dos payloads nulos por JsonUtility. O adaptador foi corrigido para Newtonsoft já instalado e as suites completas foram reexecutadas: 31/31 na versão final. Houve também um erro de ferramenta ao tentar capturar com `..` no caminho; o Pipeline o rejeitou. A captura válida foi feita no caminho permitido e movida para Docs. Um aviso transitório de `.meta` após mover a captura foi identificado e o metadata órfão removido. Nenhum desses registros foi tratado como erro de gameplay.

O console final durante execução mostrou **zero erros de runtime/compilação**, com um aviso de metadata de captura, registrado em [m02-console.json](m02-console.json). A primeira captura [m02-scene-initial.png](m02-scene-initial.png) levou à correção da escala da legenda dos rastros e da posição da dica do HUD; os PNGs finais acima mostram o ajuste. Não se afirma validação visual em outras resoluções/plataformas ou do multiplayer.

`ValidateForestPlay.Prepare` desativa controles/IA somente durante o ensaio e troca a persistência da sessão por memória usando reflexão de ferramenta de validação. Posiciona os atores, mas todos os fatos vêm de `RequestInteraction`/`RequestAttack`; não injeta eventos nem recompensas. A inspeção adicional não escreve no save do jogador. Os testes também usam stores isolados; os testes de disco usam diretórios temporários próprios.

O Editor foi deixado fora de Play. As regras do Marco 01 e os assets SampleScene foram preservados. Arquitetura, caminhos de teste, inventário de arquivos e limitações estão em [EventSystem](../EventSystem.md); o futuro contrato em [GoEventContract](../GoEventContract.md).
