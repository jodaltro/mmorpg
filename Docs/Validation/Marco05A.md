# Checkpoint 05A — concluído em 14/10/2026

Supabase de desenvolvimento existente, conexão direta IPv6 na porta 5432, TLS `verify-full` com CA oficial. O usuário autorizou migrações e alterações/reset nesse ambiente; nesta execução **não foi necessário reset**. Nenhuma chamada paga, commit ou alteração de versão Unity/Pipeline/pacotes.

## Evidência executada

| Verificação | Resultado |
|---|---|
| Supabase CLI | Migração `20261013000100` aplicada no destino aprovado; seed idempotente |
| Conexão/auth | Auth settings/JWKS HTTP 200, ES256; login Go restrito e TLS verificado — [probe](m05-dev-config-connected.json) |
| SQL remoto | 19/19 tabelas FORCE RLS; anon/authenticated/service_role sem acesso ao schema; **8/8 assertions pgTAP**, em transação revertida — [auditoria](m05-real-sql-auth-audit.json) |
| Supabase Auth + Go | Dois usuários reais, personagens privados, coleta/consumo/Leitura/relação/agenda, aviso regional compartilhado e refresh: **PASS**, 79,98 s — [teste real](m05-real-supabase.jsonl) |
| Unity + Supabase + Go | **PASS**, 49,37 s: dois logins, leitura cruzada 404, rota forest-observation, habilidade persistida e refresh; frames 23623 → 38604 — [Play real](m05-real-unity-supabase.json) |
| Go authority | **12 testes principais + 36 subcasos** aprovados com PostgreSQL 17.11 isolado e fixtures C# v1/v2/v3; teste remoto opt-in separado — [regressão](m05-authority-go.jsonl) |
| Go vet | Exit 0 após os novos comandos de desenvolvimento |
| Unity | Última regressão completa **66 EditMode + 36 PlayMode = 102**, incluindo os 90 anteriores; recompilação atual up_to_date sem falhas — [EditMode](m05-editmode.json), [PlayMode](m05-playmode.json) |
| Console atual | groundTruth.consoleErrors=0 e compilationFailed=false; erros históricos de tentativas anteriores permanecem no cursor — [console](m05-real-console.json) |
| Saves | Primária e backup iguais aos hashes originais após o Play real — [preservação](m05-save-preservation.json) |

As contas de teste foram inicialmente criadas por **seed explícito de desenvolvimento no banco**, somente para dois emails configurados e ausentes, com identidades e senhas bcrypt; não houve envio de email nem alteração de contas existentes. O Auth Server real emitiu e renovou as sessões, e o Go validou as assinaturas ES256 via JWKS. Esse seed não é um fluxo de cadastro de produção; nesse caso usar Supabase Auth/Admin API. As senhas aleatórias de teste ficam exclusivamente no arquivo ignorado `.env`.

`cmd/provision` separou a conexão administrativa em `.env.migrations` ignorado e criou `mmorpg_server` sem SUPERUSER/BYPASSRLS/CREATEDB/CREATEROLE, membro de game_backend. O `.env` usado pelo servidor contém somente esse login restrito para PostgreSQL. URLs administrativas e senhas não foram impressas nem incluídas em argumentos da CLI; a senha de migração foi entregue ao subprocesso por PGPASSWORD.

A primeira chamada longa do harness Unity atingiu o timeout de transporte da CLI de 30 s; não foi contada como aprovada. A execução registrada usou timeout de transporte 200 s e timeout da tarefa 180 s, terminou normalmente e retornou as verificações acima. Backend temporário próprio e PostgreSQL local foram encerrados; fixture com credenciais de jogadores, fora de Assets, removida; opções do Editor e fábrica de persistência restauradas.

## Limites

05A comprova autenticação, autorização, persistência e encontro **discreto por turnos** confirmado no servidor. Movimento, colisões e combate físico da cena existente continuam offline; nenhum CreatureDefeated local concede recompensa online. Não há interface online no HUD, consumidor global de outbox, worker global de agenda ou multiplayer em tempo real. A agenda mínima depende de uma intenção autenticada. Save importado só entra explicitamente em mundo is_test e continua identificado como origem offline.

Este relatório registra o gate 05A antes da expansão. 05B/05C foram concluídos posteriormente; estado atual em [Marco05](Marco05.md). Relato anterior das tentativas locais e preservação: [histórico inicial](Marco05Initial.md). Não há falha crítica conhecida de dados/segurança no gate 05A.
