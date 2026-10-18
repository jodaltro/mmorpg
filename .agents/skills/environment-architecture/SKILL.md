---
name: environment-architecture
description: Autoria modular de construções medievais pixel art 2D em perspectiva 3/4, com fontes Aseprite, receitas de volumes e lotes, acesso às estradas, exclusões de vegetação, footprint físico e oclusão de telhado. Consome terreno, materiais, água e ecossistemas sem alterá-los silenciosamente.
---

# Architecture Agent — Valdoria

Leia AGENTS.md, Docs/GameVision.md, Docs/WorldGen/ArchitectureContract.md e os contratos produtores pertinentes. Use terrain-generation, terrain-materials, world-hydrology, environment-vegetation e aseprite-pixel-art nos respectivos dados. Esta skill orienta autoria e validação por ferramentas reais; não é um serviço autônomo.

## Decisões de autoria

- Comece por lotes estáveis e acessos, não por interpretar a imagem do chão. Recuse água, rocha, reservas, declive excessivo, falta de clearance ou de conexão com a estrada. Não aplane, seque, desvie água ou refaça a estrada como efeito colateral.
- Use dimensões, altura da porta, silhueta e materiais explícitos na receita artística. A biblioteca inicial tem casa rural com anexo, casa maior com dormer e cabana com embasamento ventilado. São três gramáticas de exterior; não um gerador universal de plantas ou interiores.
- Arquivos Aseprite têm dez funções separadas: sombra, fundação, paredes, vigas, portas, janelas, telhado, chaminé, varanda e acabamentos/dormer. Reexporte os pixels realmente editados com export-library. Não gere por cima de uma fonte aprovada.
- Para recombinar aberturas, library aceita --modules-source com três fontes module-door-arched.aseprite, module-door-square.aseprite e module-window-timber.aseprite. A receita artística aceita dimensões dentro do intervalo validado. Refaça o build dos consumidores se módulos/dimensões mudarem; nunca mantenha footprint antigo para uma planta nova.
- Arte usa 32 PPU, RGBA, Point, sem mips/compressão, luz superior esquerda. Não espelhe volumes iluminados para inventar orientações. A primeira versão suporta apenas a orientação autorada sudeste; física permanece no plano 2D.
- Separe âncora, footprint, porta, aproximação, corredor de acesso e volumes visuais. Telhado/beiral não define collider. Fachadas fechadas bloqueiam: acesso à porta não significa interior jogável.
- Reservas de construção e acesso são exclusões versionadas da vegetação. Regere apenas esse consumidor, registre diferenças por ID e verifique as alterações por competição fora dos retângulos. Componha A no campo, C nos juncos e B apenas no bosque delimitado.
- Importe em destinos novos a partir do laboratório de vegetação limpo. ArchitectureStudioImporter verifica hashes e recusa sobrescrita de cena/arte. Não gera no Play. Preserve a cena oficial e aguarde avaliação estética.

## Ferramentas

```powershell
python Tools/ArtPipeline/WorldGen/architecture_art.py recipe --output Temp/Architecture/new-art-recipe.json
python Tools/ArtPipeline/WorldGen/architecture_art.py library --recipe ArtSource/Labs/World2026/WorldStudio07/Recipes/architecture-library.json --output Temp/Architecture/new-library
python Tools/ArtPipeline/WorldGen/architecture_art.py export-library --source ArtSource/Labs/World2026/WorldStudio07/LibraryR7 --output Temp/Architecture/edited-export
python Tools/ArtPipeline/WorldGen/environment_architecture.py recipe --output Temp/Architecture/new-region-recipe.json
python Tools/ArtPipeline/WorldGen/environment_architecture.py generate --recipe ArtSource/Labs/World2026/WorldStudio07/Recipes/region.json --output Temp/Architecture/new-region
python Tools/ArtPipeline/WorldGen/environment_architecture.py verify --recipe ArtSource/Labs/World2026/WorldStudio07/Recipes/region.json --output ArtSource/Labs/World2026/WorldStudio07/BuildR5
unity command run_script --caller plugin --skill unity-pipeline --timeout 120 --file AgentScripts/BuildArchitecture07.cs --entry BuildArchitecture07.Main --format json
```

--library seleciona fonte alternativa no gerador. Context consome a região existente e os manifests dos outros especialistas. Para nova importação, altere Source/Library/Art/Scene para destinos novos; o comando acima recusa os destinos já entregues.

## QA obrigatório

Python: contratos, seed, repetição, impossibilidade de lotes, contorno físico, margem de água, exclusões, competição, acesso com raio de ator, ocupação, hashes, roundtrip Aseprite e recombinação dos módulos. Os caminhos de proveniência dos consumidores variam com o diretório de saída; compare semântica e bytes físicos normalizando apenas essas referências, nunca a geometria.

Unity: compile/status/Console, Play real com perfil Temp, Input System, colisão de parede, porta proporcional ao ator, percurso estrada-porta, frente/lado/trás, cutaway de telhado e volumes superiores, sequência de câmera e custo. Capture após renderização, deixando um frame completo antes da próxima mudança de estado. Restaure Play, input, dispositivos, resolução e opções do Editor. Consulte Docs/Validation/ValdoriaWorldStudio07-Architecture.md.

Não afirmar interiores, porta interativa, fundação sobre terreno 3D, subida de escadas, simulação de inundação ou aprovação artística automática.
