# Editor de habilidades e builds — 24/10/2026

Partida: main em 0045f194, worktree limpa, pull --ff-only executado.

## Implementado

- Quatro espaços compactos de habilidades; inspeção curta de uma habilidade por vez e explicação longa opcional.
- Toque/clique apenas inspeciona. Arrasto de mouse, toque mantido por 350 ms e ação explícita Trocar posição reorganizam a barra.
- Movimento antes da espera preserva o gesto de rolagem. Mouse emulado não inicia drag-and-drop no mobile; soltar fora ou fechar cancela a troca.
- Presets compactos, um selecionado por vez, renomeação explícita, confirmação para sobrescrever e comparação dos genes antes de aplicar.
- Ordem do preset editável por arrasto na prévia, salva localmente sem equipar a build. Aplicar continua explícito e validado pelo motor.
- Salvar aqui captura a barra atual; esse snapshot e a aplicação da ordem só são confirmados localmente após sucesso HTTP. Falha preserva a ordem anterior; envio pendente impede duplo pedido.
- Atualizações em background preservam o nome em edição e a habilidade sendo arrastada. Janelas de habilidades/builds menores em telas altas.

## Executado localmente

- Godot: **18 testes body_panel**, **30 touch** e **30 new_classes**, todos sem falhas e sem SCRIPT ERROR/ERROR nos logs finais. Incluem drop conectado à prévia do preset, inspeção sem equipar, falha/sucesso HTTP simulados, clique duplicado, foco e cancelamento.
- Edge/Playwright contra localhost: **10 verificações mobile** de inspeção, texto opcional, arrasto, cancelamento, swipe e presets; **8 desktop** de mouse e edição; **10 de escala** (75–125%, quatro abas e persistência); **9 dos menus** (rolagem de detalhes e fechamento). Sem erros de console nas verificações concluídas. Capturas locais inspecionadas em D:/unity/hospedeiro-web-qa/loadout*.
- Exportação Web release e gzip/Brotli concluídos, sem erros no log final.
- Go: go vet ./... e go test ./... aprovados. gofmt -l . executado: 11 pendências preexistentes em advisor/jev.go e dez testes scenarios, sem arquivos Go alterados.

Por orientação do usuário, não executar testes contra o endereço público ou o servidor online. Não houve testes online nesta tarefa. Validação em aparelhos físicos não executada. Referências de ESO e Guild Wars 2 registradas em Docs/Hospedeiro/MobileUX.md.
