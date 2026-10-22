# Validação — Hospedeiro (cliente Godot, modo offline)

Só testes realmente executados. Godot 4.7.2 (`D:\tools\godot\bin\Godot_v4.7.2-stable_win64_console.exe`), Windows 10, AMD RX 5700 XT (Vulkan, Forward+).

## H0 — protótipo trazido para `clients/hospedeiro/` (22/10/2026)

Import limpo (`--headless --import`, sem cache `.godot/`) e runner headless:

```bash
G="/d/tools/godot/bin/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path clients/hospedeiro --import
"$G" --headless --path clients/hospedeiro --script res://tests/run_tests.gd
```

Resultado: **31 testes, 0 falhas**, sem `SCRIPT ERROR` nem `ERROR` na saída do import ou do runner.

| Suíte | Testes | Cobre |
|---|---|---|
| `test_domain.gd` | 8 | ATP, membrana, recarga, dano vindo do catálogo, i-frames do impulso, nutrientes, morte |
| `test_genome.gd` | 12 | Genes com benefício e custo, espaços, ataques moldados pelo genoma sem alterar o catálogo, pressão evolutiva, oferta única, recusa sem repetição imediata, semente determinística, salvar e carregar |
| `test_world.gd` | 11 | Mundo sobe e os frames avançam; chicote de cauda (acerto pela frente, não por trás, recarga, varredura da cauda); projétil de toxina; nutriente; vírus telegrafa e acerta; morte e renascimento; impulso; oferta de mutação aplicada à célula; genoma persiste entre sessões |

Validação visual anterior (mesmo código, no protótipo antes da mudança de pasta): `tests/capture.gd` com renderer real gerou screenshots conferidos à mão (corpo com cauda numa silhueta única, golpe de cauda, vírus telegrafando, painel de mutação). Não repetida após a mudança de pasta.

### Motor Go no mesmo commit

`go test ./...` em `engine/` (Go 1.27.2): `advisor`, `api` e `sim` passam. **`scenarios` falha em `TestClientPresentationMatchesTheUniverse`**, porque `clients/godot/data/presentation.json` não está versionado: a regra `data/` do `.gitignore` o ignora. A falha já existe na `origin/main` (61426263) e não tem relação com o Hospedeiro, que não altera o motor.

### Não testado

- Gamepad real e sessão longa de jogo interativo.
- Conexão com o motor (não existe ainda; marco H1).

## H1 — universo no motor e cliente conectado (22/10/2026)

**Motor (Go 1.27.2):**

- `worldsim validate ../universes/hospedeiro/universe.json`: ok.
- `worldsim simulate -ticks 240 -players 3 -advisor deterministic`: o corpo alterna surto, resposta imune, cura e novo surto; refeição, sono e febre acontecem; o cenário único foi reivindicado e o capítulo compartilhado concluído; genes descobertos por hábito; boatos correram.
- `go test ./scenarios -run Hospedeiro`: 4 testes passam (primeiro feito antes da oferta e mergulho; contar à Dendra arma a defesa; autorregulação sem jogadores; cenário único).
- `go test ./...`: tudo passa, exceto `TestClientPresentationMatchesTheUniverse`, a falha anterior descrita no H0.

**Cliente (Godot 4.7.2):** 38 testes headless, 0 falhas, sem `SCRIPT ERROR`. Os 7 novos (`test_host.gd`) cobrem modo offline, troca de região, chamado e células NPC, febre pelas crenças, eventos que só reagem quando novos e gene descoberto.

**Ponta a ponta com o motor real e o Jev ligado** (`worldsim serve ... -tick 500ms -advisor jev`, cliente com renderer real, `tests/e2e_engine.gd`): 7 passos ok, duas vezes (a segunda depois dos últimos ajustes de menu, feed e acentos):

1. Conecta e entra no mundo.
2. Um nutriente absorvido no combate é confirmado ao motor.
3. Osteia chama: oferta "O primeiro mergulho" na janela do Sistema.
4. Aceita.
5. Ao entrar no sangue, a missão é concluída.
6. Destruir um vírion ensina a assinatura dele.
7. O menu oferece "Contar a Dendra: como é o Vírion Espinhoso"; contado, Dendra arma a defesa (evento público).

Screenshots conferidos à mão: janela do Sistema, menu de ações, residentes (Osteia, Neva), estado "O HOSPEDEIRO DORME", oferta do cenário único.

