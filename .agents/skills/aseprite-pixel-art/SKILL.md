---
name: aseprite-pixel-art
description: Editar, inspecionar, exportar e validar fontes .aseprite, pixel art, animações e módulos de cenário do MMORPG usando o Aseprite 1.3.18.6 instalado, os scripts Lua/Python locais e os contratos atuais da Unity.
---

# Pixel art local do MMORPG — Aseprite existente

## Ground12 — direção vigente

Construções07R/08/09, árvores/rochas Nature10 e terreno/estradas Ground11 estão aprovados nos respectivos registros. Ground12 é candidato: ler `Docs/Art/EnvironmentConsolidation12.md`, `Docs/Art/Approvals/Ground12-References-2026-10-18.json` e `Docs/Art/VisualReviewEvidence.md`. Preservar os pixels aprovados; consumir âncoras/fronteiras/footprints existentes. Não alterar física, navegação ou cena oficial nesta rodada. Evidências importantes exigem originais e ReviewLite≤750KiB, manifestos e recuperação remota separada da inspeção visual. Declarações históricas de aprovação pendente abaixo não substituem esses registros.


Esta é a **skill já versionada no projeto**; funciona com qualquer agente capaz de ler arquivos e executar comandos locais, inclusive DeepSeek Harness. **Não requer plugin Aseprite separado nem MCP**. Um Harness que não faça descoberta automática deve ler este arquivo explicitamente antes de qualquer tarefa: `Leia .agents/skills/aseprite-pixel-art/SKILL.md e siga as instruções`. Não alegar que a descoberta, a instalação ou a execução local já foram verificadas.

Trabalhar na raiz `D:\unity\Mmorpg`. Antes de qualquer mudança artística, ler `AGENTS.md`, `Docs/Art/AsepriteWorkflow.md` e, conforme o alvo, `Docs/Art/HumanoidStandard.md`, `Docs/Art/ProceduralWeapons.md`, `Docs/Validation/Marco06B13R10Consolidado.md` ou os contratos históricos citados adiante.

## Contrato atual — não aplicar regras antigas ao Quaternius

| Alvo | Estado e regras |
|---|---|
| Protagonista Quaternius R8/R10 | **Ativo na cena oficial** `MmorpgWorld.unity`; 64 clips / 528 frames, oito vistas; fontes Blender/Aseprite e assets em `ArtSource/Labs/Humanoid2026/` e `Assets/Mmorpg/Art/Production/ValdoriaProtagonist/`. **Não regenerar** a caminhada/figurino/esquiva/Hurt/Death aprovados. |
| Locomoção/ataque humanoide | Frames de referência normalmente **128×160**, 32 PPU, pivô Unity **(64,34)**, pivô em pixel superior esquerdo **(64,126)**; checar o manifesto **do asset usado**, não supor valores globais. |
| Morte R8 | Usa **256×224**, 32 PPU, pivô Unity **(128,66)** para evitar recortes. Padding transparente não aumenta a escala do personagem. |
| Iron Knight | **Histórico preservado**, não protagonista ativo: canvas original 256×256, 32 PPU, sem conversão para 96×96. |
| Walk-lab B3/B4 | **Legado didático 96×96**; pivô (48,70) na origem superior esquerda, chão (48,88). Seu exportador continua disponível para regressão, mas não define os demais personagens. |
| Cenário R10 | Ilustração detalhada 1536×800 tratada como referência/único backdrop; **não** é Tilemap modular nem contém colisões, sorting por objeto ou geometria de navegação. Fontes `ArtSource/Labs/World2026/R10/`. |
| Demais props e NPCs | Verificar **canvas, pivô, PPU, footprint, profundidade e licença individualmente**. NPCs oficiais estão temporariamente ocultos por decisão artística de proporção. |

O grupo visual do protagonista está atualmente em escala 1.25, o cenário em 1.74 e a câmera ortográfica em 7.03125; essas configurações são **candidatas ainda sem aprovação artística**. Não modificar escala/câmera como efeito colateral da exportação Aseprite.

## 1. Preflight local (somente leitura/teste em temporários)

```powershell
cd D:\unity\Mmorpg
git status --short
python Tools/ArtPipeline/Aseprite/aseprite.py locate
python Tools/ArtPipeline/Aseprite/aseprite.py validate
```

