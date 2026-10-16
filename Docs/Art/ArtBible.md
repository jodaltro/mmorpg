# Direção de arte — Marco 06B.3

**Atualização de direção em 16/10/2026:** o usuário pediu humanoides maiores, com proporções humanas, incluindo o protagonista, e autorizou adequar/ampliar o cenário, mantendo pixel art moderna. O [estudo do novo padrão](HumanoidStandard.md) orienta essa pesquisa. Os números e limitações B3 abaixo são históricos; não constituem teto de resolução para a nova família. Nenhum candidato foi promovido automaticamente.

Referência de identidade: espadachim castanho, túnica azul, ombreiras de aço e couro quente dos PNGs locais. Fantasia medieval, luz superior esquerda, câmera top-down 3/4. Não misturar projeção isométrica. A silhueta e a direção do golpe têm prioridade sobre partículas.

## Resolução e escala

32 pixels lógicos = 1 unidade Unity; terreno de 32×32; humano ~48–54 px de altura visível; lobo ~38 px; golem ~56 px, largo e pesado. Os originais de 1448×1086 possuem detalhe interpolado e não uma grade pixel art uniforme. O humano é reamostrado por nearest a 1/3, com inspeção individual. Props usam escalas de processamento documentadas, preservando uma porta compatível com um humano; nunca corrigir o corpo com escala aleatória do GameObject.

Canvas humano 96×96, âncora dos pés (48,88). O pivô de importação (48,70) mantém o centro físico antigo: pés 18 pixels abaixo do root. A simulação e os colliders ficam intactos. Quadrúpedes: canvas 80×80, pés 10 pixels abaixo do root. Padding é espaço transparente, não tamanho físico visível. Árvores e casas ancoradas no chão. Voo deve ter âncora aérea e sombra separada; não usar animação terrestre para morcegos.

Câmera URP PixelPerfectCamera, 640×360, 32 PPU, Windowbox, PixelSnapping, ortográfica 5,625. Follow em LateUpdate, grade de 1/32; manter movimento físico contínuo. Point, sem compressão/mipmap/MSAA/HDR. Canvas overlay mantém texto em resolução de tela. Referência oficial: [configuração URP Unity 6.6](https://docs.unity.com/en-us/engine/6000.6/manual/unity2d/2d-urp/2d-pixelperfect/configure).

## Paleta e leitura

Ambiente: verdes oliva e musgo, terra ocre, pedra fria, madeira castanha. Contornos escuros coloridos, sem preto puro em grandes massas. Herói azul/aço claro; corrupção violeta; veneno verde ácido; cristal ciano. HUD: carvão azulado, bronze discreto, texto marfim. Saturação máxima reservada a perigo e habilidade confirmada. Manter sombras semitransparentes; nunca color-key de preto.

Quatro orientações nativas S/O/N/L para o conjunto inicial. Diagonais quantizadas pelo maior eixo; empate vertical, sem espelhamento. Movimento e hitbox continuam em 360°. Corpo acompanha a mira; esquiva acompanha deslocamento. Espada separada, única, controlada pelo mesmo SwordSwing responsável pela varredura física. Máscaras manuais removem somente lâminas de derivados; as poses com duas espadas e braços incompatíveis são rejeitadas. Não fabricar quadros novos para preencher FPS.

## Animação e composição

Walk humano: duas poses reais a 8 FPS, limite do material. Idle estável. Ataques usam preparação/ativo/recuperação observados do SwordSwing, nunca um loop livre. As quatro direções usam stances compatíveis com a empunhadura em substituição aos braços reprovados; precisam de redesenho para acabamento corporal final. A espada separada executa a varredura contínua. Dodge é uma pose nativa sustentada pelo estado real, sem prometer rolamento completo. Dano usa evento confirmado e flash curto; morte sem desenho nativo usa fade explicitamente documentado.

Ground e detalhes abaixo dos atores; obstáculos por pé no eixo Y; copas devem cobrir atores que passam atrás. Colisão de árvore só no tronco, casas na base, nenhuma colisão em VFX. Não transformar bounds com padding em footprint físico. VFX de impacto exige HitConfirmed; habilidades só mostram estados realmente ativos. Terrenos repetíveis precisam passar teste de mosaico; bordas do atlas são referências, não tiles aprovados automaticamente.

## Gate de qualidade

Revisar prancha, dois ciclos e gameplay: pés estáveis, identidade, mãos/espada, direção, escala, transparência e sorting. Defeitos do atlas não se tornam conteúdo aprovado por serem importáveis. Expansão só após validar o primeiro conjunto. Não alterar regras, missões, backend, saves pessoais ou pacotes para acomodar a arte.
