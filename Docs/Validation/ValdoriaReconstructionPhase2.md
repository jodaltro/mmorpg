# Valdoria — reconstrução Fase 2

17/10/2026 · Unity 6000.6.5f1 · branch `main` · baseline `e10007a`.

**Entrega: área-piloto funcional candidata. Aprovação artística pendente.** A composição v3 permanece como fundo; o mundo ainda não é um conjunto de módulos independentes com chão reconstruído sob os objetos. Não foram implementados outros biomas, interiores ou geração a cada Play.

## Protagonista e remoção do legado

O commit `3db0124` moveu, pelo AssetDatabase, `IronKnight/PlayerVisual.prefab` para `Assets/Mmorpg/Art/Production/ValdoriaProtagonist/PlayerVisual.prefab`. GUID preservado: `11c15445266e03141a9f8ec3d3f3d0db`. Default: `ValdoriaProtagonist.asset`, 64 clips, 528 frames. Corpo, espada separada, máscaras procedurais dos dedos, sombra, Rigidbody2D e collider existentes foram mantidos. A raiz física continua em escala 1 e VisualRoot em 1,25 na cena oficial.

A auditoria do commit removeu as duas cenas Wardrobe do Build Settings, consumidores de vestuário obsoletos, seis ferramentas Iron Knight B9–B12 e assets IronKnight sem consumidores. O manifesto de autoria/licença em ArtSource foi preservado. `MmorpgWorld.unity` permanece a primeira cena habilitada. Não há mais necessidade de prefab sob caminho IronKnight.

## Biblioteca e reprodução

O commit `b2190c7` consolidou os 19 módulos R10Llm, manifesto e metas. Nesta continuação, `rebuild_valdoria_r10.py --verify` efetivamente reconstruiu **todos os 19**, conferiu hashes publicados e comparou os pixels com a biblioteca. Reconstruiu também o backdrop da biblioteca e o de produção: ambos idênticos ao topo 1536×800 da fonte Aseprite 1536×1024 `valdoria-village-detail-v3.aseprite`.

A fonte dos módulos é o documento irmão `valdoria-llm-detail-clean.aseprite`; os módulos não são recortes do panorama v3. Essa diferença explica, por exemplo, casa modular de palha versus casa de telhas azuis do mundo. Não se deve sobrepô-las.

O comparador foi corrigido: diferenças RGB não podem desaparecer quando o delta de alfa é zero. Um caso de regressão com RGB diferente e mesmo alfa foi executado e rejeitado corretamente. A ferramenta histórica de crop agora recusa uma biblioteca publicada existente. Exportações novas recusam destinos existentes.

[Relatório dos 19 módulos e backdrops](ValdoriaReconstructionPhase2/library-rebuild.json).

## Blueprint e construção

[Receita editável](../Art/ValdoriaWorldBlueprint.json), schema v2: ID, tipo, posição/âncora em pixel do backdrop, pivô, tamanho aparente, variante, seed e footprint. O builder `AgentScripts/BuildValdoriaPhase2.cs` projeta essas coordenadas pelo Transform e pivô reais do SpriteRenderer, sem fórmulas históricas aproximadas.

O root `ValdoriaPilotArea` contém poço, casa, árvore, cerca, caminho e jardim. A receita não extrai colisão de pixels escuros. `PolygonCollider2D` usa os footprints de autoria; cobertura/copa não criam bloqueios físicos.

Antes de substituir o root antigo, a auditoria dos 23 IDs de cena encontrou somente o consumidor SceneRoots, sem consumidores externos. A árvore do piloto anterior estava sobre o caminho. A casa tinha um telhado de palha sobre a composição azul e âncora nula. Esses elementos foram substituídos pela descrição coerente da composição.

Também foram desativados cinco objetos de cenário legados (`TreeEast` e quatro `Árvore cinzenta`), com somente Transform/SpriteRenderer/BoxCollider2D, que introduziam obstáculos na área nova. O dressing `Art06B3Details` foi desativado. Recursos e narrativa existentes não foram removidos. O maze SolidBoundaries já havia sido desativado pelo commit `b755bb4`.

## Física e profundidade

- **Poço:** footprint irregular somente na base de pedra/barril, sem bloquear a cobertura.
- **Casa:** polígono da base/paredes projetadas, incluindo fachada fechada. Não há portal falso para um interior inexistente. Porta desenhada permanece pequena em relação ao personagem, com revisão artística pendente.
- **Carvalho:** base/raízes sem collider da copa. A posição foi alinhada ao carvalho real da imagem.
- **Cerca:** polígono estreito seguindo o segmento diagonal desenhado, com rota livre ao sul.
- **Caminho/jardim:** sem collider próprio.

