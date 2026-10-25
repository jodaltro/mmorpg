# Desgaste dos inimigos e mira dos chicotes — 25/10/2026

Mudanças descritas em [CombatPresentation.md](../Hospedeiro/CombatPresentation.md). Sem alteração do core Go, do universo ou das recompensas.

## Validação executada — apenas local

- Godot headless `--import`: concluído sem erros.
- `run_tests.gd -- lash_targets`: **4 testes, 0 falhas**. Três chicotes divididos entre dois contatos, convergência em um só contato, alvo fora do cone excluído, cauda como primeira ponta, prioridade de alcance no automático, mira manual e dano aplicado uma única vez.
- `run_tests.gd -- combat_feedback`: **6 testes, 0 falhas**. Interpolação da integridade, perda de espinhos, fragmentos limitados/temporários, cura, primeira aparição ferida, repetição de snapshots, HP e hitbox preservados.
- A primeira execução isolada de `touch` encontrou um erro de inferência de tipo na nova variável de alcance; corrigido com tipo `float` explícito. Não foi considerada aprovada.
- Runner completo após essa correção: **381 testes, 0 falhas**, sem `SCRIPT ERROR`/`ERROR`. Durante a execução houve um ajuste visual nas raízes dos chicotes; o conjunto `lash_targets` foi executado novamente depois desse ajuste: **4 testes, 0 falhas**.
- `go -C engine vet ./...` e `go -C engine test ./...`: aprovados, com resultados de teste em cache. `gofmt -l engine` executado: os dez arquivos preexistentes de advisor/scenarios fora de formato continuam inalterados.
- Exportação web final por `build_web.py`: concluída.
- `test_combat_visual_web.py`: Edge headless com touch, WASM real, HTTP loopback e Nakama/storage em memória. Requisições externas bloqueadas. Aprovou HP real 100/55/15 com tamanhos visuais ordenados e três pontas apontadas para dois contatos, sem erros de script. A fixture espera a física indexar seus alvos após teleportá-los; a primeira tentativa sem essa espera foi corrigida.
- Capturas finais `build/combat-wounded.png` e `build/combat-targeted-lash.png` inspecionadas: diferença de espinhos e silhueta legível, fissuras/fragmentos presentes e apêndices dirigidos aos contatos. Imagens de QA não versionadas.

Nenhum teste no servidor publicado, banco real ou Jev ao vivo. Nenhum reset de mundo.
