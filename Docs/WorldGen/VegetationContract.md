# Vegetation Contract v1

Implementação: `Tools/ArtPipeline/WorldGen/environment_vegetation.py`, generator `environment-vegetation/1.0.0`. Fontes: `vegetation_art.py`; integração: `VegetationStudioImporter`. Autoria offline; nenhuma regeneração em Play.

## Inputs imutáveis

WorldRegion (altura/inclinação/umidade/solo/reservas), Organic Roads (coverage/navigable), Terrain Materials (composição/manifests), Water Agent (hidrologia, geometria compartilhada, navegação e relief referenciado), biblioteca e receita. Cada referência registra caminho relativo e SHA-256. Inputs de terreno divergentes ou manifests alterados são rejeitados. Não escrever alturas, traçados, níveis ou fronteiras da água para acomodar plantas.

## Receita e distribuição

`valdoria-vegetation-recipe/v1`: version, seed inteiro, composition A/B/C, speciesCounts, profiles, habitatFocus, actorClearanceUnits, protectedAreas e patches de exclusão retangular em unidades do mundo. O foco explícito concentra metade dos pais em torno do lago; não é descoberta automática de pontos narrativos.

Espécies: oak, elm, hazel, fern, wildflowers, reeds, drygrass, plantgroup. Perfis definem raio físico, spacing, distância mínima de estrada/água, limites de altura/declive/umidade. Umidade combina campo original e proximidade da água; sombra é proxy de proximidade de árvore. Modelo de adequação autorado, sem evolução temporal ou calibração climática. Pais espaciais elípticos, competição e rejeição produzem agrupamentos. Altura/declive/solo vêm das células semânticas; água/relevo usam interpolação triangular subcélula. Posições finais quantizadas em 1/32 u.

Cada espécie tem orçamento finito de candidatos. `densityResults` registra requested/placed/exhaustedCandidates. Não contornar exclusões para atingir contagens. Uma edição de exclusão pode propagar mudanças por competição; ausência de alteração fora do patch não é garantida.

## Saídas

`valdoria-vegetation/v1` em vegetation.json: generator, seed, composition, sizeUnits, instances, densityResults, ecologyModel e inputs. Cada instância contém ID, espécie, variante, posição, raio físico, amostras de habitat e referência de cluster. `manifest.json` (`valdoria-vegetation-build/v1`) assina os bytes de todos os outputs e inputs. distribution-diagnostic.png é diagnóstico, nunca arte final.

`valdoria-vegetation-navigation/v1`: size, stepUnits=0.25, vegetationBlocked, walkable, componentCount e baseComponentCount. Arrays row-major; y=0 ao norte. vegetationBlocked é apenas a ocupação acrescentada; base hidrológica permanece intacta. actorClearanceIncluded=false: consumidores precisam inflar obstáculos pelo próprio agente. Conectividade de pontos da grade é validada; não equivale a prova de alcance de todos os corredores para qualquer raio de ator. QA real cobre as passagens de estudo.

## Espaço, física e apresentação

Região 64×48 u. Conversão para Unity: (x,48-y). Arte 32 PPU; SpriteRenderer local usa sourceRect/offset para preservar a âncora do chão após trim. Frames 0/1/2 são silhuetas, não animação. Biblioteca final: oito fontes Aseprite, seis camadas funcionais, três variantes; 69 partes não vazias e atlas RGBA 1024².

Troncos: oak raio .30 u, elm .40 u; CircleCollider2D na camada ambiental 8, sem collider de copa/arbusto/sombra. Margem de colocação física inclui raio + actorClearance .45 u + .05 u; reservas/caminhos/vau são adicionais. Não bloquear a copa inteira. VegetationAnchor preserva ID e metadados mesmo quando arte é agrupada.

Árvores: SortingGroup 100-round(worldY*16), tronco 0 e copa 1 dentro do grupo. Sombra estática no chão, fora do grupo. Plantas sem colisão: meshes estáticos em faixas de .25 u, erro máximo de âncora de sorting .125 u; não usar esse batching em objetos altos que exigem oclusão exata. LabController alterna arte, física e overlay de navegação em conjunto. Teclas 0=antes, 1/2/3=A/B/C, R=pose inicial; WASD/Space mantêm contrato do protagonista.

## Handoff

Architecture/Structures devem reservar áreas antes da distribuição ou aplicar exclusões e regenerar; ler footprints, não alfa das copas. Climate pode substituir o proxy de adequação por campos versionados explícitos. Water mantém autoridade sobre raso/profundidade/vau; só juncos podem ocupar raso permitido. Materiais mantêm autoridade sobre pigmento do terreno. Futuros consumidores devem combinar navegação base e overlay, conferir hashes e aplicar clearance do ator. Não inferir madeira coletável, abrigo, crescimento ou combustível sem contratos próprios.

Destinos existentes são recusados pelo gerador/importador. Arte experimental permanece candidata até avaliação do usuário. Evidências e limites: relatório Marco06.


## Architecture Agent — Marco07

Consumidor implementado: [ArchitectureContract.md](ArchitectureContract.md). Mantém este produtor por hash e cria lotes, footprints, acessos e exclusões versionadas de vegetação. A vegetação afetada é regenerada em saída nova, com relatório de efeitos da competição. Casca física exterior, telhado visual e corredor transitável são dados separados; transparência não libera colisão.
