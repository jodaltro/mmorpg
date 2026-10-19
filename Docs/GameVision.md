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
10. **Missões proativas e pessoais.** O mundo oferece oportunidades a cada jogador conforme o que ele fez e sabe. O mesmo modelo gera missões diferentes para pessoas diferentes.
11. No máximo **uma missão ativa** e **uma proposta pendente** por personagem. Propostas recusadas não voltam logo; propostas que perderam o sentido são retiradas.
12. **O Jev é assíncrono e consultivo.** Ele escolhe entre opções já validadas pelo motor; nunca inventa recompensas, fatos ou dano; nunca bloqueia movimento, combate ou interação. Com prazo vencido, aplica-se o padrão determinístico.
13. **O combate em tempo real é do servidor de jogo** (da engine escolhida). O motor recebe apenas **acontecimentos confirmados** ("o jogador derrotou o guardião"), nunca valores de dano vindos do cliente.
14. Não há leveling tradicional. A progressão vem de feitos, conhecimento, títulos, reputação, itens e capítulos da história.
15. O jogo precisa ser divertido mesmo com serviços externos (Jev) desligados.

## Fora do escopo atual

Combate, física, animação, arte e cenários pertencem ao cliente ou ao servidor de jogo de cada engine, não ao motor. Escala multi-servidor, autenticação de produção e editor visual de universos vêm depois (ver [Arquitetura](Architecture.md#próximos-passos)).
