# Reconstrução Valdoria — Fase 1: combate limpo e consolidação de assets

Data: 17/10/2026 · Branch: `main` · Unity 6000.6.5f1

## 1. Origem física definitiva do Sweep

**Arquitetura:** existe **uma única** origem física para golpes de espada — o `Rigidbody2D.position` do ator, no plano do mundo. Não há mais política selecionável e a arte (pivô do sprite, canvas, mão projetada, escala visual) **não** participa do cálculo de dano.

**Defeito corrigido (medido, não inferido).** A cena oficial era a **única** ainda em `LegacyGrip`; as três cenas experimentais já usavam `PlanarSweepOrigin`. O caminho legado derivava a origem da mão projetada:

```
frame.hand (espaco sprite) = (-0.55, 1.69)
Grip() aplicava Body.transform.TransformPoint(hand) SEM dividir por PPU (32)
-> offset injetado em unidades de MUNDO = (-0.55, 1.69)  => 1,78 u de deslocamento
hand/32 = (-0.02, 0.05)   <- seria o valor correto
```

A origem ficava **1,78 u acima/esquerda da raiz e idêntica em todas as direções** — a hitbox não acompanhava o golpe.

**Motivo histórico expirado:** o R7 manteve `LegacyGrip` como padrão *"para o protagonista oficial"* — que era o Iron Knight. Com Quaternius como único protagonista, o motivo deixou de existir.

**Removido:** `SweepOriginPolicy`, `ConfigureSweepOrigin`, `PhysicalGrip`, `previousGrip` e a interpolação da origem artística. `Grip()` permanece explicitamente como **apresentação apenas**.

## 2. Resultados dos testes (Play real na cena oficial)

| Teste | Resultado |
|---|---|
| Básico 20 — 8 direções | OK 8/8 com exatamente 20 de dano |
| Pesado 36 | OK exatamente 36 |
| Fora de alcance (2,0 u > 1,25) | OK 0 de dano |
| Um acerto por golpe | OK 1 golpe = 20 |
| Origem física = raiz, 8 direções | OK delta 0,0000 u em todas |
| Input System real | OK teclado físico moveu o ator via `PlayerController` |
| Console | OK sem erros novos; apenas warnings de deprecação pré-existentes |

**Não alterados:** dano básico 20, pesado 36, counter 30, alcance 1,25/1,65, arco 110°, `bladeWidth` 0,12, `activeDuration` 0,14, `recovery` 0,16, cooldown 0,4 s, LOS, facção, morte, esquiva, um hit por alvo.

**Perfil:** isolado em `Temp/ValdoriaEnvironmentR9/IsolatedProfile`. Os saves pessoais foram conferidos por SHA-256 antes e depois — **byte-idênticos**.

**Escala visual 1,25 confirmada:** é uma *override de cena* em `VisualRoot`, dentro da `PrefabInstance` de `PlayerVisual.prefab` (`MmorpgWorld.unity` ~68386-68402).

## 3. Assets mantidos e descartados

### Descartados

| Alvo | Volume | Justificativa |
|---|---|---|
| `ArtSource/Labs/World2026/R9/SwordProposals/` | 27,6 MB | `qa.json` (11,4 MB) é dump com caminhos absolutos, `artisticApproval: pending`. O `.blend` contém **43 ações stock** do rig (Pistol, Spell, Swim, Driving) e **nenhuma** pose de guarda customizada — o R9 é procedural. Zero referências em docs, scripts, assets ou cenas. |
| `ArtSource/References/PixelLab/Marco06B6-R1`, `-R2` | 67 arqs | Iterações rejeitadas. Os 7 docs rastreados que citam PixelLab linkam para `Marco06B6/` (rastreado, preservado) — **0 links quebrados**. |
| `ValdoriaEnvironmentR10`, `R10Detail` | 34 PNGs + 2 `.meta` | `R10` e `R10Detail` são **clones exatos entre si** (17/17 hashes idênticos). Nenhum PNG referenciado por cena/prefab/asset. |
| `export_valdoria_r10.py` | 1 script | Escrevia no `R10Detail`; saída superada pelo pipeline R10Llm. |
| `pixellab_preview_b6_r1/r2.py`, `Marco06B6-R1/R2.md`, `build_sword_guard_proposals_r9.py` | 5 arqs | Ferramentas/relatórios dos estudos acima. |

