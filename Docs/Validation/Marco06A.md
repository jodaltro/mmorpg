# Marco 06A — validação do Action RPG

## Entrega e execução

Cena: `Assets/Mmorpg/Scenes/ActionVerticalSlice.unity`, derivada da cena action original. Abra no Editor Unity 6000.6.5f1 e pressione Play. Sem login, Supabase ou serviço Go obrigatório. O modo `Backend Online Experimental` continua na cena original `Marco05World.unity`.

| Input | Ação |
|---|---|
| WASD | Movimento físico em oito direções |
| Mouse / clique esquerdo | Mira e ataque básico, alcance 1,25, dano 20 |
| Clique direito | Golpe pesado preparado, dano 36; preparação, cooldown e alcance configuráveis |
| Espaço | Esquiva física, 0,22 s de invulnerabilidade, cooldown 0,9 s |
| Q | Leitura de Fraquezas; marca de 5 s, cooldown 8 s, +10 somente no acerto aceito |
| F | Contra-ataque; janela de 1,4 s após esquiva de ataque real, cooldown 3 s, dano 30 |
| C | Marca do Caçador; alvo próximo visível, +5 e exposição de armadura por 8 s; cooldown 10 s |
| E | NPC, rastros, amostra, quadro e sinal da passagem próximos |
| I / Tab / Esc | Inventário de evidência / Diário / pausa |
| R | Retornar à vila, vida restaurada e memória preservada |
| F9 (somente Editor) | Alternar teste isolado de técnicas bloqueadas; não concede desbloqueios no save |

Normalmente Q exige a descoberta original com Mira ou Orin. C exige rastros confirmados e informação compartilhada com Orin. F exige essa informação e uma esquiva de golpe preparado confirmada no histórico. F9 é exclusivo do Editor; não existe na build do jogador. Condições de C/F são derivadas de fatos persistidos, sem XP ou níveis e sem conceder todas as técnicas automaticamente.

## Funcionalidades realmente jogáveis

Vila e floresta contínuas, casas/árvores/rochas sólidos, corredor atravessável, câmera acompanhando o Rigidbody2D. Mira e Orin são entidades físicas; interações validam alvo registrado, vida, distância e bloqueio. O collider do próprio NPC é permitido no fim do raio, mas paredes continuam bloqueando.

Lobo patrulha/persegue/prepara/investe/recupera. Aranha mantém distância e reposiciona; lança um Rigidbody2D com collider trigger, bloqueado por cenário, que aplica veneno temporário em acerto aceito. Golem aproxima lentamente, fixa área na preparação e resolve impacto espacial após 0,8 s. Couraça reduz dano em 14; Q/C expõem a proteção e F a atravessa. Todos recebem feedback de dano e desativam o corpo ao morrer.

O percurso existente é: conversar com Mira, sair caminhando, derrotar lobo, coletar amostra junto do corpo, retornar, entregar e receber reação/descoberta no diário. A coleta é única por fato e só aparece após derrota confirmada. O quadro publica a reação contextual pelo orquestrador existente.

## Testes e evidências

A compilação final foi concluída sem erros. **124 testes Unity distintos executados e aprovados**: regressão completa **68/68 EditMode + 55/55 PlayMode** após fechamento da persistência, seguida de **1/1 PlayMode focado** acrescentado para desbloqueios normais. São execuções separadas, sem contar testes repetidos como novos. Todos os 105 existentes permanecem nas suites.

