# Marco 05 — entrega e validação

**05A, 05B e 05C validados em desenvolvimento em 14/10/2026.** O mundo expandido é um protótipo jogável por turnos/intenções abstratas, com navegação visual na Unity. Não se declara autoridade de movimento/colisões, nove IAs físicas, escala MMO ou multiplayer em tempo real. Unity 6000.6.5f1, Pipeline e pacotes preservados; nenhum commit, chamada paga ou reset remoto.

| Checkpoint | Resultado / relatório |
|---|---|
| 05A | Supabase Auth real, dois usuários privados, região compartilhada, persistência, importação explícita — [05A](Marco05A.md) |
| 05B | Cinco regiões, nove arquétipos, 12 técnicas, 38 itens, 12 NPCs, 31 oportunidades, acontecimento único — [05B](Marco05B.md) |
| 05C | 120 jornadas principais, seis atores em um mundo compartilhado, replay e testes Jev sem custos — [05C](Marco05C.md) |

## Arquivos e arquitetura

[Manifesto completo dos arquivos criados/alterados](m05-files.json). Componentes principais:

- `Backend/authority`: Go/pgxpool, Auth JWKS/HS256 Auth Server, HTTP v1, transações, receipts/outbox, importação e ferramentas explícitas de desenvolvimento.
- `Backend/authority/journey`: catálogo versionado e único motor da expansão; os mesmos efeitos usados pelo servidor e pelo simulador.
- `Assets/Mmorpg/Runtime`: SupabaseSession/OnlineAuthorityClient e WorldJourneySession/Hud/View. Não aplicam recompensas locais ao falhar.
- `Assets/Mmorpg/Scenes/Marco05World.unity`: cena nova; OfflineClearing e sample assets preservados. `AgentScripts` contém autoria, validação, exportação de saves e geração de relatórios reproduzíveis.
- `Backend/decisions`: serviço Jev existente preservado; novas baterias de histórias/telemetria/contingência e comparação manual opt-in.

[Arquitetura](../Architecture.md), [auditoria/plano](../Marco05Plan.md), [integração e ambiente](../SupabaseIntegration.md).

## Schema e migrações

Três migrações aplicadas pela Supabase CLI no projeto de desenvolvimento autorizado:

1. `20261013000100_game.sql`: schema privado, Auth owner, projeções normalizadas, história/fatos/memórias, habilidades/inventário/equipamento/oportunidades, perspectivas NPC, mundo/regiões/eventos, agenda, decisões, outbox, encontros/receipts/importações.
2. `20261014000100_expanded_world.sql`: seleção de regras por mundo, novos slots/statuses, runtime do personagem, cooldowns, agenda por ações e encontros distintos em registros próprios.
3. `20261014000200_sourced_regional_updates.sql`: atualização regional por presença ou acontecimento imutável confirmado pelo autor, permitindo concluir agenda após viajar.

`supabase/seed.sql` é reproduzível e idempotente: mundos `marco05-dev` e `marco05-expanded`, conteúdo e regiões. As 23 tabelas são privadas e FORCE RLS. anon/authenticated/service_role não têm acesso ao schema; o servidor usa mmorpg_server restrito + SET LOCAL ROLE game_backend + contexto de dono verificado. Administração fica somente em `.env.migrations` ignorado; cliente não recebe URI/senha PostgreSQL, secret/service_role ou OpenRouter.

[Histórico/migrações reais](m05b-real-migrations.json), [auditoria final com 8/8 pgTAP](m05-real-sql-auth-audit-final.json). Não houve `supabase test db` com stack Docker funcional; as oito assertions pgTAP foram executadas no banco de desenvolvimento em transação revertida. Testes que criam/dropam bancos só usam PostgreSQL nativo isolado em loopback.

## Fluxo de autenticação e persistência

Unity → Supabase Auth sign-in/refresh → access token em memória → Go valida assinatura ES256/RS256 via JWKS ou HS256 via Auth Server, issuer/audience/exp/sub → personagem vinculado ao usuário autenticado → intenção validada → alterações normalizadas/fatos/outbox/decisão/receipt na mesma transação → projeção para Unity. Propriedade nunca deriva só do ID enviado pelo cliente.

