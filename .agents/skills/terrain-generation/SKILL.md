---
name: terrain-generation
description: Autoria procedural offline de topografia e estradas orgânicas de Valdoria. Use para receitas, seeds, relevo, rotas, curvas, largura navegável, máscaras subcélula, patches e importação nos laboratórios Unity 2D. Materiais finais, hidrologia e aprovação artística permanecem separados.
---

# Terrain Agent — Valdoria World Studio

O Codex interpreta a intenção e opera geradores determinísticos. A skill não é um processo autônomo nem comprova execução de subagentes.

Leia `AGENTS.md` e `Docs/GameVision.md`. Para terreno, use `Docs/WorldGen/WorldRegionContract.md`; para estradas, leia `Docs/WorldGen/OrganicRoadsContract.md`. Autoria de novos sprites requer também a skill `aseprite-pixel-art` e seu workflow. Qualidade técnica e aprovação artística são verificações distintas.

## Escolha do pipeline

- **Topografia:** `Tools/ArtPipeline/WorldGen/terrain_agent.py`, receita `valdoria-terrain-recipe/v1`, patch `valdoria-terrain-patch/v1`. Altura, inclinação, umidade proxy, reservas, erosão térmica simplificada, circulação e manifest. Previews são diagnósticos.
- **Estudos do Marco 01:** `studio01.py`, materiais experimentais editáveis Aseprite, WorldRegion ampliado e `TerrainStudioImporter`. A cena `ValdoriaTerrainLab.unity` contém os estudos originais A/B/C.
- **Estradas do Marco 02:** `organic_roads.py`, receita `valdoria-organic-road-recipe/v1`, patch `valdoria-road-patch/v1`. A* sobre topografia/clearance, Catmull–Rom centrípeta, amostragem por distância, larguras limitadas, máscaras 32 PPU e referência versionada ao terreno imutável. `OrganicRoadStudioImporter` e `ValdoriaOrganicRoadsLab.unity` comparam Antes/A/B/C sobre um terreno compartilhado.

- **Materiais do Marco 03:** use a skill separada `terrain-materials` e `Docs/WorldGen/TerrainMaterialsContract.md`. O compositor consome a mesma região/estrada por hash, sem refazer topografia ou caminhos; a apresentação contínua substitui os reinícios visuais por célula somente no laboratório de materiais.

Esses recursos existem; sua execução em uma nova sessão deve ser verificada. Consulte os relatórios `Docs/Validation/ValdoriaWorldStudio01.md` e `ValdoriaWorldStudio02-OrganicRoads.md` para evidências e limites, sem tratar a arte experimental como aprovada.

## Fluxo de autoria

1. Confira worktree e atualize `main`, conforme `AGENTS.md`.
2. Expresse relevos, acessos, reservas e pontos obrigatórios em receitas com seed explícita. Não derive física dos pixels do panorama R10.
3. Gere em **diretório inexistente**. Não apague resultados anteriores para passar testes. Verifique manifests por reconstrução e hashes, preservando bytes no Git.
4. Para estrada, valide clearance de toda a largura/ombro, água/células proibidas, inclinação, conectividade e curvatura. Se o traçado não couber, ajuste receita/guias ou retorne erro de autoria. Nunca aplane o mundo silenciosamente para obter passagem.
5. Edite pontos interiores por patch; IDs de segmentos e ruído de largura usam suporte local. Leia o contrato para o halo de dependência. Não prometa que a própria vizinhança do segmento editado ficará inalterada.
6. Recortes de regiões adjacentes devem consumir a **mesma geometria global**, com origem, seed, fase e escala compartilhadas; não gerar duas estradas independentes e presumir uma emenda perfeita.
7. Importe por ferramentas do Editor em destinos novos. Mantenha dados, piso, relevo visual, colisões e máscaras separados. Não regenere em Play.
8. Faça QA curto no Editor real com `--caller plugin --skill unity-pipeline`, perfil em `Temp/`, Input System, frames avançados, Console e capturas reais. Restaure input/Play/overrides e remova PNGs/metas temporários de `Assets` após copiar evidências.

## Comandos

```powershell
python Tools/ArtPipeline/WorldGen/terrain_agent.py generate --recipe ArtSource/Labs/World2026/WorldGen/Recipes/valdoria-highlands-pilot.json --output Temp/WorldGen/highlands-new
python Tools/ArtPipeline/WorldGen/organic_roads.py generate --region ArtSource/Labs/World2026/WorldStudio01/Regions/B/world-region.json --recipe ArtSource/Labs/World2026/WorldStudio02/RoadsR3/recipe-A.json --output Temp/WorldGen/road-new
python Tools/ArtPipeline/WorldGen/organic_roads.py verify --recipe ArtSource/Labs/World2026/WorldStudio02/RoadsR3/recipe-A.json --output ArtSource/Labs/World2026/WorldStudio02/RoadsR3/A
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p 'test_*.py' -v
```

Para edição, acrescente `--patch caminho/patch.json`. O gerador usa Python/Pillow/NumPy já declarados em `Tools/ArtPipeline/requirements.txt`.

## Invariantes e limites

- A física deriva de dados semânticos. A máscara visual de borda **não cria colliders**; grama invadindo visualmente uma margem não bloqueia movimento.
- `waterCandidate` não é água renderizada. O módulo de estrada o trata como exclusão conservadora; travessias precisam de autorização explícita na receita, não removem obstáculos sólidos e não implementam pontes.
- Elevação normalizada e relevo projetado não tornam montanhas escaláveis. O ator continua no plano 2D; o código de movimento/combate mantém autoridade independente da arte.
- O Marco 02 reutiliza o atlas de estudo para exibir cobertura. Não iniciar Material Agent/Marco 03 dentro de uma tarefa exclusiva de estradas.
- Fontes e receitas ficam em `ArtSource/Labs`; Python não escreve em `Assets`. O importador Unity pode criar assets/cenas experimentais no escopo autorizado. Não promover ao mundo oficial sem avaliação visual explícita.
- Water, Climate, Material, Architecture, Vegetation e Structures devem produzir artefatos próprios referenciados por hash, sem alterar silenciosamente a topografia de outro especialista.

Para água, use a skill `world-hydrology` e `Docs/WorldGen/WorldHydrologyContract.md`. O laboratório05 usa uma revisão explícita de fronteira compartilhada; isso não altera a topografia original nem autoriza o Material Agent a editar física por pigmento.


Para construções, use `environment-architecture` e `Docs/WorldGen/ArchitectureContract.md`. Esse consumidor mantém os produtores por hash, acrescenta footprint/acesso e registra exclusões da vegetação em revisão própria; não desloca água, estrada ou relevo para encaixar edifícios.
