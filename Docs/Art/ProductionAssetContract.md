# Contrato de produção — 06B.4

Este contrato complementa a [ArtBible](ArtBible.md). `ArtSource/` é a fonte de produção fora de `Assets/`. Os seis PNGs de `assets_para_usar/` e os assets/cenas B3 são preservados. Um arquivo importável não equivale a uma animação aprovada.

## Coordenadas e entrega

- PNG RGBA, alfa real; sem fundo pintado, escala não uniforme ou espada embutida no corpo do herói. Pixels lógicos a 32 PPU; piso de 32×32 = uma unidade.
- Herói: canvas 96×96, pés de referência `(48,88)`, pivô `(48,70)` para compatibilidade com a raiz física existente. O pivô fica 18 pixels acima da linha do chão. Nunca deslocar Rigidbody/collider para compensar desenho.
- Todas as coordenadas do manifesto são pixels no canvas: origem superior esquerda, +X direita, +Y baixo. Unity recebe pivô `(x/width,1-y/height)` e mão local `((handX-pivotX)/PPU,(pivotY-handY)/PPU)`.
- Perspectiva top-down 3/4; cabeça estável, contorno coerente, armadura cinza, roupa/capa azul e cabelo castanho da referência fixa. Espada na mão direita anatômica, sem espelhamento de equipamento assimétrico.
- Nomes: `ArtSource/Characters/Hero/walk/south/frame_000.png` etc. Direções `south,west,north,east`; animações `idle,walk,attack,dodge,hurt,death`. Numeração contígua desde zero. Não incluir arquivos ausentes nem repetir quadros para cumprir contagem.
- Um `manifest.json` por personagem/criatura: `schema,id,ppu,coordinates,status,clips,missing,groundContact,collider`. Cada clip declara `animation,direction,frameCount,loop,status,frames`. Cada frame declara `png,canvas,pivot,feet,rightHand,leftHand,equipmentAngle,equipmentDepth,duration,events,source,sha256`.
- Ângulos em graus Unity: zero aponta à direita, positivo anti-horário. Profundidade do equipamento é relativa ao corpo. A mão é o contato com o pivô da empunhadura, não a ponta da lâmina.
- Eventos permitidos: `footstep`, `cloth`, `weapon-trail`, `pose-ready`; são marcadores de apresentação. Dano, desbloqueio e recompensa não são eventos de arte. O adaptador de gameplay observa estados confirmados.

## Gate artístico

| Grupo | Contrato de produção | Material atual |
|---|---|---|
| Herói | 8 desenhos distintos por direção de caminhada; 4 direções; ataque com preparação/corte/recuperação próprios; dodge/hurt/death completos | 2 poses nativas de walk por direção; stances adaptadas e dodge de uma pose. Provisório |
| Mira/Orin/ferreiro/pesquisador | Humano proporcional ao herói; idle e walk por direção; pés e mãos por quadro | Healer/Hunter/Smith/Scholar: uma pose frontal cada. Walk ausente |
| Lobo | Canvas próprio, apoio no chão, corrida e ataque direcionais; hurt/death reais | 80×80, poses limitadas; mantém adaptador B3. Morte por fade |
| Aranha | Silhueta baixa, pernas legíveis; veneno separado; collider no corpo | Manifesto de preparação; não aprovar sequência só por possuir poses |
| Golem | Maior/pesado que herói; canvas próprio; apoio e colisão separados das extremidades | Poses B3 preparadas; expansão de animação não aprovada |
| Morcego | Âncora corporal aérea e sombra independente; collider de corpo | Duas poses frontais de voo; sem inimigo físico novo |

Não exigir canvas idêntico entre espécies. A primeira importação conserva os canvases e as escalas B3, documentados por frame. Colliders existentes continuam na raiz física; nenhuma silhueta animada gera collider automaticamente. Cada novo collider requer revisão do gameplay físico e registro de dimensões, offset e layer. Pivôs de VFX: chão nos pés para poeira/sombra, centro corporal para impacto, mão para corte e marcador acima do alvo.

## Armas

`ArtSource/Weapons/IronSword/manifest.json`: tipo, PNG, dimensões, PPU, pivô da empunhadura, ponta, orientação original, alcance visual e compatibilidade. A espada atual é o recorte separado B3, 80×80, pivô `(31,45)`, orientação original ~38,8°. Não foi desenhada uma nova espada neste marco. A integração preserva a calibração da lâmina e o alcance do Sweep. Ver [WeaponAttachment](WeaponAttachment.md).

## Ambiente e interface

Pisos repetíveis: 32×32 sem padding externo, bordas contínuas e perspectiva plana. Transições têm máscara de vizinhos explícita; `Path_0..15` usa esquerda/direita/baixo/cima. Árvores, casas, pedras, minérios, baús, portas e decorações ficam em catálogo de props separado, com pivô no apoio. Colisão bloqueia tronco/base, não copa. As definições B3 e os caminhos das cinco regiões continuam vigentes.

Ícones têm canvas próprio, sem serem redimensionados para piso. Manter bronze escuro/azul/cinzas da HUD; texto legível. Não introduzir recursos externos sem licença.

## Efeitos

Manifestos em `ArtSource/VFX/{SwordCut,Impact,Dodge,WeaknessReading,HuntersMark}` declaram canvas, pivô, frames, duração, loop, eventos de início/fim e offset de sorting. Corte inicia somente na janela ativa; impacto somente após `HitConfirmed`; poeira somente quando esquiva foi aceita; marcas duram conforme os estados das habilidades. Um corte de uma imagem orientada pelo Swing não é uma sequência de desenhos novos. Os adaptadores atuais continuam donos da temporização e não aplicam regras de habilidade.

## Aceitação

Revisar em sequência real: no mínimo dois ciclos, quatro direções, parada/retomada, colisão, ataque e contato da arma. Reprovar duplicação de poses, deriva de pés, mão fora do cabo, identidade instável, serrilhado inconsistente e efeitos cortados. As duas propostas geradas em `ArtSource/References/Rejected/` foram reprovadas; não fazem parte dos assets de gameplay.
