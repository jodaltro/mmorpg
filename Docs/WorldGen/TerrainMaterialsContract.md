# Terrain Materials — contrato de composição v1

`valdoria-material-recipe/v1` e `valdoria-material-composition/v1`, gerador `terrain-materials/1.0.0`.

## Entradas e autoridade

- WorldRegion v1 com células de 1 u, altura, inclinação, umidade proxy, material e máscaras físicas. O envelope v2 pode referenciar esse arquivo sem duplicá-lo.
- Organic Road v1 e seu manifest; cobertura, ombros, desgaste e navegabilidade em PNG L a 32 PPU. Manifest da estrada precisa apontar para o mesmo hash do terreno.
- Biblioteca `valdoria-material-library/v1`: fonte Aseprite RGBA 384×192, motivos em seis linhas e três colunas de 128×32. Paleta de seis tons por material, luz superior esquerda, translação apenas, arquivos com hash. Área útil dos motivos é menor que o módulo.
- Receita: seed inteiro, estilo A/B/C, `ppu=32`, `chunkPixels=512`, versão, paleta, densidade e patches. Destinos existentes são recusados.

Os bytes de altura, colisão, circulação, curvas, largura e masks da estrada permanecem idênticos. A distância aproximada aos samples existentes é consultada somente para pigmento/desgaste; não reautoriza nem reconstrói geometria física. A cobertura original é usada diretamente.

## Coordenadas e continuidade

Pixels e retângulos usam origem superior esquerda, x leste, y sul. Pixel `(x,y)` amostra seu centro `(x+.5,y+.5)`. Mundo Unity é `(x/32, height-y/32)`; UV global `(x/worldWidth, 1-y/worldHeight)`.

`Context.render(recipe,[x,y,w,h],stage)` é a API de recorte e regeneração localizada. Candidatos a detalhe são definidos numa vizinhança global com halo de 32 pixels, posições jittered, prioridade estável e separação mínima de 12 pixels entre centros aceitos. O halo permite que um motivo atravesse a emenda sem ser cortado de forma diferente. Nenhuma variante iluminada é espelhada.

Chunks de 512×512 são retângulos de um atlas espacial, não novos mapas semânticos. A textura é gerada em coordenadas globais e pode ser composta por recortes idênticos, em qualquer ordem. Os testes concatenam quatro recortes em duas direções e comparam os pixels integralmente.

Isso prova recortes de **um contexto global compartilhado**. Regiões independentes precisam de origem mundial e halo semântico comum; não há promessa de emenda perfeita ao gerar mapas sem vizinhos. O estudo usa uma região 64×48 u. O atlas 2048×1536 é descartável e regenerável; as fontes modulares e a receita são autoridade artística.

## Composição

1. **Base:** pigmento contínuo quantizado em paleta, macro/mesovariação, sem transições nem motivos sobrepostos. Não impõe borda de tile.
2. **Transições:** campos escalares de material interpolados no espaço semântico; distância assinada de rocha, umidade e seleção contextual permitem contornos diagonais e junções de vários materiais. Não há máscara cardinal 4-bit nem blur bilinear da textura renderizada. A saída continua Point.
3. **Final:** mesmos campos e masks, motivos transparentes contextuais e fraturas da face rochosa. Coverage/ombros/desgaste existentes dirigem integração da estrada. Detalhes nunca criam colliders.

Campos de pigmento usam escalas distintas de 193/57/17 pixels; o seletor de manchas usa 37 pixels. Esses comprimentos não são periodicidades de tiles: cada nó do campo tem hash de coordenadas. Não há repetição exata a cada 32 pixels.

Patches `{rectPixels:[x,y,w,h],toneOffset:-1|0|1}` alteram pigmento somente dentro do retângulo. O recorte pode ser regenerado isoladamente; o CLI gera uma revisão completa em destino novo para manter manifest íntegro. Esse patch não modifica semântica ou navegação.

## Relevo visual

`valdoria-material-relief/v1` contém distância visual da borda e altura projetada amostradas a cada .25 u. A altura provém do campo original suavizado; o contorno provém da ocupação bloqueada. A suavização atua **no campo semântico de apresentação**, não nos pixels nem nos colliders.

`TerrainReliefBuilder.AddContinuous` recorta triângulos pela isocurva, compartilha coordenadas/UV globais e iluminação por vértice. Faces de rocha usam atlas contínuo com fraturas não periódicas. Remove o reinício por célula do relevo anterior, mas continua apresentação 2D de terreno bloqueado, sem escalada.