- [Compilação](m06a-compile-final.json), [EditMode](m06a-editmode-final.json), [PlayMode completo](m06a-playmode-final.json), [desbloqueios normais](m06a-normal-unlocks.json).
- Cobertura nova: movimento/colisão reais, mouse/mira/erro/alcance, pesado e compromisso, Q consumido no hit aceito, esquiva e Contra, lobo espacial, projétil/veneno/reposicionamento, golem/área/armadura/exposição, coleta/entrega, caminhada através da passagem, HTTP atrasado, serviços ausentes, fila de disco, recarga imediata em storage lento e C/F desbloqueados por rastros/Orin/defesa sem modo de teste. Save v1/v2/v3 continua coberto pelos testes anteriores.
- [Caminhada na vila](m06a-gameplay-village-final.json), [combate do lobo](m06a-gameplay-wolf-final.json), [coleta e retorno/entrega](m06a-gameplay-delivery-final.json), [save/reload real](m06a-gameplay-reload.json), [Q aprendido no boneco](m06a-gameplay-weakness.json), [aranha](m06a-gameplay-spider.json), [golem/esquiva/Contra](m06a-gameplay-golem-final.json), [quadro e diário](m06a-gameplay-journal.json).
- Capturas verificadas visualmente: `m06a-village`, `m06a-investigation`, `m06a-golem-defeated`, `m06a-hud-final` e `m06a-journal-final`. O último ajuste de apresentação reduziu diálogo e corrigiu ordem de desenho do diário; não alterou regras ou posições físicas.
- Métricas e ambiente: [ActionRpgPerformance](../ActionRpgPerformance.md). Ao fim do golem: impacto evitado, Contra acertou, jogador HP=100; ao consultar quadro/diário: notice=true, journal=true, 8 fatos preservados. Os ensaios de habilidades bloqueadas usaram somente F9 no Editor; o teste de desbloqueio normal passou sem F9.

Regressão inicial executada: 66/66 EditMode e 39/39 PlayMode (105 existentes). Depois da primeira recuperação: 68/68 EditMode e 51/51 PlayMode. A suíte action inicial encontrou duas falhas, corrigidas sem excluir testes: interação bloqueada pelo collider do NPC e câmera do fixture de mira não sincronizada após reposicionamento. Execuções e erros históricos permanecem nos JSONs `m06a-*`.

Go executado sem APIs pagas ou banco remoto: authority **21 testes principais + 51 subcasos**, zero falhas, **9 ignorados** por dependência de PostgreSQL isolado/fixtures/Auth real. Decisions **28 principais + 11 subcasos**, zero falhas, **3 pagos ignorados**. `go vet ./...` executado nos dois módulos, exit 0. [Resumo](m06a-go-summary.json), [authority](m06a-go-authority.jsonl), [decisions](m06a-go-decisions.jsonl). Não se afirma revalidação SQL/Auth neste marco.

O ensaio ao vivo usa `AgentScripts/ValidateActionGameplay.cs`: teclado/mouse sintéticos, observação do Rigidbody2D e caminhada por pontos físicos; não reposiciona o personagem nem invoca ataques/interações internos. JSON de teste em Temp, sem carregar saves do jogador. Os testes PlayMode usam reposicionamento de fixtures para isolar alcance/colisão, e inputs reais nos casos de movimento, mira, pesado, Q/C, coleta e transporte indisponível.

O primeiro ensaio ao vivo morreu durante o intervalo entre ferramentas porque zonas de detecção sobrepostas trouxeram outras criaturas; detecção foi reduzida para 5 unidades e o ciclo repetido com sucesso. Os ensaios do golem levaram ao reconhecimento de esquiva para fora da área e à correção da mira usada por Espaço no mesmo frame. Não se apagaram assertions: acrescentados testes físicos específicos, seguidos da regressão completa. Erros de harness anteriores estão em `m06a-gameplay-delivery.json` e `m06a-gameplay-golem.json`.

## Serviços e persistência

Modo determinístico padrão não inicia HTTP. O mesmo LocalDecisionClient/WorldDecisionClient e serviço Go/Jev permanecem disponíveis opt-in; corrotinas de decisão não bloqueiam input/física. Respostas são revalidadas por revisão/elegibilidade; erro ou ausência de resultado seleciona a política determinística. Teste com loopback atrasado exercita movimento e preparação de ataque enquanto a decisão está pendente; outro usa porta sem serviço para comprovar fallback com Go e OpenRouter indisponíveis. Nenhuma chave ou chamada paga foi usada.

