# Checkpoint 05C — simulação e qualidade validadas

Executado em 14/10/2026 após os gates [05A](Marco05A.md) e [05B](Marco05B.md).

- **120 jornadas principais** reproduzíveis, seis perfis, sementes 505000–505019, até 240 intenções por personagem. **Seis atores adicionais no mesmo mundo** e seis controles com política fixa. [Comparação](../Simulation.md), [JSON completo](m05-simulation.json), [CSV](../SimulationComparison.csv), [replay](m05-simulation-replay.json).
- As 31 oportunidades foram alcançadas e cada uma apareceu em pelo menos dois perfis. Zero consequências duplicadas, conflitos e repetição excessiva de serviços/interações. Misto: 12 técnicas/31 oportunidades; explorador: 3/5; combatente: 6/9; pesquisador: 12/23; coletor: 6/23; ignora: 0/0, oito recusadas e cinco regiões ainda acessíveis.
- Diversidade por decisões, mantendo semente fixa: distância média de Jaccard **0,8023** sobre habilidades, conclusões e relações. Variar só sementes com política mista: **0** para resultado final. Não se usa diferença aleatória de ordem/digest como prova suficiente.
- Go authority/journey: **29 testes principais + 64 subcasos**, zero falhas, incluindo PostgreSQL isolado, saves, replay, auth, concorrência, reservas devolvidas uma vez e falha fechada se uma projeção obrigatória faltar. `go vet` e build do servidor passaram. [Go](m05c-authority-go.jsonl).
- Serviço Go/Jev: **28 testes principais + 11 subcasos**, zero falhas; os 26 anteriores e oito subcasos preservados. Três testes pagos ignorados. Histórias distintas, múltiplos candidatos, persistência/restart, revisão, fallback, limites e telemetria testados com HTTP loopback. [Go/Jev](m05c-decisions-go.jsonl).
- Auditoria Supabase final: **23/23 tabelas FORCE RLS**, três papéis da Data API negados, **8/8 assertions pgTAP** em transação revertida. [Auditoria real](m05-real-sql-auth-audit-final.json). Nenhum reset/teste destrutivo remoto.
- Unity: última regressão completa **105/105** e Play real com 68 ações; atualizações posteriores de apresentação compilaram e foram capturadas/inspecionadas. Console final sem erros atuais. Não se declarou execução paga ou teste não executado como aprovado.

A primeira política simulada alternava ferramentas desnecessariamente. O diagnóstico de repetição motivou uma decisão por contexto (picareta para veios, estojo para alquimia), seguida de reexecução e replay estável. A primeira fixture Jev usava um ID de resposta fora do contrato existente; foi corrigida para o prefixo aceito, sem relaxar a validação do provedor. Apenas as suites finais aprovadas contam nos totais.

O simulador usa o mesmo Catalog.Step da autoridade, sem implementar recompensas paralelas. Seus perfis são políticas fictícias; não são classes obrigatórias nem pesquisa com jogadores reais. A expansão continua por turnos/intenções abstratas. Movimento/colisões/combate físico offline, escala de lock mundial e agenda por atividade são limites documentados, não autoridade MMO completa.

Bateria manual de Jev preparada, não executada sem autorização específica: até três chamadas, deadline e acompanhamento de usage/custo. Nenhuma solicitação paga foi realizada neste marco. Isso é uma condição explícita do pedido, não um teste automatizado faltante promovido a sucesso.
