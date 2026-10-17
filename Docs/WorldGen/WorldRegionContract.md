# Valdoria World Studio — WorldRegion v1

## Propósito e estado

Contrato inicial do **Terrain Agent**. Base técnico-procedural para futuros especialistas em água, material, vegetação, arquitetura, clima e estruturas. **Ainda não existe um orquestrador multiagente, nem um editor procedural integrado à Unity.** O Codex opera a skill `.agents/skills/terrain-generation/SKILL.md`.

Este módulo **não usa a composição v3 R10 como altura ou mapa de colisão**: o backdrop ilustra a direção artística, mas não deve determinar os novos terrenos.

## Entrada

`valdoria-terrain-recipe/v1` define `regionId`, `seed`, `size:[width,height]` em células, `cellSizeUnits`, `baseElevation`, `features` (hill/valley/plateau), `protectedZones`, `route` e `waterCandidateBelow`. A ordem dos features importa. `protectedZones` e `route` impõem área plana; `patch` opcional cria alterações locais sem perder a receita original.

Patches `valdoria-terrain-patch/v1`: lista ordenada de brushes raise/lower/flatten/paint. Patches de elevação atuam antes do nivelamento de zonas protegidas; paint atua após classificação e não modifica células reservadas.

## Saída

Diretório novo, contendo:

| Arquivo | Contrato |
|---|---|
| `region.json` | `valdoria-world-region/v1` com camadas semânticas e metadados |
| `height.png` | Grayscale 8-bit diagnóstico de elevação, 1 px/célula |
| `terrain-preview.png` | Mapa de diagnóstico em 12 px/célula; não é pixel art final |
| `manifest.json` | Schema de build, hash da receita/patch, hashes dos artefatos, versão e status |

Todas as camadas `layers` são arrays **row-major**, linha 0 no **topo**. Índice = `y * width + x`. Cada elevação, inclinação e umidade é quantizada de 0 a 1000. `material` é string: grass, forest, dirt, mud, sand, rock. `walkable`, `reserved` e `waterCandidate` são booleanos.

Conversão Unity futura: `worldX = x * cellSizeUnits`, `worldY = (height - 1 - y) * cellSizeUnits` para a origem local da célula; o builder define o Transform da região explicitamente. **Elevação é campo ambiental, não deslocamento vertical direto do Rigidbody2D.**

`waterCandidate` representa células baixas que um futuro Water Agent pode analisar, **não** lagos gerados ou água apta a gameplay.

## Garantias e limites atuais

- Para mesma versão de código, receita, seed, patch e versão do Pillow, os artefatos verificam byte a byte. A representação de JSON é canônica.
- Gerador só grava em diretório inexistente e não modifica assets Unity.
- `reserved` preserva área plana/corredor e marca walkable; isso não certifica conectividade global/navegação real.
- Não há erosão física, modelagem hidrológica, texturas profissionais, água renderizada, chunks contínuos, integração de Tilemap, física 2D ou testes em Unity nesta primeira entrega.
- O preview é técnico; arte profissional depende da skill Aseprite, materiais e avaliação do usuário.

## Handoff futuro entre especialistas

Terrain Agent exporta `WorldRegion` imutável. Water Agent deverá adicionar dados de rede de rios, bacias, água e margens sem destruir elevação. Material Agent consumirá elevação, solo, água e bioma para gerar materiais/transições; Architecture e Vegetation consumirão áreas reservadas, inclinação, clima e footprints. QA verificará união espacial, navegabilidade, colisões, sorting e escala no Editor real.

O `AGENTS.md` tem precedência nas questões de gameplay, saves, licenças, escopo e validação.