**Não testado:** gamepad real; várias pessoas ao mesmo tempo no mesmo mundo; sessão longa com tick real de 4 s.

## Evolução guiada pelo Jev (22/10/2026)

**Motor:** decisão nova `evolution` em `core/evolution.go` (pressão, candidatas, `fit` pelo estilo, oferta com destaque, verbos `evoluir` e `recusar-evolucao`, genoma no estado e na visão) e instruções do Jev em `advisor/jev.go`.

- `go vet ./...` ok; `go test ./...`: tudo passa, exceto a falha anterior de `presentation.json` (H0).
- 6 testes novos em `engine/scenarios/evolution_test.go`: sem pressão não há oferta; o padrão segue o caminho do jogador (um lutador recebe só mutações de combate); a escolha do Jev é revalidada e lidera a oferta; escolher expressa o gene e reforça o caminho; oferta recusada não volta logo; espaços reabsorvem o gene mais antigo.
- `worldsim simulate -ticks 120 -players 3 -advisor jev -pace 800ms`: **3 decisões `evolution` resolvidas pelo Jev** (latência média 386 ms, confiança média 0,67) e 14 `world`, todas no prazo.

**Cliente:** com o motor ligado, genoma, pressão e oferta vêm do motor; o gene escolhido pelo Jev aparece com "◆ o corpo pende para cá"; escolher e recusar viram os verbos do motor; esquivas são confirmadas (`esquivar`). Offline, o laço local continua. 38 testes headless, 0 falhas.

**Ponta a ponta com o Jev** (`e2e_engine.gd`, servidor de teste em tick de 0,5 s): os 7 passos do H1 e mais 2: três vírions confirmados estouram a pressão; a oferta chega com o destaque **escolhido pelo Jev** (no log do mundo, `resolve` de `evolution` com `provider: jev`: Flagelo Calejado, com Cauda Longa e Vesícula Tóxica, todas do caminho de combate); escolhido, o gene é expresso no corpo.

## Missões com recompensas de jogo e corpo procedural pelo Jev (22/10/2026)

**Missões:** 12 no universo (6 novas): "O primeiro gene", "Caça no capilar", "Banquete no sangue", "Dançar com o perigo", "Caçador veterano" e "Linhagem definida", com metas em feitos de jogo (abates, nutrientes, esquivas confirmadas, genes expressos). As recompensas agora são sentidas: **pressão evolutiva** (as de 10 garantem uma mutação), reparo da célula (evento `bonus-reparo`), chuva de nutrientes (`bonus-nutrientes`) e títulos; o cenário único também paga em evolução. `evoluir` virou feito nativo do motor, para missões poderem pedir genes.

**Aparência:** decisão nova `appearance` (`core/appearance.go`): eixos calculados do comportamento (ataques usados, esquivas, exploração, relações com quem fala, genes), variantes candidatas e o Jev escolhe; todos veem o corpo de todos. A mudança é lenta e em segundo plano: reavaliação a cada 45 ticks com pelo menos 20 feitos novos; no cliente o corpo escorre até os valores novos em cerca de 30 s e o comportamento é relatado em lotes de 3 s, sem esperar a rede.

- `go vet ./...` ok; `go test ./...` passa, exceto a falha antiga de `presentation.json`.
- Novos testes: 3 de aparência (o corpo segue como cada um joga e outros jogadores o veem; a escolha do Jev é revalidada; sem feitos novos não muda) e 3 de missões (caça paga evolução e reparo; missões de evolução; esquiva confirmada).
- `simulate -advisor jev -ticks 100 -players 3`: 30 decisões `appearance` resolvidas pelo Jev (~406 ms, confiança 0,65), antes de espaçar as reavaliações.
- Godot: 41 testes, 0 falhas (inclui: genes mudam o corpo; o corpo do motor aparece gradualmente, não estala; comportamento relatado em lote sem bloquear o quadro).
- Ponta a ponta com o Jev ligado (`e2e_engine.gd`): os 9 passos anteriores e mais o novo: o cliente relata ataques em segundo plano e o **Jev decide o corpo "Caçador"** (log do mundo: `resolve` de `appearance` com `provider: jev`).
- Capturas conferidas: quatro corpos distintos (caçador de espinhos, andarilho de cílios e cauda longa, erudito com halo e partículas violeta, banqueteiro grande com grânulos) e as marcas de cada gene (cílios, vesículas de toxina, mitocôndrias, grânulos, anel do núcleo, parede dupla, cauda blindada e longa).
