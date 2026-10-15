# Contrato preliminar de acontecimentos — Go

Contrato comportamental v1, ainda sem API de rede. Eventos são **saída da autoridade**, e não comandos que um cliente pode declarar. O servidor deve validar movimento, colisão, alcance, linha de visão, vida, dano, cooldowns, interações e posse da evidência antes de produzir fatos.

## Envelope

Marco 03 acrescenta um contrato HTTP v1 de seleção consultiva de reações em [JevIntegration](JevIntegration.md), sem transformar estes eventos em comandos de cliente. O serviço local não é a futura autoridade Go/Nakama.

| Campo | Tipo Go proposto | Regra |
|---|---|---|
| version | int | 1; rejeitar desconhecida até migração explícita |
| eventId | string | ID único gerado pela autoridade; chave de deduplicação |
| eventType | string | Uma das variantes da tabela abaixo |
| actorId | string | Personagem derivado da sessão autenticada |
| sourceId | string | Produtor interno ou entidade validada; nunca comprovação enviada pelo cliente |
| worldId | string | Instância de mundo controlada pelo servidor |
| timestamp | int64 | Unix milissegundos da autoridade; cooldowns usam relógio monotônico separado |
| payloadVersion | int | 1 |
| payload | objeto tipado | Exatamente a variante correspondente a eventType |

O save C# v1 serializa o enum numericamente e usa campos de união `creature/evidence/trace/npc/discovery`. O futuro wire Go proposto usa nomes estáveis e um único `payload`. Não envie o save diretamente: um mapper explícito converterá ambos. Índices C# v1: CreatureDefeated=0, EvidenceCollected=1, TraceExamined=2, NpcInteracted=3, EvidenceDelivered=4, OpportunityDiscovered=5, AbilityUnlocked=6. A ordem não deve ser reinterpretada em migrações.

## Variantes

| eventType | payload v1 | Produtor / pré-condição |
|---|---|---|
| CreatureDefeated | creatureId, encounterId, observed: bool | combate; transição vivo→morto após hit confirmado; observed deriva de rastros + informação transmitida a Orin antes da derrota |
| EvidenceCollected | evidenceId, encounterId | mundo/inventário; drop válido após derrota, interação espacial válida, não coletada/entregue antes |
| TraceExamined | traceId | mundo; examinador vivo, rastro existente e próximo |
| NpcInteracted | npcId, sharedFact?: string | interação; alvo/proximidade válidos; fato compartilhado já conhecido pelo ator |
| EvidenceDelivered | evidenceId, encounterId, recipientId | inventário; posse/identidade/proveniência e destinatário válido; consumo único |
| OpportunityDiscovered | definitionId, routeId | regras; oportunidade desconhecida passa a elegível/disponível |
| AbilityUnlocked | definitionId, routeId | consequência; rota concluída validamente, técnica ainda não registrada |

IDs desta história: world `offline-clearing`, ator local `player`, criatura `corrupted-wolf`, rastro `corrupted-tracks`, amostra `corruption-sample`, NPCs `mira/orin`, rotas `forest-sample/forest-observation`, técnica `weakness-reading`. Encontros offline `clearing-wolf-01` e `clearing-wolf-observation`; em produção usar identidade única da instância de criatura/encontro.

```json
{
  "version": 1,
  "eventId": "server-generated-unique-id",
  "eventType": "EvidenceDelivered",
  "actorId": "authenticated-character-id",
  "sourceId": "mira",
  "worldId": "forest-instance-id",
  "timestamp": 1791914400000,
  "payloadVersion": 1,
  "payload": {
    "evidenceId": "corruption-sample",
    "encounterId": "server-encounter-id",
    "recipientId": "mira"
  }
}
```

## Transação e segurança futuras

Persistir fato, consumo de evidência, estado da oportunidade, confiança e desbloqueio em uma transação. Índices únicos recomendados: eventId; (ator, mundo, encontro, tipo de derrota); (ator, instância de evidência, entrega); (ator, técnica); (ator, oportunidade, consequência). O contrato offline possui uma evidência narrativa única; inventário multiplayer precisará distinguir definitionId de instanceId.

NPCs recebem apenas fatos com fonte válida de transmissão ou observação autorizada. Eventos de outros jogadores exigirão regras explícitas de visibilidade, percepção e compartilhamento. Jev só poderá escolher IDs dentre candidatos calculados pela autoridade; revalidar elegibilidade ao aplicar a resposta. Nunca aceitar inventário, habilidade, dano, morte ou `observed` declarados pelo cliente/modelo como verdade.

Portar as regras com testes de paridade: ambos os caminhos, rejeição de pré-condições, repetição de evento/recompensa/entrega, limites e consumo de marca, conhecimento de NPCs e transação de persistência. Nenhum backend foi implementado neste marco.


## Marco 04 ? extens?o v1 consultiva de candidatos

O mesmo POST `/v1/decisions/evaluate` admite `policyId: world-context-v1`. N?o h? microservi?o adicional. Request v1 mant?m ator/mundo, `eventId` da avalia??o (primeira causa + revis?o), `stateVersion`, fatos, conhecimento com fonte identificada por NPC, regi?o e `eligibleConsequences`; acrescenta `candidates`. [Exemplo completo](../backend/decisions/examples/world-request.json).

Cada candidato v1 cont?m `id,type,scope,causeId,context,ruleId,conditions,authorizedActions`. Causas referenciam fatos, condi??es e a??es devem concordar com as tr?s defini??es conhecidas. O Go rejeita candidatos incompat?veis com fatos/conhecimento/regi?o, IDs/a??es inventados, campos desconhecidos e limites excedidos. Essas verifica??es s?o **de consist?ncia offline**, n?o autentica??o do estado Unity.

Pergunta Jev `world_event`, type choice: candidatos eleg?veis + `none`. Resposta usa o DecisionRecord v1 anterior, incluindo escolha, identidade/revis?o, metadados, m?tricas, tentativa e fallback. Probability da op??o e confidence permanecem distintas; gate desabilitado por padr?o. Cache e conflitos continuam por ator/mundo/avalia??o/pol?tica. Sele??es independentes restantes recebem novas avalia??es; `none` adia esse contexto opcional sem bloquear rotas garantidas do Journey.

`CombatActionVerified` ? acrescentado **no final** do enum C# existente, ?ndice **7**, sem reinterpretar os ?ndices 0?6. Payload `combat` v1 cont?m `actionId,encounterId,targetId,preparedAttackId`. `prepared-dodge`: somente autoridade confirma um golpe preparado aceito, jogador vivo em alcance/cone/linha de vis?o e na janela de esquiva; `training-hit`: acerto com dano aceito no boneco durante treino iniciado. Esquiva solicitada, ataque comum, imunidade de dano, parede ou erro por dist?ncia n?o bastam. Fonte combat ? um produtor interno, n?o prova fornecida por clientes.

Contratos WorldFact/EventCandidate/WorldOpportunity/ScheduledConsequence/WorldState v1, gatilhos e diagramas em [WorldEventOrchestrator](WorldEventOrchestrator.md). Save v3 engloba ambos os logs/proje??es, sem credenciais. O servidor multiplayer futuro ter? que reconstruir contexto/elegibilidade a partir da pr?pria autoridade e aplicar fato/consequ?ncia/agenda/conhecimento com ?ndices ?nicos numa transa??o. N?o expor o endpoint local como autoridade p?blica.
