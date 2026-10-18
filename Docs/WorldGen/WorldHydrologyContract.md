# World Hydrology — contrato v1

Gerador `world-hydrology/1.0.0`, schemas `valdoria-hydrology-recipe/v1`, `valdoria-hydrology-patch/v1`, `valdoria-hydrology/v1`, `valdoria-hydrology-build/v1`. Leia [WorldRegion](WorldRegionContract.md), [Organic Roads](OrganicRoadsContract.md), [Terrain Materials](TerrainMaterialsContract.md) e [fronteiras compartilhadas](EnvironmentBoundaryContract.md).

## Entrada e modelo

WorldRegion imutável; referência de estrada deve pertencer ao mesmo SHA de terreno. Região atual 64×48, células de 1 u, 32 PPU. Altura normalizada é interpolada para análise .25 u; não é altitude em metros. Reservas, bloqueio sólido e cobertura de estrada são exclusões. Áreas protegidas adicionais usam retângulos explícitos; interseções retornam erro antes de publicar build. Não cortar um rio silenciosamente para encaixar sua máscara.

A análise implementa flood por heap estável a partir das bordas abertas, seguindo o princípio de [Barnes, Lehman e Mulla, Priority-Flood](https://rbarnes.org/sci/2014_depressions.pdf). Níveis preenchidos e pais são auxiliares. Em declive estrito, o grafo escolhe maior descida D8; em flats usa pais de flood com rank decrescente. O par (nível preenchido, rank) prova ausência de ciclos. A implementação local é uma aproximação de autoria, não o pacote/código do artigo.

Lago: seed deve estar numa depressão conexa com profundidade mínima. `fillFraction` interpola entre fundo e vertimento; apenas o componente submerso dessa bacia é aceito. Um rio parte de fonte autorada e segue pais até alcançar o lago. Se a fonte não drena para ele ou atravessa exclusão, recusa. Caminho D8 é densificado linearmente a cada .0625 u para a envoltória; não se cria uma curva que atravesse morros. Pequenas subidas no terreno bruto podem ocorrer dentro de depressões preenchidas pela análise e devem ser reportadas separadamente do declive do nível auxiliar.

Larguras variam suavemente por arco e seed, limitadas por min/max. A superfície é a união da envoltória dos cursos com o lago. Lago usa nível menos altura original para profundidade; rio usa perfil transversal de profundidade **aproximado**, autorado, sem escavar o chão. Nenhuma mecânica mede metros de lâmina d'água. Sem pressão, vazão calibrada, conservação de massa, chuva, erosão fluvial, cachoeiras ou alteração temporal de lago.

## Receita e patches

Seed inteiro, `stepUnits=.25`, `ppu=32`, `lake:{id,seedPoint,fillFraction,minimumDepression}`, `rivers:[{id,source,minWidth,maxWidth,relativeDepth}]`, `blockedDepth`, `wetMarginUnits`, `protectedAreas`, `crossings`, `patches`.

Travessia inicial: `kind=shallow-ford`, `riverId`, `point`, `radiusUnits`. Reduz explicitamente o proxy de profundidade dentro do trecho autorizado para liberar passagem 2D; não é ponte nem natação. Não vence rocha ou estrada protegida. Confirmar que largura e raio permitem o corpo do protagonista, não somente seu centro.

Patch v1: `edits:[{kind:river-width,riverId,arcRange:[a,b],factor}]`, fator .65–1.3 e transição de .6 u dentro do intervalo. Altera largura local e máscaras dependentes; não muda centro, drenagem ou lago. A envoltória alterada pode afetar pontos num halo de até metade da largura máxima ao redor do segmento. Fonte, nível, inserção de curso e escavação não são patches v1. Nova receita pode reanalisar toda a bacia; não prometer independência global de mudanças hidrológicas.

## Arquivos

| Artefato | Conteúdo |
|---|---|
| hydrology.json | Versão, seed, hashes de inputs, lago/bacia/níveis, rios/perfis, travessias, modelo e status artístico |
| geometry.json | `valdoria-environment-boundary/v1`: loops e escalares compartilhados de rocha/água/bloqueio/fluxo |
| navigation.json | `valdoria-environment-navigation/v1`: ocupação subcélula, transitabilidade e componentes, sem raio de ator |
| drainage.json | `valdoria-drainage/v1`: nível preenchido, pais YX e rank |
| surface.png / blocked.png / shallow.png | L 8-bit: água, água bloqueante, água rasa transitável |
| wetland.png | L 8-bit: solo seco dentro da faixa de distância configurada à margem |
| depth.png | PNG 16-bit: profundidade normalizada ×65535; fora d'água zero |
| flow.png | RGBA: R/G = direção X/Y sul mapeada -1..1 →0..255; A=água; B reservado |
| water-render.json | Chunks, quatro frames por chunk, duração e campo auxiliar de margem |
| water-x-y-fN.png | Arte RGBA em chunks 256 px / 8 u; substituível sem mudar física |
| manifest.json | SHA-256 de todos os outputs e referências dos inputs, receita, biblioteca, relevo e quatro máscaras de estrada |

Origens e amostragem seguem o contrato de fronteiras. `crop` gera masks de um contexto global, com hashes e bounds explícitos; `water_art.render_chunk` faz recorte artístico com halo de motivos. Não reexecutar análise só com os dados locais de um chunk. Source/modo/rank globais permanecem necessários.

## Fonte artística e Unity

`valdoria-water-library/v1`: Aseprite 128×192 RGBA, seis camadas funcionais (raso, profundo, reflexos, sedimento, espuma localizada, traços de fluxo), quatro frames de 180 ms. `water_art.py library/export-library` cria/exporta em destino ausente; pixels exportados são consumidos. Paleta e formas são editáveis, com proveniência original do projeto. Reflexos têm orientação autorada; apenas alfa geométrico do fluxo é projetado na tangente com cor mundial reaplicada.

O importador constrói seis meshes recortados nas fronteiras semânticas de água/margem e 24 texturas 256×256, não um quad com PNG do mapa inteiro. A animação alterna frames existentes via MaterialPropertyBlock, sem gerar terreno ou hidrologia em Play. Point, RGBA, mipmaps/compressão off. Superfície/raso/espuma são visuais; PolygonCollider2D usa somente o limite de bloqueio por profundidade. Sorting do piso aquático -1985, abaixo do ator, e relevo mantido. Não há refração, forças de água ou natação.

Vegetation Agent deve evitar água profunda e pode contextualizar margens/solo úmido. Architecture Agent deve consultar sólido, alagado, faixa de margem, clearance e reservas. Structures Agent pode propor pontes/vaus novos com revisão explícita de travessia; o Water Agent não cria estrutura. Todos validam input hashes, origem e unidades. Água desligada é modo diagnóstico do laboratório, não alteração persistente do mundo.
