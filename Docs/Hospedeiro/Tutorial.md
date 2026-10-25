# Tutorial de entrada

O guia começa depois que o mundo está pronto. Na sessão online, aguarda a visão privada do motor e o primeiro snapshot do jogador; nenhuma etapa prática depende de um cronômetro ou de um clique que apenas enviou uma intenção.

As doze etapas apresentam objetivo, movimento, membrana/ATP, golpe próximo, Toxina, impulso, habilidades de classe, NPC, interação, missões, Corpo e saída para o Sangue. A classe inicial não recebe poderes artificiais para cumprir o guia: as habilidades especiais são explicadas e permanecem bloqueadas até a diferenciação normal.

O alvo de treino fica na Medula. Recebe impactos visuais, confirma acertos por jogador e ataque, mas não ataca, morre, se desloca por repulsão ou concede recompensas. No online, existe na autoridade Godot; cada jogador recebe apenas seus próprios contadores. Um disparo no vazio ou o golpe de outro jogador não completa a lição.

A Medula é um refúgio para todos, mesmo depois do tutorial: não permite surgimento de inimigos selvagens, impede sua entrada por movimento e ignora seus golpes vindos de fora. Essa proteção não se aplica a inimigos de instâncias pessoais. Fora da Medula, o guia pede o retorno ao refúgio; não dá invulnerabilidade individual.

O fundo escurece com recortes suaves sobre o controle e os elementos necessários à ação. Contornos pulsantes, gestos de toque/arraste, setas, trilha de partículas, progresso e confirmação animada guiam a atenção. A camada visual deixa os controles acessíveis. O cartão muda de posição ao abrir a navegação e se oculta durante a leitura de janelas reais; reaparece depois de fechá-las.

Pausar salva a etapa. A entrada seguinte retoma um guia incompleto. O menu mobile oferece **Rever / continuar tutorial**; no desktop existe o botão **Tutorial**. Depois de concluído, o guia só recomeça por escolha do jogador. Progresso local versionado em `user://hospedeiro_tutorial_v1.json`.

Sem motor, Estroma é identificado como demonstração offline. Não se inventam conversas, missões ou progresso do mundo.

## Depois do tutorial

O cartão compacto **Próximo passo** permanece disponível após a conclusão. Prioriza o destino marcado no atlas, a missão ativa, um chamado aguardando resposta e as escolhas de evolução. Na ausência deles, orienta a saída da Medula para o Sangue; lá, sugere o primeiro vírion e cinco nutrientes antes de explicar a continuidade da evolução. Essas sugestões não criam missões, recompensas ou progresso: online, os contadores vêm da visão privada confirmada pelo motor; offline, dos acontecimentos locais confirmados.

A trilha azul animada aponta para trechos dos vasos, respeitando as passagens abertas. Missões iniciais com destino conhecido têm orientação explícita; missões dinâmicas sem localização conhecida mantêm seu objetivo textual, sem inventar coordenadas. Marcar um local no atlas substitui temporariamente a sugestão; a marca pode ser limpa no cartão e termina ao chegar perto do destino. Menus, tutorial reaberto, morte e masmorras ocultam o cartão e a trilha.

O atlas inicia ampliado nos locais conhecidos, com opção de ver o corpo inteiro. A legenda distingue jogador, regiões, vasos e masmorras. **Locais e masmorras** oferece botões grandes, explicações de NPCs, nutrientes e vírions, e detalhes das entradas conhecidas. Masmorras são apresentadas como desafios opcionais em instâncias pessoais, com salas e chefe; disponibilidade e impedimentos usam os dados recebidos pelo cliente. Marcar caminho não entra automaticamente nem libera uma entrada bloqueada. Os portais no mundo também levam o rótulo **Masmorra**.

Referências consultadas em 25/10/2026: [Roblox — Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques), com o foco visual de Hello Kitty Cafe e trilhas no mundo; [Apple — Onboarding for Games](https://developer.apple.com/app-store/onboarding-for-games/), com etapas curtas e prática progressiva. São referências de interação; nenhum asset desses jogos é redistribuído.
