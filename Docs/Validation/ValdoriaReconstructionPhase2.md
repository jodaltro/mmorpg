# Reconstrução Valdoria — Fase 2: protagonista canônico e mundo modular

Data: 17/10/2026 · Branch: main · Unity 6000.6.5f1 · Baseline e10007a

## 1. Prefab Quaternius canônico

Assets/Mmorpg/Art/Production/IronKnight/PlayerVisual.prefab -> Assets/Mmorpg/Art/Production/ValdoriaProtagonist/PlayerVisual.prefab

Movido com AssetDatabase.MoveAsset, preservando o GUID 11c15445266e03141a9f8ec3d3f3d0db e as **164 referências** em 9 cenas. O Git registrou como rename de 99%. Verificado ao vivo em MmorpgWorld:

| Propriedade | Valor |
|---|---|
| VisualRoot prefab source | ValdoriaProtagonist/PlayerVisual.prefab |
| VisualRoot escala | **(1.25, 1.25, 1.25)** — preservada |
| ProductionVisualDefinition.character | **ValdoriaProtagonist** (64 clips) |
| body / weaponPivot | BodySprite / WeaponPivot |

O default do prefab apontava para IronKnight.asset — era a última razão pela qual o personagem histórico continuava load-bearing.

## 2. Assets Iron Knight removidos

Removidos (154 arquivos, -168.718 linhas):
- Cenas Marco06B13R3Wardrobe e Marco06B13R4NpcWardrobe, e do Build Settings (MmorpgWorld mantida em primeiro);
- AgentScripts/BuildGarmentLab*, InspectGarmentLab*;
- AgentScripts/IronKnight06B9, InspectIronKnight06B9/10/11, InspectOfficialHero06B12, PromoteIronKnight06B12;
- Assets/Mmorpg/Art/Production/IronKnight/ e Experimental/IronKnightB9-B11.

**Preservado:** ArtSource/Characters/IronKnight/manifest.json — registra licença **CC0-1.0** e autoria (Hormelz, 8-directional Iron Knight).

Após a migração, **zero** assets referenciavam IronKnight.asset.

## 3. GUIDs migrados

| GUID | Antes | Depois |
|---|---|---|
| 11c15445266e03141a9f8ec3d3f3d0db | IronKnight/PlayerVisual.prefab | ValdoriaProtagonist/PlayerVisual.prefab (preservado) |

## 4. Biblioteca ambiental consolidada

Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm — 19 módulos + manifest v2 versionados com seus .meta. Verificado: **todos** os sha256, canvas (32 PPU) e metas conferem; sem PNGs órfãos.

## 5. Reprodutibilidade dos sprites

A lacuna era real: o backdrop não tinha etapa geradora e o manifesto apontava o pai errado. Medido:

    village-scene-v3.png == topo 1536x800 de
      ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-detail-v3.aseprite
      -> diff média 0.0, máximo 0  (pixel-idêntico)

    valdoria-llm-detail-clean.aseprite -> difere ~70/255 (irmão, não pai;
      alimenta só os props via crop_valdoria_llm_aseprite.py)

Novo Tools/ArtPipeline/World/rebuild_valdoria_r10.py: exporta para temporário e compara **sem escrever** nos assets publicados. --verify retorna **exit 0** com pixelIdentical: true contra biblioteca e produção. --output recusa sobrescrever.

O manifesto agora registra backdropSource, backdropRect, backdropSha256, rebuildScript e a semântica corrigida de artSource.

## 6. Estrutura semântica do ambiente

Docs/Art/ValdoriaWorldBlueprint.json (schema valdoria-world-blueprint/v1) descreve cada objeto com ID, tipo, posição, pivô, âncora de chão, dimensões aparentes, footprint de colisão, camada visual, variante artística e seed.

Coordenadas derivadas do backdrop por transformação inversa documentada (32 PPU, escala 1.74, pivô 0.5208/0.4625).

## 7. Colisões de poço/casa/árvore/cerca

| Objeto | Colisão | Nota |
|---|---|---|
| Poço | CircleCollider2D r=1.05 em (-0.66, -9.09) | **Só a borda de pedra.** A cobertura (8.16 u acima) não bloqueia |
| Cerca | BoxCollider2D 4.8x0.24 em (-5.2, -10.6) | Reposicionada para não pinçar o poço |
| Casa | BoxCollider2D 12.8x2.8, offset +5.2 | Apenas as paredes; **não** o retângulo da imagem |
| Árvore | CircleCollider2D r=0.45 | Só o tronco; a copa é camada de oclusão |

### Defeito corrigido: maze invisível bloqueava a vila

ExplorableWorld/RegionTilemaps/SolidBoundaries — TilemapCollider2D, 326 tiles, x[-12,41] y[-8,32], pertence à região **Floresta Cinzenta**, não a Valdoria.

