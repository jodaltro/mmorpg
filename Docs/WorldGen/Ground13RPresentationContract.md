# Ground13R — extensão de apresentação 1.0.0

Estado: candidata, sem promoção. Esta extensão consome os mesmos dados físicos de Ground13. Não muda `WorldRegion`, Organic Roads, hidrologia, regiões protegidas, ocupação ou navegação. O topo permanece inacessível.

## Forma e coordenadas

Autoridade: `ArtSource/Labs/World2026/Ground13R/recipe.json`. Três formações da mesma região recebem contornos superiores e fraturas autorados, inclinação de estratos e depressões locais. Não são novos biomas nem simulação de erosão. A seed continua 910213; as posições de composição são explícitas.

A apresentação usa amostragem de .125 u. O escalar físico original de .25 u é interpolado segundo **a mesma diagonal dos triângulos originais**, não por bilinear. Isso preserva o contorno zero. `groundFeet` é validado contra os segmentos completos dos loops físicos, incluindo subdivisões colineares.

As alturas são apenas de apresentação, projetadas por `(x,48-y+h,0)`. Inclinações, recessos e recortes não autorizam caminhar, construir ou plantar sobre esse topo. Consumidores devem consultar os contratos semânticos existentes; nunca inferir altura física dos vértices visuais.

## Meshes e pigmento

Saída final: `ShapeV6/visual-relief.json`. Mantém o envelope `valdoria-visual-relief/v1`, com especialização obrigatória `version=valdoria-ground13r/1.0.0`. **Não passar ao importador Ground13 antigo**, que não entende `kind=mixed` e `selector`.

Cada grupo reúne uma faixa de chão de 1 u. `vertices`, `uv`, `colors`, `selector` e `triangles` formam o contrato. `selector.x=0` escolhe o atlas superior; `selector.x=1` escolhe o mineral vertical existente. Cada triângulo tem uma única seleção. Os UVs minerais repetem em coordenadas projetadas, evitando estirar pixels de uma superfície horizontal numa parede.

`Ground13RGeology.shader` é um material unlit local de duas fontes. O material único conserva a sequência de triângulos dentro da faixa; não altera o sistema de batching da vegetação, não cria geometria em Play e não é um shader de água. O sorting segue a mesma referência de chão; geometria fora da faixa não é combinada.

A compactação compartilha apenas atributos **bit a bit iguais em float32**, incluindo UVs, cor e seletor. A ordem dos triângulos permanece igual. `ShapeV5` conserva os cantos anteriores; o teste expande ambos os index buffers e compara todos os atributos. Não suavizar juntas nem mesclar fontes diferentes por posição apenas.

## Fonte editável

`SourceV4/upland-contacts.aseprite`, 800×544, RGBA, um frame e seis layers, é a autoridade dos pixels finais. `ExportV4` apenas exporta essa fonte. O atlas contém três peças locais, em 32 PPU, sem rotação, reescala, compressão ou mipmaps. Os texels não usados não devem ser amostrados; manter Point e Clamp.

Os contatos relacionam pigmento à inclinação, às fraturas, a bolsões de folhagem e a clareiras autoradas. A última camada separa línguas de substrato e seus contatos de terra. Receitas e scripts preservam a autoria inicial; não devem regenerar sobre uma fonte posteriormente aprovada ou editada.

O mineral lateral, as árvores, rochas, água, estradas e grama geral são referências compartilhadas dos estágios anteriores, não cópias redesenhadas.

## Comparação e importação

Cena: `ValdoriaGround13RLab.unity`. Teclas: 1=A/relevo Ground12; 2=B/Ground13; 3=C/Ground13R; 4=D/novo neutro; 5=neutro Ground13. Água e restante do ambiente Ground13 são comuns aos estados. Estados internos 5/6 por API desligam o agrupamento da vegetação apenas para prova de pixels.

O importador inicial recusa cena suja, Play e destinos existentes. A atualização explícita atua somente nos meshes do laboratório Ground13R, nunca em arquivos compartilhados. Comparativos antigos reutilizam GUIDs existentes. Rascunhos novos sem consumidores são auditados por GUID antes de remoção; não duplicar bibliotecas históricas para manter esses estados.
