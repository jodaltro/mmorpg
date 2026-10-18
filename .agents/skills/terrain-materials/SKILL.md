---
name: terrain-materials
description: Autoria e revisão de materiais pixel art procedurais de Valdoria em Aseprite e Python. Use para pigmento contínuo, variantes contextuais, transições subcélula, detalhes multiescala e composição com WorldRegion e Organic Roads, sem alterar física ou traçados.
---

# Material Agent

## Ground13R

Seguir o feedback oficial em `Docs/Art/Approvals/Ground13R-Direction-2026-10-18.json`: plateau Ground13 nao aprovado; preservar agua Ground13 e batching conservador. Fontes atuais: Ground13R SourceV4/ExportV4 e ShapeV6. Contrato `Docs/WorldGen/Ground13RPresentationContract.md`. Agua deve ser registrada em replay real apos renderizacao, sem fases forcadas. Fisica e cena oficial intocadas; aprovacao artistica depende do usuario.

## Ground13 — prioridade atual

Seguir a delimitação mais recente em `Docs/Art/Approvals/Ground13-Direction-2026-10-18.json`: vegetação Ground12 preservada após parecer positivo; platô/água candidatos com ressalvas. Sem aprovação geral automática. Relevo pode mudar apenas a apresentação (B), mantendo o pé físico, topografia, colisores e navegação; C exige proposta/autorização específica. Otimização deve preservar pixels e ordem de sobreposição, com comparativo separado de arte idêntica. Usar ReviewLite existente, não outro sistema de evidências.


## Ground12 — direção vigente

Construções07R/08/09, árvores/rochas Nature10 e terreno/estradas Ground11 estão aprovados nos respectivos registros. A composição Ground12 apresentada foi aprovada em `05d842d4050aa35f5b73c4e30314f4f5bb65d39f`; escopo/hashes em `Docs/Art/Approvals/Ground12-2026-10-18.json`. Não ampliar essa aprovação a futuras variantes ou à hidrologia completa. Ler `Docs/Art/EnvironmentConsolidation12.md`, `Docs/Art/Approvals/Ground12-References-2026-10-18.json` e `Docs/Art/VisualReviewEvidence.md`. Preservar os pixels aprovados; consumir âncoras/fronteiras/footprints existentes. Não alterar física, navegação ou cena oficial nesta rodada. Evidências importantes exigem originais e ReviewLite≤750KiB, manifestos e recuperação remota separada da inspeção visual. Declarações históricas de aprovação pendente abaixo não substituem esses registros.


## Direção vigente — Ground11

Ground11 foi aprovado; construções e as duas árvores/duas rochas Nature10 também são referências aprovadas. Ler `Docs/Art/GroundAndRoadProduction.md`, `Docs/WorldGen/GroundFinishContract.md` e `Docs/Validation/ValdoriaGround11-TerrainAndRoads.md`. Para acabamento novo, usar fontes Aseprite Ground11 e `ground_finish11.py`: pintura em massas, união estrada/acesso, bordas por distância, desgaste por percurso, contatos por footprint e patches globais. Não redesenhar objetos aprovados. Não usar bootstrap sobre fonte revisada. A bancada de nove conexões é visual, não planejamento/navegação de rede oficial. Importação nova recusa sobrescrita; reimportar pixels derivados é ação explícita no próprio laboratório. Os fluxos03/04/09 abaixo são referências históricas de contratos, não aprovação de seus materiais.

Direção de acabamento natural: consultar `Docs/Art/NaturalEnvironmentProduction.md` e `Docs/Validation/ValdoriaNature10-ArtRefinement.md`. Solo deve sustentar volumes, manter áreas de descanso e transições vinculadas às máscaras/footprints. Inspecionar base, transições e detalhes em Game View na mesma escala. Não resolver forma com saturação nem redesenhar relevo a partir de cores. Nature10 é candidato, sem aprovação artística automática.

Para reproduzir o Marco 04, use o refino 1.1 descrito ao final; para acabamento novo, seguir Ground11 acima. Os comandos 1.0 abaixo conservam o baseline de comparacao do Marco 03; nao representam a direcao artistica mais recente.

Leia `AGENTS.md`, `Docs/Art/TerrainMaterialsStandard.md` e `Docs/WorldGen/TerrainMaterialsContract.md`. Use também `aseprite-pixel-art` para fontes e `terrain-generation` para interpretar os dados. A skill é um especialista operado pelo agente, não um serviço independente.

