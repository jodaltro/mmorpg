# Estabilidade do início — validação local — 25/10/2026

## Motor e preservação do mundo

- `go vet ./...` e `go test ./...` em `engine/`: aprovados. Dois cenários novos do universo real verificam confirmação de recebimento, propriedade/origem, espera além da expiração antiga, ausência de oferta substituta, viagem, conclusão depois de aceitar e replay.
- `gofmt -l engine`: somente os mesmos dez arquivos preexistentes; nenhum Go alterado nesta entrega listado.
- Uma cópia local do log atual, sem escrever no mundo real, foi reproduzida usando o código de `8360ecb2` e o código novo. Ambos: **691 comandos**, Digest `95e3456079b314458d64f5b72f4255f63faf1ff754b7e58f8f24542837f9c8b0`. Mesmo fingerprint de universo. A confirmação é um novo acontecimento no log, não uma interpretação retroativa de comandos antigos.

## Godot

- Importação headless aprovada.
- Suítes focadas finais: `net_responsiveness` **18**, `journey` **7**, `touch` **33**, `host` **13**, `tutorial` **11** testes; zero falhas e sem `SCRIPT ERROR`/linhas `ERROR` nesses logs.
- Incluem identidade vazia sem teletransporte, uma réplica fixa de treino por ID em snapshots sucessivos, ausência de população local fantasma em eventos online, trava de alvo, alvo destruído, troca para mira manual e retorno, oferta confirmada, falha de resposta sem esconder missão e trilha sob notificação de gene.
- A primeira execução completa encontrou um acesso a alvo já liberado, apesar de zero falhas contadas pelo runner. Não foi considerada aprovada. A guarda foi corrigida antes de passar o alvo ao parâmetro tipado, e o teste de toque passou a destruir o alvo para cobrir a regressão.
- `tools/build_web.py`: exportação e geração Brotli/gzip concluídas com sucesso. Logs externos em `D:/unity/hospedeiro-run/onboarding-*.log`.
- Rodada completa final: **359 testes, zero falhas, sem `SCRIPT ERROR` ou linhas `ERROR`**. Os 14 arquivos Brotli/gzip da nova exportação foram descomprimidos e comparados aos originais localmente: todos iguais.

Validação exclusivamente local; não houve partidas sintéticas, testes de carga ou requisições de teste ao endereço publicado.

## Implantação

Depois das aprovações locais, o supervisor foi reiniciado com `worldsim-onboarding.exe`, sem `-Fresh`, mantendo o diretório de dados, o universo, a chave de sessão, o banco Nakama e o túnel. O motor iniciou por replay no tick **570**, com advisor Jev e modo público; o fingerprint permaneceu `c7dcd8a48d9676ffccef799a084925fa1308a4d0d522f0ed01139e32583faf17`. A cópia padrão `worldsim-nakama-v2.exe` foi atualizada para impedir que uma inicialização futura retome o executável anterior aos novos comandos.

O Godot de autoridade foi reiniciado pelo supervisor existente e confirmou conexão ao Nakama nos logs locais, sem erros de inicialização. `deploy_online.py web` concluiu com código zero e confirmou publicação dos arquivos e Worker em `https://hospedeiro.memowhats.workers.dev`, preservando a origem do túnel. Não houve reset de mundo, alteração de banco ou teste no serviço publicado.
