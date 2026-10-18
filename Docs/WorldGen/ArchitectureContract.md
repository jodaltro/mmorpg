# Architecture Contract v1

## Referências Barn/Castle — extensão 08

Após aprovação visual da casa 07R e autorização explícita para os dois modelos seguintes, o exportador compartilhado aceita `sourceFile`, `canvas`, `layers`, `roles`, `groundLayers` e posição de lote nos metadados de autoria. Campos opcionais preservam os defaults 07R. Aseprite continua sendo a autoridade dos pixels; expansão de parâmetros não é um gerador universal de formas.

O celeiro consome o mesmo contrato de região/lote/acesso/exclusões do 07R. O build pode receber posição explícita sem mudar metadados artísticos; a posição efetiva e seed ficam em `house.json`. Neste estudo seed 810801, posição geográfica (38,5;45,5), terreno original intacto.

O castelo usa `valdoria-authored-architecture-review/v1`: pátio técnico 80×80, `reviewOnly=true`, **siteQA.worldLotAccepted=false**, seed 810802. Não é WorldRegion novo nem implantação ambiental aprovada. Fornece posição, sete footprints físicos, poses de revisão, percurso portão–pátio–aproximação do keep, cinco `depthGroups` e navegação .25 u. Sua colocação futura exige uma decisão explícita de região/plataforma; não aplanar nem ampliar a região existente silenciosamente.

`footprints` são polígonos em união para navegação e física. Cada polígono cria um `PolygonCollider2D` independente no chão. Uma única instância com contornos sobrepostos mostrou lacunas no teste real; não presumir equivalência de representações. O contorno `footprint` externo é guia de apresentação, **não** bloqueia o pátio inteiro. Vãos do portão permanecem livres sob a parte visual superior.

`depthGroups`: ID, parts e outline geográfico de cada volume. Reutilizam SortingGroup/ReferenceHouseDepth por volume, com fallback de profundidade na frente do próprio volume quando X está fora do seu outline. KeepWalls/KeepRoof/KeepDoor compartilham profundidade; torres, arco e muralha têm regras próprias. Fundamentos preservados opacos; CourtyardFloor/Shadow são chão fora dos grupos. Transparência por bounds ainda é aproximada, sem faces ocultas pintadas, interiores, escadas ou andares jogáveis.

Detalhes, fontes e evidências em `Docs/Validation/ValdoriaWorldStudio08-BarnAndCastle.md`. Celeiro e castelo continuam candidatos à avaliação visual; a casa anterior aprovada não lhes transfere aprovação.

## Extensão autorada 07R — prioridade visual vigente

A arte A/B/C do Marco 07 foi rejeitada pelo usuário. As gramáticas geométricas descritas nas seções históricas abaixo permanecem como contexto de engenharia, **sem aprovação estética**. O 07R entrega uma referência autorada e não amplia a biblioteca. A porta fixa de 5 u e a projeção antiga não são requisitos da nova fonte.

- `valdoria-authored-house/v1` (`SourceV1/house-source.json`): canvas, PPU, âncora, camadas, contornos anotados de chão/volumes, abertura da porta, escala do master, estudo escolhido e proveniência. Os contornos são dados de autoria revisáveis; alpha da imagem não vira collider automaticamente.
- `valdoria-authored-house-export/v1`: doze partes efetivamente lidas de `rural-reference.aseprite`, recortes e offsets preservando âncora. A fonte é a autoridade dos pixels. Exportar não chama ImageGen, Blender ou `architecture_art.py`. `valdoria-authored-house-art-build/v1` assina fontes/metadados/exports. Imagem assistida por IA é uma etapa de design arquivada, sem promessa de regeneração bit a bit pelo modelo; export da fonte e build semântico são reproduzíveis.
- `valdoria-authored-house-region/v1`: uma casa, ID/seed, posição, footprint de seis vértices, frente projetada, entrada, aproximação, acesso e QA do lote. O seed registra o build; uma referência e um lote explicitamente autorados não mudam de desenho a cada seed. `valdoria-authored-house-region-build/v1` assina outputs e contratos produtores. `RegionV1/Vegetation/manifest.json` também é validado pelo importador: apenas A é regenerado pelas exclusões, bosque B e juncos C são consumidos como seleções imutáveis.
- Navegação reutiliza `valdoria-architecture-navigation/v1`, grade analítica .25 u, ocupação do polígono mais footprints de plantas e base ambiental; não inclui inflação do ator. Acesso precisa manter .57 u de clearance final. Não há alteração de topografia, água ou Organic Roads.

Espaço da anotação: pixels do master 1254², convertidos pela escala 966/1254 e âncora nativa; coordenadas geográficas x leste/y sul e Unity=(x,48-y). Porta medida 154,8373 px / 32 = 4,8387 u; corpo visível Quaternius 117 px × 1,25 / 32 = 4,5703 u. Medida de altura aparente, sem afirmar metros anatômicos ou um piso 3D.

