# WorldRegion — contrato para o Valdoria World Studio

Estado: Marco 01, 17/10/2026. Terrain Agent offline, materiais experimentais editáveis e importador Unity 2D implementados. Arte candidata; nenhuma promoção ao mundo oficial.

## Receita e autoria

Entrada `valdoria-terrain-recipe/v1`: `regionId`, `seed`, `size` (16–256 células por eixo), `cellSizeUnits`, `baseElevation`, `features` (hill/valley/plateau), `protectedZones`, `route`, `waterCandidateBelow`. O Marco 01 acrescenta `noiseAmplitude`, `thermalErosion:{iterations,talus}` e `navigation:{maxSlope,maxElevation}`.

Elevação é um escalar normalizado 0–1, não metros de altitude. A inclinação é a magnitude da diferença central desse escalar por célula, não um ângulo em graus. A mesma receita só é comparável com o mesmo tamanho de célula e os mesmos limiares. Uma calibração métrica futura exige revisão explícita de schema.

O patch opcional `valdoria-terrain-patch/v1` contém brushes raise/lower/flatten/paint. Brushes de altura têm suporte circular finito; erosão posterior pode propagar a alteração até uma célula por iteração. Normais/inclinação dependem ainda de uma vizinhança de uma célula. `reserved` protege rotas e plataformas: brushes e erosão não vencem as reservas. Paint não altera reservas. A ordem das operações é significativa.

## Saída e coordenadas

`region.json`: `valdoria-world-region/v1`, com camadas alinhadas row-major, linha zero no topo. Índice = `row * width + column`. Canto inferior esquerdo da célula Unity: `(column, height-1-row) * cellSizeUnits`; centro = canto + meio tamanho de célula. O Transform da região fornece a origem do mundo.

| Camada | Significado / autoridade |
|---|---|
| elevationMilli | Elevação ambiental normalizada, 0–1000 |
| slopeMilli | Diferença de elevação por célula ×1000 |
| moistureMilli | Proxy procedural de umidade; não simulação climática |
| material | Solo semântico grass/forest/dirt/mud/sand/rock |
| walkable | Circulação permitida no plano 2D |
| blocked | Complemento de walkable, origem das colisões |
| route | Corredor principal reservado e navegável |
| reserved | Rota ou área protegida de construção |
| waterCandidate | Candidato topográfico; não água nem obstáculo automático |

`navigation` (`valdoria-navigation/v1`) inclui IDs de componentes conexos, tamanhos, conectividade 4 e `routeConnected`. Não é NavMesh nem inclui raio do ator: conferir clearance e travessia física separadamente. O importador recusa rotas desconectadas e contradições entre walkable/blocked.

O Terrain Agent grava `height.png` e `terrain-preview.png` exclusivamente diagnósticos, e `manifest.json` com versão, hashes de receita/patch e artefatos. Destino deve ser inexistente.

## Materiais e apresentação do Marco 01

`studio01.py` acrescenta `world-region.json`, `navigation.json`, hashes `studioOutputs` e vínculo SHA-256 ao manifesto de materiais. O WorldRegion ampliado mantém o schema base e contém `presentation.tileIndices` (32×32, 32 PPU), `routePoints` e dicas `cliffFaces` da primeira apresentação em sprites.

A implementação final consome `elevationMilli` e `blocked` para construir relevo em quads no plano Z=0, com cantos compartilhados e iluminação direcional calculada na autoria. O campo `cliffFaces.heightUnits` é apenas a dica do estudo inicial; **não** define a altura final das malhas nem a física. Projeção final: média das quatro alturas vizinhas no vértice, `clamp((height-0.48)*9,0.65,4.8)` unidades visuais, somente em células bloqueadas. Nenhum Rigidbody é elevado. A superfície caminhável continua no plano físico.

140 tiles de superfície, quatro variantes por família/máscara, atlas fixo 512×288, faces em atlas 128×64. Fontes Aseprite em `ArtSource/Labs/World2026/WorldStudio01/Materials`. Materiais Unity Point, RGBA, sem mipmaps/compressão. As 16 máscaras cardinais usam N=1/E=2/S=4/W=8 para vizinhos de grama. Bordas homogêneas entre variantes são verificadas; cantos diagonais e encontros de três materiais ainda precisam de um autotile mais rico.

## Integração Unity

`TerrainStudioImporter`: valida hashes antes de importar, constrói Tilemap de superfícies, colisões em runs horizontais exatos e malhas de relevo por linha. `TerrainRegionData` conserva o TextAsset semântico; `TerrainLabController` só alterna alternativas já gravadas. Não há geração em Awake, Start ou Play.

Sorting: superfícies `-2000`; ator `100-round(footWorldY*16)`; relevo por linha e faces com ordem ancorada no bordo sul. Oclusão por linha é aproximada, não uma decomposição de silhuetas arbitrárias. Não há NavMesh, escalada, z-height do ator, pulo de precipício ou hidrologia.

Menu `Valdoria/World Studio`: 01 cria cena/arte em destinos ausentes; 02 regenera receita para diretório novo; 03 importa uma revisão como prefab novo com JSON e malhas próprios. `ImportGeneratedRegion(regionFile,destination)` é o equivalente por CLI. Destinos existentes são recusados. Revisões não substituem automaticamente a cena oficial ou candidatos existentes.

## Handoff para especialistas futuros

| Especialista | Consome | Acrescenta em artefatos próprios |
|---|---|---|
| Water Agent | elevação, inclinação, umidade, waterCandidate, reservas | Bacias, rede de rios, margens, água e travessias; jamais inferir água jogável do proxy atual |
| Material Agent | solo, relevo, rotas, futuras máscaras de água | Paletas, atlas, transições, variações e revisão artística, preservando footprints |
| Climate Agent | região, seed, altitude normalizada, futuros biomas | Temperatura/precipitação e umidade calibradas, identificando unidades/modelo |
| Architecture Agent | plataformas, reservas, componentes navegáveis | Lotes, acessos, âncoras, dimensões e receitas de edifícios |
| Vegetation Agent | solo, inclinação, clima, reservas | Distribuição determinística, sprites, footprints e âncoras; preservar clearance |
| Structures Agent | rotas, terreno, reservas e futuras margens | Cercas, pontes e estruturas com colisão, travessia e sorting explícitos |

Cada handoff deve registrar schema, gerador, seed, hashes dos inputs, unidades, origem espacial e outputs. Nenhum especialista altera silenciosamente o arquivo de outro: uma mudança no relevo exige receita/patch novo e revalidação dos consumidores. Esses especialistas não foram implementados neste marco.

## World Studio 02 — estradas por referência

O envelope `valdoria-world-region/v2` mantém `terrainRef` e `roadRefs` por hash, sem duplicar a topografia v1. A estrada usa curva contínua/largura navegável e máscaras visuais subcélula separadas. Em consumidores v2, a rota vem de `roadRefs`; o campo `route` do terreno base continua sendo a reserva histórica do Marco 01. Consulte [Organic Roads Contract](OrganicRoadsContract.md) para schemas, edição local, recortes adjacentes e consumo pelo Material Agent.
