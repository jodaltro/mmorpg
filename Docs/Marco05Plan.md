# Marco 05 — auditoria e execução por checkpoints

Auditoria em 13/10/2026, antes da implementação. Foram lidos AGENTS.md, Architecture, EventSystem, TrainingDummy, GoEventContract, JevIntegration, WorldEventOrchestrator e relatórios de validação dos Marcos 01–04. Unity 6000.6.5f1 / Pipeline 0.8.0-exp.1 preservados. Git master sem commits; projeto inteiro não rastreado. Nenhum stage/commit será feito. Baseline SHA-256 em Temp/m05-baseline-files.json e Temp/m05-baseline-saves.json, sem conteúdo de segredos.

## Regras e autoridade existentes

JourneyEngine confirma derrota/coleta/entrega/rastros/conversas, resolve forest-sample e forest-observation, concede weakness-reading e confiança, registra conhecimento com sourceEventId. IConsequencePolicy seleciona IDs e o motor revalida. WorldEventOrchestrator confirma fatos importados, oportunidades, agenda, publicação regional e conhecimento. Todas essas confirmações são locais. OfflineAuthority valida alcance, paredes, orientação, cooldowns, golpes/esquiva e dano na física Unity. JourneySession autentica interações por referência/posição local. Esses controles não constituem autoridade multiplayer.

LocalDecisionClient e WorldDecisionClient são loopback consultivo. Backend/decisions valida consistência dos candidatos recebidos, consulta o provedor ou fallback e persiste decisões em arquivos com mutex por processo. Não comprova os fatos nem autentica personagens. Não será exposto como API pública nem usado como fonte de recompensas.

## Inventário existente e IDs a preservar

Mundo offline-clearing, personagem player; cena OfflineClearing.unity. Criatura corrupted-wolf, encontros clearing-wolf-01 / clearing-wolf-observation; training-dummy não é criatura recompensável. NPCs mira/orin. Rastro corrupted-tracks, item/evidência corruption-sample. Habilidade weakness-reading. Rotas forest-sample / forest-observation. Acontecimentos forest-alert / new-threat-tracks / hunter-training. Reações mira-scientific / mira-concern / mira-suspicion / mira-neutral. Nenhum level/XP.

## 05A — Auth, banco e autoridade persistente

1. Schema game privado, tabelas normalizadas, histórico separado de projeções, IDs/versionamento, índices, transações e outbox. Mundo de desenvolvimento explícito. Supabase CLI local, sem link/push/reset remoto. Backend pgxpool com papel mínimo.
2. Auth Supabase: JWKS RS256/ES256 com verificação de assinatura/issuer/audience/exp/sub; HS256 legado validado pelo Auth Server, sem JWT secret no cliente ou backend. Identidade do dono deriva do token e é conferida em cada acesso.
3. API /v1: personagens, estado próprio, região pública, intenções limitadas. Encontro mínimo por turnos simulado no Go; não aceita CreatureDefeated ou recompensa do cliente. Fluxo da floresta demonstrará obtenção/consumo, habilidade, relação e consequência regional transacional. Movimento/colisão Unity seguem offline.
4. Importação de desenvolvimento explícita: leitura/checksum/replay v1/v2/v3 no Editor, exportação para destino novo, importação apenas em mundo marcado de teste. Saves originais intocados; sem sincronização automática. História importada permanece identificada como não confiável e nunca entra num mundo confiável.
5. Testes com dois usuários, autoria, replay/idempotência/concorrência, SQL/grants, falhas de transação, auth inválida e regressão Unity/Go. Não avançar sem evidência real do banco/Auth e sem resolver falhas críticas.

## 05B — expansão após aprovação técnica de 05A

Cinco áreas conectadas (Valdoria, floresta, Kharum, Ecos, Asterion); conteúdo versionado com referências validadas. Reutilizar combate/adaptadores existentes e preservar a cena offline. Diversificar comportamentos antes de aumentar números. Alvos: 8–10 criaturas, 10–12 NPCs, 30–40 itens, 25–35 oportunidades, ≥8 habilidades com efeito e testes. Evento único com autoria/lock mundial. Documentar separadamente dados, gameplay parcial e funcionalidades validadas.

## 05C — simulação após validação de 05B

Simulador Go usando as mesmas regras da autoridade, seis perfis e ≥100 jornadas reproduzíveis. Comparar escolhas/rotas alcançáveis e significado dos resultados; RNG isolado não comprova diversidade. Reutilizar decisions/Jev com candidatos autoritativos e testes sem custos. Bateria paga somente após autorização. Regressão completa e relatório final com limitações.

## Migração e compatibilidade

Não alterar enum existente 0–7, IDs ou formato journey-v1.json. JsonJourneyPersistence valida checksum e JourneyEngine.Restore valida caches/replay e WorldState v1. Continuar aceitando snapshots v1/v2/v3. Backend não aceita snapshot local como prova autenticada. Exportação independente converte entidades para um novo personagem em mundo de teste explicitamente indicado e registra proveniência; importação não promove esse personagem para mundo confiável. Supabase user UUID será a identidade comum para futuro Nakama (verificação de token/link no servidor), sem outro cadastro.
