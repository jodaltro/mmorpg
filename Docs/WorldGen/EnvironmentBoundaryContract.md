# Environment Boundary — contrato compartilhado v1

Schema `valdoria-environment-boundary/v1`, autoria `environment_geometry.py`. É um derivado explícito, não substituição silenciosa do WorldRegion v1.

## Autoridade e coordenadas

O WorldRegion original permanece intacto. O relevo contínuo do Marco04 já usa escalares amostrados a cada **.25 u**, subdividindo cada quadrado em A-B-C / A-C-D. Clipping no sinal >=0 produz superfície e pé visual. A física anterior usava runs de células de 1 u: são duas representações diferentes, origem do desvio de até .4718 u.

A revisão05 extrai a união dos mesmos triângulos positivos e cancela arestas interiores. Vértices são arredondados a 1e-6 u; loops fecham implicitamente. Sem simplificação de silhueta. `rockLoops` usa esse pé; os meshes de relevo do Marco04 permanecem. A cena nova remove somente os 29 BoxCollider2D do relevo e usa PolygonCollider2D com três paths; quatro colliders de borda continuam. Isto muda explicitamente a geometria de bloqueio derivada, não o array de altura ou a estrada original.

X leste, Y sul, origem superior esquerda; Unity `(x, regionHeight-y)`. Loops preservam orientação; ocupação Python usa paridade even-odd. A integração Unity deve validar ilhas/buracos e amostras contra a física, não presumir equivalência só por chamar SetPath.

## Água e navegação

`waterFields.surface` é positivo onde existe água. `waterFields.depth` é profundidade ambiental normalizada. `waterFields.blocked=min(surface,(depth-blockedDepth)*180)` expressa bloqueio profundo e vaus. As unidades do sinal superficial são auxiliares para clipping; distância de margem deve ser medida aos loops, **não** inferida da magnitude desse sinal.

`waterLoops` e `waterBlockedLoops` são extraídos pelo mesmo clipping; o primeiro define geometria molhada, o segundo física. Não são o mesmo limite: existe faixa rasa transitável, visualmente distinguida. `waterFields.flow` contém direção planar X/Y sul. Nada disso é produzido a partir de cores de PNG.

`valdoria-environment-navigation/v1` amostra os mesmos triângulos nos centros de subcélulas .25 u: `solidBlocked`, `waterBlocked`, `surfaceWater`, `wetland`, `walkable` e componentes conexos em quatro vizinhos. Grid de navegação é aproximação amostrada; não contém raio do ator. Loops/triângulos são a autoridade contínua. Planejadores futuros precisam de clearance e teste de segmento contra os polígonos para agentes com volume.

Runtime `EnvironmentRegionData.SampleCell` devolve bits: 1=sólido, 2=água bloqueante, 4=água superficial, 8=margem úmida. `CellWalkable` considera o toggle do laboratório. Não usa esse grid para substituir a autoridade física de ActorMotor. Água desligada remove visuais, colliders aquáticos e restrição de navegação aquática juntos; bloqueio sólido permanece.

## Continuidade e validação

Chunks compartilham o contexto global, origem, diagonal, seed e fase. Não gerar fronteiras de chunks sem halo. PNGs a 32 PPU aproximam o limite contínuo por centros de pixel (até meio pixel por eixo). Não exigir igualdade entre a cobertura de um pixel de borda e um ponto exatamente no contorno.

QA05 compara todos os 49.152 centros da navegação com PolygonCollider2D real e os 860 vértices de rockLoops com os pés dos meshes existentes. Tolerância para conversão float Unity: 1e-5 u. Mudanças no algoritmo de interpolação, diagonal, contorno ou limiar exigem revisão e QA dos consumidores.

Referência de integração: [Unity PolygonCollider2D.SetPath](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/PolygonCollider2D.SetPath.html).


## Consumidor Vegetation Agent — Marco06

Veja [VegetationContract.md](VegetationContract.md). O consumidor valida referências/manifests por SHA-256, preserva os bytes deste produtor e acrescenta instâncias e overlay de navegação separados. Troncos têm footprints circulares; copas são visuais. Estradas, reservas, água profunda e vau permanecem restrições de colocação. Navegação combinada ainda requer clearance específico do ator. Não inferir ocupação física pela imagem dos sprites.
