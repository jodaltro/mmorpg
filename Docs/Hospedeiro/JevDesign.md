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

## O próprio projétil é desenhado pelo Jev

Três traços novos mudam o **tiro** (hoje nos projéteis das habilidades `bolt` e `volley`, como o anticorpo do linfócito B), não só o visual: **trajetória** (reta, ondulada, espiral, arco, teleguiada), **calibre** (fino, médio, grosso: raio de acerto, velocidade, alcance e um dano que paga o tamanho) e **impacto** (simples, perfurante, explosivo, fragmenta, grudento). O `ritmo` também acelera ou atrasa o tiro. Tudo em `BioProjectileDesign` e `BioAbilityBolt`:

| Impacto | O que o tiro faz | Golpe direto |
|---|---|---|
| Perfurante | atravessa até 3 inimigos, 25% mais fraco a cada um | x0,80 |
| Explosivo | explode: quem está a 2,2 u do impacto leva 55% | x0,78 |
| Fragmenta | vira 3 fragmentos que seguem (30% cada, alcance 3 u) | x0,72 |
| Grudento | gruda e queima 40% do golpe em 3 s | x0,80 |

**Risco e recompensa.** Quanto mais difícil de acertar, mais o tiro dá em troca (`BioProjectileDesign.PATHS`). A chance de acerto contra um inimigo que se mexe é a medida no teste e o dano compensa, de modo que dano x chance fica igual (dentro de 12%) para toda trajetória:

| Trajetória | Chance de acertar | Dano | Velocidade | Alcance |
|---|---|---|---|---|
| Teleguiada | ~90% | x1,0 | x0,85 | x1,0 |
| Espiral (tubo largo) | ~75% | x1,15 | x0,95 | x1,0 |
| Ondulada (serpente, varre os lados) | ~70% | x1,25 | x1,0 | x1,0 |
| Arco (contorna) | ~65% | x1,3 | x1,0 | x1,2 |
| Reta (agulha) | ~55% | x1,6 | x1,25 | x1,15 |

Então o anticorpo em serpente, mais difícil de acertar que o teleguiado, bate 25% mais forte; e a reta bate 60% mais forte, mais rápida e mais longe.

**Foco: a mesma régua para todas as outras habilidades.** O Jev também desenha o `foco` da célula (cones, estocadas, novas, investidas, zonas e devorar): **amplo** (largura x1,45, alcance x0,85, dano x0,8), **médio** ou **preciso** (largura x0,65, alcance x1,2, dano x1,3). Muda a geometria da própria habilidade e o dano de cada golpe dela (`BioAbilityFocus`); o chicote básico e os projéteis ficam de fora (os projéteis têm o desenho próprio acima).

A trajetória é física: a onda e o saca-rolhas varrem os lados (e acertam ali), o arco contorna, a teleguiada persegue com giro forte, a reta não persegue. A régua é a mesma (`test_projectile.gd` exige 95% a 120% do tiro simples contando o que o impacto traz de volta) e cada comportamento é testado em corpos reais. **Debug:** F7 troca o impacto, F8 a trajetória, F9 o calibre; o painel F3 mostra o projétil em vigor.

## Cada família de habilidade tem um comportamento próprio

Além do foco (largura, alcance e dano), o Jev desenha **como cada família se comporta** (`BioAbilityMode`, seis traços `modo_*`). Cada modo troca um pouco de dano direto pelo que traz, e uma régua só (`worth`, entre 95% e 120% do golpe simples) vale para todos:

| Família | Modos | O que muda de verdade |
|---|---|---|
| Cone | padrão · **fecha** · **chicoteia** | fecha arrasta as vítimas até a célula (dano x0,9); chicoteia golpeia de novo 0,35 s depois (0,7 + 0,5) |
| Nova | padrão · **pulsos** · **repele** | três batidas (0,48 + 2 x 0,32); repele joga os inimigos para longe (x0,9) |
| Estocada | padrão · **arpão** | arpoa e puxa a vítima (x0,9) |
| Investida | padrão · **dupla** | um segundo golpe 0,4 s depois (0,65 + 0,55) |
| Zona | padrão · **migra** | a zona anda até o inimigo mais próximo (1,3 u/s), menor (raio x0,9) e mais fraca (x0,85) |
| Devorar | padrão · **suga** | puxa a presa antes de morder (x0,9) |

`test_modes.gd` confere a régua, que o universo oferece exatamente os modos que existem, e cada comportamento em corpos reais (a vítima é puxada ou jogada, o segundo golpe chega, a zona anda). O chicote básico e os projéteis não têm modos.

## Os efeitos do estilo (queimadura, quebradiço, lentidão, cadeia, sifão)

O traço `efeito` continua dando uma consequência física a cada golpe de habilidade (tabela e testes em `BioEffectPhysics`): chama queima, cristal deixa o alvo quebradiço, névoa atrasa o alvo e os vizinhos, elétrico salta para até dois inimigos, orgânico devolve membrana. **As partículas decorativas do estilo (esporos, lascas, nuvens) foram removidas**: só o projétil e as consequências físicas ficaram.

## Composição por partes (o Jev "propondo" formas novas)

A API de decisões do Jev só aceita escolha entre opções; então a liberdade vem de **combinar traços independentes**: o núcleo composto tem lobulação x recorte x nucléolo (72 combinações), e junto com membrana, organelas, brilho, efeito, densidade, rastro e ritmo o espaço de células passa de 10 milhões. O motor valida cada peça; o cliente desenha qualquer combinação (`BioNucleusShapes.draw_composite`). Limite: o Jev ainda não inventa uma peça que o vocabulário não tenha.

## Próximos passos

1. Traços por classe (um macrófago e uma T citotóxica com vocabulários diferentes) e sabores de efeito por habilidade.
2. Medir a diversidade com muitos jogadores (hoje só 2).
3. Um cenário com vidas ambíguas para a linhagem e a aparência (o Jev ainda concorda com o padrão nesses dois).