`WorldArtSorting`, já existente, ordena as silhuetas pela âncora de chão. Um SortingGroup no VisualRoot mantém corpo, espada, dedos e sombra juntos perante objetos externos; `ProductionVisualSync` transmite a ordem do proxy ao grupo. Não foi mantido outro sistema paralelo de depth.

Três silhuetas RGBA foram produzidas pelo **Aseprite local 1.3.18.6**, mediante polígonos de autoria, sem recorte retangular. A fonte editável está em `ArtSource/Labs/World2026/Phase2/valdoria-depth.aseprite`. `rebuild_valdoria_depth.py --output <pasta-nova> --verify` as reconstruiu em um segundo diretório, com pixels idênticos.

**Limite:** são camadas contextuais alinhadas à composição, com fundo ainda baked. Os contornos não são uma extração artística final; chão sob os objetos e módulos independentes continuam pendentes. Não houve geração de imagem nova.

## Pés, sombra e câmera

O pivô importado (64,34), equivalente a (64,126) em origem superior esquerda, não coincide com a extremidade opaca das botas R8. Medição dos oito idle: final do conteúdo entre y138 e y149, isto é, 12–23 px abaixo do pivô. Foi aplicado **offset de apresentação de 18/32 unidades locais no BodySprite**, com sombra no chão da raiz e sorting pela raiz. Escala física não foi alterada. Essa compensação deixa diferenças por direção de até aproximadamente 0,23 u e precisa de revisão artística, especialmente em esquiva/morte.

Câmera mantida em **7,03125**, follow ativo, viewport `(0,0,1,1)`. PixelPerfectCamera e AdaptivePixelViewport permanecem desativados na câmera oficial; não se afirma pixel perfect inteiro.

## Empunhadura e contrato de unidades

`ProductionFrame.hand` já é local Unity: importadores R8 calculam `((handX-64)/32, (126-handY)/32)`. `SwordSwing.Grip()` aplica TransformPoint no BodySprite corretamente. **Não dividir por 32 de novo.** Isso corrige a interpretação registrada na Fase 1: a remoção da origem LegacyGrip era necessária para separar física e arte, mas os dados de mão não eram pixels crus.

Metadados das oito direções foram inspecionados. O offset de apresentação move mão, corpo e lâmina juntos; os sprites e máscaras aprovados não foram regenerados. Guarda mais avançada, inclinação menos reta e revisão anatômica continuam pendentes. Não foi promovida uma pose nova.

O Sweep permanece exclusivamente em `Rigidbody2D.position`, com dano básico 20, pesado 36, arco/alcance/cooldowns originais. Nenhuma geometria de dano foi alterada.

## QA real e limites dos probes

Editor conectado e cena oficial confirmados, recompile concluído sem erros. O Editor sofreu timeouts/“Hold on”; foi reiniciado e recuperado pelo launcher `unity open`. Backend final novamente DX12. Erros de requisição Pipeline durante recuperação são de infraestrutura.

Os primeiros probes tinham problemas próprios: alvo sintético sem SpriteRenderer; referência destruída após F5; reutilização de perfil temporário contendo morte. Não foram tratados como defeitos do jogo nem como aprovação. O isolamento foi parametrizado dentro de `Temp/`, com recusa de caminhos que escapem dessa pasta. A execução final usa diretório novo e conserva o objeto de isolamento durante F5.

O QA movimenta por Input System real com dispositivos sintéticos. Os oito golpes direcionais usam a autoridade offline real; o pesado usa o botão direito do mouse. Teleportes são somente setup entre casos. Inimigos autônomos são suspensos durante a fixture de geometria e restaurados; circulação contínua dentro de cada percurso usa teclas reais do Input System.

Capturas dos GIFs vêm da câmera **em Play real**, renderizada em RenderTexture depois de avançar frames. Não são capturas Blender/Aseprite. Capturas Game View com HUD são identificadas separadamente. Teste técnico não equivale à aprovação artística.

## Artefatos e pendências

A pasta de evidências conserva resultados compactos, capturas selecionadas e GIFs; frames intermediários e perfis não são versionados. Resíduos locais preexistentes (`test.aseprite`, duplicatas de capturas em Assets/Docs e ValdoriaR10.meta) permanecem fora dos commits.

