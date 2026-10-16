---
name: aseprite-pixel-art
description: Criar, editar e exportar pixel art e animações do MMORPG com o Aseprite local, CLI e Lua, preservando os contratos de importação Unity.
---

Use somente o executável local e Lua para esta produção artística. Não usar PixelLab, ImageGen ou geração externa/paga. A partir da raiz do repositório, leia `Docs/Art/AsepriteWorkflow.md` para comandos e limitações verificadas.

Antes de preparar arte para produção, leia `Docs/Art/ProductionAssetContract.md`, `HeroAnimation.md`, `WeaponAttachment.md` e `ProductionPipeline.md` em `Docs/Art/`, além de `Docs/Validation/Marco06B5.md` e `Marco06B6.md`.

## Ferramentas

- Detectar: `python Tools/ArtPipeline/Aseprite/aseprite.py locate`. Prioriza ASEPRITE_EXE e PATH; verifica instalações Windows/Steam e a instalação local conhecida. Não copiar binários/licenças nem instalar automaticamente.
- Validar em temporários: `python Tools/ArtPipeline/Aseprite/aseprite.py validate`.
- Criar laboratório: operação `lab --output <novo.aseprite>`.
- Exportar: operação `export --source <documento.aseprite> --output <diretorio-novo>`; produz frames PNG, sheet horizontal, JSON, GIF e QA. `verify --output <diretorio>` verifica o contrato de canvas do herói. Requer Python/Pillow já usados pelo ArtPipeline.
- CLI direta: `& Tools/ArtPipeline/Aseprite/Invoke-Aseprite.ps1 -b <entrada> --save-as <saida>`. A ordem das opções importa; use argumentos separados e caminhos absolutos quando estiver fora da raiz.

## Autoria

Use `Sprite(96,96,ColorMode.RGB)` para RGBA, `newLayer()`, `newEmptyFrame()`, `Image`, `newCel()` e `frames[i].duration` em segundos. Leia o exemplo executável `Tools/ArtPipeline/Aseprite/walk_lab.lua`; `inspect.lua` demonstra leitura real de frames/camadas. Edite cópias ou novos documentos; recuse sobrescrever originais. Não reexecute o gerador sobre trabalho manual.

Mantenha paleta, proporções, canvas inteiro e pixels inteiros; não converter para indexed nem escalar fracionariamente sem intenção explícita. Organize partes em camadas e use tags como `walk_south`, `walk_west`, `walk_north`, `walk_east`; não espelhe equipamento assimétrico. A nova identidade artística pode diferir do herói antigo, desde que consistente. Mantenha espada separada.

Guias de chão, pivô e mãos ficam ocultas nas exportações. Use origem superior esquerda: pivô (48,70), chão de referência (48,88); marque mão direita e esquerda individualmente em cada frame. Marcadores do laboratório são experimentais, não âncoras aprovadas. Exporte metadados de attachment revisados para o manifesto existente; o JSON nativo do Aseprite não é um manifesto ProductionCharacterSet.

Revise a animação em loop, em tamanho nativo e nearest inteiro: contato, passagem, peso, continuidade da cabeça/roupa, retorno último→primeiro e contato da mão com a arma. PNGs distintos não comprovam animação convincente. GIF é prévia; preserve alfa nos PNGs. Declare desenho manual e validação artística pendentes quando aplicável.

## Unity

Fontes experimentais ficam em `ArtSource/Labs/Aseprite`, fora de Assets. Somente após revisão prepare os PNGs e manifestos conforme o contrato: 32 PPU, 96×96 para herói, pivô e mãos por frame, durações, hashes e status explícito. Sem trim automático: altera coordenadas. Mão Unity = ((handX-pivotX)/32,(pivotY-handY)/32); pivô normalizado = (x/width,1-y/height).

Use o importador existente `ProductionArt06B4.Import`, SpriteRenderer Point, sem compressão/mipmaps, preservando GUIDs e ProductionSpriteAnimator. Nunca execute `production.py` para atualizar desenhos: a migração B3 pode sobrescrever fontes. Não duplicar importador nem alterar física para compensar arte. Se uma tarefa futura exigir Editor, siga AGENTS.md e a skill unity-cli; esta configuração não abre Unity.

Referências oficiais: [CLI](https://www.aseprite.org/docs/cli/), [scripting](https://www.aseprite.org/docs/scripting/), [API Lua](https://www.aseprite.org/api/).
