# Visão obrigatória do jogo

1. O jogo é um action RPG 2D em tempo real, futuramente multiplayer.
2. O mundo possui memória persistente e evolui conforme as ações dos jogadores.
3. O Jev avalia contextualmente oportunidades e consequências.
4. Missões são oferecidas proativamente pelos NPCs ou pelo mundo, sem exigir procurar NPCs para descobrir todas as missões.
5. O personagem recebe uma proposta contextual e pode aceitar, recusar ou ignorar.
6. Apenas uma missão pode estar ativa por personagem. Não sugerir novas missões enquanto houver uma missão aceita e ativa.
7. No máximo uma proposta pendente por vez; evitar repetição imediata de propostas recusadas.
8. Concluir ou abandonar uma missão torna o personagem elegível para novas oportunidades.
9. Oportunidades dependem de acontecimentos confirmados, combates, recursos coletados, descobertas, relações e estado do mundo.
10. O Jev seleciona entre candidatos válidos; o domínio valida condições e aplica consequências.
11. O Jev trabalha assincronamente e nunca bloqueia movimento, combate ou interações imediatas.
12. Não existe leveling tradicional.
13. A progressão acontece por habilidades, conhecimentos, equipamentos, especializações e acontecimentos.
14. Missões são oportunidades de progressão, não o único meio de descobrir conteúdos ou evoluir.
15. O gameplay deve ser divertido mesmo com serviços externos desligados.

O modelo de propostas acima é uma diretriz futura. O Marco 06B.2 apenas o documenta; não implementa propostas, novas missões ou progressão.
Movimento, colisão, acertos e dano precisam de validação independente na futura autoridade multiplayer. A experiência action offline usa a autoridade local e não depende de HTTP.

## Direção inicial de ambientação —19/10/2026

Valdoria deve apresentar um reino inicialmente precário e marcado por corrupção. A pobreza e o abandono das moradias e ruas contrastam com os recursos concentrados no castelo: interior protegido, mais bonito e iluminado, com gramado, fonte, árvores e flores. O usuário escolheu a adaptação animada de **Release That Witch** como referência de cenário; o manhua não orienta a estética atual. Essa premissa informa autoria ambiental e futuras consequências do mundo, sem importar personagens ou copiar a história da obra. Não representa implementação de um sistema de corrupção, novas missões ou progressão.
