# 2026-10-28 — Hospedeiro P1 · coortes e fisiologia

- Baseline: `main` @ `cfb00ba9` (P0). Mundo: apenas testes em memória/`worldsim simulate` local; nenhum mundo real tocado.
- Ambiente: Windows 10, Go 1.27.2.
- **Fingerprint muda** (universo ganhou `populations`): journals antigos do Hospedeiro não abrem com o novo universo. O usuário autorizou reiniciar o mundo/banco; nenhuma migração foi escrita, nenhum mundo real foi reiniciado por este trabalho.

## Entregue (código)
- `engine/core/population.go`: `PopulationDef`/`WorkDef`/`RecruitDef`, `PopState` (headcount + frações de trabalho), `State.Pops` e `State.Ledger` (`omitempty`: outros universos mantêm o digest), `Cond.Pop`, `View.Pops`, `populationTick` no `tick` (sem jogador, sem relógio, ordem por id).
- Contrato genérico: coorte move `Count*Rate/1000` unidades de `K` de `From` para `To`; vazio em `From` = fonte exógena e vazio em `To` = sumidouro, ambos no ledger; teto de destino `ToMax`; perda `Loss` vai ao ledger; mortalidade e reposição pagas por uma reserva. Validação em `core.Compile`.
- `universes/hospedeiro/universe.json`: 4 coortes — `hemacias_sangue` (transporte de O₂ pulmão→sangue, só com pulmão ≥70), `suporte_sangue` (consome O₂), `neutrofilos_pulmao` e `macrofagos_pulmao` (retiram carga do pulmão), todas repostas de `medula.reserva`.

## Testes executados (resultado real)
`go vet ./...` limpo; `go test ./... -count=1` todos `ok`; `gofmt -l` sem os arquivos novos/alterados de `core`.
Novos em `engine/scenarios/population_test.go`: conservação exata com perda e teto (120 ticks, total constante, nunca negativo); frações de trabalho mantidas (100 ticks × 0,3/tick = 30); reposição gasta a reserva e a coorte encolhe sem ela; definições inválidas rejeitadas (5 casos); corpo do Hospedeiro 600 ticks sem jogador (coortes vivas, nada negativo, O₂ entregue e consumido, digest igual em 2 execuções); replay do log de 200 ticks reproduz o digest.
`worldsim validate` ok; `worldsim simulate -ticks 300 -players 3 -advisor deterministic` roda (digest `3b84b47e…de33dd`).

Estado medido ao tick 600, sem jogador, Jev desligado: hemácias 650/650 (166 nascidas, 116 mortas), neutrófilos 60/60, macrófagos 30/30, O₂ sangue 99, pulmão 99, reserva da medula 92 (309 gastos em reposição), 380 unidades de carga removidas por defesa. Os parâmetros foram ajustados uma vez após uma primeira execução em que a reserva zerou e o O₂ do sangue caiu a 12 (registrado aqui por honestidade); os valores acima são os finais.

## Não executado / limites
Godot e Nakama não tocados; Jev não consultado; sem teste de 1.000 coortes; o balanceamento é de jogo, não clínico. Gate P1 (mundo vazio distribui recursos sem negativos nem duplicados): **aprovado localmente**.
