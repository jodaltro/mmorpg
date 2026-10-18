# Direção da pintura — uma casa rural de referência

Modo utilizado: ferramenta integrada `image_gen`, uma chamada, fundo transparente, sem CLI/API/key externo. Referência de composição: `../VolumeStudies/02-deep-gable.png`, previamente inspecionada. A pintura assistida por IA é um conceito refinado para esta casa; não é um gerador determinístico nem uma fonte de personagem.

Prompt de direção registrado abaixo em forma normalizada (não uma transcrição byte a byte da chamada):

> Create ONE sophisticated, grounded medieval rural cottage as a transparent-background game asset for Valdoria. Use the supplied orthographic Blender clay study as the volume/composition reference, not as a texture to trace. Present a broad front wall and a substantially visible right gable wall in consistent 2D three-quarter orthographic perspective. Build a convincing pitched roof with real structural thickness, deep eaves, a coherent ridge and dark contact shadows beneath the overhang. Timber structure, irregular stone masonry, weathered oak, layered wooden shingles, a recessed human-sized door, integrated shuttered windows, a stone footing, a subordinate low storage bay and a masonry chimney. Warm upper-left illumination, restrained earth palette, shaded lateral plane, nuanced material clusters and carefully stepped pixel-art edges. Natural irregularities must support construction and volume. Serious detailed pixel art compatible with an elaborately shaded medieval protagonist; avoid cartoon, vector, flat geometric facade, a thin roof plate, random noise, plastic surfaces, oversaturated colors or blurry painting. Show the entire house, isolated with only its local contact shadow; no terrain scene, no characters, no text, no logo, no additional houses.

Saída selecionada: `cottage-painted-master-v1.png`, RGBA 1254². Arquivo original da ferramenta copiado de `$CODEX_HOME/generated_images/01a14b5b-0ccf-7062-aba5-78b8e4e46efb/exec-4b8251e8-a784-4958-8a99-419ddbb3baaf.png` para o projeto.

Refino técnico executado no Aseprite: tamanho nativo 966² por nearest, quantização octree de até 128 cores com alpha, sem dithering automático, retorno a RGBA; resultado com 120 valores RGBA. As operações estão em `palette-and-native-scale.lua`. Separação semântica em doze camadas a partir de contornos de autoria: nenhum pixel é redesenhado por essa separação. A recomposição é exatamente igual à pintura quantizada.

`assemble-authored-layers.lua` é **proveniência da montagem inicial**, não o caminho normal de exportação. A autoridade editável agora é `../SourceV1/rural-reference.aseprite`. Não reaplicar a montagem nem regenerar pintura por cima de edições futuras. Autoria assistida por IA e organização no Aseprite; não há alegação de pintura manual pixel a pixel. Nenhuma alteração nos pixels aprovados do Quaternius.

Avaliação pendente: o usuário precisa avaliar a imagem integrada. O estudo 02 foi escolhido tecnicamente; isso não constitui aprovação artística.
