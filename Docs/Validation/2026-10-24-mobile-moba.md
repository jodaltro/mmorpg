# HUD mobile inspirado em Wild Rift — 24/10/2026

Referências, decisões e limites: `Docs/Hospedeiro/MobileUX.md`.

## Executado

- `git pull --ff-only origin main`: atualizado, worktree inicialmente limpo em cf7ee260.
- Godot 4.7.2 headless, suíte touch: **22 testes, 0 falhas**, sem SCRIPT ERROR/ERROR na execução final. Cobriu layout em 747x420, 909x420, 1024x768 e outras proporções, centro livre, não sobreposição, mira assistida, captura de dedos, cast apenas ao soltar, cancelamento e abertura do atlas pelo minimapa.
- Exportação Web release concluída; log conferido para ERROR/SCRIPT ERROR. Arquivos comprimidos em gzip/Brotli.
- Browser local Edge/Playwright: **14 verificações** da parte de celular da suíte online passaram (movimento, dois polegares, ataque, menus e habilidades), sem erros de console.
- Novo teste de combate mobile local: **9 verificações** passaram, cobrindo segurar sem disparar, cancelar, disparar ao soltar, ícones distintos no macrófago e ausência de erros de console em 844x390, 667x375 e tablet 1024x768. Capturas de combate, mira e cancelamento inspecionadas.
- `go vet ./...` e `go test ./...` aprovados em engine. `gofmt -l .` executado; as mesmas 11 pendências preexistentes fora desta alteração permanecem (advisor/jev.go e dez arquivos de testes scenarios). Nenhum arquivo Go foi alterado.

## Publicação

Atualização dos assets no R2 do projeto Hospedeiro, preservando Worker, túnel, dados e servidor com Jev. Não foram apagados mundos nem alteradas regras de universo.

A repetição do novo teste contra o endereço público passou com **9 verificações**, nos mesmos três tamanhos de tela. SHA-256 de index.pck e index.html públicos iguais ao build local; health do mundo 200/ok. Captura pública em `mobile-moba/phone.png`. Não foi feito teste em aparelho físico nesta tarefa. A comparação visual não certifica ergonomia em todas as mãos; editor de posição/tamanho/opacity e avaliação física permanecem próximos refinamentos.
