# Supabase + autoridade Go — checkpoint 05A

Status de execução e pendências: [Marco05](Validation/Marco05.md). Migração da arquitetura: [plano e auditoria](Marco05Plan.md).

## Configuração local

Unity/Pipeline/pacotes existentes preservados. Supabase CLI 2.120.0 foi obtida do release oficial com SHA-256 conferido, fora do repositório. `supabase/config.toml` possui project_id próprio, Auth de desenvolvimento com email sem confirmação e somente `public` exposto pela Data API; `game` não está exposto. Não há credenciais na configuração.

Com Docker compatível funcionando, a partir da raiz:

```powershell
supabase start
supabase migration up --local
supabase test db
```

`start` aplica migrações/seeds na stack local. A migração inicial `20261013000100_game.sql` cria schema privado, tabelas e papel game_backend NOLOGIN/NOBYPASSRLS. O seed cria somente `marco05-dev` is_test=true e o conteúdo já existente. Não cria usuários, senhas ou mundo de produção. Não executar link/push/reset remoto nesta entrega. Para recriar um ambiente de teste, usar outro project_id/stack isolada; nunca resetar banco remoto.

Provisionar um login **exclusivo do backend** com senha entregue por canal seguro ao administrador do banco, sem incluí-la em migrações, logs ou argumentos de shell. Exemplo de atributos, sem senha:

```sql
CREATE ROLE mmorpg_server LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
GRANT game_backend TO mmorpg_server;
```

Configurar a senha separadamente (por exemplo `psql` interativo `\password mmorpg_server`). `DATABASE_URL` deve usar esse login; o servidor recusa superuser/BYPASSRLS/CREATEROLE/CREATEDB e exige TLS verificado fora do loopback. Conta de migração/admin e conta de execução são distintas. Backend executa `SET LOCAL ROLE game_backend` e `set_config('app.user_id', UUID verificado, true)` em cada transação. O contexto de dono não vaza entre conexões reutilizadas.

Configurar no processo Go as variáveis do modelo [Backend/authority/.env.example](../Backend/authority/.env.example); o novo servidor **não carrega .env automaticamente**. Alternativa: preencher um arquivo `.env` ignorado e passá-lo explicitamente com `./Start-Authority.ps1 -EnvFile .env` / `go run ./cmd/server -env-file .env`. Parser literal, sem expansão/execução; ambiente tem prioridade; erros não exibem valores. A configura??o de desenvolvimento preenchida fica em Backend/authority/.env ignorado; nunca versionar seu conte?do:

| Variável | Uso |
|---|---|
| DATABASE_URL | PostgreSQL com login restrito; segredo somente no backend |
| SUPABASE_URL | URL base do projeto Auth (HTTPS; loopback HTTP permitido explicitamente) |
| SUPABASE_PUBLISHABLE_KEY | Publishable key ou anon legada; nunca service_role/secret key |
| AUTH_MODE | jwks para RS256/ES256; auth-server para HS256 legado |
| ALLOW_LOCAL_AUTH | true somente para loopback de desenvolvimento |
| LISTEN_ADDR | loopback, padrão 127.0.0.1:8093 |
| ENABLE_DEV_IMPORT | false por padrão; true somente para importação explícita em mundo de teste |

```powershell
Set-Location Backend/authority
go test -count=1 ./...
go vet ./...
./Start-Authority.ps1
```

Nenhuma conexão externa será criada/publicada por esses comandos. O processo serve apenas loopback. Para produção seriam necessários ingress HTTPS, rate limiting/quotas, observabilidade e implantação aprovada separadamente.

Para verificar a configuração sem alterar o destino: `go run ./cmd/check -env-file .env`. O probe consulta somente Auth settings/JWKS e metadados PostgreSQL, reforça TLS em memória, não modifica o arquivo e retorna apenas estados/booleans/algoritmos. Nunca imprime URI, senha, chave ou corpo upstream. DATABASE_URL precisa ser URI PostgreSQL completa do diálogo Connect, incluindo usuário/host/banco; somente a senha ou a URL HTTPS pública não são uma conexão de banco.

## Autenticação e renovação

`SupabaseSession` é um adaptador opt-in da Unity: SignIn/SignUpDevelopment, refresh e Clear. Somente URL pública e publishable/anon entram no cliente; nenhum password PostgreSQL, service_role, JWT secret ou OpenRouter. Access/refresh tokens permanecem em memória, não em PlayerPrefs, Inspector ou saves. Signup sem confirmação é exclusivo do ambiente local. Nova geração da sessão invalida respostas antigas.

