# Valdoria — produção de elementos naturais

Referências JEV/Nature10, 18/10/2026. As casas07R/08, as duas novas árvores e as duas novas formas de rocha estão **aprovadas artisticamente**. [Aprovação Nature10 com hashes](Approvals/Nature10-2026-10-18.json). Solo e estradas Nature10 continuam não aprovados e são o foco da rodada Ground11. Consulte [a validação real](../Validation/ValdoriaNature10-ArtRefinement.md) e [a linguagem arquitetônica](ArchitectureStyleGuide.md). Não redesenhar as fontes aprovadas para corrigir o solo.

## Forma antes de textura

A casa funciona por paredes com orientações distintas, beirais espessos, sobreposições e sombra nos encontros. Transferir **essas relações**, não desenhar folhas como telhas. Uma árvore começa com suporte, peso e vazios; uma pedra começa com faces e apoio. Matiz e saturação entram depois.

Luz pintada: alto/esquerda, planos quentes; recuos frios, sombras verde-escuras nas copas e cinza-esverdeadas nas pedras. Realces pequenos e descontínuos, sem contorno preto uniforme. Reservar o maior contraste a troncos, faces rochosas e arquitetura. O solo tem contraste menor e áreas de descanso. Não rotacionar/espelhar um sprite iluminado para produzir uma suposta variação.

32 PPU é o contrato da arte integrada. Quaternius permanece com visual1,25 e aproximadamente117px úteis de altura na fonte: 4,57u aparentes. A porta aprovada permanece intacta. Os carvalhos novos têm aproximadamente400px de desenho, 12,5u: árvores adultas, não arvoretas com escala arbitrária no Transform. Pedras usam o mesmo tamanho de pixel. Não igualar a resolução absoluta dos canvas como substituto de calibração.

## Nova árvore

1. Colocar uma casa aprovada e Quaternius na prancha de escala. Definir altura, peso e âncora do chão antes do acabamento.
2. Desenhar uma silhueta assimétrica reconhecível, três massas dominantes e volumes secundários. Prever vazios que revelem galhos. Conferir o desenho também sem detalhes internos.
3. Fazer o tronco afunilar e bifurcar para sustentar as massas. Raízes assentam no chão; conexões de galhos não terminam em discos de folhagem. Separar plano iluminado, meia-luz e recuo.
4. Blender pode testar sustentação e sobreposição com câmera ortográfica. O estudo `VolumeStudy/` desta rodada é uma análise auxiliar independente, **não** a fonte dos pixels e nem uma reconstrução geométrica exata do desenho. Não converter automaticamente o render em sprite final.
5. Interpretar o desenho no Aseprite, no tamanho final, com clusters de folhas, arestas e pequenos realces intencionais. Evitar dithering indiscriminado, antialias de exportação e folhas isoladas cobrindo toda a imagem.
6. Fonte em camadas: sombra, raiz/tronco, galhos estruturais, recuos, massas de folhagem e acentos. Nesta rodada são camadas de propriedade dos pixels exteriores; não contêm reconstrução de superfícies ocultas.
7. Variar a bifurcação, distribuição das massas e inclinação. `oak-reference` e `oak-forked` são duas silhuetas diferentes. Recolorir, espelhar ou apenas mudar a escala não é criar uma espécie/variante artística.
8. Exportar, conferir chão/escala, testar frente/trás e caminhar junto ao tronco. O círculo físico representa o tronco; a copa pode cobrir o ator sem bloquear sua circulação.

## Nova rocha

Definir apoio e proporção; escolher um plano superior, um frontal e um lateral com orientações legíveis. Quebrar a silhueta sem transformar a rocha em uma gema simétrica. Pintar luz por face e aprofundar fraturas em encontros reais. Musgo ocupa juntas baixas; não substitui o desenho das faces. A sombra de contato é curta. Produzir uma segunda forma por mudança de fratura e proporção — nesta rodada, um bloco principal e uma laje partida.

Fonte Aseprite: sombra, faces frontais, superiores, laterais, musgo basal e acentos de fratura. O footprint é um polígono **autorado** no plano de chão, separado da projeção visual. Importar a forma física a partir da mesma metadata que produz ocupação, contato de solo e envelope frontal do sorting. Nunca gerar collider com o retângulo do PNG ou inferir altura de sua cor.

## Solo e transições

Para a rodada seguinte ao feedback Nature10, seguir [GroundAndRoadProduction](GroundAndRoadProduction.md) e [GroundFinishContract](../WorldGen/GroundFinishContract.md). O método Nature10 descrito abaixo é o baseline comparativo; sua superfície não recebeu aprovação. As fontes das árvores/rochas aprovadas permanecem intactas.

`base.png`: pigmento contínuo em coordenadas de mundo, sem fronteira de célula. `transitions.png`: cobertura e shoulders das estradas existentes, domínio rochoso existente e manchas pequenas de contato derivadas dos footprints declarados. `final.png`: clusters esparsos de pincéis Aseprite, sem disputar a atenção com objetos. Manter os três estados comparáveis.

