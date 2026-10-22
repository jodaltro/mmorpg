# Visão do jogo

Atualizada em 19/10/2026, quando o projeto foi refeito a partir do motor.

## Produto

1. Um **MMORPG de mundo vivo**. Tudo o que um jogador faz pode mudar o mundo, e o mundo continua evoluindo sem ninguém conectado.
2. **O motor é independente da interface.** O mesmo mundo pode ser jogado por clientes 2D ou 3D, em Unity, Unreal, Godot, web ou outro qualquer. Os clientes apresentam; o motor decide.
3. **História fixa do mundo, destino dinâmico.** O mundo tem arcos narrativos escritos (ex.: *A Maldição do Selo*). Cada arco é uma sequência de capítulos com ramificações.
4. **Cenários únicos** (estilo *Shangri-La Frontier* e *Overgeared*): vários jogadores podem perseguir o mesmo capítulo ao mesmo tempo, mas **só o primeiro a cumpri-lo** o conclui e muda a história para todos. Ele recebe título e reconhecimento público.
5. **Ninguém perde a história.** Quem chega depois não tem o progresso apagado: recebe efeitos de rival e continuações próprias (ex.: "O que você viu no selo"), que podem levar a outros ramos.
6. **A história muda de rumo.** Quando um capítulo único é concluído, o próximo ramo é escolhido entre as opções escritas. O Jev escolhe pelo contexto (quem concluiu, o que está acontecendo); sem o Jev, uma regra determinística escolhe.
7. **Capítulos compartilhados** podem ser vividos por todos, e o arco avança quando o mundo atinge uma condição coletiva (ex.: três replantios da floresta).
8. **Cada pessoa vê um mundo diferente.** A verdade do mundo é separada do que cada um sabe. Jogadores e NPCs têm crenças com procedência (observação, conversa, anúncio público) que podem ficar desatualizadas.
9. **NPCs agem pelo que sabem**, não pelo que é verdade. Uma curandeira só prepara o antídoto depois de saber do veneno; se a crença estiver errada, a tentativa falha e ela aprende.
10. **O Sistema entrega as missões; o mundo reage ao que o jogador faz.** O jogador não precisa procurar ninguém: a janela do Sistema aparece em qualquer lugar. Algumas missões envolvem um NPC (quem pede ajuda), outras não. **O que limita é a coerência, não a distância:** a oferta nasce dos acontecimentos e do que o jogador fez e sabe, e é retirada se deixar de fazer sentido. **Um NPC só aparece numa missão para quem ele conhece** (decisão de 22/10/2026): quem acabou de chegar e não fez nada é um estranho e não recebe pedidos de ninguém. O NPC passa a conhecer o jogador ao vê-lo agir por perto (testemunha) ou por boato, e viajantes levam a notícia a outros lugares. Missões sem NPC dependem só do que o jogador fez e soube. O mesmo modelo gera missões diferentes para pessoas diferentes.
10b. **Ritmo humano.** O universo declara o tempo para o qual foi calibrado (`tickSeconds`); em Valdoria, 15 s por tick: um dia de 12 minutos, um acontecimento a cada ~2 minutos e um intervalo de ~75 s entre missões.
11. **Uma missão por vez:** no máximo uma ativa e uma proposta pendente. Em Valdoria, a missão aceita precisa ser concluída antes da próxima (`allowAbandon: false`), e há um intervalo curto entre uma missão e a seguinte (`questGap`). Propostas recusadas não voltam logo.
11b. **Janela do sistema e missões vivas** (estilo *Overgeared*): a oferta mostra quem chama (ou "Sistema"), **rank** (F a SSS), descrição, objetivo, recompensa e penalidade. Uma missão aceita pode **mudar no meio** quando o mundo muda (novo estágio, novo objetivo, rank que sobe), **falhar** (outro resolveu antes, o prazo acabou) e recusar pode ter consequência.
11c. **O mundo aprende e lembra:** aprende o estilo de cada jogador; cada NPC lembra quem o ajudou ou recusou; boatos correm entre quem divide um lugar; o diretor alterna tensão e alívio; há **missões ocultas raras**, com requisitos bem específicos e sorte.
11d. **Habilidades se descobrem vivendo o mundo:** por hábito (forjar três vezes, cochilar cinco noites), por sorte enquanto se faz outra coisa (grimórios de magias inúteis, no espírito de Frieren), em lugares e povos escondidos com técnicas exclusivas (a Toca dos Lebrinos, no espírito de Shangri-La Frontier) e como recompensa. Raridades: comum, incomum, rara, épica, lendária e absurda. Elas conversam com o resto: abrem caminhos alternativos em missões, liberam missões ocultas, se fundem em outras e viram fama pública.
12. **O Jev é assíncrono e consultivo.** Ele escolhe entre opções já validadas pelo motor; nunca inventa recompensas, fatos ou dano; nunca bloqueia movimento, combate ou interação. Com prazo vencido, aplica-se o padrão determinístico.
13. **O combate em tempo real é do servidor de jogo** (da engine escolhida). O motor recebe apenas **acontecimentos confirmados** ("o jogador derrotou o guardião"), nunca valores de dano vindos do cliente.
14. Não há leveling tradicional. A progressão vem de feitos, conhecimento, títulos, reputação, itens e capítulos da história.
15. O jogo precisa ser divertido mesmo com serviços externos (Jev) desligados.

## Fora do escopo atual

Combate, física, animação, arte e cenários pertencem ao cliente ou ao servidor de jogo de cada engine, não ao motor. Escala multi-servidor, autenticação de produção e editor visual de universos vêm depois (ver [Arquitetura](Architecture.md#próximos-passos)).

O caminho da spike ao MVP (sinais, Caderno, vila viva, chegada, enigmas) está em [MvpPlan.md](MvpPlan.md).
