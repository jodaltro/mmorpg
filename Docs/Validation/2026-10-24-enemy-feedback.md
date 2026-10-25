# Feedback visual dos inimigos

## Alteração

Inimigos mostram impacto com brilho breve, onda na membrana e recuo elástico apenas visual. Ataques possuem deformação com preparação, impulso e recuperação, arco discreto na direção do golpe e recuo de disparo. A preparação vermelha existente agora é suavizada. O golpe do bacilo também dispara o gesto. Nenhuma posição lógica, hitbox, dano, custo, alcance ou tempo de ataque foi alterado.

O online antes atualizava os vitais sem reproduzir os sinais locais de dano/ataque dos inimigos. Snapshots agora incluem um estado visual compacto com contadores cumulativos de impactos e ataques, preparação e direção. O cliente reproduz apenas novos sinais, inclusive depois de descartar snapshots intermediários; a primeira aparição não repete golpes antigos. Não há simulação de dano no cliente.

## Validação local executada

- Import Godot: sem erros de script.
- `run_tests.gd -- combat_feedback`: 3 testes, 0 falhas, execução final sem erros; impacto confirmado, repetição/idempotência, primeira aparição e direção do ataque após snapshots descartados.
- `run_tests.gd -- network_server`: 6 testes, 0 falhas, sem erros; inclui ataque real do inimigo, dano confirmado, reprodução visual e preservação dos vitais ao reproduzir a animação.
- Prévia gráfica local com três corpos (repouso, impacto, ataque), renderizada e inspecionada. A primeira execução revelou desenho de arcos fora de `_draw`; corrigido e renderizado novamente sem erros. Captura externa ao Git: `D:/unity/hospedeiro-web-qa/combat-feedback.png`.
- Export Web final com caminho absoluto: concluído sem erros. Uma tentativa anterior com caminho relativo ao diretório `engine` foi rejeitada e não foi usada.
- `go vet ./...` e `go test ./...`: aprovados, cache local, sem Jev ao vivo. Go não foi alterado. `gofmt -l .` executado e voltou a listar os mesmos 11 arquivos preexistentes fora do escopo; não se declara formatação global aprovada.

Cliente publicado no R2 existente, nove arquivos HTML/JS/PCK e compressões. Mantida a origem local, sem contratar hospedagem. Apenas Godot headless reiniciado pelo supervisor para carregar o código; Nakama, banco e processo Go mantidos. Nenhum reset do mundo e nenhum teste contra o endpoint publicado ou banco remoto.