Para ampliar: editar primeiro `ground-brushes.aseprite` (seis ritmos de lâminas, grãos de terra e pequenos planos minerais), depois paleta/densidade/escala dos campos na receita/ferramenta. Os clusters usam pais e filhos com seed, não ruído independente por tile. Pixels de caminho continuam seguindo cobertura semântica e o acesso aprovado. Não alterar água, relevo ou rota para encaixar uma borda pintada. Patches recortam coordenadas globais; distância de contato é analítica e não depende da borda do recorte.

## Fontes e reconstrução

Raiz: `ArtSource/Labs/World2026/Nature10/`. `Masters/` e `prompts.json` preservam as quatro pinturas iniciais assistidas por ImageGen. `SourceV2/*.aseprite` é a autoridade final editável; `source.json` fixa canvas, âncora, footprint e camadas. A pintura IA não é determinística. A reprodução garantida começa **nas fontes retidas**, não em uma promessa de repetir o prompt.

`initial-authoring.lua` e a função `author` são bootstrap histórico da interpretação inicial, não o comando de atualização das fontes finais. A correção explícita `cleanup-raster-edge.lua` remove uma linha branca isolada herdada do master da rocha. **Não executar `author` sobre arte revisada.** O exportador só lê as camadas reais, não redesenha os sprites. A autoria desta rodada é IA assistida, quantização/interpretação e correções Aseprite; não é alegada pintura manual integral.

```powershell
python Tools/ArtPipeline/WorldGen/nature_reference10.py export --source ArtSource/Labs/World2026/Nature10/SourceV2 --output Temp/NatureExportNovo
python Tools/ArtPipeline/WorldGen/nature_reference10.py compose --output Temp/NatureSurfaceNova
python Tools/ArtPipeline/WorldGen/nature_reference10.py placement --output Temp/NaturePlacementNovo
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_nature_reference10.py -v
```

Todos os destinos de geração devem estar ausentes. O CLI `compose` usa a biblioteca de referência `ExportV3`; a API `compose(output, exported=...)` permite outra exportação. `placement` e o importador têm os caminhos da composição de referência explícitos; para uma revisão, selecionar inputs e destino novos, não alegar descoberta automática de novos biomas. `NatureReference10Importer.Build()` cria somente a cena/arte experimental e recusa sobrescrever destinos. Seus arquivos gerados são recursos de importação; os pixels continuam na fonte Aseprite/receita.

## Importação, física e reutilização

RGBA32, Point, sem mips/compressão/NPOT resize; atlas1024² com2px de margem. Sprites FullRect a32PPU, pivô local inferior esquerdo **mais offset de recorte preservando a âncora do objeto**. Texturas do solo não são sprites: PPU do TextureImporter não governa sua escala; UV de mundo usa32px/u. Não reamostrar na montagem do atlas.

Prefabs: `oak-reference`, `oak-forked`, `fieldstone`, `broken-slab` sob `Assets/Mmorpg/Art/Experimental/ValdoriaNature10/`. Escala1. Eles compartilham atlas/material, incluem sombra/contatos, componentes de profundidade e footprint. Instanciar pelo chão. Não usar cópias de pintura por posição. A laje é reutilizada duas vezes na composição; o QA também instancia prefabs em Play e os remove depois. Esse probe temporário de autoria não é um spawner de gameplay nem atualiza navegação persistida.

Árvores ordenam pelo chão; rochas usam `NaturePropDepth`, com envelope frontal do mesmo polígono físico e posição horizontal do ator. Árvores/pedras permanecem opacas e podem ocultar o personagem atrás delas. A casa mantém seu cutaway aprovado. Não foi adicionada iluminação dinâmica, vento, destruição ou animação de vegetação.

Mudanças físicas desta amostra são declaradas: dois raios de tronco passaram de0,3/0,4u para0,5u, e três pedras ganharam polígonos próprios. A navegação experimental é reconstruída sobre os mesmos dados de terreno/água/casa. Testar clearance até a porta e recusar estrada, água, reserva e ocupação existente; não modificar produtores silenciosamente.

## O que requer direção artística

Não automatizar a aprovação da silhueta, suporte dos galhos, distribuição das massas, seleção das faces principais, qualidade dos encontros, direção de luz ou equivalência com a casa. Hashes não julgam essas decisões. Parametrizar exportação, packing, offsets, máscaras, densidade subordinada, seed, validação de ocupação e montagem Unity **depois** de escolher as formas. Primeiro uma composição pequena; somente após feedback ampliar famílias e cobertura do mapa.

Validar sempre em Play na escala real e em movimento. Capturar mesma câmera/ator/resolução antes e depois, três estados do solo, detalhes, colisão e oclusão. Distinguir PNG de fonte, render Blender e Game View. Relatar memória ativa e custo adicional do laboratório comparativo; não tratar este laboratório com quatro estados residentes como orçamento final do jogo.
