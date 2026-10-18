# Organic Roads — contrato de autoria e consumo (Marco 02)

Schemas: receita `valdoria-organic-road-recipe/v1`; patch `valdoria-road-patch/v1`; saída `valdoria-organic-road/v1`; build `valdoria-road-build/v1`. Gerador `organic-roads/1.0.0` em `Tools/ArtPipeline/WorldGen/organic_roads.py`.

## Entrada, coordenadas e autoridade

A entrada é um WorldRegion v1 imutável. O gerador lê altura, inclinação, bloqueio, reservas e candidatos a água. Nenhum desses arrays é alterado. Unidade de altura/inclinação permanece a normalização do contrato de terreno, não metros/graus.

Waypoints são posições contínuas em unidades de mundo, X para direita e Y para baixo, a partir da origem da região. O centro da célula `(column,row)` é `origin + ((column+.5),(row+.5))*cellSizeUnits`. Pixels são amostrados em seus centros. Na região de estudo, Unity `(x,48-y)`; para outras regiões usar a altura/origem do bounds explicitamente.

A receita informa seed, roadType, waypoints, `width` (nominal/min/max/variation/maxRate), `curve` (sampleSpacing/maxCurvature/tension), `edges` (amplitude/shoulder), constraints (maxSlope/slopeWeight/heightWeight, forbiddenCells, authorizedCrossingCells) e protectedAreas (rect/allowRoad). Áreas protegidas sem `allowRoad:true` são exclusões. `reserved` do terreno já pode representar acesso/plataforma: a semântica original é preservada, e exclusões adicionais são explícitas. Waypoints obrigatórios precisam caber no corredor; não há teleporte sobre restrições.

Células bloqueadas, inclinação excessiva e água são proibidas. `waterCandidate` é tratado conservadoramente como exclusão potencial, não como água efetiva; `waterOccupied` futuro também é reconhecido. `authorizedCrossingCells` só libera água em células originalmente não sólidas e dentro da inclinação máxima; não implementa ponte ou muda colisão.

## Geometria e perfil

A* em oito vizinhos com proibição de cortar cantos escolhe guias. O custo combina distância, inclinação e altura; atalhos de visibilidade precisam respeitar clearance e custo. Segue-se Catmull–Rom centrípeta (alpha=1/2), amostragem fina e reamostragem por comprimento de arco, no máximo 0,125 unidade nos estudos. Curvas que saem do corredor ou excedem a curvatura configurada retornam erro, antes de gravar saída. Não há rebaixamento de montanha para fazer o caminho caber.

