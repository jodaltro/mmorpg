# Marco 05 — entrega parcial por checkpoint

**Estado atual em 14/10/2026: 05A conclu?do com Supabase Auth, PostgreSQL e cliente Unity reais.** [Relat?rio 05A e evid?ncias atuais](Marco05A.md). 05B e 05C ainda pendentes; Marco 05 n?o est? conclu?do.

O registro abaixo descreve a valida??o inicial local e seus impedimentos, posteriormente resolvidos no relat?rio 05A. A autoriza??o atual permite migra??es e resets no projeto de desenvolvimento existente; nenhum reset foi necess?rio.

## Resultado executado do 05A

| Verificação | Evidência/resultado |
|---|---|
| Editor Unity | 6000.6.5f1 conectado; CLI/Pipeline/pacotes preservados |
| Regressão inicial Unity | 59 EditMode + 31 PlayMode aprovados após corrigir a execução inicial no modo errado |
| Compilação final | completed, failed=false, compilationFailed=false — [recompile](m05-recompile.json) |
| EditMode final | **66/66** aprovados, zero falhas/ignorados — [EditMode](m05-editmode.json) |
| PlayMode final | **36/36** aprovados, zero falhas/ignorados — [PlayMode](m05-playmode.json) |
| Total Unity | **102/102**, preservando os 90 anteriores |
| Go decisions anterior | **26 testes principais + 8 subcasos** aprovados; dois pagos ignorados — [JSONL](m05-decisions-go.jsonl) |
| Go authority | **11 testes principais + 36 subcasos** aprovados; integração Auth real ignorada — [JSONL](m05-authority-go.jsonl) |
| go vet / build authority | Executados, exit 0; binário de teste fora do repo |
| PostgreSQL real | 17.11 nativo em 127.0.0.1:55432, cluster descartável fora do repo, sem dados do jogador |
| SQL migração/seeds | Aplicados nos bancos de teste; seed executado duas vezes sem duplicações |
| Supabase CLI migração | 2.120.0 com checksum verificado; `migration up --db-url` **somente loopback** executado; repetição sem migrações pendentes — [CLI](m05-cli-migrations.json), [repetição](m05-cli-migrations-repeat.json) |
| PostgreSQL segurança/transações | Isolamento, grants/RLS, rollback de múltiplas entidades, constraints, agenda, aviso único compartilhado, concorrência e replay aprovados nos testes Go |
| Exportação saves | **9 verificações** v1/v2/v3/checksum/recusa de sobrescrita/fontes intocadas — [Editor](m05-save-import.json) |
| C# export → PostgreSQL | Três subcasos v1/v2/v3 aprovados com arquivos gerados pelo Editor; projeções e histórico preservados |
| Play ao vivo | **9112 → 9191 frames**, advancing=true, sessão com save temporário — [frames](m05-frames.json) |
| Console | Compilação final sem falha; histórico de erros anteriores/tentativas preservado — [Play](m05-console-play.json), [final](m05-console-final.json) |
| Supabase stack/Auth real | **Não executado com sucesso**; faltam configuração acessível do projeto dev e teste com dois usuários reais |
| pgTAP `supabase test db` | Preparado com oito assertions; **não executado** por ausência de stack Supabase local |

Os testes PostgreSQL usam auth.users mínima de fixture para integridade de FK e identidades de teste. Não são usuários autenticados no Supabase Auth real. JWKS/Auth Server usam httptest nos testes unitários; Unity usa HTTP loopback simulado nos novos testes. Esses resultados não são promovidos ao gate completo 05A.

## Implementado e utilizável em testes

- Migração privada `game`: characters, character_facts/memories/abilities/inventory/equipment/opportunities, npc_knowledge/relationships, worlds/regions/events, scheduled_consequences, decision_records, event_outbox; auxiliares de conteúdo/encontros/receipts/importação. PKs/FKs/UNIQUE, versões, índices, grants mínimos e FORCE RLS.
- Go pgxpool com papel mínimo verificado, JWT RS256/ES256/JWKS ou HS256/Auth Server, identidade e dono revalidados, contratos HTTP /v1 e erros sanitizados. Configuração por ambiente ou arquivo local explícito, sem expansão de shell.
- Encontro por turnos simulado pelo Go: preparo, esquiva, exposição, dano calculado, derrota e coleta única. Rotas A/B da floresta, consumo/transação, habilidade/relação/conhecimento/agenda, aviso único e projeção regional compartilhada. Não aceita derrota/dano/recompensa do cliente.
- Adaptadores Unity opt-in de login/refresh/intenção/replay de requestId; sem recompensa offline ao falhar, sem tokens nos saves e sem acoplar a cena offline ao banco.
- Export/import explícito de desenvolvimento v1/v2/v3, novo destino is_test e proveniência offline-import. Histórico arquivado por registros; agenda offline preservada como arquivo histórico, não reativada como consequência mundial confiável. Original intacto. Fingerprint impede substituir uma importação com outro conteúdo.
- Teste real opt-in preparado para stack local ou projeto de desenvolvimento existente, com dois usuários preexistentes no modo remoto. Não cria contas/projetos/tabelas remotos nem executa reset. Depende de configuração e migração revisada/aprovada no destino.

## Falhas encontradas e corrigidas

