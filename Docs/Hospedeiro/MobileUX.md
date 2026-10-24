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

Tamanho global já configurável de 75% a 125%, com preferência salva. Próximos passos: editor individual de posição e opacidade; teste em aparelhos físicos e com mãos de tamanhos diferentes; tratamento próprio do mapa dentro de masmorras. O minimapa atual é ocultado nas masmorras para não mostrar uma posição enganosa no corpo.


## Menus e janelas (24/10/2026)

A navegação abre uma gaveta compacta com destinos e tamanho da interface. Escolher um destino fecha a gaveta antes de mostrar a janela. Apenas uma janela ocupa a tela por vez; tocar fora ou em Fechar retorna ao jogo. O botão flutuante Menu fica oculto enquanto outra janela está aberta para não cobrir o botão Fechar.

O Corpo usa abas laterais no toque. Cabeçalho, abas e estado de ajuste ficam fixos; apenas o conteúdo rola. As colunas consideram a largura real do conteúdo, inclusive quando a interface está em 125%. Códice, Sinais e chamados usam ScrollContainer, em vez de texto desenhado sem interação. O atlas usa marcadores e legenda para evitar nomes sobrepostos.

Selecionar uma ficha exige pressionar e soltar sem arrastar. O movimento do dedo passa para a rolagem, sem selecionar genes, builds ou habilidades. Botões dentro das listas também permitem a propagação do gesto ao ScrollContainer. Não há atalhos de teclado nas janelas mobile. Enquanto uma janela recebe input, o personagem não se move nem ataca.

O componente BioModal centraliza tamanho, cabeçalho, fechamento e fundo. O toque fora só fecha ao soltar, se o gesto começou e terminou fora e não foi um arrasto. Fechar um chamado pelo fundo significa responder depois; a oferta continua disponível.

Referências técnicas: [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html) e [Control / propagação de input](https://docs.godotengine.org/en/stable/classes/class_control.html). Validação por toque emulado no Edge; aparelhos físicos ainda precisam de avaliação de uso.


## Editor de habilidades e presets (24/10/2026)

Referências desta revisão: [barra de habilidades do ESO](https://help.elderscrollsonline.com/app/answers/detail/a_id/2665/~/how-do-i-assign-skills), com arrastar até o espaço desejado, e [templates do Guild Wars 2](https://www.guildwars2.com/en/news/learn-all-about-build-and-equipment-templates/), que agrupam escolhas em presets inspecionáveis. A implementação e os ícones do Hospedeiro continuam originais.

Habilidades passam a ser quatro espaços de 70 unidades de altura, em uma linha. Tocar ou clicar apenas seleciona o inspetor: nome, custo, recarga, dano e efeito curto. A explicação longa fica em Como funciona. A alternativa Trocar posição permite selecionar um destino sem arrastar.

No desktop, arrastar e soltar usa o drag-and-drop do Godot. No toque, segurar por 350 ms permite pegar a habilidade; arrastar sobre outro espaço realça o destino e soltar troca as posições. Soltar fora, cancelar o toque ou fechar a janela abandona a troca. Um deslize de mais de oito unidades antes da espera é rolagem, nunca uma troca. O caminho de mouse emulado fica desativado nesse editor mobile para não ignorar a espera.

Builds mostram três seletores compactos e os detalhes de um único preset, com genes, ordem salva e comparação. Selecionar não equipa; Renomear abre o campo somente por solicitação; Salvar aqui substitui um preset ocupado apenas depois de confirmação; Aplicar envia a intenção ao motor. Nomes são locais e genes continuam validados pelo motor.

Salvar aqui captura os genes e a barra atual; a ordem desse snapshot só é salva ou equipada depois de sucesso HTTP. A ordem de um preset existente também pode ser arrastada diretamente na prévia: essa organização é salva localmente, sem equipar o preset, até o jogador escolher Aplicar. Falhas preservam a ordem anterior e aparecem no próprio painel. Operações pendentes impedem envio duplicado. Atualizações em segundo plano não substituem o campo de nome nem interrompem uma habilidade sendo arrastada. Arrastar muda a organização da barra, sem executar habilidades nem mudar regras de combate.
