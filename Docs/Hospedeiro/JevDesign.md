# Jev como autor da célula (design procedural)

## O que o Jev decide hoje

| Decisão | O que o Jev escolhe | Antes |
|---|---|---|
| `evolution` + **`evolution-slot` (novo)** | a mutação em destaque **e cada vaga restante, uma depois da outra**, cada uma sabendo o que as anteriores viraram (aprofundar o caminho, surpresa ou aposta alternativa): a oferta inteira é do Jev | só a primeira vaga era do Jev |
| `lineage` | a linhagem (classe) | idem |
| `ability` | a habilidade que desperta | idem |
| `appearance` | a variante do corpo (6) | idem |
| **`design` (novo)** | **onze traços procedurais da célula**: núcleo (8 formas + *composto*), membrana (5), organelas (6), brilho (6), sabor dos efeitos (5), **núcleo composto por partes** (lobulação 3 a 8, recorte, nucléolo: 72 núcleos únicos) e **a sensação dos efeitos** (densidade, rastro e ritmo das partículas) | não existia: tudo isso saía do cliente por regras fixas |
| `rota`, `world`, `dungeon`, `offer` | o próximo lugar a apontar, o acontecimento do mundo, o modificador, a missão | já eram do Jev |

Cada traço é uma decisão própria (`design:<traço>:<jogador>:<tick>`), criada em conjunto e respondida em paralelo (11 chamadas de ~370 ms). O contexto de cada uma diz quais opções os outros jogadores já usam, para manter as células reconhecíveis. O motor só valida (a opção tem de ser do próprio traço), guarda no `Look` e o cliente desenha. No prazo vale o padrão determinístico (a opção cujas afinidades casam com os eixos do corpo), então o jogo funciona com o Jev desligado.

## O que mudou no contrato com o Jev

Os textos das opções traziam `[fit N]`, a nota do próprio motor. Medido ao vivo: com a nota, o Jev concordava com o padrão em 100% das decisões de mutação e de linhagem, ou seja, só confirmava. **A nota foi removida**; o padrão continua existindo como reserva, mas o Jev passa a julgar pelo contexto (estilo de jogo, atos, genes, classe, regiões em que viveu, estado do corpo).

## Como o cliente desenha

`BioDesign` (tabelas), `BioEffectSignature` (sabor dos efeitos: muda cor e forma dos membros, nunca números) e `BioCellBody` (núcleo, membrana, organelas e brilho). O teste `test_design.gd` percorre o universo e garante que toda opção que o motor pode oferecer tem desenho.

## Os efeitos são físicos (não só visuais)

O estilo que o Jev escolhe para os efeitos (trait `efeito`) muda o combate. Todo golpe de **habilidade** (o ataque básico não) carrega uma consequência, paga com um golpe direto menor (`BioEffectPhysics`):

| Estilo | Consequência | Golpe direto |
|---|---|---|
| Chama | o alvo queima: +38% do dano ao longo de 3 s | x0,78 |
| Cristal | o alvo fica quebradiço: +20% de dano recebido por 4 s | x0,88 |
| Névoa | o alvo e os vizinhos (1,8 u) ficam 38% mais lentos por 3 s | x0,85 |
| Elétrico | o golpe salta para até 2 inimigos próximos (3,2 u) com 40% do dano; o salto não encadeia de novo | x0,72 |
| Orgânico | 32% do dano volta como membrana para quem lançou | x0,88 |

Uma régua só: `test_effect_physics.gd` exige que o golpe direto mais o valor do efeito fique entre 95% e 120% do golpe sem estilo, e testa cada consequência de verdade (a queimadura continua depois do golpe e para; o quebradiço passa; a névoa não atinge quem está longe; o arco alcança dois, não três; o sifão cura; o ataque básico não muda).

## Composição por partes (o Jev "propondo" formas novas)

A API de decisões do Jev só aceita escolha entre opções; então a liberdade vem de **combinar traços independentes**: o núcleo composto tem lobulação x recorte x nucléolo (72 combinações), e junto com membrana, organelas, brilho, efeito, densidade, rastro e ritmo o espaço de células passa de 10 milhões. O motor valida cada peça; o cliente desenha qualquer combinação (`BioNucleusShapes.draw_composite`). Limite: o Jev ainda não inventa uma peça que o vocabulário não tenha.

## Próximos passos

1. Traços por classe (um macrófago e uma T citotóxica com vocabulários diferentes) e sabores de efeito por habilidade.
2. Medir a diversidade com muitos jogadores (hoje só 2).
3. Um cenário com vidas ambíguas para a linhagem e a aparência (o Jev ainda concorda com o padrão nesses dois).