`ReferenceHouseDepth` substitui a linha horizontal única na referência: para cada X do ator, calcula a interseção frontal mínima em Y Unity do footprint; `SortingGroup=100-round(frontY×16)`. Ator atrás e bounds visuais sobrepostos: telhado/beirais/chaminé .18, paredes/vigas/aberturas .28, fundação/sombra conservadas. É uma aproximação para **um protagonista e uma orientação**, com bounds por parte; não é oclusão exata por pixel ou interior reconstruído. Physic footprint continua bloqueante mesmo com alpha reduzido. Telhado não tem collider.

Integração: `ArchitectureArt07RImporter` clona Vegetation Lab em destino novo e recusa sobrescrita; cena `ValdoriaArchitectureArtLab07R.unity`. Comparação antiga A é um rig visual desativado, sem collider nem instância de edifício. Não altera `MmorpgWorld.unity`. Recomposição/export jamais redesenha sobre a fonte Aseprite. Modularização posterior requer aprovação artística; ver `Docs/Validation/ValdoriaWorldStudio07R-ArchitectureArt.md`.

Geradores: environment_architecture.py e architecture_art.py. Skills: environment-architecture e aseprite-pixel-art. Integração: ArchitectureStudioImporter, ArchitectureBuilding, ArchitectureOcclusion e ArchitectureRegionData. Autoria offline, sem geração no Play.

## Produtores e autoridade

Consome por SHA-256 WorldRegion, Organic Roads/coverage/navigable, Terrain Materials/composição/relevo, Water Agent/geometria/navegação, biblioteca Vegetation06 e manifests A/B/C. Context valida as referências comuns. Não escreve topografia, água, estrada ou biblioteca/receitas aprovadas de vegetação. Cada nova retirada de plantas produz exclusões e novas receitas/outputs do consumidor, mantendo as fontes anteriores.

## Receitas

`valdoria-architecture-recipe/v1`, generator environment-architecture/1.0.0: seed inteiro, actorRadius, accessRadius, minimumBuildingGap, groveRect e um a três sites com IDs únicos, archetype, guide e searchRadius. Guia válido é mantido; candidatos alternativos são pesquisados por seed quando necessário. Trocar seed não obriga um guia explícito válido a mudar de posição. Sem rotação/espelhamento automático: orientação única autorada sudeste.

`valdoria-architecture-art-recipe/v1`: seed, três archetypes com width/depth/wallHeight/roofRise/lift e identidade/material do telhado. Intervalos de dimensões são validados; portas mantêm 2.2×5 u para a escala visual atual do Quaternius. Alterar dimensões exige novo library e nova análise de lotes/consumidores. Sem inferir altura 3D do ator a partir do sprite.

## Gramática artística e edição

Fontes A/B/C.aseprite, RGBA 512², um frame, dez camadas: sombra, fundação, paredes, vigas, portas, janelas, telhado, chaminé, varanda e acabamentos/dormer. Módulos opcionais vazios são omitidos. A tem anexo baixo, B dormer e cobertura lateral, C base ventilada e varanda. Não são apenas recolorações da mesma caixa; ainda são três gramáticas de exterior, não qualquer planta arquitetônica.

Três fontes de abertura reutilizáveis: module-door-arched.aseprite, module-door-square.aseprite, module-window-timber.aseprite. `library --modules-source` lê esses pixels editados no Aseprite e os recombina na gramática. `export-library` exporta as fontes completas efetivamente editadas, sem redesenhar os módulos. Um novo bake exige destinos ausentes. Não editar cópias intermediárias PNG esperando que elas substituam automaticamente a fonte Aseprite.

`valdoria-architecture-modules/v1`: partes com ID, archetype, função, arquivo RGBA, sourceRect, trimmedFile e offsetUnits. O recorte preserva âncora (240,438) a 32 PPU. Luz superior esquerda, Point, sem mips/compressão. library manifest assina fontes, metadados e exports. A receita artística controla volumes do gerador; as paletas são editáveis nas fontes; a troca arbitrária de qualquer telhado entre dimensões incompatíveis não é suportada.

## Espaço e footprints

Entrada geográfica x leste/y sul em unidades de mundo, região 64×48. Unity=(x,48-y). A gramática projeta coordenadas de autoria (x,z,h) para o pixel (240+32(x+.5z),438+16z-32h). O footprint físico usa a mesma projeção de chão (x+.5z,.5z), sem componente de altura. A altura do prédio afeta somente volume visual. Escadas/embasamento elevado são apresentação exterior: não alteram Y físico, não dão acesso a um segundo piso e não implementam subida 3D.

