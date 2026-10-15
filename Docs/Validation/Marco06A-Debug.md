# Debug do gameplay

Painel ativo por padrão na ActionVerticalSlice, canto superior direito, reduzido para 310×145 com fonte 11. F8 mostra/oculta sem interromper gameplay. Mostra tempo de frame, vida, modo narrativo, pedidos HTTP, motivo de espera e últimos três registros. O histórico mantém até 14 registros.

O save inspecionado tinha EvidenceDelivered e uma decisão Mira determinística já registrada. PendingMiraDecision e PendingEvaluation eram nulos; portanto HTTP 0 era esperado, não falha de transporte. Não são reenviados acontecimentos já resolvidos.

Restaurada nova jornada em Esc → N → N para confirmar. Substitui apenas o save local do slice. R mantém os fatos e retorna à vila. Abertura da pausa, confirmação e cancelamento foram exercitados através de eventos de teclado do Input System; nenhum reset foi confirmado no save do usuário. Painel 310×145 verificado em Play, frame 3808, zero erros. Recompilação concluída sem erros. Ao entregar uma nova amostra a Mira em jornada nova, a política narrativa fica elegível para HTTP.

Histórico limitado aos últimos 14 registros: ataques, acertos, esquivas confirmadas, fatos aceitos, mensagens de jornada, pedidos/respostas HTTP de Mira e mundo, fallback, aplicação/rejeição de decisões de mundo e avisos/erros. Não mostra tokens, credenciais ou corpos HTTP. Não é uma inspeção completa do processo Go/OpenRouter; mostra o que o cliente observa. Ocultar mantém a captura ativa.

Componentes: ActionDebugPanel e ActionDebugTrace; authoring repetível em AgentScripts/ConfigureActionDebug.cs. Recompilação sem erros; painel verificado em Play com frames avançando. A build Windows anterior não foi atualizada.
