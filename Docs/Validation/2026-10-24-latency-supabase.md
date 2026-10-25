# Hospedeiro: latência mobile e PostgreSQL privado

## Executado localmente em 24/10/2026

- Godot headless import e export Web: sem `SCRIPT ERROR`/`ERROR`.
- `run_tests.gd -- latency`: 4 testes, 0 falhas; RTT, previsão/histórico, metadados compactos e descarte de estados antigos sem perder eventos.
- `run_tests.gd -- touch`: 33 testes, 0 falhas; indicador não intercepta toque, respeita menu/modal e mostra offline.
- `run_tests.gd -- network_server`: 5 testes, 0 falhas; autoridade/combate/serialização existentes.
- `test_latency_browser.py`: 4 verificações aprovadas em localhost 8198, viewport 844×390, toque e atraso artificial de 180 ms em cada direção do WebSocket. Movimento visível antes dos 360 ms, convergência para autoridade, indicador de jogo 428 ms na execução final e nenhum erro de browser/script. Captura externa ao repositório: `D:/unity/hospedeiro-web-qa/latency/mobile-ping.png`. Não é medição do servidor publicado nem de capacidade/carga.
- Preparação em PostgreSQL 17.6 local, banco isolado `hospedeiro_schema_qa`: reset de schemas de aplicação, instalação de `pg_trgm`, migrações oficiais Nakama 3.41.0 (20 tabelas no schema privado), runtime com DML nas tabelas e sem CREATE no schema. O migrator não é superusuário. A versão final da preparação foi reexecutada com sucesso localmente.
- Supervisor QA usando as URLs privadas, configuração de migração separada da execução: `test_nakama_local.py`, 7 verificações aprovadas (dois convidados, movimento, rejeição de falsificação/adapter, ator da sessão, IDs compartilhados, reconexão e reset apenas do mundo isolado QA).
- `go vet ./...` e `go test ./...`: aprovados, cache local; Jev ao vivo não habilitado. Nenhum arquivo Go mudou. `gofmt -l .` executado: listou 11 arquivos já existentes fora do escopo desta alteração; não se declara formatação global aprovada.

## Operações externas, sem testes online

Consultadas documentação oficial, preços e capacidades da conta Cloudflare. Nenhum teste foi executado contra o jogo publicado. Subidos nove arquivos do cliente (HTML/JS/PCK e compressões) para o bucket R2 já existente; Worker não modificado. Nakama/Godot locais reiniciados com código novo, motor Go e dados do mundo mantidos, sem reset real.

A conexão Supabase arquivada inicialmente não resolvia DNS; o usuário retomou o projeto pausado. Inventário administrativo mostrou `public` vazio e nenhum schema `game`. A preparação oficial do Nakama foi aplicada ao projeto dos EUA, em schema privado e sem expor tabelas a `anon`/`authenticated`. Não houve testes remotos nem consulta de dados de jogador. Naquele momento o jogo permaneceu usando PostgreSQL local, pois a meta posterior do usuário exige Brasil; a continuação abaixo registra o corte posterior.

DNS/faixas oficiais AWS indicaram `us-east-1`, confirmado no painel como East US (North Virginia). O projeto antigo foi pausado para liberar uma vaga gratuita e o painel confirmou `Project mmorpg is paused`. O formulário `hospedeiro-brasil` foi preparado em São Paulo (`sa-east-1`), Data API desligada; definição da senha e conclusão da criação ficaram com o usuário. Capturas externas ao checkout em `D:/unity/hospedeiro-web-qa/supabase-paused.png` e `supabase-brasil-ready.png`. Outros projetos da organização não foram alterados. A origem de jogo ainda não foi migrada para cloud e a meta de 100 ms ainda não foi verificada. A preparação do banco não implementa persistência remota do log Go.

## Continuação: banco brasileiro

O usuário criou `hospedeiro-brasil` pelo formulário preparado e salvou `SUPABASE_PASSWORD` no `.env`. Foram obtidos os parâmetros públicos pela janela Connect, a conexão completa foi salva em `engine/.env.supabase-brasil` (ignorado) e as migrações oficiais Nakama aplicadas ao novo schema privado com sucesso. A primeira tentativa recebeu `database system is shutting down` durante o provisionamento; a seguinte concluiu. Painel confirmou `Healthy` em São Paulo, `sa-east-1`.

O supervisor real foi apontado para o arquivo externo de runtime/migração e reiniciado. Inspeção local da configuração confirmou host brasileiro e role `hospedeiro_runtime`; logs locais sem erros, autoridade pronta e listeners 7350/8096 ativos. Motor Go manteve o mesmo processo e os mesmos dados. Não foram executados testes contra o banco remoto ou endpoint publicado. É uma operação de configuração/migração do serviço; os testes de comportamento e permissões foram feitos antes no PostgreSQL local isolado. Captura do painel em `D:/unity/hospedeiro-web-qa/supabase-brasil-ready-final.png`.

O supervisor agora lê `HOSPEDEIRO_NAKAMA_DATABASE_ENV` apenas fora de `-LocalTest`; parsing PowerShell validado após essa alteração. A origem de jogo permanece no PC e não se declara a meta de 100 ms atingida.
