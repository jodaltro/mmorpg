---
name: environment-architecture
description: Autoria modular de construções medievais pixel art 2D em perspectiva 3/4, com fontes Aseprite, receitas de volumes e lotes, acesso às estradas, exclusões de vegetação, footprint físico e oclusão de telhado. Consome terreno, materiais, água e ecossistemas sem alterá-los silenciosamente.
---

# Architecture Agent — Valdoria

## Referências seguintes — celeiro e pequeno castelo

O usuário avaliou a casa 07R com **“Ficou bom”** e autorizou, em seguida, um celeiro e um pequeno castelo pelo mesmo processo. Em 18/10/2026, aprovou também o celeiro e o pequeno castelo entregues em `43ee9e4657e894340001e183ff4065c763d79b5f`, com o feedback literal **“ficou bem boas”**. Registro com hashes: `Docs/Validation/ValdoriaWorldStudio08/artistic-approval.json`. As três referências podem orientar acabamento e modularização; a aprovação não promove assets à cena oficial nem aprova automaticamente variantes futuras.

As referências individuais estão em `ArtSource/Labs/World2026/WorldStudio08/{Barn,Castle}`. Cada uma tem estudo Blender, prompt e pintura assistida por IA, `SourceV1` Aseprite e `ExportV1` assinado. `architecture07r_reference.py export` agora lê canvas, sourceFile, camadas e papéis dos metadados, preservando o comportamento da casa anterior. Não usa fórmulas para redesenhar a arte. `architecture_models.py prepare` é somente montagem inicial; não executar sobre uma fonte editada.

O celeiro possui lote validado na região existente e acesso publicado. O castelo está num **pátio técnico de revisão**, não num lote geográfico aprovado: nenhuma topografia/água/estrada foi alterada para acomodá-lo. Não descrever essa cena como castelo já implantado no mundo. O portão permite circulação ao pequeno pátio; corpo principal fechado, sem interiores/pisos superiores.

Castelo: sete polígonos físicos independentes, cada um em um `PolygonCollider2D`. Não juntar contornos sobrepostos num único collider presumindo união: o teste real revelou lacunas nas interseções. Cinco grupos de profundidade reutilizam `ReferenceHouseDepth` com linhas de chão próprias: keep, torres, portão e muralha. Piso do pátio fica fora dos grupos de oclusão. A caminhada atrás do arco não deve tornar transparente o keep quando o ator está à sua frente.

`BuildArchitectureModels`, `ValidateArchitectureModels` e `InspectArchitectureModels` constroem e validam as duas cenas experimentais. Documentação/evidências: `Docs/Validation/ValdoriaWorldStudio08-BarnAndCastle.md`. As duas referências estão aprovadas visualmente; os resultados técnicos continuam registrados separadamente. Ainda não é uma biblioteca combinatória.

## Prioridade 07R: uma referência autorada antes da biblioteca

As três casas do Marco 07 foram **rejeitadas artisticamente pelo usuário**. Seus testes aprovam engenharia, não desenho. A gramática `architecture_art.py` abaixo é histórica; não é a direção visual atual. Não ampliar a biblioteca nem reconstruir fachadas por polígonos e ruído para simular acabamento.

Comece por planta, proporção de duas paredes realmente visíveis, estrutura/espessura do telhado, beirais, cumeeira, aberturas e fundação. Compare até três estudos de volume da **mesma casa**, preferencialmente em Blender ortográfico, com Quaternius na mesma escala aparente. Escolha uma composição antes de refinar materiais. O modelo Blender é autoria offline, não runtime 3D.

O estudo atual está em `ArtSource/Labs/World2026/WorldStudio07R/`. `SourceV1/rural-reference.aseprite` é a autoridade dos pixels: doze camadas editáveis, um frame, 966², 32 PPU. `ArtDirection/` conserva a pintura assistida por IA, a direção artística e as operações iniciais de paleta/organização. Esses scripts de montagem são proveniência; **não** devem ser executados por cima da fonte editada. O exportador normal apenas lê a fonte Aseprite.

```powershell
python Tools/ArtPipeline/WorldGen/architecture07r_reference.py export --output Temp/Architecture07R/new-export
python Tools/ArtPipeline/WorldGen/architecture07r_reference.py build --output Temp/Architecture07R/new-region
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_architecture07r.py -v
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/BuildArchitecture07R.cs --entry BuildArchitecture07R.Main --format json
```

Destinos devem estar ausentes. O importador exige Vegetation Lab limpo e recusa a cena/arte 07R já existente. O build consome a referência autorada e um lote explícito; não é um novo gerador universal. A altura da porta é medida contra o alpha do sprite real: neste estudo 4,8387 u contra corpo visível 4,5703 u, sem reutilizar automaticamente 5 u. Transformar a referência em módulos combináveis depende de avaliação visual explícita do usuário.

O footprint anotado e a linha frontal projetada alimentam física/navegação e `ReferenceHouseDepth`. O sorting acompanha a borda frontal na coordenada X do ator; somente volumes interceptados reduzem alpha. Não inferir interior pintado atrás do telhado: as camadas são uma separação da pintura exterior, ainda sem reconstrução de superfícies ocultas. Evidências e limites em `Docs/Validation/ValdoriaWorldStudio07R-ArchitectureArt.md`.

Leia AGENTS.md, Docs/GameVision.md, Docs/WorldGen/ArchitectureContract.md e os contratos produtores pertinentes. Use terrain-generation, terrain-materials, world-hydrology, environment-vegetation e aseprite-pixel-art nos respectivos dados. Esta skill orienta autoria e validação por ferramentas reais; não é um serviço autônomo.

## Decisões de autoria

As receitas e gramáticas seguintes descrevem a engenharia e o histórico do Marco 07; não autorizam reutilizar sua arte rejeitada ou ampliar a biblioteca no 07R.

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
