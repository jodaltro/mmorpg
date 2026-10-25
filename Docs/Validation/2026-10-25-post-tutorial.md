# Orientação após o tutorial — 25/10/2026

Mudança de apresentação no cliente: próximo passo, trilha pelos vasos, atlas com locais selecionáveis e explicação das masmorras. Nenhuma alteração de universo, contrato HTTP, banco ou regras do motor.

Validações executadas somente localmente:

- Importação Godot 4.7.2 headless: sem erros de script.
- `run_tests.gd -- journey`: 6 testes passaram, sem `SCRIPT ERROR`/`ERROR`. Cobre transição do tutorial, supressão por menus/morte/instância, passagens fechadas, prioridade das missões reais, ausência de destino inventado para missão dinâmica, lista de masmorras, marcação/chegada e contadores confirmados do primeiro combate/coleta.
- `run_tests.gd -- tutorial`: 11 testes passaram, sem erros de script.
- Suíte completa `run_tests.gd`: 339 testes passaram, sem `SCRIPT ERROR`/`ERROR`. Depois dos ajustes finais de alvo de combate e proteção do clique no cartão, os seis testes de orientação passaram novamente; as últimas alterações do teste de morte usam o estado inativo real da apresentação.
- Revisão visual nativa com controles touch e janela 844×390: cartão compacto, detalhes do próximo passo, atlas ampliado na área conhecida e lista de locais com botões grandes. Capturas locais em `D:/unity/hospedeiro-web-qa/journey-*.png`; logs em `D:/unity/hospedeiro-run/journey-*.log`.
- Exportação Web release concluída sem erros de script.
- Publicação dos nove arquivos HTML/JS/PCK (originais, gzip e Brotli) no bucket web concluída. Isso foi envio de artefatos; nenhum teste remoto foi executado. Serviços de jogo, banco e túnel permaneceram em execução sem reinício.
- Em `engine/`: `go vet ./...` e `go test ./...` aprovados (resultados dos testes em cache). `gofmt -l .` ainda lista os dez arquivos previamente fora do formato: `advisor/jev.go` e nove testes em `scenarios/`; nenhum Go foi alterado nesta tarefa.
- `git diff --check` aprovado.

Não foram executados testes no servidor publicado nem em serviços externos. A orientação não aceita chamados automaticamente, não altera disponibilidade das entradas e não concede recompensas.
