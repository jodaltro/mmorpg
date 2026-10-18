---
name: environment-vegetation
description: Autoria e integração de vegetação pixel art procedural de Valdoria com habitats, clusters, footprints de tronco e sorting por chão. Consome terreno, materiais, estradas, hidrologia e fronteiras compartilhadas, sem modificar esses dados.
---

# Vegetation Agent — Valdoria

Leia `AGENTS.md`, `Docs/GameVision.md`, `Docs/WorldGen/VegetationContract.md`, `EnvironmentBoundaryContract.md` e `WorldHydrologyContract.md` no mesmo diretório. Use terrain-generation, terrain-materials, world-hydrology e aseprite-pixel-art nos respectivos contratos. Esta skill orienta autoria real; não inicia um subagente ou simulação de ecossistema automaticamente.

## Fluxo

1. Confira worktree e pull conforme AGENTS. Preserve trabalho alheio. Confirme Editor, versão, cena limpa e compilação. Localize e valide Aseprite antes de autoria.
2. Consuma manifests e referências por hash. `Context` valida que WorldRegion, Organic Roads, materiais e hidrologia compartilham os mesmos inputs. Consulte os escalares triangulados e loops compartilhados; nunca derive colisão da aparência do PNG.
3. Autorize densidades, habitats e reservas na receita. Use umidade aproximada, solo, altitude, declive, distância da água/estrada, sombra aproximada, competição e pais espaciais. Registre densidade não atingida; não force árvores em locais inválidos. Mantenha vau e passagem obrigatória livres, com margem do ator além do raio do tronco.
4. Gere biblioteca original em camadas e três silhuetas por espécie no Aseprite. Os três frames são variantes, não animação. Para editar, salve cópia e execute export-library: os pixels editados são a fonte. Atlas RGBA, Point, 32 PPU, sem mips/compressão; mantenha offsets do recorte e âncora original. Não rotacione luz pré-pintada.
5. Mantenha tronco, copa, sombra, âncora, footprint e oclusão separados. Só oak/elm bloqueiam nesta versão. O círculo do tronco jamais é o retângulo da copa. Árvores usam SortingGroup exato pelo chão; plantas baixas podem usar faixas estáticas de 0,25 u, documentando aproximação máxima de 0,125 u.
6. Gere offline em destino ausente. Integre por `VegetationStudioImporter.Build()` a partir do laboratório de hidrologia limpo. O importador verifica hashes, recusa sobrescrita de cena/arte e não gera no Play. Não modifique a cena oficial sem pedido e avaliação artística explícita.
7. Valide contratos, determinismo, fontes reconstruídas, exclusões, footprints, competição, navegação e hashes. Na Unity: recompile/status/Console, Play real com perfil Temp, WASD/diagonal/esquiva, tronco, passagem sob copa, frente/trás, margens/vau, câmera em movimento e desempenho. Capture depois de renderizar, deixando um frame completo antes de mudar visibilidade. Restaure teclado/dispositivos, opções do Editor, resolução e Play.
8. Compare A/B/C com região/seed/câmera/ator iguais. Relate densidades não atingidas, memória, draw calls e limitações. Testes técnicos não aprovam arte; nenhuma promoção automática.

## Comandos

```powershell
python Tools/ArtPipeline/WorldGen/vegetation_art.py library --output Temp/Vegetation/new-library
python Tools/ArtPipeline/WorldGen/vegetation_art.py export-library --source ArtSource/Labs/World2026/WorldStudio06/LibraryR5 --output Temp/Vegetation/edited-library
python Tools/ArtPipeline/WorldGen/environment_vegetation.py recipes --output Temp/Vegetation/new-recipes
python Tools/ArtPipeline/WorldGen/environment_vegetation.py generate --recipe ArtSource/Labs/World2026/WorldStudio06/Recipes/recipe-A.json --output Temp/Vegetation/new-A
python Tools/ArtPipeline/WorldGen/environment_vegetation.py verify --recipe ArtSource/Labs/World2026/WorldStudio06/Recipes/recipe-A.json --output ArtSource/Labs/World2026/WorldStudio06/BuildR6/A
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p 'test_*.py' -v
unity command run_script --caller plugin --skill unity-pipeline --timeout 120 --file AgentScripts/BuildVegetation06.cs --entry BuildVegetation06.Main --format json
```

`--library` seleciona biblioteca alternativa no gerador. Outros inputs são parâmetros explícitos da API Python `Context`; o CLI inicial fixa a região de estudo existente. Para importar outra geração, configure as constantes do importador e destinos novos. Receita `patches` contém retângulos de exclusão; a seleção subsequente pode mudar por competição, portanto não promete estabilidade fora do patch.

Consulte `Docs/Validation/ValdoriaWorldStudio06-Vegetation.md`. Não afirmar crescimento temporal, vento animado, clima científico, destruição/colheita, natação, NavMesh ou streaming: não fazem parte desta implementação.


Para construções, use `environment-architecture` e `Docs/WorldGen/ArchitectureContract.md`. Esse consumidor mantém os produtores por hash, acrescenta footprint/acesso e registra exclusões da vegetação em revisão própria; não desloca água, estrada ou relevo para encaixar edifícios.


## Direção central vigente — World Studio09

Antes de produzir ou revisar arte ambiental, ler [ValdoriaVisualLanguage](../../../Docs/Art/ValdoriaVisualLanguage.md) e, para construções, [ArchitectureStyleGuide](../../../Docs/Art/ArchitectureStyleGuide.md). A casa07R orienta acabamento, luz e escala; fontes aprovadas ficam preservadas, revisões09 são candidatas. Não aplicar saturação/tint global nem alterar geometria para resolver cor. Exportar pixels reais do Aseprite e guardar comparações Game View na pasta de validação do projeto.