Pendências artísticas: contorno fino das silhuetas, reconstrução modular independente do fundo, proporção da porta, variação do contato das botas por direção, guarda da espada e substituição dos pequenos recursos/NPCs antigos ainda visíveis. A área-piloto não deve ser apresentada como acabamento definitivo.

## Resultados finais registrados

[QA sobre a cena salva e recarregada](ValdoriaReconstructionPhase2/qa.json): **26/26 verificações, 9.021 frames avançados, sem exceção no probe final**.

| Verificação | Resultado |
|---|---|
| WASD, diagonal, parada/idle | Passaram; direção diagonal 7 |
| Esquiva via Input System | Estado dodge confirmado |
| Básico, oito direções | 8/8, exatamente 20; delta da origem física 0 |
| Pesado via botão direito | Exatamente 36 |
| Fora de alcance / parede | 0 / 0 |
| Poço | Contato com seu collider; distância -0,00261 u (tolerância do solver) |
| Casa | Contato com seu collider; distância -0,00500 u |
| Cerca | Passagem ao sul, 5,82 u percorridas |
| Árvore, atrás / à frente | Grupo do ator -132 / -36, árvore -84 |
| Câmera | 7,03125; viewport completo |
| Morte e F5 | death confirmado; F5 recarregou vivo com 100 HP |

[Probe adicional em perfil novo](ValdoriaReconstructionPhase2/single-hit.json): **J pelo Input System, um único HitConfirmed, 20 de dano, dano recebido durante esquiva = 0**. O alvo usa trigger para não empurrar o ator durante a preparação da fixture. Tentativas anteriores do probe adicional usaram um ator que já havia morrido enquanto o jogo continuava rodando e um alvo sólido que alterava a distância; não foram promovidas como resultado válido.

Console após cursor 47: nenhum erro novo. As 18 entradas anteriores eram das fixtures sem SpriteRenderer; os timeouts Pipeline pertencem às sessões anteriores do Editor. Após a limpeza/recompile, os avisos CS0618 em testes existentes reapareceram; compilação sem erros. O grupo foi confirmado para corpo, espada, dedos e sombra depois de reabrir a cena.

Play foi parado, dispositivos sintéticos removidos, teclado/mouse e backgroundBehavior originais restaurados, timeScale 1, override de perfil nulo, câmera e cena oficiais sem objetos temporários. Autotick já estava habilitado no preflight e foi mantido.

Uma entrada preliminar em Play ocorreu sem override, antes da instalação da fixture, e foi interrompida. Não foi feita certificação byte a byte do perfil pessoal nesta fase; os testes finais usaram somente perfis novos em Temp. Nenhum save é versionado.

## Capturas para revisão

- [Antes, Game View com HUD](ValdoriaReconstructionPhase2/before-hud.png).
- [Depois, perto do poço, Game View com HUD](ValdoriaReconstructionPhase2/well-hud.png).
- [Circulação contínua perto do poço — câmera em Play](ValdoriaReconstructionPhase2/well-circulation.gif).
- [Circulação junto ao carvalho — câmera em Play](ValdoriaReconstructionPhase2/tree-circulation.gif).
- [Árvore pela frente](ValdoriaReconstructionPhase2/tree-front.png) / [por trás](ValdoriaReconstructionPhase2/tree-behind.png).
- [Casa e contato físico](ValdoriaReconstructionPhase2/house-after.png).

Os enquadramentos antes/depois usam posições de teste distintas; não são uma comparação pixel a pixel. GIFs são previews 640×360, 128 cores; PNGs preservam as capturas de revisão. A circulação testa somente os footprints descritos no blueprint: demais cercas, rochas e elementos do panorama ainda exigem conversão semântica.

## Resíduos locais preservados fora dos commits

Seis arquivos preexistentes, sem alteração por esta entrega:

- `ArtSource/Labs/World2026/R10/Aseprite/test.aseprite`
- `Assets/Docs/Validation/ValdoriaProductionR10.meta`
- `Assets/Docs/Validation/ValdoriaProductionR10/gameplay.meta`
- `Assets/Docs/Validation/ValdoriaProductionR10/gameplay/protagonist-scale75.png`
- `Assets/Docs/Validation/ValdoriaProductionR10/gameplay/protagonist-scale75.png.meta`
- `Assets/Mmorpg/Art/Production/ValdoriaR10.meta`
