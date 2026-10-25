# Inimigos sem espinhos e masmorras automáticas — 25/10/2026

## Mudanças

- Auditoria dos caminhos de criação: inimigos do mundo, ninhos, atiradores, chefes e salas de masmorra usam `spawn_virus`/`spawn_enemy`, que habilitam o desgaste independentemente da quantidade de espinhos. NPCs decorativos, aliados e alvos de treino conservam suas apresentações próprias.
- Fissuras aparecem desde os primeiros danos. Membranas apresentam reentrâncias progressivas; modelos sem espinhos desprendem gotas arredondadas. Contração, recuperação com cura e pulso crítico continuam comuns aos inimigos, sem mudar hitbox/HP nem enviar novos pacotes.
- Aproximar-se de portal liberado envia entrada automaticamente. Estado `ready` envia `iniciar-masmorra` uma vez, sem confirmação. A trava por aproximação impede reentrada ao retornar; afastar-se permite nova tentativa. Consulta dos prêmios pelo atlas e resgate por escolha após vitória permanecem. Falha real mostra mensagem e botão de nova tentativa.
- Requisitos do universo e validação da autoridade preservados; não há migração de mundo ou alteração no core.

## Executado apenas localmente

- Importação Godot: sem erros de script.
- `run_tests.gd -- dungeon_rewards`: **8 testes, 0 falhas**, após corrigir o posicionamento de uma asserção no teste novo de falha/retry. Verifica entrada por aproximação, início automático único, prevenção de reentrada, portal distante/bloqueado, resgate e tentativa após falha sem flood.
- `run_tests.gd -- dungeon`: **20 testes, 0 falhas**, executado antes da adição do teste de retry; cobre preparação, combate, recompensas e masmorra do fígado.
- `run_tests.gd -- combat_feedback`: **7 testes, 0 falhas**, incluindo quatro modelos sem espinhos (linfócito, macrófago, hepatócito e gota de gordura), partículas, integridade e contração.
- `run_tests.gd -- host`: **13 testes, 0 falhas**. Todas as saídas inspecionadas também por `SCRIPT ERROR`/`ERROR`.
- `go -C engine vet ./...` e `go -C engine test ./...`: aprovados, testes em cache. `gofmt -l engine` executado: dez arquivos preexistentes de advisor/scenarios fora de formato, sem mudanças nesta entrega.
- Exportação final web: concluída sem erros.
- `test_combat_visual_web.py --smooth`: aprovado no Edge com touch; confirma HP 100/55/15, contração ordenada e pontas dirigidas aos contatos. A fixture foi corrigida para contar os modelos lisos no grupo de inimigos de mundo; a primeira tentativa usava o grupo de masmorra e não era encontrada pelo probe. Captura `build/combat-smooth-wounded.png` inspecionada visualmente.
- `test_dungeon_auto_web.py`: aprovado com WASM real, desbloqueio por feitos em journal isolado, aproximação ao Granuloma e passagem até `active` sem E/Agir, botão de entrada ou botão de início. Captura `build/dungeon-auto-entry.png` inspecionada: sala carregada e contagem de preparação, sem confirmação. Teste repetido após o ajuste que unifica a entrada manual na mesma trava de aproximação.

Browsers acessaram somente HTTP loopback e fixture Nakama/storage em memória. Nenhum teste contra servidor publicado, banco real ou Jev ao vivo; nenhum reset de mundo. Capturas de QA não versionadas.
