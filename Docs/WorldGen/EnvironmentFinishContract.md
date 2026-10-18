# Environment Finish12 — apresentação candidata v1

Gerador `valdoria-environment-finish/1.0.0`, `Tools/ArtPipeline/WorldGen/environment_finish12.py`. Consome fontes Aseprite exportadas, Ground11, hidrologia05 e âncoras ecológicas07R/Nature10. Não substitui produtores de terreno, estradas, água, navegação ou ocupação.

- `valdoria-environment-source/v1`: assets, canvas, âncora em pixel superior/esquerdo,32PPU, camadas e referência de master. Pixels finais são os Aseprite; masters são proveniência. Camadas descrevem propriedade exterior, sem reconstrução de faces ocultas.
- `valdoria-environment-finish-recipe/v1`: versão, seed inteiro,32PPU, `geometryChange:false`, famílias de árvore, `wetBankExtentPixels≤24` (atual18) e `visualDeepScalar` entre.001 e.05 (atual.012). Este último normaliza **cor**, não profundidade física. `waterPhaseMs=180` nesta versão.
- `valdoria-environment-finish-build/v1`: inputs por caminho/SHA256 e arquivos por SHA256. Export e composição têm manifests separados; o importador verifica ambos. Saídas existentes são recusadas.
- `valdoria-environment-composition/v1`: versão/seed, `geometryChanged:false`, limite da interface de margem, chunks aquáticos originais e referência das âncoras. Domínio64×48u/2048×1536px. Arrays e PNGs usam origem superior/esquerda; Unity recebe `(x,48-y)`.

`relief-top.png` e `relief-face.png` usam os UVs existentes, separados por orientação/função. `ground-bank.png` preserva os pixels Ground11 fora de `bank-influence.png`; não muda cobertura da estrada. Os24 frames aquáticos preservam alpha byte a byte; o recorte final continua nos seis meshes compartilhados. Nenhum PNG fornece física nova.

Vegetação: uma substituição gráfica por âncora histórica autorizada; IDs, espécies semânticas, pontos, raios e collider continuam do produtor. Os dois carvalhos Nature10 são excluídos das substituições. Peças baixas podem ser agrupadas em faixas de.25u, erro máximo de sorting.125u; árvores usam o chão exato. Prefabs novos são visuais e exigem host com footprint/contexto. Não inferir ocupação pelo alpha ou retângulo da copa.

`EnvironmentFinishLab` alterna materiais/renderers/gráficos e frames existentes, sem reconstruir a região ou gerar colisores. `EnvironmentFinish12Importer` cria apenas a cena experimental; `QueueRefresh()` é reimportação explícita dos PNGs derivados Ground12 em laboratório parado/limpo, com domínio mantido. Não usar para fontes aprovadas ou mudança física.

Validação: manifests/reexport/determinismo, proteção dos pixels fora da margem, estrada intacta, alpha aquático, hashes dos produtores e comparação Unity de colliders, navegação, âncoras, vértices/UVs. Aprovação artística permanece separada. Evidências seguem `Docs/Art/VisualReviewEvidence.md` e schema `valdoria-visual-review/v1`.
