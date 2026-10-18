# Ground13 — contrato de apresentação v1

Estado: candidata, não promovida. Consumidores físicos continuam usando `WorldRegion`, `EnvironmentBoundaryContract`, Organic Roads, Hydrology e ArchitectureRegionData. `Ground13Lab` não gera mundo durante Play.

## Relevo

`ArtSource/Labs/World2026/Ground13/ReliefV3/visual-relief.json`, schema `valdoria-visual-relief/v1`, contém grupos de triângulos, UVs, cores e faixas de profundidade. A receita conserva o campo escalar histórico e o contorno zero; recortes adicionais são exclusivamente visuais. `groundFeet` lista inclusive as bordas posteriores não desenhadas, para confronto completo com `physicalLoops`.

`heightIsPresentationOnly=true` é obrigatório. As alturas `.20 / 2.45 / 3.10` são deslocamentos de desenho em unidades Unity, **não** novos níveis transitáveis. Nenhum especialista deve inferir elevação, solo plantável ou localização de construção a partir desses vértices. O topo permanece obstáculo; não há escalada.

Projeção: `(x, 48-y+h, 0)`. Luz superior esquerda, limites subcélula de .25 u do contrato existente. Paredes posteriores são descartadas pela orientação do contorno; o piso físico não é descartado. As faixas mantêm o sorting por chão. Este contrato pressupõe câmera 2D/3/4 fixa; não serve para rotação livre.

## Água

`WaterV2/water.json`, schema `valdoria-water-finish/v1`: seis chunks, quatro PNGs RGBA por chunk, 180 ms por frame. O campo de profundidade, a distância à margem e os motivos são compostos em coordenadas globais antes do recorte. Todos os alphas são byte a byte iguais aos 24 PNGs de Hydrology05; profundidade, fluxo e vau permanecem autoridade do Water Agent.

Os cinco layers de `SourceV2/water-material.aseprite` são autoridade dos motivos. O gerador aplica rampas e posicionamento a partir dos dados existentes; não redesenha os motivos na exportação. `bank-influence.png` limita a modificação de contato a 18 px, excluindo a cobertura das estradas. A faixa não fornece colisão nem modifica a umidade semântica.

## Atlas e ordem

`AtlasV1/atlas.json` declara `sourceRect`, retângulo de destino, dimensão original e SHA dos inputs. Não há rotação nem reescala. Retângulos usados por flores/grama seca do atlas legado conservam suas UVs; novos sprites ocupam apenas espaço livre, com extrusão de dois pixels. Texturas e materiais aprovados continuam intactos.

O agrupamento só reúne mesmo sorting layer/order. `Ground13PackingSafety` preserva os renderers originais quando texels sobrepostos de cores distintas podem mudar a composição. Sombras monocromáticas compatíveis podem ser reunidas. Não agrupar árvores dentro de SortingGroups vivos, telhados/cutaway ou protagonistas. Não converter a árvore inteira em footprint.

## Estados de revisão

1. Ground12 original; 2. mesma arte com agrupamento; 3. forma sem textura; 4. candidata completa agrupada; 5. mesma candidata sem agrupamento. Teclas 1–5 são ferramentas do laboratório. Não são cinco arquiteturas de gameplay. Nenhuma versão comparativa é promovida à cena oficial.

O importador recusa destino existente e cena suja/Play. Reconstruir em novos destinos explícitos. `RefineGround13Meshes` registra a migração pontual V2→V3 executada nesta rodada, limitada aos meshes experimentais `Strata_*`; a importação limpa já usa V3.
