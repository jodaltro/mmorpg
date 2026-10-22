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
