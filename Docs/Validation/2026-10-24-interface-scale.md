# Escala da interface mobile — 24/10/2026

- Main atualizada via pull --ff-only, começando em 7cf2b4ce, sem mudanças locais anteriores.
- Ajuste no menu de 75% a 125%, em passos de 5%, aplicado ao soltar a barra. Restaurar 100% e preferência persistida (localStorage no navegador, configuração local no cliente nativo).
- Escala de toda a interface via viewport lógico; zoom da câmera compensado para preservar o campo de visão. Controles se reorganizam no espaço disponível e o alvo de cancelar mira permanece separado das habilidades.
- Janela Corpo usa colunas verticais em telas lógicas estreitas e abas menores para caber quando a interface é ampliada.

## Executado

- Godot headless: **24 testes touch, 0 falhas**, sem SCRIPT ERROR/ERROR. Inclui persistência em arquivo isolado, limites e controles nas escalas 75/100/125%, ausência de colisão do alvo de cancelar e campo de visão preservado.
- Godot headless: **11 testes body_panel, 0 falhas**, sem SCRIPT ERROR/ERROR.
- Exportação Web release e compressão gzip/Brotli concluídas, log conferido para erros.
- Edge/Playwright local: **5 verificações**, aprovando aumento, redução, restauração, persistência após reload e ausência de erros de console; capturas da maior e menor interface inspecionadas.
- Go: `go vet ./...` e `go test ./...` aprovados. `gofmt -l .` executado; permanecem as mesmas 11 pendências preexistentes fora do escopo, em advisor/jev.go e dez testes scenarios. Nenhum arquivo Go alterado.

Publicação concluída no R2, preservando Worker, túnel e mundo. Edge/Playwright no endereço público: **6 verificações aprovadas**, incluindo janela Corpo dentro da tela em 125% no celular 667x375 e preferência preservada após recarregar. Capturas públicas inspecionadas. Hashes SHA-256 de index.pck/index.html iguais ao build local; health 200/ok. Sem testes em aparelhos físicos nesta tarefa.