`SupabaseAuth` valida issuer `${SUPABASE_URL}/auth/v1`, audience authenticated, exp obrigatório, iat, nbf, sub UUID canônico e role authenticated. Em jwks verifica assinatura RS256/ES256 no endpoint fixo `.well-known/jwks.json`; nunca usa jku/x5u enviado pelo token. O cache local de chaves dura um minuto; há também cache upstream, portanto isso não garante revogação imediata de chaves. Reiniciar limpa apenas o cache local. Validação JWT não consulta auth.sessions: encerrar a sessão não impede por si só o uso de um access token já emitido antes da expiração. SupabaseSession.Clear limpa a memória do cliente, sem revogação remota; operações que exigirem revogação imediata precisarão validar session_id no servidor. [Sessões oficiais](https://supabase.com/docs/guides/auth/sessions), [cache de JWKS](https://supabase.com/docs/guides/auth/signing-keys). Em auth-server só aceita HS256 e exige HTTP 200 de `/auth/v1/user` para o mesmo sub. Timeout/redirect/resposta inválida falham sem autenticar. O backend não recebe o segredo simétrico.

Token inválido/expirado retorna 401 com erro sanitizado. `OnlineAuthorityClient` renova uma vez e repete **o mesmo corpo/requestId**; se a renovação falhar, encerra a sessão. Erro de banco/rede não produz recompensa ou fallback offline. Para persistência de sessão entre reinícios será necessário armazenamento seguro específico da plataforma; nesta entrega o usuário autentica novamente.

Referências oficiais consultadas: [JWT e verificação HS256 pelo Auth Server](https://supabase.com/docs/guides/auth/jwts), [JWKS/rotação](https://supabase.com/docs/guides/auth/signing-keys), [CLI local e migrações](https://supabase.com/docs/guides/local-development/cli-workflows).

## HTTP v1 e autoridade

Todos os `/v1/*` exigem Bearer validado; desconhecidos/corpos excessivos/JSON extra/Origin são recusados. O serviço consultivo anterior em 8091 continua separado e **não concede estado persistente**. Não foi exposto ao multiplayer. A nova autoridade não aceita damage, reward, inventory, abilities, ownerId ou CreatureDefeated como comandos.

| Método/rota | Operação |
|---|---|
| GET /healthz | Saúde do processo; inicialização confere papel/banco |
| GET /v1/characters | Lista apenas os IDs do dono |
| POST /v1/characters | `{version:1,worldId,name}`; dono vem do token |
| GET /v1/characters/{uuid} | Projeção privada; outro dono recebe 404 |
| POST /v1/characters/{uuid}/intentions | `{version:1,requestId:UUID,expectedRevision,kind,targetId}` |
| GET /v1/worlds/{world}/regions/{region} | Somente projeção regional pública, sem inventários/fatos privados |
| POST /v1/development/imports | Desabilitado por padrão; mundo explícito is_test obrigatório |

Intenções implementadas: examine-tracks/corrupted-tracks, brief-orin/orin, start-encounter/corrupted-wolf, attack ou dodge/UUID do encontro, collect/UUID do encontro, deliver-mira/mira e tick/targetId vazio. São ações discretas do **encontro por turnos de demonstração**, não interações físicas confirmadas na cena Unity. O Go controla hp, turnos, fases, dano (20), preparo/contra-ataque (15), exposição após esquiva, coleta única e bônus limitado da Leitura (10 durante exposição).

Rota A consome a amostra, conclui a oportunidade, concede a habilidade uma vez, registra relação/conhecimento de Mira, decisão determinística e agenda em uma transação. Rota B exige rastros + conversa com Orin **antes** da derrota simulada, concede a mesma habilidade por outra causa e não exige entrega. Conhecimento de um personagem não aparece em outro. Após 15 segundos de relógio do banco, `tick` ou outra intenção revalida investigação, conhecimento de Mira e ameaça, publica um único aviso mundial e altera a projeção regional compartilhada. Não existe worker global nesta entrega: clientes precisam solicitar tick; uma agenda privada não é avançada sem atividade autenticada do dono.

Receipts/fingerprints, trava do personagem, revisão esperada, fact semantic_key, PKs e UNIQUE mundial garantem replay/idempotência/concorrência entre processos PostgreSQL. Falha em qualquer entidade reverte toda a transação. Outbox é gravada na mesma transação por fato; seu consumidor assíncrono ainda não existe. O payload contém IDs, não texto privado nem credenciais.

Movimento, colisão e combate em tempo real da OfflineClearing permanecem locais. Não há transporte multiplayer, reconciliação ou autoridade Go dessa física. Não vincular callbacks de derrota local à API online. A cena mantém saves/offline anteriores; o adaptador online é usado explicitamente por código/harness e não possui uma tela de login ou conexão com o HUD existente.

## Modelo persistente e segurança

`characters` vincula owner_id a auth.users(id) e referencia mundo/região. Projeções separadas: character_abilities, character_inventory (quantidade positiva), character_equipment, character_opportunities, npc_knowledge, npc_relationships e world_regions. Histórico por registros: character_facts, character_memories, world_events, decision_records, scheduled_consequences e event_outbox. Auxiliares: content_definitions, encounters, command_receipts, development_imports. Payload JSON é limitado a um fato/decisão/receipt; não substitui todas as tabelas por um blob de personagem.

Escopos: inventário/atributos/fatos/agenda/decisões privados do personagem; NPC knowledge/relação são a perspectiva privada do personagem; threat/notice são públicos por região; world_events são únicos no mundo e atribuem autoria ao character UUID. Não há conhecimento global automático. Histórico é append-only pelo papel backend; somente projeções recebem UPDATE/DELETE necessários. FORCE RLS ativo em todas as tabelas; anon/authenticated/service_role não têm USAGE ou grants em game. Qualquer futura tabela disponibilizada na Data API deverá receber grants/políticas específicas antes de exposição.

Equipamento tem integridade por FK, mas nenhuma operação de equipar/consumíveis foi implementada no 05A. Não apresentar tabelas preparadas como gameplay de itens/expansão. O aviso regional atual não é o evento experimental de Asterion do 05B.

## Saves v1/v2/v3 e importação de desenvolvimento

`JsonJourneyPersistence`, enum/IDs e arquivos originais não são alterados. A ferramenta [ExportDevelopmentSave](../AgentScripts/ExportDevelopmentSave.cs) exige sourcePath, outputPath novo, destinationWorld e characterName. Verifica envelope/checksum e `JourneyEngine.Restore` (inclui replay do WorldState v3), lê somente a primária nomeada e recusa sobrescrever saída. Nenhum upload automático.

Invocar pelo Editor conectado:

```powershell
unity command run_script --caller plugin --skill unity-pipeline -- --file AgentScripts/ExportDevelopmentSave.cs --entry ExportDevelopmentSave.Export --args '["CAMINHO_ORIGEM", "CAMINHO_SAIDA_NOVO", "marco05-dev", "Nome"]'
```

Em shells que removem aspas JSON de argv, chamar a CLI por subprocess com vetor de argumentos (sem compor command strings), ou usar o harness `ValidateDevelopmentImport.Run` no mesmo arquivo para fixtures isoladas.

O export normaliza fatos, decisões, conhecimento, relações, itens e oportunidades. Logs/agenda/decisões anteriores são arquivados como fatos/memórias separados. **Agenda offline pendente é preservada como histórico, não reativada em um mundo compartilhado.** A importação gera um personagem novo, marcado offline-import, apenas em is_test=true, mantendo fonte/version/checksum. Não concede autoria de world_events nem aplica threat/notice adulteráveis. O checksum/replay valida consistência offline, não prova legitimidade multiplayer. Nunca promover um import para mundo confiável.

Com backend EnableDevImport e token do usuário no ambiente temporário:

```powershell
./Backend/authority/Import-DevelopmentSave.ps1 -ExportPath CAMINHO_EXPORT
```

Repetir o mesmo conteúdo/sourceChecksum/dono/destino reutiliza o personagem importado. Importações com checksum igual não servem para substituir o estado existente. Export/POST não modificam a origem. Personagem importado não tem encontro de combate local convertido em prova de derrota online.

## Validação e futuro Nakama

Go unit usa httptest para JWKS/Auth Server; nunca chaves reais ou API paga. `TEST_DATABASE_URL` habilita testes PostgreSQL **somente 127.0.0.1, database postgres de uma instância descartável**. A fixture cria/dropa seus próprios bancos mmorpg_test_UUID e papéis com UUID, aplica SQL/seeds, usa login mínimo e testa rollback/concorrência/grants. Sua auth.users mínima é fixture de FK, **não Supabase Auth real**. Não configurar essa variável para produção. pgTAP requer a stack Supabase local real e `supabase test db`.

`TestSupabaseLocalAuthAndPersistentCharacters` está preparado para a validação real, desabilitada nas suites normais. Local: `SUPABASE_LOCAL_TEST=1`, banco/login mínimo e Auth local configurados. Projeto remoto de desenvolvimento já existente: exige `SUPABASE_DEV_TEST=1`, `ALLOW_REMOTE_DEV_TEST=1`, `AUTH_ENV_FILE` apontando ao arquivo local e dois usuários **preexistentes** (SUPABASE_TEST_EMAIL_A/PASSWORD_A e B), além de TLS verificado. Mundo marco05-dev precisa estar marcado is_test. O teste não cria projetos/tabelas/contas remotas, não executa reset; cria dois personagens de teste e confirma isolamento, encontro, obtenção/entrega, região e refresh. Rodar apenas após identificar/aprovar o projeto e aplicar migrações de forma revisada.

Nakama futuro deve validar/linkar o mesmo sub Supabase no servidor e manter characters.owner_id como referência única de conta. Não criar segundo cadastro, não aceitar UUID cliente como propriedade. Sessões Nakama e autoridade Go terão que validar simulação/collision/hits e persistir o mesmo modelo transacional. Não foi adicionado Nakama neste checkpoint.
