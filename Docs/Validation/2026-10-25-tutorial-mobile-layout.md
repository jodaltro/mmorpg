# Tutorial mobile: painel alto e retomada fora da Medula — 25/10/2026

O cartão usava a altura mínima dos textos sem limite de viewport; essa medida pode refletir uma largura anterior durante reflow. O ramo que aguardava retorno ao refúgio saía antes de atualizar o layout, preservando dimensões inadequadas. O cartão também começava sob o botão Mundo / amigos.

Correção: conteúdo em rolagem interna, altura limitada a 58% da tela, rodapé fixo fora da rolagem, atualização também durante espera e margem superior para o botão de amigos. Fora da Medula, **Ver caminho** fixa o destino no GPS e pausa o tutorial na etapa atual. O exercício de movimento começa a medir dentro do refúgio, sem contar o deslocamento feito fora dele. Nenhum teleporte ou mudança na autoridade de combate.

## Executado apenas localmente

- Importação Godot sem erros de script.
- `run_tests.gd -- tutorial`: **13 testes, 0 falhas**, sem `SCRIPT ERROR`/`ERROR`. Inclui texto excessivo/altura anterior de 1500 unidades, rodapé visível, controles liberados, rota para o refúgio e etapa preservada, além dos testes de prática, persistência e spotlight.
- `go -C engine vet ./...` e `go -C engine test ./...`: aprovados, testes em cache. `gofmt -l engine` executado: os mesmos dez arquivos preexistentes de advisor/scenarios fora de formato, sem alterações nesta entrega.
- Exportação web concluída.
- `test_tutorial_layout_web.py`: aprovado com Edge headless, touch e WASM real; somente HTTP loopback e fixture de storage em memória, com requisições externas bloqueadas. Cinco combinações de viewport/escala: 1280×576/1, 640×360/1,25, 360×780/1,25, 780×360/0,75 e retorno a 1280×576/1. Verificou limites do cartão e rodapé, toque real em Ver caminho, GPS ativo e etapa 2/12 preservada.
- Capturas `build/tutorial-waiting-fit.png` e `build/tutorial-return-gps.png` inspecionadas visualmente: cartão compacto abaixo de Mundo / amigos e rota para a Medula após a pausa. Capturas não versionadas.

Nenhum teste em servidor publicado, banco real ou Jev ao vivo. O anexo enviado pelo usuário foi preservado fora do commit.
