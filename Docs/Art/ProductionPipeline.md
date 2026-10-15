# Pipeline de produção — 06B.4

Fontes e contexto: [AnimationPipeline B3](AnimationPipeline.md), [contrato B4](ProductionAssetContract.md), [limitações do herói](HeroAnimation.md).

## Reprodução

Na raiz do projeto, com Python/Pillow já disponíveis:

```powershell
python Tools/ArtPipeline/production.py
python Tools/ArtPipeline/production_verify.py
unity command recompile --caller plugin --skill unity-pipeline --format json
unity command recompile_status --caller plugin --skill unity-pipeline --format json
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/ProductionArt06B4.cs --entry ProductionArt06B4.Import --timeout 120 --timeout_ms 110000 --format json
```

`production.py` migra os desenhos B3 existentes para nomes explícitos, adiciona âncoras revisadas e dois retoques localizados de luva. Não gera novas fases de movimento. Ao receber desenhos externos finais, editar os PNGs/manifestos de `ArtSource` e executar **Import**, sem reexecutar a migração B3 que regeneraria as fontes provisórias. `production_verify.py` valida o conjunto migrado (hash, RGBA, canvas, pivô, mão visível, duração, contagem e unicidade). Para novas fontes, atualizar também o hash de proveniência intencionalmente.

`ProductionArt06B4.Import` usa a API instalada Unity 6000.6.5f1 (`ISpriteEditorDataProvider`). Verifica capacidades para nome/rect/pivô/criação; mantém SpriteIDs e pares nome/fileID quando já existem. Cada PNG de personagem tem um SpriteRect explícito de canvas inteiro; não usa grade sobre atlas irregular. Arma/VFX usam Single com pivô explícito. Point, 32 PPU, FullRect, Clamp, alfa, mipmaps off, uncompressed e limite 2048. Reimportar conserva `.meta`/GUIDs; nunca edita metadados por texto.

O importador rejeita PNG ausente, numeração ambígua, dimensões divergentes, contagem/duração inválida e eventos de gameplay não autorizados. Gera/atualiza `ProductionCharacterSet`, AnimationClips e marcadores de apresentação. As curvas de sprite são exportadas para revisão/reutilização; na cena, o controlador equivalente seleciona sprite e attachment juntos. Não ativar outro Animator no mesmo corpo simultaneamente.

Saídas: `Assets/Mmorpg/Art/Production/{Hero,Wolf,...}`, `Animations`, `Auxiliary`, `Prefabs/PlayerVisualB4.prefab`. Foram migradas 92 entradas de personagem/criatura; não são 92 desenhos novos nem todas sequências aprovadas. VFX/espada migrados mantêm os desenhos B3. Props, pisos e ícones têm catálogos em `ArtSource/Environment`, `Terrain`, `Interface`; os assets/referências B3 continuam sendo utilizados no cenário/HUD.

## Cena e prefab

```powershell
# Só uma vez, com B3 salva e limpa aberta: recusa sobrescrever uma B4 existente.
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/ProductionArt06B4.cs --entry ProductionArt06B4.CreateScene --format json
# Com B4 aberta fora de Play:
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/ProductionArt06B4.cs --entry ProductionArt06B4.Integrate --format json
```

Integrate altera apenas a cena B4, recria seu grupo `SessionToolsB4`, atualiza referências e o prefab visual sem lógica de autoridade. Prefab contém `ProductionVisualDefinition`, corpo, arma e sombra; integração de atores fornece motor/saúde existentes. As cenas anteriores não são regeneradas. B4 é adicionada às cenas de build para permitir reload por caminho; a ordem inicial anterior não é alterada.

## Câmera e HUD

URP 2D Pixel Perfect instalado, 32 PPU, PixelSnapping, sem HDR/MSAA/AA. `AdaptivePixelViewport` escolhe escala inteira `max(1,height/360)`; a partir de 480 px usa no mínimo 2. Resolução lógica adaptativa é o tamanho da janela dividido pela escala, arredondado para par. Windowbox deixa somente o resto necessário a pixels inteiros. A área de mundo visível varia com a janela, sem esticar sprites. 1280×720 resulta 640×360 a 2×; 1920×1080, 640×360 a 3×. Janelas menores podem mostrar menos mundo.

CameraFollow mantém suavização e grade de 1/32. B4 limita o centro às dimensões gerais do Ground para reduzir vazio nas bordas externas. Esse retângulo não elimina todo vazio em corredores entre regiões; expansão de cenário continua incremental. A HUD conserva vida/slots/cooldowns/contexto/região. Mensagens curtas desaparecem em 5 s; longas vão ao histórico limitado de seis mensagens no Diário. Não foi refeito todo o sistema de UI.

## Atualização 06B.5

Não executar `production.py` como rotina de atualização: a migração B3 pode substituir fontes de produção editadas. O 06B.5 não executou essa migração nem reimportou/desenhou por cima dos assets. Use `ProductionArt06B4.Import` para fontes/manifestos intencionalmente revisados. Os clips de fase opcionais `attack-preparation`, `attack-cut`, `attack-recovery` usam a mesma estrutura de manifesto, duração individual e eventos exclusivamente visuais.

`AgentScripts/ProductionAnimation06B5.cs`, entrada `CreateScene`, exige B4 limpa, fora de Play, e recusa destino existente. Copia a cena completa para B5 e adiciona apenas essa cópia às cenas de build. Não chama `Integrate` B4 nem recria regiões/prefabs. A cena inicial anterior permanece na mesma ordem.

`AgentScripts/InspectAnimation06B5.cs` contém inspeções curtas por input real do Input System, perfil isolado em Temp e captura `ScreenCapture.CaptureScreenshotAsTexture` após WaitForEndOfFrame. Execute Prepare fora de Play, editor_play, Setup, Movement, Attacks e Combat; pare Play e execute Cleanup. Game View deve estar renderizando. Attacks usa timeScale 0,35 somente para evidência lenta; Combat e Movement usam 1. Cleanup restaura input e opções do Editor. Não executar suítes extensas neste marco.

`Tools/ArtPipeline/gameplay_previews_b5.py` monta GIFs de capturas reais com metadados, recorte de acompanhamento e nearest. Não desenha poses nem simula gameplay. As prévias e os relatórios ficam em `Docs/Validation/Marco06B5`; fontes PNG brutas podem ser arquivadas localmente em `Temp/Marco06B5/Captures` após a montagem.