`valdoria-architecture/v1`: generator, seed, sizeUnits, inputs, ecotone e buildings. Cada edifício fornece ID, seed, archetype, position/orientation/groundAnchor, dimensions, footprint, porchPosts, bounds, entry, approach, doorWidth/Height, parts e siteQA. O teste de ocupação inclui pontos exatamente na borda (tolerância de 0.00001 u para a precisão float da Unity). Footprint é uma casca exterior fechada bloqueante (PolygonCollider2D); varanda tem pequenos círculos de postes. A porta permanece fechada e não é um portal. Nenhum collider corresponde ao retângulo do telhado.

Os lotes são validados em amostras de .5 u num bounds conservador com .75 u de margem: limite de declive normalizado .065, variação de altura .13, ausência de água/rocha/reserva e distância da estrada. Limite de margem: .75 u na cabana e 2 u nas demais. Não são cálculos geotécnicos, graus de inclinação ou cota de cheia. Floodplain é apenas margem conservadora sobre a hidrologia estática existente; não há previsão de inundação. Consumidores críticos devem usar também limites e footprint analíticos, especialmente postes menores que a grade.

## Acessos e vegetação

Cada prédio tem approach fora da fachada e access.points conectando essa aproximação à cobertura existente da estrada. Dijkstra em oito vizinhos, sem cortar cantos, sobre navegação ambiental menos os prédios; clearance .7 u e suavização limitada por esse clearance. O acesso final combinado é novamente verificado contra a vegetação e raio do ator .45 u + margem .12. Pontos são contínuos; a grid .25 u é o modelo de análise, não uma malha de rua nova.

O acabamento de chão do acesso pertence ao Architecture Agent: texturas locais recortadas por caminho, sem alterar o artefato Organic Roads. access-render.json informa arquivo, rectPixels e origem Unity. Não é um único panorama da região. A superfície visual não muda física.

`valdoria-architecture-vegetation-exclusions/v1`: retângulos de clearance de construção/copa e envelopes de acesso, seed e consumerEffects por A/B/C. Recipes/outputs de vegetação ficam sob o build novo. Regenera-se o consumidor inteiro de vegetação, não só plantas dentro do retângulo: competição pode propagar mudanças. Registrar old/new counts, IDs iguais e IDs removidos/reposicionados. Nunca afirmar estabilidade externa ao patch sem comparação real.

Composição final: A fora do groveRect, B apenas dentro, juncos de C; competição final remove conflitos entre conjuntos. IDs recebem prefixo da composição. vegetation.json registra sourceBuilds por path/hash; verify/importador validam a cadeia até os manifests de consumidores regenerados. Outros especialistas não são regenerados.

## Navegação, sorting e oclusão

`valdoria-architecture-navigation/v1`: size, stepUnits=.25, architectureBlocked, walkable combinado e componentCount; row-major y norte para sul. actorClearanceIncluded=false. ArchitectureRegionData substitui o overlay VegetationRegionData no laboratório, sem duplicar autoridades. Dados originais EnvironmentRegionData permanecem a base. Consumidores futuros devem inflar footprints pelo ator e não supor que centros de células cobrem postes finos.

SortingGroup por edifício: 100-round(groundUnityY×16). Partes têm ordem local, sombra fora do grupo no chão. ArchitectureOcclusion reduz alpha de telhado/chaminé/dormer a .18 e volumes superiores de fachada a .28 quando os pés estão atrás da âncora e a projeção da cabeça intercepta bounds visuais. Fundação/varanda permanecem. Transição temporal de alpha; restaura ao sair. É cutaway exterior para leitura do protagonista, sem revelar interior completo. QA testa frente/lado/trás e colisão separadamente.

## Integridade e handoff

Build manifest assina outputs principais e inputs, incluindo biblioteca e manifests produtores. Cadeia de consumidores também deve ser verificada. Caminhos de proveniência internos variam com o diretório de geração: reconstrução compara bytes físicos/arte e semântica após normalizar apenas sourceBuilds; cada manifesto interno continua verificável contra suas referências reais. Não normalize seeds, pontos, colliders ou arte para fazer testes passarem.

Climate pode fornecer cota de cheia versionada no futuro; Water mantém a autoridade sobre profundidade/vau. Vegetation consome exclusões antes da distribuição; Structures pode acrescentar muros/cercas com footprint próprio e preservar acesso. Nenhum consumidor pode bloquear uma entrada ou plantar dentro de footprint pelo fato de o telhado ser transparente.

Cena/arte experimental recusam sobrescrita. Nenhuma promoção ao mundo oficial nem aprovação artística automática. Veja Docs/Validation/ValdoriaWorldStudio07-Architecture.md para evidências reais e limitações.