## Responsabilidade

O Terrain Agent decide relevo, solos e circulação. Este módulo decide pigmento, transições, desgaste e detalhes. Consuma WorldRegion v1, composição v2 e road v1/máscaras verificadas. Nunca modifique `blocked`, altura, navegação, waypoints, largura ou cobertura da estrada para obter um visual mais fácil.

`Tools/ArtPipeline/WorldGen/terrain_materials.py` implementa biblioteca editável, composição por coordenadas globais, recortes, patches retangulares de tom, manifests e reconstrução verificável. `OrganicRoadStudioImporter.Materials.cs` amplia o importador existente; `TerrainReliefBuilder.Materials.cs` substitui a apresentação quadriculada do relevo no novo laboratório. A física continua original.

## Autoria efetiva

1. Confira worktree e pull conforme AGENTS. Identifique primeiro emendas, repetição, transições e relevo. Guarde o diagnóstico antes de criar material novo.
2. Gere em destino ausente. Use seed, origem, PPU e versão explícitos; todos os chunks da região compartilham contexto completo. Nunca alegue continuidade entre regiões independentes sem halo semântico compartilhado.
3. Biblioteca: seis materiais, três funções por material em módulos 128×32; área útil menor para stamps transparentes. Camadas semânticas Aseprite, paleta e luz superior esquerda. Não espelhe/rotacione luz. Edite a fonte em cópia e exporte nova revisão, preservando contrato do canvas.
4. Componha em três estados: base sem stamps; transições sem stamps; final com detalhes. Corrija contornos/UVs na camada estrutural. Não esconda grade com ruído ou vegetação.
5. Varie macro pigmento, meso manchas e micro motivos contextualizados por umidade/material/estrada. Densidade moderada e distância mínima espacial; não use uma rotação aleatória de tiles iluminados.
6. Importe no Editor real em cena/arte novas. Point, RGBA, mipmaps/compressão off. Atlases são saídas reproduzíveis de fontes modulares, não um panorama canônico. Não gere em Play nem crie um GameObject por detalhe.
7. Execute testes, recompile, Console, Play/Input System, caminhada/esquiva, sorting, pés, sequência de câmera em movimento. Restaure dispositivos, perfil, resolução e Play. Apresente A/B/C na mesma estrada, seed, pose, câmera e escala.

```powershell
python Tools/ArtPipeline/WorldGen/terrain_materials.py library --output Temp/Materials/new-library
python Tools/ArtPipeline/WorldGen/terrain_materials.py export-library --source ArtSource/Labs/World2026/WorldStudio03/LibraryV2/terrain-motifs.aseprite --output Temp/Materials/edited-library
python Tools/ArtPipeline/WorldGen/terrain_materials.py generate --recipe ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio03/LibraryV2 --output Temp/Materials/new-region
python Tools/ArtPipeline/WorldGen/terrain_materials.py verify --recipe ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio03/LibraryV2 --output ArtSource/Labs/World2026/WorldStudio03/BuildR7/A
python Tools/ArtPipeline/WorldGen/terrain_materials.py render --recipe ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio03/LibraryV2 --bounds '[1024,704,192,160]' --stage final --output Temp/Materials/local-revision
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p 'test_*.py' -v
```

## Revisão e limites

- Não chamar grid removido ou arte concluída só porque testes passaram. Inspecione base, transições, detalhes e movimento na Game View. Grade claramente visível reprova o marco artisticamente.
- Hashes provam integridade, métricas de linhas revelam periodicidade; nenhum deles certifica beleza. Aprovação artística é explícita do usuário.
- Lama/umidade são aparência sobre o proxy existente, não simulação hídrica. Areia é uma superfície, não um bioma novo.
- Patches atuais alteram pigmento em área definida; não são pintura vetorial universal nem editor completo de materiais. Regenerar é autoria offline.
- Relevo projetado continua visual no plano 2D. Não anunciar escalada, hidrologia, vegetação física, construção ou promoção ao mundo oficial.
- Ferramentas de IA podem ajudar o agente a decidir receitas e formas; não afirmar uso de ImageGen/Blender quando não executados. Preserve proveniência/licenças das fontes usadas.


## Refino artistico 1.1 (Marco 04)