O `locate` procura `ASEPRITE_EXE`, PATH e instalações conhecidas; a última instalação registrada é `D:\Aseprite\Aseprite.exe`. `validate` usa temporários e o walk-lab legado **sem modificar PNGs/fontes aprovados**. Requer Python/Pillow. Se falhar, registrar erro e parar; não instalar binários, copiar executáveis/licenças ou simular resultado. Consultar `Docs/Art/AsepriteWorkflow.md`.

## 2. Inspecionar fontes existentes sem alterações

```powershell
python Tools/ArtPipeline/Aseprite/aseprite.py inspect --source "ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-detail-v3.aseprite"
```

`inspect` abre o Aseprite em batch com `Tools/ArtPipeline/Aseprite/inspect_document.lua`, lê canvas, frames, camadas, tags e durações e **não salva** o documento. Funciona com dimensões distintas (não somente 96×96). A inspeção do exemplo acima **precisa ser executada na máquina**; não inferir que o arquivo é legível a partir do nome.

O antigo `inspect.lua` permanece **exclusivo do laboratório 96×96/4 frames/8 layers** e não deve ser usado para inspecionar Quaternius ou cenário.

## 3. Criar, editar e exportar

- **Nunca salvar sobre uma fonte aprovada.** Copiar para laboratório novo com nome e versão explícitos. Distinguir original, nova variante e arte produzida por geração de imagem. Não recalcular fontes antigas por scripts com parâmetros históricos.
- Ferramentas Aseprite locais: `app.activeSprite`, `Sprite`, `newLayer`, `newEmptyFrame`, `Image`, `newCel`, tags e `frame.duration`. Inspecionar `Tools/ArtPipeline/Aseprite/walk_lab.lua` como exemplo **apenas didático**, não como proposta profissional de geometria.
- Para roupas, personagens e equipamentos, preferir as fontes profissionais e Blender/Aseprite do pipeline Quaternius. A mão, dedos, braços, arma separada, oclusão e cortes devem continuar coerentes; **não** substituir animação profissional por poses inventadas/repetidas ou corpo procedimental tosco. A geometria 3D é autoria **offline**, não solver 3D executado na Unity.
- Para cenário, usar Aseprite para acabamento, camadas e peças **modulares** de árvores, poço, casas, telhados, piso e bordas. A imagem composta R10 só fornece referência visual: criar máscaras, footprint, âncoras e colisão semântica **separadamente**, com validação real na Unity.
- Para personagens assimétricos, jamais completar oito direções com espelhamento automático de ombreira/arma. Manter contornos, textura, iluminação e alfa coerentes na escala nativa.

### Exportar um documento de estudo para um destino novo

```powershell
# Exemplo LEGADO 96x96 — somente laboratório existente ou novo:
python Tools/ArtPipeline/Aseprite/aseprite.py lab --output ArtSource/Labs/Aseprite/teste-skill.aseprite
python Tools/ArtPipeline/Aseprite/aseprite.py export --source ArtSource/Labs/Aseprite/teste-skill.aseprite --output ArtSource/Labs/Aseprite/teste-skill-export
python Tools/ArtPipeline/Aseprite/aseprite.py verify --output ArtSource/Labs/Aseprite/teste-skill-export

# Exemplo de canvas humanoide (usar SOMENTE numa cópia de trabalho existente):
python Tools/ArtPipeline/Aseprite/aseprite.py export --source "CAMINHO_DO_ESTUDO.aseprite" --output "ArtSource/Labs/Aseprite/export-128-novo" --canvas 128x160
python Tools/ArtPipeline/Aseprite/aseprite.py verify --output "ArtSource/Labs/Aseprite/export-128-novo" --canvas 128x160
```

Substituir `CAMINHO_DO_ESTUDO.aseprite` por uma fonte **real, de trabalho**. Os comandos `export/verify` esperam frames RGBA de canvas inteiro e sheet horizontal; a opção `--canvas WIDTHxHEIGHT` é obrigatória quando diferente de 96×96. Para morte R8, seria `--canvas 256x224`; objetos de cenário exigem canvas próprio. Essa utilidade não substitui os exportadores específicos R5–R10 nem metadados de armas, pivôs e sorting por frame.