Tokens expirados retornam 401; refresh repete o mesmo corpo/requestId uma vez. Clear limpa memória, sem revogação remota. JWT válido pode continuar aceito até expiração após logout; garantias imediatas exigiriam validação adicional de session_id. Isso não é confundido com o cache local de chaves. [Sessões Supabase](https://supabase.com/docs/guides/auth/sessions).

Duas contas foram seeded explicitamente como fixtures de desenvolvimento ausentes, sem emails ou alterações de contas existentes. Sessões foram emitidas/renovadas pelo Auth real. Seed direto de auth.users/identities não é cadastro de produção; usar Auth/Admin API nessa etapa. [Prova Go](m05-real-supabase.jsonl), [prova Unity 05A](m05-real-unity-supabase.json), [mundo expandido real](m05b-real-unity.json).

## Conteúdo jogável

| Sistema | Entrega |
|---|---|
| Regiões | Valdoria, Floresta Cinzenta, Minas de Kharum, Pântano dos Ecos, Ruínas de Asterion — [mapa](../WorldMap.md) |
| Criaturas | Lobo, javali, aranha, morcego, sentinela, rastejante, eco, hidra e guardião; distância, veneno, voo, armadura, ocultação, resistência etérea, regeneração e proteção — [condições/mecânicas](../WorldContent.md) |
| NPCs | 12 identidades/localizações, papéis, informação inicial e oportunidades; perspectivas/conversas privadas e fontes registradas |
| Habilidades | 12 com efeitos/capacidades e regras de ativação; rotas alternativas por combate, defesa/esquiva, investigação, extração, estudo e memória — [habilidades](../Abilities.md) |
| Itens | 38 definições usadas em receitas, encontros, evidências, equipamento ou consumo; quantidade/obtenção/uso persistidos — [itens](../Items.md) |
| Oportunidades | 31 na expansão, mais fluxos anteriores preservados. Linhas opcionais conectadas; máximo três visíveis; ignorar não bloqueia exploração |
| Histórico | Farol de Asterion único por mundo, condições inter-regionais, autoria e rota de descoberta para outros. Lock + UNIQUE + rollback; sem arma superior |

O Play real executou **68 ações**, visitou cinco áreas, desbloqueou 12 habilidades, enfrentou lobo/morcego, coletou, forjou/equipou e consumiu. Efeitos das 12 habilidades e nove padrões de encontro foram testados no domínio Go; não se afirma que todos os efeitos foram exercitados individualmente pela Unity real. [Game view inspecionada](m05b-ui.png).

## Simulação e testes

120 jornadas principais, 20 por perfil, sementes 505000–505019, até 240 ações. Seis atores adicionais compartilham mundo; seis controles isolam variação de sementes. [Relatório comparativo](../Simulation.md), [CSV](../SimulationComparison.csv), [históricos completos](m05-simulation.json).

- Combatente: 6 habilidades / 9 oportunidades; explorador: 3 / 5; pesquisador: 12 / 23; coletor: 6 / 23; misto: 12 / 31; ignora: 0 / 0 e oito recusadas. Todos conseguem visitar cinco áreas.
- Zero oportunidades inacessíveis na união; zero monopolizadas por um perfil; zero consequências duplicadas/conflitos/repetição excessiva de serviços. Dependências e consumos são validados pelo mesmo motor usado na persistência.
- Distância de resultados entre políticas com semente fixa: 0,8023; controle só de sementes com política fixa: 0. Replay da bateria completo byte a byte. Isso não prova variedade humana infinita dentro de cada estilo ou balanceamento MMO.

| Testes executados | Resultado |
|---|---|
| Unity EditMode | **66/66** — [resultado](m05b-editmode.json) |
| Unity PlayMode | **39/39** — [resultado](m05b-playmode.json) |
| Unity total | **105**, incluindo todos os 90 iniciais; apresentação posterior compilada/inspecionada, console atual sem erros |
| Go authority/journey | **29 principais + 64 subcasos**, zero falhas — [resultado](m05c-authority-go.jsonl) |
| Go/Jev | **28 principais + 11 subcasos**, zero falhas; três testes pagos ignorados — [resultado](m05c-decisions-go.jsonl) |
| SQL real | Migrações/seeds e **8/8 pgTAP**; isolamento, rollback, concorrência, inventário, agenda e replay também nos testes PostgreSQL isolados |
| Importação saves | v1/v2/v3, nove verificações Editor e três fixtures C# → PostgreSQL; origens de teste intactas |
| Vet/build | Dois módulos Go com vet aprovado; servidor construído fora do repo |

Jev mantém sua função consultiva nos acontecimentos anteriores. A expansão usa decisões determinísticas do Go; Jev não é fonte de loot/desbloqueio. A bateria automática usa mocks HTTP para escolhas/custo/latência, não medições pagas reais. Bateria manual de três contextos preparada, **não executada** sem autorização específica. Não se chama Jev em cada ataque/movimento.

## Inicialização

```powershell
Set-Location D:\unity\Mmorpg\Backend\authority
$env:GOTMPDIR = "D:/tmp/mmorpg-m05-tools/gotmp"
$env:GOCACHE = "D:/tmp/mmorpg-m05-tools/gocache"
.\Start-Authority.ps1 -EnvFile .env -GoCommand "$env:TEMP\mmorpg-go-tools\go\bin\go.exe"
```

Abrir `Assets/Mmorpg/Scenes/Marco05World.unity` e dar Play. Usar uma conta Supabase do ambiente de desenvolvimento; as contas de teste estão apenas no arquivo local ignorado, sem publicação de credenciais. Nome e ID vazio criam um personagem; guardar/reutilizar o ID exibido para continuar com a mesma conta. WASD move a representação, botões enviam ações e a roda do mouse navega o diário. Backend padrão loopback 8093; serviço Jev anterior permanece separado em 8091.

Migrar novamente: `go run ./cmd/migrate -migration-env .env.migrations -apply`, passando `-supabase-cli` se a CLI não estiver no PATH. O comando preserva conta restrita/arquivos, exige mundo de desenvolvimento existente e não executa reset. Reprodução local/testes/simulador detalhados em [SupabaseIntegration](../SupabaseIntegration.md) e [Simulation](../Simulation.md).

## Limitações e Nakama

Movimento e colisões não possuem autoridade remota. O combate físico original permanece offline; o novo combate é discreto por turnos. Arte e salas usam placeholders, não mapas/artes finais. Não há servidor multiplayer publicado, reconciliação, rate limiting/quotas de produção, consumidor global de outbox, worker mundial ou teste de carga MMO. Agenda depende de atividade; lock mundial serializa o protótipo. Sessões não são armazenadas entre reinícios; IDs precisam ser reutilizados explicitamente.

Nakama futuro deve validar/linkar o mesmo sub Supabase, conservar owner_id e transações, sem segundo cadastro. Próximas etapas: transporte/sessões multiplayer, simulação independente de movimento/colisão/hits, snapshots/reconciliação, worker/outbox, locks por recurso, observabilidade/limites e revogação de sessão para operações sensíveis.

Saves primária/backup e arquivos anteriores foram conferidos por hash. Houve um autosave transitório na auditoria inicial do 05A, restaurado byte a byte com os hashes integrais; as sessões seguintes foram isoladas e a cena nova não os carrega. [Preservação final](m05-save-preservation.json), [histórico detalhado de tentativas/correções](Marco05Initial.md). Arquivos originais alterados intencionalmente: Docs/Architecture e EditorBuildSettings para acrescentar a cena. Nenhuma exclusão original, stage ou commit.

O lan?amento opcional final do backend em segundo plano foi bloqueado pela revis?o autom?tica com apenas ?blocked by policy?, sem motivo adicional. N?o foi contornado; o backend de valida??o foi encerrado e a inicializa??o deve ser feita pelo comando acima. Esse bloqueio n?o altera os resultados executados de banco/Auth/Unity.