Persistência normal da cena: `Application.persistentDataPath/action-vertical-slice.json`, envelope/checksum e snapshots v1/v2/v3 existentes. QueuedJourneyPersistence serializa gravações em um worker sem objetos Unity; coalesce checkpoints pendentes. Load revalida pelo adaptador antigo. Encerramento e troca de cena esperam a fila antes da próxima leitura; o combate não espera disco. Os saves `journey-v1.json` e backup não são carregados ou sincronizados; fatos offline não são enviados à autoridade online.

## Limitações e próximos passos

- Placeholder funcional; sem avaliação com jogadores externos, animações finais ou balanceamento aprovado.
- IA usa perseguição/local reposicionamento e linha de visão; não existe pathfinding geral em labirintos.
- Inventário action contém a evidência desta investigação. Os 38 itens/12 técnicas do catálogo Go permanecem no modo experimental; não foram declarados convertidos.
- Saúde/posição/cooldowns são transitórios. Memória e derrota narrativa do lobo são restauradas; aranha e golem reaparecem na recarga, sem loot online ou fatos de recompensa extras.
- Contrato `RealtimeAuthorityContract` prepara intenções sem dano/recompensa; não implementa autoridade remota, transporte ou reconciliação. Go futuro deverá validar física, hits, saúde e movimento por conta própria.
- Métricas de feedback medem aceitação da ação até apresentação em LateUpdate; não medem latência elétrica do mouse, monitor ou renderização da GPU.
- A gravação em fila é eventual; uma interrupção abrupta antes da conclusão pode perder o último checkpoint, preservando gerações íntegras pelo adaptador existente.

Não haverá expansão automática de regiões ou missões. Diagnóstico/mapa de reutilização: [ActionRpgRecovery](../ActionRpgRecovery.md). Comparação: [ActionRpgComparison](../ActionRpgComparison.md).

## Build Windows e preservação

Build final do Editor conectado: **StandaloneWindows64 / Succeeded, zero erros, 3 avisos**, 107.704.901 bytes, 18,120 s. [BuildReport](m06a-build.json). Avisos: ausência de RuntimePipelineConfig (ferramenta de automação desabilitada no Player) e duas mensagens CS0618 pela sobrecarga antiga de FindObjectsByType; não impedem gameplay.

Executável: `Builds/ActionVerticalSlice/ActionVerticalSlice.exe`. Execute na pasta completa, incluindo `_Data`, UnityPlayer e MonoBleedingEdge. A lista explícita da build contém somente a cena action; a build antiga não foi substituída. Para reproduzir, com este Editor conectado e fora de Play: `python AgentScripts/BuildActionWindows.py`, depois `unity command build_status --caller plugin --skill unity-pipeline` até completed.

A build anterior abriu com Direct3D e permaneceu ativa no smoke de 8 segundos, sem erros no log. O smoke final está em [resultado](m06a-player-smoke-final.json) e [log do Player](m06a-player-final.log). Isso verifica inicialização; o teste completo dos controles e combate foi feito no Editor, não com inputs no Player standalone.

Preservação por SHA-256: [manifesto](m06a-preservation.json). Cenas antigas, arte, 105 testes antigos, pacotes, ferramentas de autoria e documentação anterior conservados. Nenhuma exclusão original. Os saves primário e backup `journey-v1.json` mantêm os hashes da baseline coletada após encerrar o Play pré-existente. A lista de Build Settings recebeu a cena nova preservando entradas anteriores. **ProjectSettings.asset também mudou durante as execuções/serialização do Editor**, com execução em segundo plano habilitada; não se afirma preservação byte a byte desse arquivo. A baseline contém hash, sem cópia textual anterior, e as sondagens não reconstruíram o hash original; nenhum valor desconhecido foi revertido por suposição. Os demais arquivos de configuração da baseline permanecem iguais. Não houve reset, migração, upload de save, chamada paga, stage ou commit. O Editor terminou fora de Play; persistência de teste e dispositivos/opções temporários de Play foram restaurados.

Próximo passo proposto é avaliar controles, telegráficos e equilíbrio com jogadores neste mesmo recorte, e medir a build com profiler. Não iniciar regiões, missões ou autoridade remota automaticamente.
