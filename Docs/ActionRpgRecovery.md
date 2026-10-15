# Marco 06A — auditoria e recuperação

## Diagnóstico antes da implementação (14/10/2026)

AGENTS.md, documentação de arquitetura, eventos, técnicas, itens, mundo, mapa, integração Go/Jev/Supabase, simulação e validações 01–05 consultados. Cenas e referências serializadas inspecionadas. Projeto inteiro está não rastreado no Git; nenhuma alteração será descartada por checkout e nenhum commit será criado. Baseline dos arquivos em Temp/Marco06A/baseline.json.

OfflineClearing conserva combate físico local: CombatState valida saúde e tempo; OfflineAuthority valida overlap, alcance, cone e obstáculos; ActorMotor aplica velocidade no FixedUpdate; WolfBrain patrulha, persegue e prepara golpe. JourneySession recebe HitConfirmed para produzir derrota e valida proximidade/visibilidade da coleta. WeaknessReading confirma consumo somente no acerto aceito. JourneyEngine e WorldEventOrchestrator conservam fatos, conhecimento com fonte, desbloqueios, decisões, agenda e replay. JsonJourneyPersistence aceita saves v1/v2/v3 com checksum e backup.

Marco05World usa WorldJourneySession.Busy para serializar requisições HTTP de intenções. WorldJourneyHud oferece ações, encontros e viagens abstratas; WorldJourneyView move Transform sem Rigidbody2D, muda regiões após resposta e projeta um oponente usando distância discreta. Catálogo Go contém técnicas/criaturas, mas não física espacial Unity. Não serve de fundamento para o action RPG.

## Mapa de reutilização

| Sistema | Decisão |
|---|---|
| CombatState / CombatRules | Reutilizar; regras temporais permanecem no domínio puro |
| OfflineAuthority | Ampliar a mesma autoridade para golpes e dano espacial; sem valor de dano no input |
| ActorMotor / PlayerController | Modo opt-in da nova cena para oito direções, aceleração e mira mouse |
| WolfBrain / ActorVisual / CameraFollow | Reutilizar e ampliar preparo/investida e feedback |
| JourneySession / JourneyEngine / WeaknessReading | Reutilizar investigação, marca, fatos e desbloqueio original |
| WorldEventSession / decisões existentes | Reutilizar corrotinas e revalidação, determinístico por padrão |
| JsonJourneyPersistence | Mesmo formato; arquivo action-vertical-slice.json isolado |
| WorldJourneySession/Hud/View | Preservados apenas em Backend Online Experimental |
| Supabase/Auth/Go por turnos | Preservados sem mudanças ou conexão no action offline |

Não haverá terceiro motor de combate. Novos componentes são adaptadores de IA, input, apresentação e técnicas da autoridade existente. Não haverá atualização de pacote, migração/reset, chamadas pagas ou envio de recompensas offline ao backend.

## Comparação

| Aspecto | Marco05World | ActionVerticalSlice |
|---|---|---|
| Movimento | Transform visual cardinal | Rigidbody2D diagonal com obstáculos |
| Ataque | Intenção HTTP por turno | Input mouse, alcance/cone/overlap físico local |
| Viagem | Ação abstrata | Passagem caminhável contínua |
| NPC | Lista de ações | Entidade próxima + E |
| Serviços | Login/Go para jornada expandida | Local isolado sem login |

Os resultados executados, instruções e limites serão registrados em Validation/Marco06A.md. Desempenho e gameplay só serão aprovados após evidência real.

## Resultado implementado

A cena action reutiliza a autoridade, estados temporais, motor físico, câmera, lobo, apresentação e história anteriores. ActionCombat é o adaptador de intenções/técnicas dessa autoridade; SpatialCreatureBrain acrescenta estados de aranha/golem, PoisonProjectile e PoisonStatus usam a mesma validação de dano. ActionSliceHud apresenta inventário de evidência e pausa sem painel de ações abstratas. ActionTargetVisual indica marca real. ActionMetrics mede a sessão. QueuedJourneyPersistence conserva o adaptador/checksum antigo, retira flush de disco do ataque e conclui gravação nas transições.

RealtimeAuthorityContract é somente o contrato preparado para intenções futuras; nenhum servidor de física foi criado. Não há terceira integração Jev, nova campanha ou expansão de catálogo. [Comparação dedicada](ActionRpgComparison.md), [validação executada](Validation/Marco06A.md), [performance medida](ActionRpgPerformance.md).

Referência técnica consultada para o adaptador físico: [Rigidbody2D.linearVelocity, Unity 6000.6](https://docs.unity3d.com/6000.6/Documentation/ScriptReference/Rigidbody2D-linearVelocity.html). Skills aplicadas: unity-cli/unity-pipeline, create-2d-physics (legacy-2d-physics.md), ui e ui-ugui.
