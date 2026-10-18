# GroundFinish v1 — apresentação offline de superfícies

Versão `valdoria-ground-finish/1.0.0`; ferramenta `Tools/ArtPipeline/WorldGen/ground_finish11.py`. Consome WorldRegion/Organic Roads/Architecture/Nature10 sem reescrever seus dados. Arte candidata; referências de objetos aprovadas em `Docs/Art/Approvals/Nature10-2026-10-18.json`.

## Dados

- `valdoria-ground-finish-recipe/v1`: versão, seed inteiro,32PPU, fonte384², luz `upper-left`, `geometryChange=false`, grupos `grass`, `road`, `contacts`. `validate` limita amplitudes, franja, desgaste, intensidade e tipos. Rejeitar PPU/versão/alteração de geometria incompatíveis.
- `valdoria-ground-finish-build/v1`: versão, `inputs` por caminho+SHA256 e `files` por nome+SHA256. Export da fonte, composição de mundo e bancada são builds separados. Destino deve estar ausente. Verificar inputs/arquivos antes da importação.
- `valdoria-ground-finish-composition/v1`: boundsPixels, sizePixels, seed, PPU, `canonicalWorld`, `geometryChanged=false`, estágios e casos. Pixels/paths têmY para baixo. Região atual:64×48u,2048×1536px; Unity `(x,48-y)`. Bancada:60×37,5u,1920×1200px; Unity `(x,37.5-y)`.
- `valdoria-surface-grammar-court/v1`: rede **não canônica** de teste visual, casos com slots/bounds, paths e largura visual em pixels. Curva Catmull–Rom opcional; demais paths são polylines com caps arredondados. Não é planejador topográfico, mapa novo ou promessa de navegação nesse desenho.

## Camadas e autoridade

`base.png`: pintura de grama com hierarquia de massas/áreas calmas, mantendo a interface do platô anterior no adaptador de referência. `transitions.png`: cobertura unificada, terra, margens, contatos e iluminação curta. `final.png`: desgaste orientado e detalhes subordinados. Materiais RGBA de chão, sem desenhos de casas/árvores/rochas. Não são panorama de geometria canônica.

`coverage-input.png`: união visual original estrada+acesso, imutável após leitura. `visualAlpha.png`: franja artística separada; o núcleo `navigable.png` do produtor permanece255. `bankDistance.png`: diagnóstico da distância assinada com128 de bias e clamp8bit, não altitude. `flowCoherence.png`: consenso da orientação sem direção, usado para reduzir desgaste onde percursos concorrem. Nenhum desses mapas substitui navegação/colliders.

O acesso07R usa `rectPixels=[left,top,right,bottom]`, não largura/altura. Sua máscara entra no mesmo domínio global da estrada. O renderer antigo aparece somente no estado anterior; desativá-lo na apresentação nova não altera acesso funcional.

Fontes finais: `SourceV2/*.aseprite`, quatro camadas e um frame;384² para meadow/earth,512×128 para edge-grammar. Pixels reais exportados, sem regenerar pintura na exportação. Fonte IA inicial e prompts retidos; somente reconstrução a partir dos Aseprite é determinística.

## Reutilização e patches

`render(bounds,coverage,paths,recipe,world=False,sites=None,library=...)` usa bounds globais e máscaras completas, inclusive halos/contexto para distância e fluxo. O CLI aceita `--library` e `--recipe` e registra ambos por hash. Um patch deve igualar o recorte do full render. Não alimentar apenas o recorte da máscara e esperar distância coerente nas bordas. Fontes iluminadas recebem translação, sem rotação/espelhamento.

`sites` fornece influências visuais de árvore (`point`, `influenceRadii`), rocha/fundação (`footprint` absoluto), com `kind` explícito. Dados físicos são a autoridade separada; uma influência visual não concede ocupação ou passagem. `world=True` ativa o adaptador da região de estudo e preserva sua interface rochosa anterior. Outras regiões precisam fornecer seus próprios inputs e validação física; não existe importação genérica automática de qualquer mundo.

`GroundFinishLab` troca apenas materiais e visibilidade do renderer antigo do acesso. Os quatro estados compartilham colisores, transforms físicos, navegação e objetos. `GroundFinish11Importer` cria destinos ausentes; a reimportação explícita de pintura fica limitada aos PNGs derivados do próprio laboratório e ao domínio existente. Nunca modificar silenciosamente cena oficial ou fontes aprovadas.

QA: reexport Aseprite, hashes, repetição/seed, patch, proteção do núcleo, conexões e supressão de desgaste nas junções; física/navegação equivalentes em Editor/Play, Input System, acesso, oclusão e captura após renderização. Hashes não aprovam estética. Consulte `Docs/Art/GroundAndRoadProduction.md`.
