# Ground13 — produção e revisão

Esta rodada usa [o contrato de apresentação](../WorldGen/Ground13PresentationContract.md) e mantém as referências aprovadas. Não reconstruir casas, Nature10, Ground11 ou a vegetação Ground12 para adaptar um mesh de relevo.

## Forma antes do pigmento

1. Confrontar o campo escalar, os contornos físicos e as capturas da mesma câmera. Separar pé da parede, ombro, topo e faces voltadas para a câmera.
2. Editar `ArtSource/Labs/World2026/Ground13/recipe.json`: cortes de planos em coordenadas do mundo, limiares e alturas **de apresentação**. Não interpretar esses números como altura física. Manter `physicalChange=false`.
3. Gerar em destino novo com `python Tools/ArtPipeline/WorldGen/ground13.py relief --output Temp/Ground13-Rebuild/Relief`.
4. Avaliar o estado 3 do laboratório, sem textura. O material mineral não deve esconder uma silhueta insatisfatória. A primeira interpretação concêntrica e as paredes posteriores sobrepostas foram rejeitadas internamente; V3 descarta faces ocultas e mantém os pés completos para QA.
5. Validar textura e escala na Game View. A frequência da grama superior e a regularidade residual dos patamares continuam pontos de avaliação artística. Não elevar a complexidade física para corrigir uma impressão visual sem autorização.

Blender não foi necessário nesta rodada: a representação subcélula existente fornece as seções e o laboratório mostra os planos sem textura. Não foi produzido nem apresentado render externo como captura de Unity.

## Aseprite e água

`SourceV2` é a fonte final editável: `stratified-face.aseprite`, `upland-sward.aseprite` e `water-material.aseprite`. Os dois primeiros preservam fontes anteriores em cópias; esta rodada trabalha principalmente a interpretação por face, em vez de substituir pigmentos aprovados. Água: cinco layers, quatro frames, 180 ms. Editar massas e intervalos calmos, não pulverizar brilho.

`ground13_refine_sources.py` conserva o procedimento de edição SourceV1→V2. Ele recusa destino existente. Não executá-lo sobre uma fonte posteriormente refinada pelo artista. `ground13.py export` lê os pixels finais, sem redesenhá-los.

Reconstrução verificável em destinos vazios:

```powershell
python Tools/ArtPipeline/WorldGen/ground13.py export --output Temp/Ground13-Rebuild/Export
python Tools/ArtPipeline/WorldGen/ground13.py atlas --output Temp/Ground13-Rebuild/Atlas
python Tools/ArtPipeline/WorldGen/ground13.py relief --output Temp/Ground13-Rebuild/Relief
python Tools/ArtPipeline/WorldGen/ground13.py water --output Temp/Ground13-Rebuild/Water
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_ground13.py -v
```

A geração de água usa `ExportV2` versionado por padrão. Para experimentar uma fonte diferente, chamar `water(..., library=novo_export)` em Python e manter um manifesto separado. Fonte, exportação e receita aprovadas não são recriadas a cada Play.

## Integração e agrupamento

`Ground13Importer` importa somente destinos ausentes. A cena entregue é `Assets/Mmorpg/Scenes/ValdoriaGround13RefinementLab.unity`; para nova revisão, definir novos caminhos `Art`/`Scene` antes de executar `AgentScripts/BuildGround13.cs`, entrada `BuildGround13.Main` pela Unity CLI conectada. A importação limpa já lê ReliefV3. Texturas: Point, RGBA32, sem mipmaps/compressão/reescala NPOT. UVs do relevo são em escala 32 PPU; âncoras e pivôs de objetos permanecem originais.

O atlas UV explícito de 1024² conserva os texels. Meshes de plantas só podem compartilhar o mesmo layer/order. Reexecutar a proteção de sobreposições ao mudar a distribuição ecológica. A lista dos 16 renderers não agrupados desta região é resultado da análise, não uma allowlist fixa. Conferir os estados 1↔2 e 4↔5 por diferença de pixels e em movimento. Não agrupar copas/cutaway ou sprites do personagem com o chão.

O atlas economiza chamadas e aumenta a memória de texturas ativas em cerca de 6,72 MB neste enquadramento. As duas texturas minerais de região inteira são substituídas por amostras 384² reutilizáveis, responsáveis pela redução líquida de memória. Não confundir atlas com economia automática de RAM.

## Evidências

`CaptureGround13`, `MeasureGround13Candidate`, `CaptureWaterGround13`, `ValidateGround13Candidate` e `Ground13CliffQA` produzem PNGs de Play real e traces. Usar perfil isolado, Game View 1600×900, câmeras documentadas e restaurar dispositivos/configurações ao terminar. `Nature10View.Begin/End` cria/remove a resolução temporária fora do Play.

O índice é reconstruído por `ground13_evidence.py`; os recortes existentes precisam continuar idênticos aos originais. `reviewName` permite nomes únicos para capturas com o mesmo basename em diretórios distintos. O pipeline compartilhado `review_lite.py` conserva as regras Ground12: PNG, máximo 750 KiB, transformações equivalentes nos pares, nearest e sem dithering. Redução/quantização exigem inspeção visual além dos testes. Não editar originais para satisfazer o limite.

Fontes editáveis e decisões de forma/luz são responsabilidade artística. Exportação, posicionamento contextual, recortes, atlas, hashes e verificações são reproduzíveis. Testes não concedem aprovação estética nem autorização para alterar topografia.