**Total liberado: ~30,8 MB.**

### Mantidos

- **`ValdoriaEnvironmentR10Llm`** — biblioteca ambiental canônica. Prova: `village-scene-v3.png` é **byte-idêntico** (SHA `98D5E85899B9AF23...`) ao backdrop de produção `ValdoriaVillageScene.png`. É o único kit com proveniência explícita (`schema v2`, `artSource` apontando para a fonte Aseprite R10).
- É o destino de `crop_valdoria_llm_aseprite.py` (rastreado) e a fonte de `PromoteQuaterniusR10.cs` (rastreado).

## 4. Biblioteca ambiental escolhida

**`Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm`** (42 arquivos, 19 assets + manifest v2).

Um único caminho de produção:

```
ArtSource/Labs/World2026/R10/Aseprite/valdoria-llm-detail-clean.aseprite   (fonte editável)
  -> crop_valdoria_llm_aseprite.py                                         (crops isolados)
  -> Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm/*.png        (módulos)
  -> village-scene-v3.png == Assets/.../Production/ValdoriaEnvironment/ValdoriaVillageScene.png
```

O kit **não** corresponde à composição atual como Tilemap: ele fornece módulos isolados (casa, carrinho, poço, cerca, árvores) para a futura montagem modular. O backdrop integrado é a composição única; os módulos são a base para geometria/oclusão. **Não reconstruí os cinco biomas** nesta fase.

## 5. Pendências artísticas da espada

1. **Empunhadura/pose:** o usuário pediu guarda menos reta, um pouco à frente do corpo, com palma/braço/dedos naturais. **Não ajustada nesta fase** — a Fase 1 corrigiu a física, não a arte.
2. **Correspondência lâmina/plano:** permanece a separação visual/física apontada no R7 (~2,89 u). O gate físico passou; isso **não** é aprovação artística.
3. **Diagonais R6:** passaram gate técnico, sem aprovação artística explícita.
4. `ValdoriaProtagonist.asset` continua `r8-feedback-sword-contact-and-expressive-dodge-artistic-review-pending`.

## 6. Próxima etapa — geometria e oclusão de Valdoria

O backdrop continua **imagem única sem colisão, oclusão ou navegação**. Próximos passos:

1. Montar os módulos do `R10Llm` em uma área-piloto com **âncoras de sorting** por objeto.
2. Gerar colisão semântica **separada** da arte (footprints, paredes, água) — o cenário único não cria colisão automaticamente.
3. Camadas de oclusão para copas/telhados que devem cobrir o ator.
4. Validar com o quadro de referência do **poço** e caminhabilidade real em Play.

## 7. Correção de entendimento — Iron Knight

A auditoria **refutou** a premissa de que Iron Knight é removível sem mais. `Art/Production/IronKnight/PlayerVisual.prefab` (guid `11c15445266e03141a9f8ec3d3f3d0db`) **está instanciado na cena oficial** e fornece o rig visual compartilhado do protagonista:

```
PlayerVisual > VisualRoot > { BodySprite, WeaponPivot/EquippedSword, GroundShadow }
```

A cena sobrescreve `m_LocalScale = 1.25` (a escala do AGENTS.md) e troca `character` para `ValdoriaProtagonist`. O default do prefab ainda aponta para `IronKnight.asset`, mas isso é apenas fallback.

**Conclusão:** o prefab é **infraestrutura de produção**, apesar do caminho histórico. As 2 cenas Wardrobe que também o referenciam estão no Build Settings. **Nada de Iron Knight foi removido** nesta fase; a remoção exige decisão explícita sobre esses alvos.

Os 6 `AgentScripts` IronKnight (0 consumidores externos) permanecem: são as ferramentas que reconstroem os assets B9-B12 e ficam sem função apenas se esses assets forem removidos.