1. Primeiras suites Unity disparadas com Play ativo não produziram conclusão e emitiram exceções do Test Runner. Foram canceladas e reexecutadas sequencialmente fora do Play. Apenas resultados completed contam como aprovação. Os erros históricos estão em [Console inicial](m05-console-initial.json).
2. Novo teste PlayMode referenciava JObject/Newtonsoft sem referência disponível naquela assembly. Corrigido o contrato público do adaptador para JSON string/revisão, mantendo JObject interno. A assembly de testes foi restaurada ao conteúdo original; nova compilação e 102 testes aprovados.
3. PostgreSQL detectou inferência incompatível UUID/text no INSERT de outbox. Corrigidos casts UUID explícitos; teste transacional e suite completa aprovados depois da correção.
4. Download inicial PostgreSQL em C: esgotou o espaço temporário. Apenas o arquivo incompleto criado por esta tarefa foi removido; ferramentas/builds/cluster transferidos para diretório temporário em D:. Nenhum arquivo do projeto ou save foi apagado.
5. Docker Desktop instalado não inicia engine: log `hasNoVirtualization=true`; `supabase start` falhou na inspeção do contêiner. [Tentativa CLI](m05-supabase-start.json). Não foi alterado BIOS/virtualização/Windows para contornar o problema.
6. Tentativa de compilar o Supabase Auth oficial nativamente fora do repo falhou por chamadas Unix (SetsockoptInt/SO_REUSEPORT). Não foi usado um Auth modificado para declarar validação real. O usuário escolheu o projeto dev remoto existente; ainda falta sua configuração acessível.
7. Uma tentativa de restaurar opções Play usou um nome inexistente de método de harness. A restauração foi executada em seguida pelo método existente RestoreEditorSettings. Não houve alteração final em ProjectSettings.

## Preservação e limpeza

Baselines SHA-256 em Temp, sem conteúdo de credenciais. Comparação final comprova nenhuma exclusão original; dentro de Assets/AgentScripts/Backend anterior/Packages/ProjectSettings apenas Docs/Architecture recebeu a atualização intencional de documentação. .gitignore raiz recebeu exclusões do estado local Supabase. Metadados dos quatro C# novos foram gerados pelo Editor. SampleScene, OfflineClearing, regras, testes anteriores e pacotes preservados. Saves primária/backup conferidos por hash; nenhuma importação usou o save original.

Durante a auditoria inicial, habilitar ticks com a sessão Play preexistente ativa permitiu um autosave antes de sua saída. A comparação final detectou a alteração das gerações originais. A primária exata ainda existia no backup e foi preservada antes de restaurar. O backup anterior foi recuperado a partir da primária, enumerando apenas os valores anteriores dos dois relógios do checkpoint; **nenhum candidato foi aceito sem coincidir com o SHA-256 integral registrado para o arquivo original**. As duas gerações foram restauradas byte a byte e revalidadas. [Preservação final](m05-save-preservation.json). Portanto houve escrita transitória, corrigida; não se afirma que os arquivos jamais foram tocados durante a execução. As suites posteriores e a sessão final usaram persistência isolada.

Editor encerrado fora de Play; fábrica de persistência temporária e opções originais de Play restauradas. PostgreSQL de teste encerrado; seus arquivos ficam fora do repo para reprodução. Git permanece sem commits e sem stage. Manifesto em [m05-files](m05-files.json).

A revisão automática bloqueou uma tentativa de limpar diretórios temporários de ferramentas fora do projeto, sem justificativa adicional. A limpeza não foi executada; esses diretórios foram mantidos. Isso não bloqueia testes, código ou restauração dos saves.

## Limites e checkpoint seguinte

Não há login/HUD online na cena nem autoridade remota da física Unity. O encontro Go não prova movimento/colisão/alcance em tempo real. new-threat-tracks/hunter-training físicos seguem offline; não há consumidor outbox/worker global de agenda, equipamento utilizável ou transferência entre mundos. Não há evento Asterion, cinco áreas, 8–10 criaturas, 10–12 NPCs, ≥8 habilidades, 30–40 itens, 25–35 oportunidades ou ≥100 jornadas simuladas. [Conteúdo atual](../WorldContent.md), [habilidades](../Abilities.md), [itens](../Items.md), [mapa](../WorldMap.md), [simulação](../Simulation.md).

Para concluir 05A: disponibilizar localmente a configuração do projeto dev isolado, inspecionar/aprovar o destino da migração caso ainda não aplicada, executar Auth real/JWKS ou Auth Server com dois usuários e a suite de persistência/isolamento nesse ambiente. Só depois avançar ao 05B; critérios e estratégia Nakama estão em [SupabaseIntegration](../SupabaseIntegration.md) e [plano](../Marco05Plan.md).

## Nova tentativa com configuração preenchida

Após o usuário preencher Backend/authority/.env, o probe somente leitura `cmd/check` confirmou Auth settings HTTP 200 e JWKS HTTP 200 com uma chave ES256. AUTH_MODE=jwks é compatível. Nenhum login de jogador foi realizado, portanto isso confirma conectividade/configuração pública, não autenticação completa com dois usuários.

DATABASE_URL foi rejeitada antes de qualquer conexão: não possui prefixo postgres:// ou postgresql://, host ou userinfo, e pgx classificou o erro como invalid keyword/value. Não foram impressos valores de configuração. Não houve migração, criação de conta/personagem, reset ou alteração remota. [Evidência sanitizada](m05-dev-config-retry.json). O gate continua pendente da URI PostgreSQL correta e dos dois usuários de teste configurados localmente. Go test e vet executados novamente sem falhas; testes dependentes de banco/fixtures/Auth real permaneceram ignorados nesta tentativa.