`export` **recusa pasta de destino existente**. O subcomando `verify` escreve `qa.json` no diretório da exportação e portanto deve rodar **somente em laboratórios**, nunca sobre arquivos históricos aprovados. A CLI direta (`Invoke-Aseprite.ps1`) pode sobrescrever saídas: passar destinos novos.

## 4. Contrato de importação Unity

Para cada atlas/variante, medir e documentar:

- `canvas`, `ppu`, pivô, pés/ground contact, âncoras de mão, `holdAngle`/depth, direção, duração dos frames, loop, eventos visuais, origem/licença e SHA-256;
- PNG RGBA real, transparência, `FilterMode.Point`, sem compressão/mipmaps, pixel-perfect quando compatível com enquadramento;
- Aseprite JSON e GIF **não** substituem `ProductionCharacterSet` e os metadados de apresentação usados pela Unity;
- pixels em origem superior esquerda: **mão local Unity = ((handX-pivotX)/PPU, (pivotY-handY)/PPU)**; pivô normalizado `(pivotX/width, 1-pivotY/height)`. Os pivôs têm de vir do manifesto **daquele frame/asset**.

Para fontes experimentais, manter `ArtSource/Labs` separado de `Assets`. Integrar por importadores e scripts específicos do personagem/marco e preservar GUIDs, SpriteIDs, clips e referências quando a tarefa exigir. `ProductionArt06B4.Import` é **legado para B4** e **não deve ser invocado automaticamente** sobre Quaternius R10. **Nunca** executar `Tools/ArtPipeline/production.py` como atualização genérica: pode recriar fontes B3.

## 5. Validação e aprovação

1. Inspecionar a fonte em Aseprite: frames, durações, camadas, tags, canvases e integridade dos pixels. Para exportações novas, gerar SHA e QA; comparar com baseline aprovado.
2. Avaliar a arte em tamanho nativo e nearest, dois ciclos, oito vistas quando aplicável, apoio dos pés, composição, hierarquia de camadas e transições. Em cenários, avaliar proporção junto ao **poço**, casas, árvores, sorting e caminhabilidade; não usar só uma prancha.
3. Para dizer **"validado em Unity"**, conectar o **Editor real** com `--caller plugin --skill unity-pipeline` ou integração equivalente comprovada, executar recompile/status, Play/input, capturas de Game View e Console. Skill Aseprite **não abre Unity** nem comprova gameplay.
4. Usar **perfil isolado** para qualquer Play, proteger `DevelopmentJourneys/marco06b4` e dados pessoais. Restaurar input, timeScale, editor, dispositivos, override e estado de Play.
5. Separar **prova técnica** de **aprovação artística do usuário**. Não alegar que um novo visual está aprovado sem feedback explícito.

## DeepSeek Harness — sem plugin Aseprite extra

No Harness, orientar o agente de forma explícita:

> Leia `AGENTS.md` e `.agents/skills/aseprite-pixel-art/SKILL.md`. Confirme o estado Quaternius R10. Execute **somente** `locate`, `validate` e `inspect` de uma fonte experimental existente, sem salvar cena, sem tocar em saves, sem alterar sprites oficiais. Relate comandos e saídas reais. Se a CLI não estiver acessível, pare e informe o bloqueio.

A skill Aseprite é um conjunto de instruções/scripts **locais** e não estabelece conexão com o Unity; o Harness precisa de plugin Unity compatível ou da Unity CLI autenticada. Veja `Docs/Development/DeepSeekHarness.md` para a integração.

**Fontes oficiais:** [Aseprite CLI](https://www.aseprite.org/docs/cli/), [scripting](https://www.aseprite.org/docs/scripting/) e [API Lua](https://www.aseprite.org/api/).


## Direção central vigente — World Studio09

Antes de produzir ou revisar arte ambiental, ler [ValdoriaVisualLanguage](../../../Docs/Art/ValdoriaVisualLanguage.md) e, para construções, [ArchitectureStyleGuide](../../../Docs/Art/ArchitectureStyleGuide.md). A casa07R orienta acabamento, luz e escala; fontes aprovadas ficam preservadas, revisões09 são candidatas. Não aplicar saturação/tint global nem alterar geometria para resolver cor. Exportar pixels reais do Aseprite e guardar comparações Game View na pasta de validação do projeto.