O contorno suavizado pode diferir do collider original nas quinas. Esse é um risco geométrico separado da textura: precisa de QA de contato e não deve ser ocultado por vegetação. Arquivos físicos do WorldRegion permanecem imutáveis.

## Saídas e importação

- `base-atlas.png`, `transitions-atlas.png`, `final-atlas.png`, `cliff-atlas.png`: RGBA/32 PPU.
- `relief-field.json`: apresentação projetada.
- `composition.json`: hashes de terreno, estrada e máscaras; versão/seed/receita/biblioteca; retângulos de chunks; fases; métricas diagnósticas.
- `manifest.json`: hashes de arquivos e entradas; `verify` reconstrói em temporário e compara todos os bytes.

O importador existente é ampliado por `OrganicRoadStudioImporter.Materials.cs`. Cria somente cena/arte experimental ausentes, valida manifests, reutiliza protagonista, câmera, perfil isolado e a única física do terreno. A/B/C usam **a estrada A do Marco 02**, não três geometrias distintas. Não há geração em Play nem objetos por grão/folha.

Atlas de piso compartilhado entre seus draws; atlas de faces compartilhado entre estilos. Filtro Point, Clamp, sem mipmaps/compressão. Controle 0=Antes; 1/2/3=estilos; B=base; T=transições; F=final. A cena oficial não é alterada.

## Aceitação

Contrato, hashes, seed, composição RGBA, recortes, patch, junções e invariância física são testes técnicos. Métricas de fase de borda e repetição detectam regressões, sem produzir nota de beleza. A remoção perceptiva da grade precisa ser observada nos três estados e em movimento na Game View. Grade claramente visível mantém o marco artisticamente incompleto. Aprovação estética e promoção dependem de feedback do usuário.


## Extensao 1.1 — refino 04

A receita continua `valdoria-material-recipe/v1`, com `version=terrain-materials/1.1.0`, `artDirection=contextual-hierarchy`, `clusterSpacing` e `pigmentContrast`. O compositor existente encaminha essa receita para `material_refinement.py`. Receitas 1.0 continuam reconstruindo o baseline de comparacao, sem migracao da geometria.

Biblioteca `valdoria-material-library/v2`: canvas 768x192 RGBA, seis colunas 128x32 por seis familias, funcoes explicitas em `functions`, fonte Aseprite, parentSource/parentSha256 e hashes. Transformacao autorizada: translacao. Exportacao da fonte revisada preserva o canvas v2.

O refino usa os segmentos existentes e soma seus comprimentos para obter arco global: o contrato de Organic Roads fornece `localArcUnits`, nao distancia acumulada de toda a estrada. Distancia lateral e tangente so orientam aparencia, sem refazer curvas ou largura. Grupos de vegetacao material sao globais no contexto compartilhado; filho aceita separacao minima de 8 px e halo de 32 px para recortes. A rede de fraturas usa IDs mundiais, de modo que mudar a extensao do recorte nao altera as juntas.

A apresentacao de relevo e os meshes permanecem iguais ao Marco03. O importador estendido cria `ValdoriaArtisticTerrainLab.unity` em destino ausente, com quatro novas texturas (tres pisos finais e uma face rochosa compartilhada). A referencia anterior usa apenas Marco03 A. O controlador existente tem modo finalOnly, onde B/T/F nao fingem alternar fases que nao foram carregadas.

`FinalOnlyVisuals-A.prefab` e uma exportacao experimental de visuais de um unico estilo. Seu contrato exige WorldRegion e fisica no host; nao inclui ator, controlador de comparacao nem fonte de geracao em Play. Ele demonstra descarte de comparacoes por dependencias, sem prometer streaming. Futuro carregamento por regiao/chunk devera usar os retangulos e halos existentes, carregar assets pregerados e revalidar UV/sorting, sem blur ou compressao inadequada.

No refino 1.1, o alfa dos motivos de desgaste Aseprite pode ser projetado na direcao da estrada com nearest; a cor vem da receita e os realces sao reaplicados em coordenadas mundiais. `allowedTransforms=translation` continua regendo a arte preiluminada de plantas/pedras. O campo `roadWearGeometry` registra a excecao de geometria de pincel, sem rotacao da iluminacao pronta.