Referência primária: [Yuksel, Schaefer e Keyser — Parameterization and Applications of Catmull-Rom Curves](https://www.cemyuksel.com/research/catmullrom_param/). A propriedade local da parametrização não garante evitar obstáculos ou interseções globais; o pipeline verifica o corredor separadamente. O limite de curvatura usa variação angular por distância, em inverso de unidade de mundo, incluindo as junções.

Cada segmento tem ID `road-main/NNN`, dois waypoints, guias, comprimento, curvatura máxima e samples com colunas:

`[x, y, localArcUnits, visualWidthUnits, navigableWidthUnits]`.

Largura varia por funções suaves determinísticas da distância local/seed. É limitada por clearance, min/max e taxa máxima. Junções compartilham largura e recebem transição local; o bound de derivada é reaplicado. `navigableWidthUnits >= width.min`. A borda irregular nunca invade o núcleo navegável: cobertura de todos os pixels do núcleo é 255.

Edição: patch contém `waypointEdits:[{index,point}]`, apenas para pontos interiores. Modificar um ponto altera os spans adjacentes, suas tangentes vizinhas e a transição de largura de até três unidades no próximo span. Os segmentos distantes não mudam de fase porque a distância de ruído é local, não o comprimento acumulado de toda a estrada. Inserção/remoção de waypoints e edição arbitrária de redes ramificadas não são parte deste patch v1.

## Artefatos

| Arquivo | Conteúdo |
|---|---|
| road.json | Identidade/seed/região+SHA, segmentos, perfil, máscaras lógicas, bounds, restrições e QA |
| coverage.png | L 8-bit: cobertura da estrada, borda subcélula irregular; não é colisão |
| shoulders.png | L 8-bit: faixa lateral externa e intensidade |
| navigable.png | L 8-bit: raster do corredor semântico contínuo; não modifica colliders |
| wear.png | L 8-bit: indicação longitudinal de desgaste para materiais futuros |
| road-overlay.png | RGBA de estudo: textura existente do Marco 01 aplicada às máscaras; dispensável para consumo semântico |
| world-region-linked.json | WorldRegion v2 por referência, sem duplicar topografia |
| manifest.json | SHA do input, receita, patch, atlas de estudo, gerador e todos os outputs |

A versão v2 é um envelope de composição: `terrainRef` (id/schema/SHA) e `roadRefs` (arquivo/SHA). O corpo do terreno continua v1, sem copiar suas camadas. Consumidores de v2 usam `roadRefs` como autoridade de rota; a camada `route` do terreno base permanece o registro histórico da reserva do Marco 01, não descreve os novos contornos.

`logicalMasks.navigable` é ocupação na grade lógica, limitada a células permitidas; não substitui a curva/largura para testes finos. O campo `centreline` é diagnóstico lógico. O raster 32 PPU aproxima uma fronteira contínua com erro de discretização de pixel: a largura garantida pertence ao perfil semântico, não a uma contagem ingênua de pixels de um corte oblíquo.

## Recortes adjacentes

Uma estrada global é autorada uma vez. `rasterize(segments,recipe,bounds,ppu)` recorta suas máscaras usando coordenadas mundiais e a mesma fase espacial. Juntar os dois recortes produz os mesmos bytes do raster integral, verificado por teste. Isso não afirma que duas gerações independentes, com waypoints/custos incompletos em cada chunk, produzirão o mesmo traçado. A rede global deve ser compartilhada antes do recorte.

## Material Agent (consumo futuro)

1. Validar manifests e SHA do WorldRegion. Carregar segmentos/máscaras fornecidos; **não recalcular Catmull–Rom, largura ou distância** para reconstituir sua geometria.
2. Usar coverage para superfície, shoulders para mistura lateral e wear para variações longitudinais. Texturas podem ser trocadas sem alterar os hashes da geometria se a nova saída registrar seus próprios inputs/hashes.
3. Manter núcleo navegável e clearance. Aparência de grama não cria obstáculos; objetos físicos futuros precisam de footprints e validação independentes.
4. Preservar resolução, origem mundial, seed e convenção de amostragem para alinhamento com chunks.

O Marco 02 não implementa Material Agent nem amplia sua biblioteca de materiais. A textura de terra de estudo é intencionalmente a do Marco 01.

## Integração Unity

`OrganicRoadStudioImporter` verifica hashes antes de criar `ValdoriaOrganicRoadsLab.unity`. Usa um único terreno B do Marco 01, preservando TerrainRegionData, colisões, relevo e Quaternius. A apresentação antiga fica em um Tilemap de comparação; outro Tilemap restaura grama onde havia células de estrada. Três SpriteRenderers batched com material compartilhado exibem overlays de estrada apenas; não há GameObject por detalhe nem colliders nas máscaras.

`OrganicRoadLabController` alterna 0=Antes, 1=A, 2=B, 3=C, sem gerar em Play. Point, 32 PPU, mipmaps/compressão off. Overlay order -1990 entre o chão (-2000) e atores/relevo. O importador e geradores recusam destinos existentes. A cena oficial permanece intocada.

## Medidas e limites de QA

Testes verificam repetição, seed, largura/derivada, waypoints/tangentes, máscara física conexa em 4 vizinhos, cobertura visual conexa em 8 vizinhos (pixels diagonais são válidos), diagonal longa com bordas em múltiplos offsets subcélula, patch local, desvios/exclusões, recortes adjacentes, hashes e recusa de sobrescrita. Essas medidas são geométricas e de contrato, **não notas automáticas de beleza**. Capturas reais e avaliação humana continuam necessárias.

## Handoff de água — Marco 05

O Water Agent consome cobertura e reservas existentes por hash e rejeita interseção aquática com a estrada aprovada. Não altera seus samples, larguras ou masks. O vau do estudo05 cruza apenas o riacho, não uma estrada. Travessias entre uma futura estrada e água exigirão receita conjunta/autorizações e revalidação de clearance; `authorizedCrossingCells` histórico não cria ponte nem libera rocha. Consulte `WorldHydrologyContract.md`.


## Consumidor Vegetation Agent — Marco06

Veja [VegetationContract.md](VegetationContract.md). O consumidor valida referências/manifests por SHA-256, preserva os bytes deste produtor e acrescenta instâncias e overlay de navegação separados. Troncos têm footprints circulares; copas são visuais. Estradas, reservas, água profunda e vau permanecem restrições de colocação. Navegação combinada ainda requer clearance específico do ator. Não inferir ocupação física pela imagem dos sprites.


## Architecture Agent — Marco07

Consumidor implementado: [ArchitectureContract.md](ArchitectureContract.md). Mantém este produtor por hash e cria lotes, footprints, acessos e exclusões versionadas de vegetação. A vegetação afetada é regenerada em saída nova, com relatório de efeitos da competição. Casca física exterior, telhado visual e corredor transitável são dados separados; transparência não libera colisão.
