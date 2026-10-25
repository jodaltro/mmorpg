# Progressão, recompensas e transformações — 25/10/2026

## Implementação

- Pressão por mutação 30 → 120; maturidade das diferenciações 42/120 → 168/480. Acessos a masmorras seguem a escala.
- 18 genes com transformações de ações, incluindo um gene de prova para cada uma das dez classes.
- Genes permanentes na biblioteca como recompensa de 13 missões e cinco masmorras; aquisição idempotente, privada e reproduzível por replay.
- Provas de classe contam os feitos após a diferenciação, evitando a perda da elegibilidade antes de alcançar a classe.
- Ofertas abrem inspeção/comparação antes de expressar. Habilidades mostram valores modificados e genes ativos; trocas mostram o efeito ganho/perdido.

## Verificações realmente executadas

Todas as verificações foram locais, sem testes contra o jogo publicado, Supabase ou Jev ao vivo.

- `go vet ./...` e `go test ./...`, em `engine/`: aprovados. Os quatro cenários novos também passaram sobre a definição final: recompensa da primeira travessia e replay com mesmo Digest, privacidade, idempotência, recusa de aquisição por origem não autorizada, compilação de referência inválida, cadência, recompensa nas masmorras e contadores das provas.
- `gofmt -l engine`: apenas os dez arquivos previamente fora do formato (`advisor/jev.go` e nove testes antigos de cenários). Os Go alterados/criados foram formatados.
- `worldsim validate universes/hospedeiro/universe.json`: `ok`.
- `worldsim simulate -universe universes/hospedeiro/universe.json -ticks 180 -players 3 -advisor deterministic`: concluído, 13 acontecimentos do diretor, decisões de mutação e diferenciação. Digest final `9d08b3f6efbf325baa224b36f816c22755abf652ea9e83b7aebb49d935cb84d8`. Os cenários Go de história também passaram; a simulação genérica não pretende concluir todos os arcos.
- Importação Godot 4.7.2 headless: aprovada, sem erros de script.
- Suíte completa Godot: **347 testes, zero falhas**, sem `SCRIPT ERROR`/`ERROR`.
- Depois dos últimos ajustes de inspeção, prévia e limpeza do reset: `run_tests.gd -- progression`, **10 testes, zero falhas**, sem erros de script. Cobre cada classe, genes de outra classe, pagamento/recarga, projéteis extras, dano/lentidão das poças, limite da corrente, antecipação sem gameplay, ecos gratuitos sem multiplicar efeitos, atraso/cancelamento da ruptura, cura sem beneficiar inimigos, aviso de recompensa, comparação sem consumir oferta e reset de fixture local.
- `run_tests.gd -- body_panel`: **19 testes, zero falhas**, sem erros de script; `-- genome`: **20 testes, zero falhas**.
- Revisão visual nativa touch: combate/poça ácida e habilidade modificada em 844×390; ofertas e comparação em 667×375. Capturas em `D:/unity/hospedeiro-web-qa/progression-*.png`; logs em `D:/unity/hospedeiro-run/progression-*.log`.
- Exportação Web release concluída sem erros de script. Binário Go preparado em `D:/unity/hospedeiro-run/worldsim-progression.exe`.
- Verificação local do fingerprint: `universe-before-progression.json` corresponde ao cabeçalho do log do mundo em execução.

## Ativação

O mundo compartilhado foi preservado. Seu Go, Nakama, Godot, banco e túnel não foram reiniciados. Só o processo supervisor foi substituído, reutilizando o servidor e o túnel, para fixar a definição anterior e impedir um reset automático por mudança de universo. Supervisor registrado em `D:/unity/hospedeiro-run/supervisor.pid`, log `supervisor-progression.log`; definição fixada em `D:/unity/hospedeiro-run/universe-before-progression.json`.

A versão nova está preparada; arquivar o mundo salvo e ativar a definição nova foi submetido ao usuário, sem executar o reset. Os artefatos web desta revisão não foram publicados enquanto essa decisão está pendente. A revisão não promete balanceamento econômico final nem uma duração em minutos: não houve sessão de jogadores medida para esses valores.