Medido: y=-7 e y=-8 eram **muro contínuo** em toda a largura. O spawn (-8,-1) ficava preso dentro do maze e o poço (-0.66,-9.09) do outro lado. **Nenhuma rota existia**, apesar do chão desenhado ser livre.

Ação: desativado o GameObject (não deletado — é outro bioma, reversível). Resultado medido: células alcançáveis do spawn **930 -> 1021** de 1089.

### Placeholders sobrepostos ao desenho

Objetos de blockout com Square_0 chapado renderizavam **acima** do backdrop, criando o collage de duas versões: ForestHedgeNorth, ForestHedgeSouth, OrinHouse, MiraHouse, TreeWest, RockSouth, RockWest, Bancada da forja, AncestralImpact. Desativados.

**Preservados:** ProvidedTree/ProvidedRock (sprites reais + WorldArtSorting) e Erva cinzenta (ExplorationNode, recurso coletável).

## 8. Sorting e oclusão

Backdrop em sortingOrder = -439. O blockout de chão (VillageGround/WalkingPath/VillageLane, order -490..-479) permanece **abaixo** e corretamente oculto. A oclusão por copa/telhado **ainda não foi implementada** — é a próxima etapa.

## 9. Estado da câmera

Inalterada: ortográfica **7.03125**, CameraFollow reativado, viewport completo validado em Play. Nenhum zoom histórico restaurado.

## 10. Contato dos pés com o solo

O sprite ancora pelo pivô (64, 34); o conteúdo opaco termina 115 px abaixo do pivô. Com escala 1.25 a altura visível é **4.219 u**. O personagem aparece pisando o caminho de pedras nas capturas. Oclusão por sorting alto ainda pendente.

## 11. Resultado de combate

Regras intactas: básico **20**, pesado **36**, counter 30, alcance 1.25/1.65, arco 110°, cooldown 0.4 s, LOS, facção, morte, esquiva, um hit por alvo. A origem do Sweep permanece **exclusivamente na raiz física** (Rigidbody2D.position), como consolidado na Fase 1. Nenhum dano, alcance ou collider foi alterado para mascarar falha nesta fase.

## 12. Resultado do Input System

Testado com **teclado real** (não chamadas diretas ao motor), via PlayerController:

| Entrada | Resultado |
|---|---|
| S | walk, dirIdx 0, y -1.90 -> -5.12 |
| D | walk, dirIdx 3, x -7.12 -> -3.98 |
| W | walk, dirIdx 2, y -4.83 -> -1.54 |
| S+D (diagonal) | walk, dirIdx 7, dir (0.71,-0.71) |

Rota real até o poço: percorrida de (-8,-1) a (-2.46,-10.04) — **2.04 u** do centro do poço.

**Colisão do poço:** caminhando para oeste a partir de (2.00,-9.09), o jogador parou em **0.67** (distância 1.33 = raio do poço 1.05 + raio do jogador ~0.28). Não atravessa.

**Circulação:** teste de anel em r=1.8 ao redor do poço — **8/8 pontos alcançáveis**. O jogador consegue circular o poço.

Console: **zero** entradas novas (nem erro nem aviso) durante o QA.

## 13. Pendências artísticas

1. **Empunhadura:** guarda menos reta, mais à frente, dedos naturais — não ajustada.
2. **Oclusão** por copa de árvore e telhado — não implementada.
3. **SwordSwing.Grip():** investigado. O contrato real do asset é hand = ((pixelX-64)/32, (126-pixelY)/32) (**unidades locais**, pivô 64,126), confirmado em dois importadores R8. Reconstruído: pixel (46.3, 72.0), dentro do canvas 128x160. **TransformPoint() está correto; não há defeito de unidade.** A Fase 1 removeu a *política* LegacyGrip, não um bug de transformação.
4. Diagonais R6 e ValdoriaProtagonist.asset seguem artistic-review-pending.

## 14. Arquivos não rastreados restantes

6, todos resíduo pré-existente: ArtSource/Labs/World2026/R10/Aseprite/test.aseprite, Assets/Docs/Validation/ValdoriaProductionR10* (duplicata do mesmo PNG já versionado em Docs/), Assets/Mmorpg/Art/Production/ValdoriaR10.meta.

## 15. Próxima etapa

1. **Oclusão real**: camadas de copa/telhado com sorting por âncora.
2. **Remover o blockout de chão** (VillageGround/WalkingPath/VillageLane) agora que o backdrop fornece o piso.
3. **Geometria da casa**: validar a porta na proporção do personagem.
4. Ampliar a área-piloto com os módulos do R10Llm sem duplicar o desenho.

Os outros quatro biomas **não** foram reconstruídos, conforme instruído.
