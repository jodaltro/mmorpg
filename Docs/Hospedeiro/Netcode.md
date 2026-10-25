# Resposta local e sincronização

Implementação de 25/10/2026. O cliente responde aos controles e desenha o mundo continuamente. Godot headless confirma movimento, acertos, custos, coletas e acontecimentos compartilhados; o motor Go mantém progressão e história.

| Parte | Implementação |
|---|---|
| Movimento próprio | Entradas numeradas a 60 Hz; o cliente simula imediatamente a mesma regra de aceleração, arrasto e limite de velocidade. O servidor confirma a entrada depois de simulá-la. O cliente reexecuta as entradas posteriores à confirmação. |
| Correções | A posição lógica é reconciliada; corpo e câmera recebem um deslocamento visual que desaparece suavemente. Colisões continuam locais durante a previsão. Mudança de instância, morte ou grande divergência reposicionam a apresentação. |
| Ataques | Golpe, tiro de Toxina, impulso e início das habilidades recebem apresentação imediata. ATP e recarga são reservados provisoriamente. Tokens associam cada pedido ao resultado confirmado; um resultado repetido não repete efeitos nem rejeições. |
| Toxina | O projétil local é apenas visual. A réplica confirmada da mesma origem/token não duplica o desenho. Contato previsto ilumina o alvo, sem modificar HP, contar morte ou conceder recompensa. |
| Habilidades de classe | Antecipam gesto, membros, carga e efeitos iniciais conforme o tipo. Cargas e âncoras conservam o segundo acionamento. Estados duradouros, trajetórias complexas e consequências de combate seguem a confirmação. |
| Entidades remotas | Histórico de snapshots com interpolação, atraso visual adaptativo de 60–160 ms conforme jitter e extrapolação limitada a 120 ms. Teletransportes descartam o histórico anterior. Projéteis também informam velocidade. |
| Golpe próximo | A autoridade verifica a geometria recente vista pelo jogador, limitada a 500 ms. O histórico guarda posições, sem alterar posição atual, HP ou progresso dos alvos. Só alvos vivos da mesma instância participam. |
| Envio | Relógio de envio a 30 Hz preserva o tempo excedente de cada quadro. Até quatro entradas por pacote, com redundância e reenvio seletivo dos números pedidos pelo servidor. Quedas de FPS não reduzem permanentemente a taxa das entradas. |
| Recuperação | O buffer espera entradas ausentes, rejeita duplicatas e conserva crédito de tempo do servidor. Recupera no máximo três passos por tick e nunca usa duração enviada pelo cliente para comprar velocidade. A janela de crédito é limitada a cinco segundos. |
| API do mundo | Após a primeira visão válida, falhas temporárias da API não interrompem o movimento e o combate já inicializados no Godot. A entrada inicial continua aguardando o carregamento real. |

## Contrato aditivo no transporte Nakama

O envelope de entrada admite `frames`, com `seq`, `move`, `aim`, `actions`, `tokens` e `view_time`. O tempo de cada passo é fixado pela autoridade. `result_ack` permite retirar resultados já recebidos, economizando tráfego.

Snapshots acrescentam horário de simulação, `missing_inputs`, resultados por token e duração restante de movimento balístico. `ack` corresponde à última entrada simulada. O formato anterior de intenções continua aceito durante a atualização dos clientes. Não houve mudança incompatível no contrato HTTP.

O RTT mede a confirmação real do jogo. Reenviar uma entrada conserva seu primeiro horário de envio, evitando apresentar um ping artificialmente baixo. O RTT físico continua afetando a chegada das decisões compartilhadas; a previsão antecipa a resposta local. Em perda prolongada de conexão, a autoridade pode corrigir ou recusar uma previsão. Dano, inventário e recompensas nunca são aceitos do cliente.

## Pesquisa e escolhas

[Unreal Engine 5.8 — Networked Movement](https://dev.epicgames.com/documentation/unreal-engine/understanding-networked-movement-in-the-character-movement-component-for-unreal-engine) documenta previsão, movimentos salvos, correções e suavização. A aplicação aqui usa entradas fixas numeradas e reexecução da trajetória local.

[Unity — Client anticipation](https://mp-docs.dl.it.unity3d.com/netcode/current/advanced-topics/client-anticipation/) descreve valores antecipados, tratamento de dados atrasados e conciliação com a autoridade. ATP, recargas e animações do Hospedeiro seguem esse princípio; o movimento possui também seu próprio histórico de reexecução.

Os limites de 500 ms para geometria, 120 ms para extrapolação e 60–160 ms para interpolação são escolhas deste protótipo, verificadas localmente. Não representam garantia de desempenho em aparelhos físicos nem eliminação do atraso da conexão.

Validação reproduzível: [registro de 25/10/2026](../Validation/2026-10-25-netcode.md). O runner de navegador usa exclusivamente a instância QA em loopback, com duas sessões e atraso artificial nos dois sentidos do WebSocket.
