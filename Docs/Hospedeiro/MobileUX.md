# Interface mobile — referências e implementação

Pesquisa em 24/10/2026. Referência principal: Wild Rift. Referência complementar: Brawl Stars. Os padrões de controle foram adaptados ao Hospedeiro; os ícones são vetoriais originais, desenhados em código.

## O que a pesquisa mostrou

A Riot trata mobile como uma interface própria: dois polegares, habilidades ativas acessíveis e adaptação ao dispositivo. O artigo [Rammus, Rift to Rift](https://wildrift.leagueoflegends.com/en-us/news/dev/dev-rammus-rift-to-rift/) explica a orientação de não ter botões sem ação e explorar controles duplos. A apresentação do [Wild Rift](https://wildrift.leagueoflegends.com/en-us/game-overview/) mostra sua organização de jogo.

As notas [2.2](https://wildrift.leagueoflegends.com/en-sg/news/game-updates/wild-rift-patch-notes-2-2/) documentam zonas mortas para evitar arrastes acidentais e ajustes do centro do movimento. As notas [2.5](https://wildrift.leagueoflegends.com/en-us/news/game-updates/wild-rift-patch-notes-2-5/) tratam de toque, arraste, tamanho e sensibilidade. As [2.6](https://wildrift.leagueoflegends.com/en-gb/news/game-updates/wild-rift-patch-notes-2-6/) mostram presets diferentes conforme a experiência do jogador.

Brawl Stars também investe em [controles personalizáveis](https://supercell.com/en/games/brawlstars/blog/release-notes/optional-update-customizable-controls/). Esse é um passo seguinte útil: não basta diminuir todos os botões, pois a posição e a área de toque precisam se ajustar à mão.

## Aplicado ao Hospedeiro

| Problema anterior | Nova apresentação |
| --- | --- |
| Habilidades atravessavam a borda inferior central | Quatro habilidades em arco no quadrante direito, junto ao ataque |
| Círculos com números e textos sem hierarquia | Ataque principal maior, habilidades médias, utilidades menores; ícones por função |
| Centro disputado por Agir e notificações | Centro reservado para o mundo; Agir junto ao grupo direito e chamado compacto no topo esquerdo |
| Não era possível preparar uma habilidade sem dispará-la | Pressionar prepara, arrastar define a direção e soltar usa; um toque rápido usa a mira assistida |
| Sem desistência durante a mira | Arrastar até X cancela; abrir uma janela ou interromper o toque também não dispara |
| Recargas pouco legíveis | Aro de recarga, estado escurecido e segundos restantes |
| Barras e textos grandes no topo | Minimapa local clicável, duas barras finas e nome da região |
| Mira sem indicação no mundo | Direção visível durante o arraste e aro no alvo assistido |

O ataque básico continua funcionando ao segurar. Toxina e habilidades usam o gesto de soltar. O impulso continua imediato e usa a direção de movimento já definida pelo jogo. Nenhuma regra de dano, custo, descoberta ou progressão foi alterada.

O minimapa mostra geometria das regiões conhecidas e NPCs já presentes na visão do jogador. Não consulta fatos ocultos. Tocar nele abre o atlas completo.

## Próximos refinamentos

Editor de posição, tamanho e opacidade com preferências salvas; teste em aparelhos físicos e com mãos de tamanhos diferentes; tratamento próprio do mapa dentro de masmorras. O minimapa atual é ocultado nas masmorras para não mostrar uma posição enganosa no corpo.
