# Simulação de jornadas — checkpoint 05C

Motor: `Backend/authority/journey`, o mesmo usado pela persistência transacional. Sem Unity Editor, rede, banco, OpenRouter, XP ou níveis. O simulador só executa intenções aceitas por Catalog.Step.

Bateria executada: **120 jornadas principais**, 20 por perfil; sementes **505000 a 505019**, limite de **240 ações**. Além disso, seis jornadas compartilham um mesmo mundo e seis controles usam a política mista variando apenas a semente. [Históricos completos e métricas](Validation/m05-simulation.json), [comparação CSV](SimulationComparison.csv), [replay byte a byte](Validation/m05-simulation-replay.json).

| Perfil | Jornadas | Habilidades (média) | Regiões | Oportunidades concluídas | Ignoradas |
|---|---|---|---|---|---|
| Combatente | 20 | 6 | 5 | 9 | 0 |
| Explorador | 20 | 3 | 5 | 5 | 0 |
| Pesquisador | 20 | 12 | 5 | 23 | 0 |
| Coletor | 20 | 6 | 5 | 23 | 0 |
| Misto | 20 | 12 | 5 | 31 | 0 |
| Ignora oportunidades | 20 | 0 | 5 | 0 | 8 |

Combatente prioriza defesa, rastreamento e confrontos; explorador prioriza pontos e travessias; pesquisador prioriza fontes/estudos; coletor prioriza extração e receitas; misto aceita todas as atividades; o último perfil rejeita oportunidades, mantendo exploração e conhecimentos. Essas diferenças são decisões explícitas, não atributos de classe permanentes ou níveis.

## Diversidade significativa

Distância média de Jaccard entre resultados dos seis perfis **com a mesma semente**: **0.8023**. A representação compara habilidades, oportunidades concluídas e relações/confiança. No controle com a mesma política mista e apenas sementes diferentes: **0.0000**. Portanto, nesta bateria, mudar decisões/política produz diferenças persistentes; mudar só o acaso muda a sequência sem alterar o resultado final saturado.

Cada perfil teve um resultado final característico entre suas 20 sementes. Isso **não** demonstra variedade infinita dentro de cada estilo, nem comportamento humano, equilíbrio competitivo ou retenção. Os cinco lugares foram acessíveis a todos, inclusive ao perfil que ignorou oportunidades. A ordem detalhada das ações e inventários/relações por personagem está no JSON; nem diferenças de digest nem RNG são usados sozinhos como prova de diversidade.

## Integridade e alcance

- Oportunidades não alcançadas na união dos perfis: **0** de 31.
- Oportunidades monopolizadas por apenas um perfil: **0**; cada definição foi concluída por pelo menos dois estilos.
- Consequências duplicadas: **0**; conflitos de estado: **0**.
- Repetições excessivas fora de viagem/turnos de combate: **0**. O detector considera mais de três repetições da mesma ação de serviço/interação; ataques, técnicas, aproximação e viagem são atividades repetíveis intencionais.
- Validação estática: referências ausentes, IDs duplicados, recompensas inválidas, condições contraditórias, regiões desconectadas e dependências fechadas falham. Alcance quantitativo não depende só dessa análise: o perfil misto realizou as 31 oportunidades com consumo real de materiais.
- Cada passo verifica HP, quantidades positivas, propriedade do equipamento, conclusão com fonte histórica, estados incompatíveis e no máximo três oportunidades disponíveis. Fatos/eventos já confirmados não podem aparecer novamente em NewFacts/NewEvents.
- Seis atores no mesmo mundo mantêm autoria única do farol e dos estados regionais; outros podem acessar a rota compartilhada sem receber inventário/história privada do autor. Testes PostgreSQL complementam o modelo com concorrência, rollback e idempotência. Reservas de uma consequência regional agendada cancelada por autoria concorrente são devolvidas exatamente uma vez.

## Reprodução

```powershell
Set-Location Backend/authority
go test -count=1 ./...
go run ./cmd/simulate -seed 505000 -per-profile 20 -steps 240
```

O JSON contém sementes, intenções em ordem, digest por jornada, capacidades, inventários, relações, escolhas e oportunidades observadas mas não escolhidas. Não contém contas reais nem credenciais. A execução principal é independente por mundo para medir alcance; a coorte adicional mede efeitos compartilhados. O teste de ativação simultânea usa PostgreSQL isolado, não concorrência artificial dentro do RNG.

## Jev

O serviço existente `Backend/decisions` foi reutilizado na bateria de histórias de pesquisador, combatente e explorador: múltiplos candidatos válidos, seleção persistida/restart, revisão alterada, contingência determinística, cap de três e telemetria de latência/usage. Automatização usa httptest loopback; valores de custo/tokens são **fixtures**, não preços reais medidos. Nenhuma chamada paga. A expansão usa consequências determinísticas da autoridade; Jev permanece consultivo para acontecimentos existentes, sem decidir loot/habilidades ou autorizar fatos.

A bateria manual `TestManualMarco05JevComparison` está preparada, **não executada**: requer autorização separada e JEV_MARCO05_MANUAL=1, no máximo três solicitações, 15 segundos por chamada, interrupção ao faltar usage ou atingir US$ 0,001 acumulado. Esse teto é verificado após cada resposta, não é garantia de limite rígido do provedor por chamada; usar também o limite de crédito do projeto. Nenhuma execução automática habilita essas flags.