Leia tambem `Docs/Validation/ValdoriaWorldStudio04-ArtisticRefinement.md`. `material_refinement.py` estende o mesmo compositor quando a receita tem `version=terrain-materials/1.1.0`; nao gera outro terreno. Use a biblioteca v2 768x192, seis funcoes por familia, revisada a partir da fonte do Marco 03. A geometria do relevo deve permanecer byte-identica e os meshes Unity devem ser compartilhados com o baseline.

- Nao confundir pixel art com aspecto cartunesco: evitar ilhas de pigmento com contorno vetorial, saturacao exagerada e sombreado aerografado. Usar clusters de pixels, planos e degraus de luz controlados, avaliados junto ao Quaternius na escala nativa.
- Campos 193/57 agora modulam pouco o pigmento. Contexto de umidade, trafego e base de rocha dirige solo exposto; clusters pequenos formam a textura da grama. Nao aumentar ruido independente nem cobrir o piso de tufos uniformes.
- Grupos hierarquicos possuem pais espaciais e filhos com separacao minima e areas de descanso. Grama de margem usada e curta; formas altas/rasteiras dependem do contexto. Mantenha a luz superior esquerda sem espelhar motivos.
- Desgaste usa eixo, largura, distancia lateral e arco global. `localArcUnits` reinicia por segmento: some os comprimentos dos segmentos, sem alterar sua geometria. Sulcos precisam seguir a tangente; nao criar trilhos duplos universais.
- Rocha: juntas conectadas esparsas, planos iluminados pela inclinacao, fissuras secundarias nas zonas de fratura e microclusters minerais. Nao espalhar pedrinhas uniformemente nem desenhar uma malha completa de celulas minerais.
- Diagnosticar diferenca entre contorno do pe da rocha e footprint fisico. Nunca esconder a diferenca com materiais nem corrigir colliders silenciosamente.
- O laboratorio 04 compara apenas finais A/B/C e Marco03 A; nao carrega os nove estados de comparacao. `FinalOnlyVisuals-A.prefab` e candidato visual sem controlador, baseline ou fisica. O host mantem WorldRegion/colisao. Streaming de chunks ainda precisa de implementacao; nao declarar que a exportacao de um prefab o implementa.

```powershell
python Tools/ArtPipeline/WorldGen/material_refinement.py library --output Temp/Materials/new-refined-library
python Tools/ArtPipeline/WorldGen/material_refinement.py recipes --output Temp/Materials/new-refined-recipes
python Tools/ArtPipeline/WorldGen/terrain_materials.py generate --recipe ArtSource/Labs/World2026/WorldStudio04/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio04/Library --output Temp/Materials/new-refinement
python Tools/ArtPipeline/WorldGen/terrain_materials.py verify --recipe ArtSource/Labs/World2026/WorldStudio04/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio04/Library --output ArtSource/Labs/World2026/WorldStudio04/BuildR6/A
```

As formas de desgaste da estrada usam o alfa das fontes Aseprite projetado no percurso com nearest; cores e realces sao reconstruidos na paleta e luz mundiais. Isto orienta geometria de pincel, nao gira highlights de um sprite preiluminado. Pedrinhas e plantas mantem orientacao autorada.

Integração aquática: `world-hydrology` fornece máscaras e fronteiras explícitas; leia `Docs/WorldGen/WorldHydrologyContract.md` e `EnvironmentBoundaryContract.md`. Preservar receitas/materiais04; autoria de água é um módulo separado, com revisão física documentada no laboratório05.


Para construções, use `environment-architecture` e `Docs/WorldGen/ArchitectureContract.md`. Esse consumidor mantém os produtores por hash, acrescenta footprint/acesso e registra exclusões da vegetação em revisão própria; não desloca água, estrada ou relevo para encaixar edifícios.


## Direção central vigente — World Studio09

Antes de produzir ou revisar arte ambiental, ler [ValdoriaVisualLanguage](../../../Docs/Art/ValdoriaVisualLanguage.md) e, para construções, [ArchitectureStyleGuide](../../../Docs/Art/ArchitectureStyleGuide.md). A casa07R orienta acabamento, luz e escala; fontes aprovadas ficam preservadas, revisões09 são candidatas. Não aplicar saturação/tint global nem alterar geometria para resolver cor. Exportar pixels reais do Aseprite e guardar comparações Game View na pasta de validação do projeto.
