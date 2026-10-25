# GPS celular — 25/10/2026

O GPS usa a mesma rota no cenário, no atlas e no minimapa. A linha azul segue os vasos abertos até o destino completo; as setas têm posições e opacidade estáveis, sem ciclos que as apaguem. O cartão mostra o destino e a distância restante em unidades do mundo. No atlas, tocar em um local e escolher Marcar caminho inicia a orientação, inclusive antes de terminar o tutorial.

## Chegada

Ao entrar na área de chegada (1,5 unidade, com até 2 unidades restantes na rota), o estado muda para **Chegou** e todas as setas e linhas de orientação são retiradas do cenário, atlas e minimapa. O marcador normal da célula e os vasos do mapa continuam sendo mapa, não orientação. Pequenas oscilações não reativam a rota: é necessário afastar-se mais de 2,5 unidades para voltar a seguir o mesmo destino.

Um destino marcado permanece com a confirmação de chegada. O botão **Voltar ao objetivo atual** encerra essa marca e retoma as recomendações; marcar outro local troca o destino explicitamente. Missões confirmadas como concluídas pelo motor também encerram a rota imediatamente, mesmo se a conclusão ocorrer antes do antigo marcador de centro da região. A indicação de chegada dura pelo menos 2,5 segundos antes de mostrar uma rota para um objetivo automático diferente. Nenhuma dessas operações aceita missões ou concede recompensas.

## Continuidade

O trajeto é mantido ao cruzar os limites de regiões; o GPS acompanha a projeção da posição sobre a mesma linha e um ponto adiante nela. Avisos de evolução e genes não apagam o destino. Um alvo móvel válido é mantido, e o planejamento só é atualizado ao mudar destino/passagens, ao deslocamento relevante do alvo ou ao se afastar da rota. A atualização da posição e a chegada são avaliadas por quadro; o recálculo do trajeto tem intervalo próprio.

Passagens fechadas não são atravessadas. Um destino sem rota válida mostra **Caminho bloqueado**, sem inventar uma seta através da parede. Não se atribui uma localização a uma missão desconhecida. No minimapa, linhas que cruzam sua borda são recortadas geometricamente, mesmo que seus dois extremos estejam fora do quadro.

`BioNavigationRoute` contém a geometria em pixels e distâncias acumuladas, sem Nodes ou efeitos de jogo. `BioJourney` controla o destino e a chegada. Atlas e minimapa consomem a mesma rota. O antigo indicador direcional paralelo do HUD não concorre com o GPS. Durante um destino manual, o tutorial também não desenha uma segunda trilha apontando para outro local.
