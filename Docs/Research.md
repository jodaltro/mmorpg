# Referências e como entraram no motor

Pesquisa de 20/10/2026 sobre narrativa interativa e IA de jogos, aplicada ao World Simulation Engine.

| Referência | Ideia | No motor |
|---|---|---|
| Thue, Bulitko, Spetch, Wasylishen. *Interactive Storytelling: A Player Modelling Approach* (AIIDE 2007); PaSSAGE | Aprender o estilo do jogador pelas ações e escolher o conteúdo com esse modelo | `tags` em ações e missões; `State.Styles` por jogador (ação +1, missão concluída +2, recusa −1); vai para o contexto do Jev, para a saliência e para `views/{id}.style` |
| Doran & Parberry. *A Prototype Quest Generator Based on a Structural Analysis of Quests from Four MMORPGs* (PCG 2011) | Missões classificadas pela motivação do NPC | As `tags` seguem essas famílias (mystery, help, combat, craft, social, explore) |
| Kreminski & Wardrip-Fruin. *Sketching a Map of the Storylets Design Space* (ICIDS 2018); Emily Short, *Storylets: You Want Them* | Conteúdo em pedaços com pré-condições, escolhido por saliência | Missões são storylets; `salience` pontua especificidade, estilo, história e relação com quem oferece; desconta cansaço e lotação |
| Ruskin. *AI-driven Dynamic Dialog through Fuzzy Pattern Matching* (GDC 2012) | A regra mais específica vence | A especificidade pesa na saliência; o padrão sem o Jev deixa de ser sorteio |
| Ryan, Summerville, Mateas, Wardrip-Fruin. *Toward Characters Who Observe, Tell, Misremember, and Lie* (AIIDE 2015); Talk of the Town | Personagens observam, contam e espalham conhecimento, inclusive errado | `gossip`: quem divide um lugar troca a crença mais recente; a fonte vira `rumor` e a idade original é mantida |
| Park et al. *Generative Agents* (2023) | Memória com recência e importância orienta o comportamento | Relações por par lembram ajudas e recusas e vão para o contexto do Jev |
| Sistema Nemesis, *Shadow of Mordor* (2014) | Inimigos lembram encontros com o jogador | `relate`/`rel`: missão concluída +2, recusa −1; com −3 o NPC para de chamar; confiança alta libera missões |
| AI Director, *Left 4 Dead*; narradores do *RimWorld* | Ritmo de construção, pico e alívio | `intensity`, `tension` com decaimento, fases `build-up`/`sustain`/`relax` |
| Kreminski, Dickinson, Wardrip-Fruin. *Felt* (2019); *Winnow* (AIIDE 2021) | Story sifting no log de eventos | Próximo passo |

## Missões raras e específicas

- `chance` (permilhar) é sorte **determinística**: semente + jogador + tick + sequência de eventos. O replay continua idêntico.
- `time` (horas do dia, com `dayLength`) permite "à noite" ou "ao amanhecer".
- Padrão: uma ação comum tem um efeito `if` raro que grava um **sinal durável**; a missão oculta depende do sinal.
- Valdoria: *O Javali Branco* (8% ao caçar à noite com 3 troféus); *A moeda de Asterion* (3% ao minerar; recompensa sorteada); *A canção da alvorada* (ajudou a vila de três formas, ao amanhecer).

## Próximos passos sugeridos pela literatura

1. **Story sifting** (Felt/Winnow): padrões no log que geram lendas, títulos e boatos sobre jogadores.
2. **Esquecimento e distorção** (Talk of the Town).
3. **Motivações dos NPCs** (Doran & Parberry) escolhendo que missão pedir.
4. **Modelo do jogador com o que ele ignora** (PaSSAGE).

## Habilidades (pedido do usuário, 20/10/2026)

| Inspiração | Ideia original no motor |
|---|---|
| *Shangri-La Frontier*: os coelhos vorpais ensinam técnicas que só existem na linha de missões deles | A **Toca dos Lebrinos**: um lugar escondido (achado por sorte ao amanhecer), um povo com técnicas exclusivas (Passo Leve, Corte Lunar) e um cenário único de Guardião, que exige também ter caçado o Javali Branco |
| *Frieren*: coleção de magias inúteis com efeitos engraçados ou de utilidade duvidosa | **Grimório de magias inúteis** achadas por sorte enquanto se faz outra coisa (Florescer, Remover Ferrugem, Chá Morno, Achar Botões, Uvas Azedas); **fusões** (Chá de Flores) e o título épico de **Colecionador**; a "inútil" Remover Ferrugem purifica minério amaldiçoado |
| Habilidades por hábito (ideia própria) | Contagem de feitos: Martelo Firme (forjar dobra a prática), Cochilo Estratégico (abre um sonho que dá pista da história principal), Teimosia Lendária (recusar seis vezes muda o Kael) |
| Fama (ideia própria) | Habilidades raras viram boato público; épicas e lendárias melhoram a relação com quem estava no lugar |
