# Genes, missões e reset de teste — 24/10/2026

Partida: main em ab29e5ac, limpa, pull --ff-only realizado.

- Genes: fichas compactas, contador de espaços livres, descrição selecionada e comparação sob demanda; ofertas com resumo curto.
- Missões: toque das fichas corrigido, entrada própria no menu, objetivo ativo e chamado pendente no diário; sem fichas interceptadas por um fundo sobreposto. Atualizações preservam a captura de input.
- Reset: confirmação de mundo compartilhado, capacidade de sessão, flag temporária -test-reset, autenticação e confirmação no endpoint existente. Limpa progresso local, builds e masmorra após sucesso; outros clientes conectados se recuperam ao observar unknown_observer.

## Executado apenas localmente

- Godot touch: **32 testes, 0 falhas**, sem SCRIPT ERROR/ERROR no log final. Inclui toque real no sinal de missão, abertura/fechamento do diário, atualização do objetivo, preservação do input, cancelamento e permissão do reset.
- Godot body_panel: **19 testes, 0 falhas**, sem SCRIPT ERROR/ERROR. Inclui genes compactos, comparação e os fluxos existentes de build.
- Godot abilities/redone_abilities: **32 testes, 0 falhas**, sem SCRIPT ERROR/ERROR. Inclui reinício do mundo offline e regressão de habilidades.
- Edge/Playwright offline em localhost: **6 verificações aprovadas**, sem erros de console: acesso às missões pelo menu, confirmação/cancelamento do reset, genes vazios compactos e comparação sob demanda. Capturas locais inspecionadas em D:/unity/hospedeiro-web-qa/genes-missions.
- Go: go vet ./... e go test ./... aprovados. Novo httptest verifica reset temporário autenticado, recusa sem confirmação e preservação do mundo em recusas. gofmt -l .: as mesmas 11 pendências anteriores em advisor/jev.go e dez testes scenarios; arquivos Go alterados formatados.
- Supervisor PowerShell validado pelo parser, sem erros de sintaxe. Exportação Web release e compressões gzip/Brotli concluídas.

Publicação no R2 e reinício do processo local do servidor com -test-reset, reaproveitando o túnel e os dados existentes. Como o executável antigo também é usado pelo ambiente local de QA, a versão atual do servidor roda separada em hospedeiro-run/worldsim-current.exe. Porta 8096 e flag conferidas no processo local. Nenhum teste no endereço online e nenhum reset do mundo real executados. Sem avaliação em aparelho físico nesta tarefa.
