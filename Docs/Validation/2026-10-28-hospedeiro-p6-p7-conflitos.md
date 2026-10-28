# 2026-10-28 — Hospedeiro P6/P7 · conflitos globais persistentes e infecção pulmonar

- Baseline: `main` @ `d779b43d` (P1). Apenas testes em memória e `worldsim simulate` local; nenhum mundo real tocado.
- Ambiente: Windows 10, Go 1.27.2. O fingerprint do universo muda de novo (ações e conflitos): journals antigos do Hospedeiro não abrem com ele (reinício de mundo autorizado pelo usuário; nenhum foi reiniciado por este trabalho).

## Entregue (código)
- `engine/core/conflict.go`: `ConflictDef` genérico no `Universe` (gatilho material, métrica oficial de severidade, limiares com histerese, `Contain`/`Resolve` com janelas sustentadas, recuperação com trabalho real, cooldown, frentes, efeitos por transição), `ConflictState` no `State`/`Clone`/`Digest`, `ConflictView` em `View.Conflicts` (igual para todos os observadores; só `mine` é pessoal), eventos públicos `conflict-started/escalated/eased/contained/reopened/recovering/resolved/front-opened` com `conflict`, `revision`, `phase`, `region`.
- Efeito genérico `contribute` (validado em `Compile`): credita o ator de um feito já confirmado (`adapter`, deduplicado por `RequestID` pelo próprio `Step`), com teto de 10 por feito e só enquanto o conflito está vivo. O motor não sabe de doenças: tudo vem do JSON.
- `conflictTick` roda ao fim do tick, uma transição por instância por tick, ordem estável.
- `universes/hospedeiro/universe.json`: conflito `infeccao-pulmonar` (gatilho: fato `foco` no pulmão; severidade: carga do pulmão; crítico ≥60, saída <45; contido: carga ≤25 por 6 ticks; resolvido: carga ≤5, oxigênio ≥70 e sem foco, por 6 ticks + 12 de recuperação; frente `circulacao` quando há febre) e a ação `conter-infeccao-pulmonar` (somente `adapter`, exige estar no pulmão e haver carga).

## Testes executados (resultado real)
`gofmt -l core` limpo, `go vet ./...` limpo, `go test ./... -count=1` todos `ok`.
- `scenarios/conflict_test.go` (mundo mínimo, aritmética exata): abre uma única vez pela causa; não expira por tempo (1500 ticks); histerese do crítico; contenção exige janela sustentada e reabre mantendo o id; recuperação produz trabalho, falha reabre, resolve uma vez, cooldown respeitado; frente anunciada uma vez; crédito com teto, deduplicado, só com conflito vivo, jogador não confirma feito; visão igual para todos; replay determinístico; definições inválidas rejeitadas (6 casos).
- `scenarios/conflict_hospedeiro_test.go` (universo real): 1500 ticks sem jogador → 13 instâncias, 12 resolvidas pelo próprio corpo, nunca duas vivas, revisões crescentes por instância; sem defensores (coortes e reserva zeradas) a infecção chega a crítico e a escalada é anunciada; duas contribuições confirmadas creditam 3 cada e ambos veem a mesma severidade/foco; evidência repetida é duplicata; ação de cliente rejeitada; ação sem carga rejeitada; conflito sobrevive ao jogador ausente e o replay do log reproduz o digest.
- `worldsim validate` ok; `worldsim simulate -ticks 300 -players 3 -advisor deterministic` roda (digest `bc25a8d2…b5379`).

## Achados e ajustes
1. Primeira execução: o conflito oscilava reabrir/conter ~22 vezes em 1500 ticks (infecção reaparecia a cada ~48 ticks e a inflamação do corpo nunca descia de 70). Tentei bloquear a nova infecção enquanto a inflamação >30 — isso impedia qualquer reinfecção e quebrou `TestHospedeiroLungInfectionBecomesFeverAndPasses`; **revertido**. A resolução passou a medir carga, oxigênio e ausência de foco; a inflamação ficou como métrica exibida (o surto sanguíneo recorrente a mantém alta neste universo).
2. Consequência de balanço: com as coortes P1 o corpo saudável sempre vence a infecção (pico 21–27, nunca crítico). A escalada só ocorre se as defesas faltam (testado). Torná-la jogável contra um corpo saudável exige balanceamento posterior (P12/P15).

## Não executado / limites
Godot/Nakama/HUD (P10/P11) não foram tocados; o servidor Godot ainda não envia `conter-infeccao-pulmonar` (a ação existe no motor, o adaptador não a emite); fronts não geram tarefas ainda; sem relação NPC↔jogador por contribuição (P4/P5); sem múltiplos conflitos simultâneos testados no universo real (só um conflito definido); Jev não consultado sobre conflitos. Gates: P6 aprovado localmente para o motor; P7 parcial (NPC/coorte e contribuição de adapter causais; falta integração Godot e relações).
