# Monitor central — 06B.4

**F8** mostra/oculta. **Ctrl+F8** alterna histórico expandido. Somente Editor/Development. Não pausa, não captura ponteiro e não dispara avaliação de IA. **F7** é o debug separado de espada/Sweep. Ctrl evita conflito com Shift, já usado pela esquiva.

`RuntimeDiagnostics` centraliza estados e um histórico circular thread-safe de 64 registros. `WorldDebugOverlay` lê só snapshots desse serviço a cada 0,25 s. `DiagnosticsService` mede FPS em janelas de 0,5 s e consulta apenas GET `/healthz` loopback a cada 20 s, timeout 2 s, sem redirects. Não há polling por frame de serviços, credenciais, prompt ou payload completo no HUD.

O histórico expandido apresenta os quatro registros mais recentes com correlações resumidas a oito caracteres e detalhes curtos, para caber no painel. Os 64 registros internos mantêm a correlação maior para inspeção via serviço.

| Linha | Fonte real | Limite de interpretação |
|---|---|---|
| MODE | registro de SupabaseSession em memória | configuração de URL não significa login |
| GO | resposta GET health, status JSON `ok`, tempo Stopwatch | offline/timeout/não verificado distintos; endpoint padrão 127.0.0.1:8093 |
| SUPABASE | operações autenticadas observadas de `/v1/characters` no OnlineAuthorityClient | `/healthz` atual não consulta DB. Sem operação real: não verificado. Go indisponível invalida OK anterior |
| JEV | início/fim do cliente real de Mira/mundo, provider/fallback do DecisionRecord | modo determinístico é local, não chamada OpenRouter; provedor configurado não é verificado |
| LAST | duração HTTP observada; latência/custo reportados quando há resposta de provedor | custo não é estimado; contrato atual não informa cacheHit, portanto cache não é afirmado |
| EVENTS/EVAL | consequências agendadas não executadas/canceladas e conjunto de avaliações correntes | fila de mundo e avaliações são contadores distintos |
| EVENT/CONSEQUENCE | Submit validado / TryApplyDecision | seleção inválida é rejeitada antes da consequência |
| OPP/v | oportunidade Started e revisão de WorldState | não modifica limite/regra de oportunidades |
| SAVE | captura/enfileiramento e término real do worker | distingue enfileirado/salvo; erro local é observável |

Fluxo observável: GameplayEvent → EligibilityCandidates → Decision waiting/local/completed/fallback → Validation accepted/rejected → Consequence → Persistence → apresentação atualizada. O eventId é a correlação; avaliações mundiais incluem a causa no ID e publicam ligações Candidate/causeId. Mensagens guardam somente identificadores higienizados e etapas, limitados a 48 caracteres por campo. A fila tem no máximo 64 entradas, não cresce indefinidamente.

O modo B4 fornecido continua determinístico e sem endpoint de decisão configurado. Nenhuma consulta paga é feita para verificar Jev. Acesso real ao banco só ocorre pelos fluxos online existentes e suas credenciais continuam nos adaptadores existentes, fora do painel. Sem autorização/serviço disponível, não há comprovação de Supabase online ou chamada OpenRouter real neste marco.
