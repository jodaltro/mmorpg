# Ground12 — consolidação ambiental candidata

Referências aprovadas: construções07R/08/09, duas árvores e duas rochas Nature10, terreno e estradas/transições Ground11. [Registro consolidado](Approvals/Ground12-References-2026-10-18.json). Os novos elementos desta rodada são **candidatos**, sem promoção ao mundo oficial.

## Diagnóstico e decisões

As capturas anteriores em `Docs/Validation/ValdoriaGround12/Original/` foram obtidas no laboratório Ground11 em Play real. A casa, as árvores e rochas Nature10 articulam volumes por planos sobrepostos, vazios, suporte e sombra nos encontros. O material Ground11 trabalha massas e desgaste; não precisa ser redesenhado.

|Grupo|Classificação|Decisão nesta região|
|---|---|---|
|Casa, árvores e pedras Nature10|A — compatíveis/aprovados|Preservar fontes, sprites, escala, footprints e oclusão|
|Flores silvestres e vegetação seca pequena|A — compatíveis como acentos subordinados|Reutilizar pixels e posições; não implica aprovação individual de toda a biblioteca histórica|
|Samambaias e agrupamentos baixos|B — refináveis|Duas formas de frondes com comprimentos, aberturas e planos diferentes|
|Arbustos antigos|C — incompatíveis nesta composição|Substituir a mancha geométrica por um arbusto de massas sobrepostas, ramos e vazios|
|Carvalhos/olmos antigos|C — incompatíveis|Substituir somente a apresentação por duas silhuetas novas; manter as23 posições e os troncos físicos|
|Juncos históricos|C — incompatíveis|Trocar o painel de linhas paralelas por tufos abertos com alturas diferentes; manter as39 âncoras ecológicas|
|Topo do relevo|B — material insuficiente|Interpretar planos minerais e bolsões de grama em material próprio|
|Faces laterais|B — material insuficiente|Material mineral separado, sobre os mesmos UVs e vértices|
|Água e margem|B — acabamento parcial|Separar leitura rasa/profunda, acentos leves e solo úmido; manter profundidade/limites/vau|

O diagnóstico não encontrou necessidade de alterar a malha para testar materiais. A silhueta existente continua arredondada e a extrusão é baixa em algumas vistas. A pintura acrescenta fraturas e planos aparentes, **não** plataformas ou degraus navegáveis. Se a avaliação pedir outra silhueta geológica, será necessária proposta semântica/física separada.

## Autoridade dos pixels e autoria

Fontes em `ArtSource/Labs/World2026/Ground12/SourceV1/`, exports em `ExportV1/`, composição atual em `BuildV2/`. `BuildV1/` e as capturas `*-after.png` conservam a primeira interpretação, que misturava grama demais no mineral e usava uma escala de cor inadequada à profundidade normalizada. `*-final.png` mostra a revisão. A receita anterior fica em `recipe-iteration01.json`.

ImageGen forneceu cinco estudos raster originais: duas árvores, arbusto, junco e material mineral. Os masters e prompts são retidos. Aseprite fez interpretação nearest na resolução final, redução de paleta sem dithering e organização em camadas de propriedade dos pixels exteriores. Samambaias e acentos aquáticos foram desenhados em Lua no Aseprite. As camadas não prometem superfícies ocultas reconstruídas. Não foi utilizado Blender nesta rodada: a inspeção dos meshes existentes foi suficiente para a decisão de material.

Árvores:300/294px de altura de desenho,32PPU; são menores que os carvalhos Nature10 e compartilham a escala do pixel. Não se aumentou Quaternius para ajustar a comparação. Arbusto76px e junco82px; as samambaias têm canvas80×56. Os dois desenhos de árvore diferem em bifurcação, vazios e distribuição de massa; não são recolorações. O arbusto e o junco têm **uma silhueta nova cada**, ainda sem uma biblioteca extensa de variantes.

Luz quente do alto/esquerda, recessos frios; highlights pequenos e intermitentes. Não espelhar ou girar luz pintada. Grama e estrada aprovadas permanecem referência de contraste. O adaptador de margem altera apenas uma faixa de até18px fora da água, excluindo a cobertura de estrada; fora dela, os pixels do chão Ground11 ficam idênticos.

## Reprodução e expansão

```powershell
python Tools/ArtPipeline/WorldGen/environment_finish12.py export --output Temp/Ground12/fresh-export
python Tools/ArtPipeline/WorldGen/environment_finish12.py build --library Temp/Ground12/fresh-export --recipe ArtSource/Labs/World2026/Ground12/recipe.json --output Temp/Ground12/fresh-build
python Tools/ArtPipeline/WorldGen/environment_finish12.py verify --output Temp/Ground12/fresh-build
unity command run_script --file AgentScripts/BuildGround12.cs --entry BuildGround12.Main --caller plugin --skill unity-pipeline --format json
```

Os destinos precisam estar ausentes. O importador recusa arte/cena existente; a cena entregue já existe e sua recusa é intencional. `EnvironmentFinish12Importer.QueueRefresh()` permite reimportação **explícita somente dos derivados Ground12** a partir de `BuildV2`, no laboratório limpo e parado. Não reconstrói fontes ou física. Não chamar o bootstrap `author` para editar uma fonte: abrir uma cópia no Aseprite, revisar camadas e exportar uma revisão nova. O bootstrap serve apenas como proveniência da primeira interpretação.

Para nova peça: estabelecer silhueta, estrutura, altura e chão ao lado de Quaternius/Nature10; desenhar massas dominantes antes dos acentos; testar a1×; salvar Aseprite com âncora/canvas/PPU; exportar; conferir importação Point/RGBA sem mips/compressão; validar frente/trás e contatos em Play. Aprovação de forma, luz, paleta e qualidade dos encontros não é automatizada.

Prefabs `elm-vase`, `hornbeam-open`, `hazel-layered`, `reeds-open`, `fern-0`, `fern-1` ficam em `Assets/Mmorpg/Art/Experimental/ValdoriaGround12/`. São **visuais**, sem collider/navegação: o consumidor mantém o footprint e a seleção contextual do Vegetation Agent. No laboratório, cada substituto lê a espécie/variante da âncora existente; as plantas baixas são agrupadas por textura e faixa de chão, preservando a aproximação histórica de0,125u. Árvores ordenam pelo chão exato; não se usa o retângulo da copa como colisão.

Uma nova região precisa fornecer seus produtores e âncoras coerentes; o adaptador atual está ligado à região64×48 do estudo. Isso não é um novo gerador de bioma universal. A segunda composição usa os mesmos componentes em outra parte dessa região, sem pintura por enquadramento.

## Revisão e limites

Consultar [validação Ground12](../Validation/ValdoriaGround12-EnvironmentConsolidation.md) e [pipeline de evidências](VisualReviewEvidence.md). Água permanece acabamento parcial, sem refração, natação, física nova ou hidráulica temporal. O platô ainda depende da leitura da silhueta histórica. Repetição das duas novas árvores e ausência de variantes adicionais de arbusto/junco são limites explícitos. O custo de batching por textura deve ser otimizado antes de produção ampla. Nada disso é aprovação artística automática.
