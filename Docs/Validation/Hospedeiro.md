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
