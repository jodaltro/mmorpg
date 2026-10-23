# Jev como autor da célula (design procedural)

## O que o Jev decide hoje

| Decisão | O que o Jev escolhe | Antes |
|---|---|---|
| `evolution` | a mutação em destaque da oferta | as outras duas vagas ainda são pelo ajuste determinístico |
| `lineage` | a linhagem (classe) | idem |
| `ability` | a habilidade que desperta | idem |
| `appearance` | a variante do corpo (6) | idem |
| **`design` (novo)** | **cinco traços procedurais da célula**: núcleo (8 formas), membrana (5 texturas), organelas dominantes (6), brilho (6 cores) e **sabor dos efeitos das habilidades** (5) | não existia: tudo isso saía do cliente por regras fixas |
| `rota`, `world`, `dungeon`, `offer` | o próximo lugar a apontar, o acontecimento do mundo, o modificador, a missão | já eram do Jev |

Cada traço é uma decisão própria (`design:<traço>:<jogador>:<tick>`), criada em conjunto e respondida em paralelo (5 chamadas de ~350 ms). O motor só valida (a opção tem de ser do próprio traço), guarda no `Look` e o cliente desenha. No prazo vale o padrão determinístico (a opção cujas afinidades casam com os eixos do corpo), então o jogo funciona com o Jev desligado.

## O que mudou no contrato com o Jev

Os textos das opções traziam `[fit N]`, a nota do próprio motor. Medido ao vivo: com a nota, o Jev concordava com o padrão em 100% das decisões de mutação e de linhagem, ou seja, só confirmava. **A nota foi removida**; o padrão continua existindo como reserva, mas o Jev passa a julgar pelo contexto (estilo de jogo, atos, genes, classe, regiões em que viveu, estado do corpo).

## Como o cliente desenha

`BioDesign` (tabelas), `BioEffectSignature` (sabor dos efeitos: muda cor e forma dos membros, nunca números) e `BioCellBody` (núcleo, membrana, organelas e brilho). O teste `test_design.gd` percorre o universo e garante que toda opção que o motor pode oferecer tem desenho.

## Próximos passos

1. A oferta de mutações inteira composta pelo Jev (hoje ele escolhe a primeira vaga).
2. Parâmetros dos efeitos das habilidades (densidade, velocidade, rastro) como traços, e traços para cada classe.
3. O Jev propor *novas* opções dentro de um vocabulário validado (formas compostas), em vez de só escolher entre as existentes.
