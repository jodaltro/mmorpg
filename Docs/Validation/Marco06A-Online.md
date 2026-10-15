# Configuração narrativa online

A pedido do usuário, ActionVerticalSlice foi salva pelo Editor com JourneySession e WorldEventSession em OpenRouter, endpoint http://127.0.0.1:8091/v1/decisions/evaluate. O combate e a persistência continuam locais; nenhum resultado é enviado ao mundo Supabase como prova confiável.

O backend respondeu GET /healthz com status ok. Isso confirma disponibilidade HTTP, não uma resposta bem-sucedida do provedor. Nenhuma requisição narrativa foi disparada manualmente nesta verificação.

HealthHud passou a dizer COMBATE LOCAL em vez de OFFLINE. Recompilação concluída sem erros. A tentativa de testes pelo Pipeline ficou em running e uma chamada sofreu timeout; não há novo resultado aprovado. A build Windows anterior ainda contém a configuração determinística; esta alteração foi salva na cena do projeto.

Para reproduzir a configuração, executar AgentScripts/ConfigureActionNarrative.cs pelo run_script, fora de Play. Se o serviço falhar, o fallback determinístico existente permanece ativo. A cena pode iniciar requisições pagas por acontecimentos elegíveis durante o gameplay.
