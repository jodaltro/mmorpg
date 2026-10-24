# Menus mobile — 24/10/2026

Partida: main em cdcbf528, worktree limpa, pull --ff-only executado antes das alterações.

## Alterações

- Gaveta de navegação compacta, que fecha após escolher um destino ou tocar fora.
- BioModal compartilhado por Corpo, Códice, Sinais, Atlas, ações e chamados mobile, com fundo, botão Fechar e limite proporcional à tela.
- Apenas uma janela aberta por vez. A navegação não cobre o botão Fechar; movimento e ataque ficam suspensos durante a interação.
- Corpo com abas laterais, cabeçalho fixo e conteúdo rolável; colunas e grades respondem à largura disponível, inclusive em 125%.
- Fichas de genes, habilidades e builds selecionadas ao soltar, com tolerância de movimento; arrastar não seleciona nem troca habilidades.
- Códice e Sinais reconstruídos com controles e ScrollContainer. Atualizações de sinais não recriam a lista nem interrompem a rolagem.
- Chamados e ações em listas roláveis. Escolher uma ação fecha o menu; dispensar um chamado pelo fundo mantém a oferta disponível.
- Remoção de keycaps/atalhos nas telas de toque, inclusive avisos de portal e renascimento. Atlas com marcadores e legenda.

## Verificações executadas

- Godot headless: **266 testes, 0 falhas**, sem SCRIPT ERROR/ERROR na execução completa.
- Após os ajustes finais de largura: **28 testes touch e 11 body_panel, 0 falhas**, sem SCRIPT ERROR/ERROR.
- Exportação Web release, gzip e Brotli concluídos; log de exportação conferido sem erros.
- Edge/Playwright: **9 verificações dos menus**, tanto localmente como no endereço público: seleção fecha a navegação, Corpo/Códice/Sinais rolam pelo dedo, arrastar não seleciona habilidade, toque fora fecha janelas/atlas/navegação, ausência de erros de console.
- Edge/Playwright local: **10 verificações de escala**, incluindo as quatro abas do Corpo dentro da tela 667×375 em 125%, botão Fechar por toque, persistência após reload, redução e restauração.
- Edge/Playwright público: **10 verificações de escala**, repetindo o ajuste, as quatro abas em 125%, fechamento por toque e persistência.
- Edge/Playwright integração local: **31 verificações aprovadas**, cobrindo celular, orientação vertical, tablet, teclado/mouse no desktop, separação do menu de desenvolvimento e contratos de sessão da API.
- Edge/Playwright combate público: **9 verificações aprovadas**, incluindo preparar/soltar/cancelar habilidade, ícones distintos, celular menor e tablet, sem erros de console.
- Go: go vet ./... e go test ./... aprovados. gofmt -l . executado: as mesmas 11 pendências preexistentes em advisor/jev.go e dez arquivos de testes scenarios; nenhum arquivo Go alterado.

Publicação atualizada no R2, preservando Worker, túnel e mundo. SHA-256 público de index.html e index.pck igual ao build local; backend público com health HTTP 200. Capturas em D:/unity/hospedeiro-web-qa/menus* inspecionadas. Os testes de navegador usam toque emulado no Edge; aparelhos físicos não foram testados nesta tarefa.
