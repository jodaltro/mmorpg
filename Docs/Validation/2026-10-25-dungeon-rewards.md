# Validação local — masmorras e recompensas — 25/10/2026

## Motor

- `go vet ./...` e `go test ./...` em `engine/`: aprovados após a alteração final. Os cinco cenários novos cobrem estabilidade do sorteio, preparação, autoridade, resgate único, replay, elegibilidade, descrições derivadas dos efeitos e entrega automática para entradas antigas.
- `gofmt -l engine`: nenhum arquivo alterado nesta entrega listado. Permanecem dez arquivos preexistentes: advisor/jev.go e scenarios/{acquaintance,appearance,exploration_live,hospedeiro_live,hospedeiro,lineage,live_jev,liver,nearness}_test.go.
- Binário local recompilado: `D:/unity/hospedeiro-run/worldsim-dungeon-rewards.exe`.
- `worldsim validate universes/hospedeiro/universe.json`: `ok`.
- `worldsim simulate -universe universes/hospedeiro/universe.json -ticks 180 -players 3`: concluído com advisor determinístico, sem serviços externos. Digest final: `7b642650a0d714abaab31ddc106bcba8fab7c84c9f6d1a190f9d4d8a811d722b`.

## Cliente e autoridade Godot 4.7.2

- Importação headless aprovada.
- Runner completo: **354 testes, zero falhas**, sem `SCRIPT ERROR` ou linhas `ERROR`. Essa execução antecede o último teste adicional de isolamento da sala segura e os ajustes finais de textos.
- Runner final `-- dungeon_rewards`: **5 testes, zero falhas**, sem erros de script. Inclui prêmio compreensível, botão fora da rolagem, entrada por proximidade, sala segura sem inimigos/dano/conclusão automática, reabertura e resgate depois da vitória, genes já possuídos e esgotamento explícito.
- Runner final `-- network_server`: **11 testes, zero falhas**, sem erros de script. Inclui isolamento físico da preparação e bloqueio de habilidades antes de gastar ATP, transição para a primeira sala e retorno à posição original.
- Exportação `--headless --path clients/hospedeiro --export-release Web D:/unity/Mmorpg/build/web/index.html`: concluída, código zero e sem erros.

## Inspeção visual

Um fixture externo gerou as visões de entrada e preparação usando o universo real e intenções no motor local. O cliente foi aberto sem backend, com essas visões injetadas, toque forçado e sem vírus. Capturas inspecionadas em 844×390 (entrada e preparação) e 667×375 (vitória): texto funcional dos genes, rolagem, confirmação fixa e escolha de prêmio legíveis. O estado de vitória visual foi derivado do fixture; a conclusão e a autoridade do resgate foram verificadas separadamente nos testes acima.

Artefatos externos: `D:/unity/hospedeiro-web-qa/loot-{entry,ready,claim}.png`. Logs locais em `D:/unity/hospedeiro-run/loot-*.log`. Não constituem teste em aparelho físico nem sessão de jogo publicada.

## Ativação

Nenhum teste online, publicação, migração de banco, reset ou reinício dos serviços reais foi executado. O mundo atual continua com o universo anterior preservado pelo supervisor. A nova progressão e as recompensas procedurais estão preparadas no código e no build local; a ativação depende da decisão pendente sobre arquivar o mundo anterior e iniciar o novo universo.
