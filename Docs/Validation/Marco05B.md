# Checkpoint 05B — expansão jogável validada

Execução em 14/10/2026, após concluir [05A](Marco05A.md). Não foram substituídos projeto, cena offline, saves, combate anterior ou acontecimentos existentes. Não há XP/níveis.

## Resultado executado

- Mundo `marco05-expanded` de desenvolvimento, cinco regiões conectadas dentro de `Marco05World.unity`. Transição validada pelo servidor, login/continuação explícita de personagem, navegação visual WASD, ações paginadas, diário com rolagem, inventário/consumo/equipamento e telegráficos de encontro. [Cena criada](m05b-scene.json), [Game view inspecionada](m05b-ui.png).
- Supabase CLI aplicou duas migrações adicionais e seeds: **3 migrações no histórico**, **23/23 tabelas FORCE RLS**, sem reset. [Migrações reais](m05b-real-migrations.json).
- Unity + Auth + PostgreSQL reais: **68 ações**, cinco regiões, **12 habilidades desbloqueadas**, lobo e morcego com mecanismos distintos, coleta, receitas, arma equipada, consumo e duas infusões restantes. **PASS**, 459,87 s, frames 524 → 138983. [Execução real](m05b-real-unity.json), [resultado compacto](m05b-real-world-result.json).
- Regressão Unity: **66/66 EditMode + 39/39 PlayMode = 105**, preservando os 90 iniciais e os 12 do 05A. [EditMode](m05b-editmode.json), [PlayMode](m05b-playmode.json). A atualização posterior de textos de inspeção compilou sem falhas e foi exercitada na captura real; não houve alteração de regras C#.
- Go: **23 testes principais + 64 subcasos**, zero falhas, PostgreSQL nativo isolado e fixtures de exportação Unity v1/v2/v3. Inclui efeitos das 12 habilidades, nove mecânicas de criaturas, capacidades de coleta, consumo/equipamento, rotas alternativas e ignorar, catálogo inválido, cap de oportunidades, persistência, replay, concorrência histórica e agenda após viajar. [Go](m05b-authority-go.jsonl). `go vet` passou.
- Corrida histórica: uma única autoria em `world_events`; tentativa concorrente perde sem consumir materiais ou aumentar revisão. Outro personagem acessa uma rota alternativa aberta pelo farol, mantendo fatos/inventário/conhecimento privados.
- Saves originais e backup iguais aos hashes iniciais; a cena nova não contém JourneySession nem sincronização offline. [Preservação](m05-save-preservation.json). Credenciais de jogador usadas pelo harness ficam fora de Assets e foram removidas após as sessões.

## Conteúdo efetivamente funcional

Catálogo Go versionado: **9 criaturas**, **12 NPCs**, **12 habilidades**, **38 itens**, **31 oportunidades**, **15 pontos de interação**, **5 regiões**. Os IDs herdados são preservados. As três oportunidades/eventos do Marco 04 continuam no fluxo offline anterior; não foram removidos ou indevidamente contados como novos fluxos online. [Conteúdo e condições](../WorldContent.md), [habilidades e efeitos](../Abilities.md), [itens e usos](../Items.md), [mapa](../WorldMap.md).

Go é o único motor das consequências da expansão. A Unity recebe dados e projeções, envia intenções, apresenta telegráficos e não concede capacidades/loot localmente. História/outbox/decisões são append-only; estado atual, inventário, equipamento, cooldowns, encontros e agenda ocupam registros separados. Importação v1/v2/v3 permanece destinada ao mundo de demonstração is_test, sem promoção de saves offline para o mundo expandido.

`asterion-beacon` é o evento histórico experimental. Exige fontes de regiões diferentes, registra autor e altera o mundo uma vez. Outro personagem pode ouvir o farol para descobrir Sentido Ancestral. Não concede arma superior. Repetição exige outro mundo de teste ou reset explicitamente autorizado de desenvolvimento.

## Correções e limites

A checagem de cena detectou rastros no título quando só a câmera parcial limpava o framebuffer; uma câmera de fundo sem objetos limpa o quadro inteiro. Nomes dos pontos foram ampliados e a mensagem foi movida para fora do viewport do mapa. Captura oficial ScreenCapture inclui o Canvas que a captura de câmera Pipeline omite. Não houve regeneração/sobrescrita da cena original; o gerador recusa arquivos existentes.

Chamadas de console/screenshot submetidas durante o harness longo excederam o timeout de transporte e geraram quatro erros **do Pipeline** ao responder a conexões já encerradas. Foram registrados em [erros históricos](m05b-console-errors.json), não contabilizados como falhas do jogo. As chamadas posteriores e console final tiveram compilationFailed=false e consoleErrors=0. Um erro inicial de compilação da chamada sobrecarregada com JObject foi corrigido com método PresentJson, sem adicionar pacote/referência à assembly de testes.

Este é gameplay **por turnos e interações abstratas**, com arte placeholder. Nove criaturas têm comportamentos mecânicos no Go, não nove IAs espaciais de perseguição na Unity. Movimento visual não é validado remotamente; não há colisões/projéteis autoritativos nem multiplayer em tempo real. As 12 técnicas são funcionais nesse modo; no combate físico offline permanecem as técnicas existentes. A agenda nova mede ações confirmadas do personagem; a agenda 05A continua usando relógio PostgreSQL. O lock mundial serializa as intenções do mundo de teste, adequado para validação, não para escala MMO. Esses limites não são apresentados como autoridade completa.

Não há falha crítica conhecida de dados/segurança neste gate. Próximo checkpoint: 05C, simulações reproduzíveis usando exatamente o motor Go desta expansão e avaliação do serviço Jev sem chamadas pagas automatizadas.
