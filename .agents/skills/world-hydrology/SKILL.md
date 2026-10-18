---
name: world-hydrology
description: Autoria procedural offline de lagos, drenagem, rios, margens e vaus de Valdoria, com fronteiras subcélula compartilhadas por apresentação, navegação e colisão. Use para receitas, seeds, máscaras, patches, Aseprite e laboratório Unity; não é simulação hidráulica completa nem promoção artística automática.
---

# Water Agent — Valdoria

Leia `AGENTS.md`, `Docs/GameVision.md`, `Docs/WorldGen/WorldHydrologyContract.md` e `Docs/WorldGen/EnvironmentBoundaryContract.md`. Consuma WorldRegion, Organic Roads e Terrain Materials por hash. Use `terrain-generation`, `terrain-materials` e `aseprite-pixel-art` para os respectivos contratos. A skill orienta o agente que opera ferramentas; não é um serviço ou subagente executado automaticamente.

## Fluxo

1. Confira worktree e execute pull conforme AGENTS. Confirme Editor, versão, cena limpa e compilação antes da integração; localize/valide Aseprite antes de autoria.
2. Investigue fronteiras físicas existentes antes de acrescentar água. `environment_geometry.py` usa os mesmos triângulos e zero escalar do relevo contínuo. Não interprete PNG como geometria e não esconda divergências com espuma ou grama.
3. Gere receita com seed explícita, bacia, fonte dos cursos, limites de largura/profundidade, reservas, travessias e patches. `world_hydrology.py` lê a topografia sem alterá-la. Rejeite fontes sem conexão à bacia ou água que invada terreno sólido, estradas ou reservas.
4. Priority-flood determina níveis de vertimento e um grafo D8 acíclico. Lagos ocupam depressões conexas abaixo do nível autorizado; rios seguem o grafo. Níveis preenchidos são auxiliares da análise, não escrita de altura no WorldRegion.
5. Mantenha superfície, profundidade normalizada, margem úmida, fluxo e bloqueio separados. Somente vau explicitamente autorado libera profundidade bloqueante. Não afirmar natação, pressão, balanço de massa, chuva ou escavação de canais.
6. Use Aseprite para fonte RGBA 128×192, seis funções em camadas e quatro frames de 180 ms. Edição: salvar cópia e `export-library` para destino ausente; regenerar chunks a partir desses pixels. Não girar sprites pré-iluminados. Fluxo pode orientar apenas alfa de pincel, com cor reaplicada.
7. Gere e importe em destinos novos. O menu 09 parte do laboratório04 limpo. A nova cena troca explicitamente os 29 boxes de relevo por três paths compartilhados, preservando quatro bordas. Não modificar a cena oficial ou os bytes de topografia, estrada e materiais anteriores. Mudança de footprint é uma revisão semântica própria e precisa de QA.
8. Execute testes, reconstrução por hashes, recortes em dois eixos, recompile/Console, Play real com perfil em Temp, Input System, margens, bloqueio profundo, vau, sorting e câmera. Compare água on/off com câmera/ator/escala iguais; registre frames avançados e animação. Restaure input, resolução, dispositivos e Play; remova capturas temporárias em Assets.
9. Relate custo de texturas/renderers/draw calls e limitações. Fontes e manifests são editáveis e verificáveis; testes não aprovam a arte. Nenhuma promoção sem avaliação explícita.

## Comandos reais

```powershell
python Tools/ArtPipeline/WorldGen/world_hydrology.py recipe --output Temp/Water/new-recipe
python Tools/ArtPipeline/WorldGen/water_art.py library --output Temp/Water/new-library
python Tools/ArtPipeline/WorldGen/water_art.py export-library --source ArtSource/Labs/World2026/WorldStudio05/Library/water-motifs.aseprite --output Temp/Water/edited-library
python Tools/ArtPipeline/WorldGen/world_hydrology.py generate --recipe ArtSource/Labs/World2026/WorldStudio05/Recipes/recipe.json --library ArtSource/Labs/World2026/WorldStudio05/Library --output Temp/Water/new-region
python Tools/ArtPipeline/WorldGen/world_hydrology.py verify --recipe ArtSource/Labs/World2026/WorldStudio05/Recipes/recipe.json --library ArtSource/Labs/World2026/WorldStudio05/Library --output ArtSource/Labs/World2026/WorldStudio05/BuildR4
python Tools/ArtPipeline/WorldGen/world_hydrology.py crop --recipe ArtSource/Labs/World2026/WorldStudio05/Recipes/recipe.json --patch ArtSource/Labs/World2026/WorldStudio05/Recipes/width-patch.json --bounds '[480,768,128,128]' --output Temp/Water/local-width-edit
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p 'test_*.py' -v
```

Para revisão completa com patch, acrescente `--patch` a `generate` e `verify`. Patches v1 alteram somente largura de um rio em intervalo finito de arco, com transição; não são editor arbitrário de rede/bacia. Alterar fonte, nível do lago ou reservas requer nova receita e regeneração global de dependências. Recortes precisam compartilhar a solução global, não executar drenagem isolada por chunk.

## Handoff

`hydrology.json` + `manifest.json` identificam inputs e features. `geometry.json` contém loops/escalares compartilhados. `navigation.json` e masks distinguem sólido, água profunda, raso e margem. `drainage.json` fornece pais/níveis auxiliares. Vegetation/Architecture/Structures devem validar esses hashes e consultar clearance além de ocupação. O runtime `EnvironmentRegionData` expõe amostras de navegação, não geometria fina nem um NavMesh.

Limites conhecidos: grade de análise .25 u; profundidade ambiental normalizada, não metros; perfil de rio aproximado; lago de estudo abaixo do vertimento recebe um afluente sem saída forçada. Sem simulação temporal de volume. Relevo e ator continuam no plano 2D. Confira `Docs/Validation/ValdoriaWorldStudio05-Hydrology.md` para evidências da execução e avaliação artística pendente.


Para construções, use `environment-architecture` e `Docs/WorldGen/ArchitectureContract.md`. Esse consumidor mantém os produtores por hash, acrescenta footprint/acesso e registra exclusões da vegetação em revisão própria; não desloca água, estrada ou relevo para encaixar edifícios.
