# Masmorras do Hospedeiro → crises abertas (P13)

Decisão de 28/10/2026: o Hospedeiro **não tem mais masmorras instanciadas**. O que cada uma entregava passou para a crise global do mesmo órgão. Estratégia de dados: **reset e recriação** (política vigente de 28/10/2026), sem conversão de saves, runs, genes ou recompensas antigos.

## Mapa de equivalência (P13.1)

| Masmorra (removida) | Crise que a substitui | Recompensa de quem contribuiu e a crise resolve |
|---|---|---|
| Granuloma (sangue) | `infeccao-pulmonar` | pressão +10, maturidade +8, `selo-do-granuloma`, `primeiro-selador` |
| Cordões Hepáticos | `sobrecarga-hepatica` | pressão +10, maturidade +6, `selo-do-figado`, `primeiro-selador` |
| Centro Germinativo | `congestao-esplenica` | pressão +10, maturidade +6, `selo-do-baco`, `primeiro-selador` |
| Criptas Profundas | `disbiose-intestinal` | pressão +10, maturidade +6, `selo-do-intestino`, `primeiro-selador` |
| Néfrons | `sobrecarga-renal` | pressão +10, maturidade +6, `selo-do-rim`, `primeiro-selador` |

- **Quem recebe:** só jogador cuja contribuição validada (créditos de ações confirmadas, `contribute`) soma ao menos `rewardMinCredit` (padrão 3). Quem só assistiu, e qualquer NPC, não recebe. Paga uma vez por instância, só quando ela chega a `resolved`; reabertura não paga de novo.
- **Contrato (genérico, opcional):** `ConflictDef.rewards` (efeitos com `$self` = o jogador) e `ConflictDef.rewardMinCredit`. Evento privado `conflict-reward`. Outros universos não são afetados.
- **Efeitos no mundo** que a masmorra tinha (reduzir toxina, ureia etc.) já são do ciclo da própria crise (`onResolve`, células, regras).
- **Acesso sem portal:** a participação é livre; nenhuma missão é exigida. O gene continua vindo pela barra de pressão.

## O que se perdeu de propósito

- Os **pools de genes raros** de cada masmorra (`rewardPools`) e o rascunho determinístico de expedição. Os genes seguem vindo pela barra de pressão e pelas missões. Se um gene exclusivo fizer falta, a rota é um `rewardPools` em crise, não uma sala.
- Salas, modificadores, chefes e o painel de expedição. O conteúdo de granuloma/biofilme/tumor existe como **frente persistente** (`fronts`) e como massa de tecido (`tumor-intestinal`).

## Estado do código

- **Hospedeiro:** `dungeons` removido do `universe.json`; removidos do Godot `BioDungeon`, `BioDungeonPanel`, `BioGate`, `BioHazardPool`, `BioBossSlam`, os portais, a chamada de entrada, o HUD/atlas/toque da masmorra e a sala isolada do servidor autoritativo. `BioDungeonPlan` virou `BioEnemyCatalog` (só as definições de criaturas, que os moradores selvagens usam).
- **Motor genérico:** `engine/core/dungeon.go` e o resto ficam, porque o contrato é genérico e tem testes. Nenhum universo atual o usa. Os cenários de masmorra rodam em um **fixture congelado** (`engine/scenarios/testdata/legacy-dungeons`), não no universo vivo.
- **Catálogo de criaturas:** os chefes, ninhos e criaturas que só existiam nas salas continuam definidos em `BioEnemyCatalog` como dado; nenhum sorteio os usa. Podem ser reaproveitados como moradores de frentes.
