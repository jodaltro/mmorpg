# Hospedeiro web e mobile — 24/10/2026

## Ambiente e estado encontrado

Branch main, pull --ff-only sem alterações remotas. Worktree já continha a implantação Cloudflare, API pública, exportador web e controles por toque ainda sem commit. Worker/R2 existentes; backend na 8096 e túnel ativos. Nenhum mundo foi reiniciado ou apagado.

## Executado

- Go: `go vet ./...` e `go test ./...` aprovados em engine. `gofmt -l .` executado: apontou 11 arquivos preexistentes fora do escopo (advisor/jev.go e dez testes de scenarios). Os quatro arquivos Go da implantação não apresentam pendência de gofmt.
- Godot headless: suíte completa com **257 testes, 0 falhas**, sem SCRIPT ERROR/ERROR na execução final dessa suíte. As primeiras execuções revelaram erro no teste novo de alvo e bindings de mouse persistentes entre cenários desktop/toque; corrigidos e reexecutados.
- Após ajustes adicionais de interface: suíte de toque com **19 testes, 0 falhas**, conferindo também ausência de erros de script. Inclui mira automática estável, mira relativa ao contato, soltura ao abrir janelas, menus, limites e separação de controles.
- Exportação Web release: concluída sem ERROR/SCRIPT ERROR. Compressão gzip/Brotli, preset e shell incluídos no repositório. O preset estava ignorado e foi recuperado para permitir reproduzir o build.
- Navegador local (Edge via Playwright, WebGL por software): **30 verificações aprovadas** em celular horizontal, vertical, tablet, desktop e API. Capturas inspecionadas; sobreposições de HUD corrigidas.
- Mock do publicador: republicar web preserva o binding ORIGIN existente.
- Cloudflare: publicação executada, health público 200 e SHA-256 de index.html/index.pck conferido contra o build local na primeira revisão publicada.

## Conexão inicial e revisão seguinte

As primeiras verificações HTTPS reais apresentaram chamadas iniciadas sem conclusão no prazo do teste. A renderização por software chegou a 1 FPS no desktop durante testes simultâneos; não foi possível atribuir todas as demoras exclusivamente ao transporte. O transporte web passou a usar fetch do navegador, AbortController e prazo por chamada (15 s na conexão inicial, 5 s em segundo plano). O cliente nativo mantém HTTPRequest. Diagnóstico do probe não inclui tokens ou credenciais.

A tela inicial aguarda a sessão e a aplicação da primeira visão (NPCs, missões, estado). Após 20 s oferece tentar novamente ou offline explicitamente, mantendo a observação de uma resposta tardia. Entrar offline por opção não exige API. Agir foi reduzido para raio lógico 23, fontes mobile menores e guia reposicionado acima dos polegares.

Após a revisão, os cinco cenários de carregamento passaram (offline explícito, espera pela API, aviso de demora, escolha offline e resposta inicial tardia). A suíte de toque voltou a passar com 19 testes e sem erros de script. Na repetição serial pública, **24 verificações de navegador** passaram: celular horizontal, rotação, tablet, desktop e menu de desenvolvimento. As **7 verificações da API pública** passaram em uma etapa separada. O runner inicialmente recebeu bloqueio Cloudflare 1010 para o User-Agent do urllib; o helper HTTP passou a usar requests e a etapa da API foi reexecutada com sucesso. Assim, os 31 checks foram executados nas duas etapas; não se declara um único encerramento verde do runner completo nessa repetição.

Também passaram os **5 testes de carregamento** com o transporte fetch, incluindo uma resposta inicial tardia após o aviso de timeout. Foram conferidos novamente os hashes SHA-256 públicos de index.html/index.pck e health 200 após o último deploy. Nenhum valor de credencial do env foi encontrado no diff staged. Nenhum teste de aparelho físico ou nova medição de latência/custo do Jev foi realizado nesta tarefa. O processo existente continua configurado com advisor jev; isso não equivale a uma medição ao vivo.

## Limites

Servidor ainda hospedado neste PC; Cloudflare publica o cliente e encaminha a API. Combate ainda local, sem cooperativo autoritativo; manifesto sem cache integral offline. Ver Docs/Hospedeiro/Online.md.
