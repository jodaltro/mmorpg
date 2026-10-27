# Atlas de comportamentos — sociedade celular autônoma do Hospedeiro

> **Branch:** main · **27/10/2026** · **Estado:** especificação de conteúdo/IA para implementação em fases, sem pretensão de precisão médica quantitativa.  
> Direção de arte e animação de cada papel: [VisualInteractionAnimationPlan.md](VisualInteractionAnimationPlan.md), storyboards V01–V16; intervenções precisam de corpo, contato, progresso e consequência visível.
> Vinculado ao [Plano Mestre](AutonomousBodyImplementationPlan.md), [Runbook Claude Code](ClaudeCodeAutonomousBodyRunbook.md) e [Gates QA](AutonomousBodyQualityGates.md).

## 1. Princípio: cada célula existe por um trabalho, não por ser um quest giver

Uma célula tem papel, necessidade, capacidade, objetivos, informação e restrições. Sua posição, animação, falas, memória e decisões são **consequências** desse papel. Um NPC sem jogador não está parado, nem é produzido apenas na chegada do avatar. Um conjunto de NPCs isolados que atacam inimigos próximos não constitui um organismo.

Os comportamentos abaixo são intenções e contratos biológicos simplificados; o motor Go determina se são permitidos e seus efeitos, o headless confirma combate/colisões e o Jev seleciona entre escolhas contextualizadas. NPCs não têm um chat generativo autônomo irrestrito. Uma hemácia transporta oxigênio, não solta "habilidades" de macrófago porque Jev sugeriu.

### 1.1 Modelo comum — vida e trabalho

Cada agente nomeado tem:
- **identidade:** ID, tipo celular, nome de NPC, região de origem, função primária, cor/forma procedural, idade lógica;
- **corpo:** vitalidade, ATP/energia quando aplicável, capacidade, carregamento, vulnerabilidade, estado de descanso e reparo;
- **condições:** rota, posição lógica, tarefa, prioridade atual, origem/destino, prazo lógico, recursos comprometidos;
- **relações:** NPCs próximos relevantes e jogadores encontrados; ajuda comprovada, confiança, promessa;
- **conhecimento:** observações próprias, notícias recebidas e incerteza, sempre distinto da verdade;
- **memória episódica:** apenas acontecimentos marcantes e vínculos, com validade e fonte;
- **agenda:** evento de despertar, mudança de fluxo/órgão, bloqueio, chegada, sinal químico, conflito, falta de recurso;
- **proatividade:** quando a capacidade é insuficiente para necessidade, oferece cooperação a outra célula/jogador ou muda plano;
- **resultado:** progresso material na função + registro causal de evento, não apenas mudança de `doing`.

**Laço:** perceber → conferir necessidade → criar/continuar trabalho → reservar recursos → percorrer rota → atuar → registrar efeito → observar resultado → lembrar/aprender → retornar ao trabalho, descanso ou outra prioridade.

### 1.2 Como lidar com milhares de indivíduos
- O motor simula **populações de fundo em agregado**, coortes funcionais em grafo de órgãos e NPCs nominados mais importantes separadamente.
- Os corpos fisicamente visíveis são uma projeção de entidades/células do estado canônico, ou atores locais decorativos explicitamente sem consequências de jogo (nunca equivaler uma partícula decorativa a um agente que executou trabalho).
- NPC nominado importante tem `persistent_id`. Um ator visual temporário tem `visual_instance_id` separado. A aproximação do jogador não recria memórias ou suprimentos.
- Uma célula de fundo pode ser agregada numa coorte e um representante promovido a NPC persistente somente mediante transição determinística documentada; a soma de capacidade da coorte deve reduzir na promoção e voltar quando despromovido.
- Morte natural/apoptose/renovação são processos rastreáveis. Trocar NPC relevante deve preservar histórico público/relações com outros por memória dos sobreviventes, não por clonagem fantasma.

## 2. Matriz de papéis celulares

| Papel | Trabalho na rotina | Quando muda de prioridade | Como pode pedir ajuda | Impacto verificável |
|---|---|---|---|---|
| Hemácia (Rubra) | carregar/entregar oxigênio no fluxo | obstrução, baixa oferta, rota perigosa | proteção, desbloqueio de vaso, nova rota | oferta e entrega por tecido |
| Plaqueta | vigilância e agregação em ferida | lesão, sangramento, instabilidade do tampão | defesa, materiais de reparo | integridade da barreira e risco de entrada |
| Neutrófilo (Neva) | patrulha e defesa de foco agudo | sinais químicos, ameaça, ATP baixo | reforço ou sinalização | pressão sobre carga de invasores |
| Macrófago | limpeza, fagocitose, reparo | acúmulo, ameaça persistente, excesso de tarefa | contenção, transporte de resíduos | resíduos/ameaça/recuperação |
| Dendrítica (Dendra) | observar antígenos e comunicar | encontro com padrão novo, perigo | escolta da informação/rota | crenças e coordenação imune |
| Estroma medular (Osteia) | suporte de nicho e maturação | reserva baixa, demanda hematopoiética | materiais/suprimento | capacidade medular |
| Linfócito B | reconhecimento e anticorpos | antígeno apresentado e ativação | identificação, proteção | defesa específica ao alvo |
| Linfócito T citotóxico | patrulha e remoção de alvos infectados | alvo reconhecido e autorizado | revelação/apoio | queda de focos intracelulares |
| Linfócito T auxiliar | coordenação da resposta imune | antígeno/sinais válidos | reforço entre populações | eficácia de resposta e coordenação |
| Linfócito T regulador | frear resposta exagerada | inflamação sistêmica excessiva | informação/assistência na contenção | menos dano inflamatório |
| Célula NK | vigilância de alterações celulares | célula suspeita, sinais específicos | busca/avaliação de alvo | redução de células alteradas |
| Eosinófilo | resposta antiparasitária contextual | parasitas e sinais adequados | apoio de outras células | contenção de ameaças específicas |
| Mastócito | sentinela tecidual e sinalização | lesão/alérgeno/alarme local | chamar outras células | recrutamento/inflamação (custo associado) |
| Fibroblasto | reconstrução e matriz | dano tecidual e sinal de reparo | materiais/proteção | tecido recuperado/cicatriz |
| Endotélio vascular | integridade de vaso e passagem | obstrução/lesão/sinal de passagem | auxílio em vaso | permeabilidade/fluxo |
| Hepatócito | metabolismo e transformação de compostos | carga tóxica, baixa reserva | insumo/remoção | carga tóxica/energia |
| Célula renal tubular | depuração/reabsorção | sobrecarga/lesão renal | transporte/manutenção | ureia/íon balanceado (escala de jogo) |
| Enterócito | absorção e barreira intestinal | nutrientes disponíveis/lesão | proteção/barreira | entrada de nutriente |
| Células da microbiota | mutualismo, competição e produção local | alimento, disbiose, patógeno | sinalizar por condições de ecossistema, não interação social necessariamente | estabilidade intestinal |
| Glia/microglia | suporte/defesa local do tecido nervoso | dano/infecção/sinais | suporte/reparo | integridade nervosa |

**Importante:** cada linha é proposta de comportamento; nem todas essas classes possuem código específico no repositório hoje. Priorizar as seis primeiras no primeiro ciclo de implementação, expandir uma função por vez sem prometer cobertura completa.

## 3. Procedimentos concretos das seis células iniciais

### 3.1 Rubra — hemácia
```text
Rotina: receber carga → escolher rota com fluxo disponível → transportar → entregar
        → registrar suprimento na região receptora → voltar ao ponto de coleta.
Desvios:
 - Vaso bloqueado: tentar rota alternativa viável.
 - Sem rota: criar necessidade "abrir passagem" e comunicar a células próximas.
 - Perigo alto: solicitar escolta; não atravessar ameaça letal sem motivo.
 - Pouca oferta de oxigênio: transportar o que existe; sinalizar déficit real.
Memória: ajudantes, rotas confiáveis, episódios de obstrução, destinos atendidos.
Pedidos ao player: "Este capilar está obstruído. Consegue ajudar a abrir passagem?"
Nunca: criar oxigênio por diálogos, ir a órgãos inacessíveis ou ignorar capacidade.
```
Fluxo e oxigenação são abstratos de jogo; não confundir entrega com medidas clínicas. **Teste:** dois cargueiros numa mesma reserva não entregam mais do que há disponível.

### 3.2 Neva — neutrófila
```text
Rotina: patrulhar → perceber gradiente químico → avaliar se foco existe → migrar
        → defender quando autorizado → recuperar → patrulhar.
Desvios:
 - Ameaça supera capacidade: pedir reforços por sinal químico (não spawn mágico).
 - Sinal era falso: investigar e corrigir crença.
 - ATP baixo: procurar recuperação/evitar suicídio repetitivo.
 - Foco contido: ajudar a proteger/limpar e voltar à vigilância.
Memória: focos difíceis, quem salvou patrulha, alertas falsos, antígenos conhecidos.
Pedidos: "O foco cresceu; preciso de outra célula na frente de defesa."
Nunca: causar dano em `core` declarado pelo jogador, ver todos os inimigos no mundo.
```

### 3.3 Dendra — célula dendrítica
```text
Rotina: inspecionar → observar antígeno → guardar procedência/tempo
        → buscar via de comunicação → apresentar informação → continuar observação.
Desvios:
 - Antígeno desconhecido: prioridade alta de comunicar.
 - Rota indisponível: encontrar outra, pedir proteção ou marcar tentativa pendente.
 - Notícia obsoleta: atualizar crença e registrar correção.
Memória: origem do antígeno, de quem recebeu notícia, quem ajudou na entrega.
Pedidos: "Identifiquei um sinal novo; preciso chegar ao linfonodo."
Nunca: informação privada se tornar verdade pública só porque passou ao Jev.
```

### 3.4 Osteia — estroma da medula
```text
Rotina: medir estoque local → nutrir nicho se houver recursos
        → apoiar renovação celular → registrar suprimento → avaliar demanda sistêmica.
Desvios:
 - Ferro/insumo baixo: requisitar transporte/reciclagem no baço.
 - Demanda excessiva: priorizar funções escassas dentro das regras do universo.
 - Falha de supply: informar impossibilidade, não produzir do nada.
Memória: épocas de déficit, interações com transportadores e recuperadores.
Pedidos: "A medula precisa de materiais para sustentar as novas células."
```

### 3.5 Macrófago
```text
Rotina: patrulhar/estacionar → identificar resíduo ou foco → fagocitar/limpar
        → devolver resíduos processados → participar de reparo → recuperar.
Desvios:
 - carga de limpeza alta: solicitar ajuda/coorte, dividir tarefas por fronteira;
 - excesso de inflamação: buscar contenção, não atacar indiscriminadamente;
 - novidade patológica: comunicar Dendra ou célula apropriada.
Memória: áreas frequentemente contaminadas, ajudantes, falhas de limpeza.
Pedido: "Este tecido continua cheio de resíduos; ajude-me a limpar a área."
```

### 3.6 Plaqueta
```text
Rotina: circular/patrulhar → detectar ruptura de barreira → deslocar-se à ferida
        → reservar materiais → formar tampão → reforçar/encerrar atividade.
Desvios:
 - Faltam materiais: pedir ajuda para transporte e proteção.
 - Excesso de resposta: não bloquear todo vaso; respeitar regras de fluxo/coágulo.
 - Ferida não estabiliza: pedir células de reparo e registrar situação crítica.
Memória: feridas atendidas, equipes aliadas, rotas perigosas.
Pedido: "Estamos fechando a abertura. Preciso que impeçam novos invasores."
```

## 4. Como células cooperam sem estar programadas para missão fixa

O motor expõe necessidades e capacidades; não roteiriza uma fala para toda colaboração.

| Necessidade detectada | Quem pode perceber | Quem pode atuar | Resultado ou falha |
|---|---|---|---|
| Capilar obstruído | Rubra, endotélio, sentinelas | Endotélio/apoio, limpeza e escolta | fluxo volta ou déficit aumenta |
| Foco infeccioso | Neva, macrófagos, Dendra | neutrófilos, macrófagos, linfócitos | carga muda; inflamação também |
| Antígeno desconhecido | Dendra, células próximas | Dendra leva informação, linfócitos respondem | memória/defesa muda |
| Ferimento da pele | plaquetas e sentinelas | plaquetas, defesa, fibroblastos | barreira recupera ou há invasão |
| Sobrecarga de resíduos | macrófagos, baço | macrófagos, transporte, suporte | limpeza ou acúmulo |
| Oxigenação insuficiente | hemácias, suporte regional | transporte/correção de via, outras células | consumo/suprimento entram em equilíbrio |
| Inflamação exagerada | células reguladoras e tecidos | Treg, macrófagos reguladores, suporte | dano secundário diminui |
| Toxina circulante | hepatócitos, rim | metabolismo/depuração/suporte | carga cai ou afeta novos órgãos |

**Coordenação:** trabalho é um registro com limite de capacidade; células elegíveis avaliam custo/impacto. Um NPC pode ajudar outro por delegação/transferência de tarefa, não por encenar chat. Dúvidas contextuais complexas → Jev avalia alternativas; trabalho rotineiro → planner determinístico.

## 5. Drama emergente: cinco histórias que surgem sem roteiros rígidos

### 5.1 Proteção de transporte
Uma hemácia encontra perigo, solicita escolta. Um neutrófilo aceita protegê-la, mas um foco crítico noutro capilar exige reforços. O coordenador decide: manter escolta até zona segura ou redirecionar a defesa? A consequência aparece na distribuição do oxigênio, risco dos alvéolos e memória da hemácia. O Jev analisa prioridades dadas as opções autorizadas; não define sozinho o oxigênio entregue.

### 5.2 Batalha por um tecido
Um foco aumenta e recruta defesa. Macrófagos conseguem conter parte; neutrófilos gastam recursos e o órgão entra em inflamação. A batalha pode avançar, recuar, estabilizar ou atingir outro vaso com atraso. Jogadores auxiliam em tarefas distintas — matar não é a única solução.

### 5.3 Sobre-reação perigosa
Células defensoras atacam com sucesso, mas a intensidade inflamatória ameaça o tecido. Um NPC regulador tenta frear a resposta, enquanto outro insiste em defesa por crenças desatualizadas. O mundo é moralmente/biologicamente mais ambíguo que inimigo vermelho versus aliado azul.

### 5.4 Memória de auxílio
Rubra foi protegida por jogador A num evento antigo; tempos depois vê A e tem maior confiança. Contudo, se o jogador realmente prejudica transporte depois, a nova evidência atualiza relação. Não esquecer fatos nem criar fidelidade eterna após uma ajuda pequena.

### 5.5 Crise distante chega por rumores
Dendra detecta antígeno no intestino, chega a um local de sinalização, notícia é recebida gradualmente por células pertinentes. Antes disso, uma patrulha do sangue só percebe sinais indiretos, não sabe causa verdadeira. Jogador pode investigar e encaminhar conhecimento, ajudando também sem combate.

## 6. Política de personalidade sem psicologizar a biologia

NPCs têm **traços funcionais** (precaução, rapidez de escalada, disposição de pedir ajuda, tolerância ao risco, preferência por explorar ou manter posto), expressos numa escala curta e estável. Podem evoluir após acontecimentos importantes, sem sobresscrever função biológica.

Exemplo:
- Rubra: prioriza entregar carga; precavida ao avaliar novas rotas; memória forte de eventos de escolta.
- Neva: alerta e responsiva a sinais; menos disposta a abandonar um foco enquanto colegas estão em risco.
- Dendra: coleta cuidadosamente informação; menos provável de transmitir hipótese como certeza.
- Osteia: conservadora com reservas; prioriza sustentação do nicho.
- Macrófago: prioriza contenção/localidade e gerenciamento de excesso de detritos.
- Plaqueta: reage rapidamente a ruptura mas depende de fluxo/material real.

Os traços orientam desempates e preferências **dentro das possibilidades legais**. Não converter em fichas humanas de personalidade arbitrária nem enviar toda biografia ao Jev.

## 7. Gerador de decisões do Jev a partir do estado atual

```text
available_actions := LegalActions(npc, world, capabilities, resources, region)
if len(available_actions)==0:
    npc.status = WAIT_FOR_RESOURCE_OR_SIGNAL
elif HighImpactOrAmbiguous(npc, conflict, memory):
    queue BatchQuestion(npc.id, summary_of_relevant_truth_and_beliefs, available_actions+["continue"])
else:
    plan = DeterministicPriority(available_actions)
OnAnswer(answer, revision):
    validate world revision/constraints/resource reservation
    commit chosen legal intent via Step
    record evidence and outcome
```

**Jev nunca vê onisciência de um NPC:** contexto de microdecisão pode incluir indicadores públicos de conflito, mas distingue `npc_knows`, `npc_suspects` e `system_truth_for_validation` (último reservado ao core; se enviado ao Jev, não confundir em instrução do personagem). Separar macro (mais informação autorizada do sistema) de micro (informação acessível ao agente).

**Perguntas no mesmo lote apenas quando compartilham snapshot e objetivo contextual:** Neva defender ou pedir reforço; Rubra solicitar escolta; Dendra comunicar ou inspecionar; coordenador meso definir capacidade de resposta. Resposta válida pode perder validade antes do commit; nesse caso replanejar.

## 8. Ciclo temporal, vitais e sustentabilidade

- NPCs trabalham por **agenda lógica e eventos**; não por constantes microdecisões a 60fps.
- Estados têm duração realista de jogo: viagem, transferência, comunicação e reparo não são instantâneos.
- Quando nada exige atenção, podem descansar, manter posto, circular ou seguir rotina.
- Necessidades acumulam ou melhoram conforme trabalho. Loops devem alcançar equilíbrio em cenários estáveis, sem extinção automática infinita ou crescimento exponencial de NPCs.
- Quando a população não dá conta da doença, o organismo sofre e o jogador pode sentir consequências; também deve existir possibilidade limitada de a defesa celular conter sozinha crises menores.
- Seres celulares não precisam viver para sempre. Ciclo de vida, morte e reposição contam história sem apagar o valor das interações já ocorridas.
- Não chamar Jev para a mesma escolha repetidamente se mundo/risco/recursos não mudaram.
- Alertas globalizados representam **mudança de condição material relevante**; microeventos pessoais/locais vão ao contexto ou ao diário, não a banners grandes.

## 8A. Assinatura visual e gestos por papel (critério de NPC completo)

O Atlas especifica **comportamento de verdade**; [VisualInteractionAnimationPlan.md](VisualInteractionAnimationPlan.md) define **como esse trabalho é percebido**. Os dois são obrigatórios e devem evoluir juntos, não em fases desconectadas.

| NPC | Forma e movimento | Trabalho visual polido | Reação a obstáculo/ajuda | Storyboard |
|---|---|---|---|---|
| **Rubra (hemácia)** | disco orgânico flexível, oscilação no fluxo e vesículas no interior | transportar e transferir oxigênio com ligação ao tecido | desacelerar, sinalizar, pedir ajuda, reconhecer intervenção e retomar entrega | V01/V02 |
| **Neva (neutrófila)** | lobos e pseudópodes ágeis, atenção direcional | quimiotaxia, patrulha e combate defensivo com telegraph | pedir reforço e trabalhar em formação sem spawn fictício | V04 |
| **Dendra (dendrítica)** | prolongamentos exploratórios e gestos de varredura | investigar e recolher antígeno, comunicar por sinais/rota | revisar crença falsa, entregar informação e participar de escolta | V05/V09 |
| **Osteia (estroma)** | ancoragem e pulsações de matriz | nutrir nicho com transferência de material | reduzir ritmo sob falta de suprimento, agradecer reposição | V07 |
| **Macrófago** | corpo pesado e pseudópodes envolventes | fagocitose, vacúolos e limpeza material da região | interromper/soltar alvo em falha, solicitar apoio e avançar limpeza | V03 |
| **Plaqueta** | partículas/células pequenas e agrupadas | aderir e formar trama de reparação em camadas | pedir proteção, mostrar brecha persistente e progresso proporcional ao reparo | V06 |
| **Órgãos e ambiente** | membranas, veias, partículas de fluxo e tecido com profundidade moderada | reação gradual a oxigenação, perfusão, inflamação, ferimento e recuperação | diferenciação entre fase crítica, contida e curada com causa validada | V13 |

**Regra:** a animação de `confirmed` depende de resultado autorizado, não do simples início da pose. Cada intervenção deve ter estados `idle/notice/approach/anticipate/contact/progress/confirmed/fail/recover` relevantes, blending/interrupção e material que muda por trabalho real. A mesma tarefa fora da câmera continua em Go, sem necessidade de efeito visual.

**Começar por Rubra/Neva/Dendra/macrófago/plaqueta/Osteia** antes de expandir para as demais 14 famílias. Ao adicionar uma nova família de NPC, entregar simultaneamente comportamento, silhueta, gesto de trabalho, feedback de falha, sincronização e LOD, com testes headless/visuais e benchmark mobile. **Não marcar novo tipo de intervenção como pronto sem animação funcionalmente expressiva**.

## 9. Avaliação de autonomia por tipo

Para cada papel, exigir caso de teste que prove:
1. rotina começa sem jogador;
2. tarefa usa recursos válidos e toma tempo;
3. problema real muda prioridade;
4. possui pelo menos duas alternativas coerentes; consegue ficar sem ação quando necessário;
5. coopera com outra célula e não duplica capacidade;
6. reage a informação antiga incorreta;
7. responde à ajuda do jogador sem obrigar aceite de quest;
8. interrompe pedido após solução;
9. mantém estado após reload e fora de câmera;
10. não realiza ação biológica de outra linhagem sem regra explícita;
11. sua ação é visualmente distinta, com aproximação, contato, progresso e resultado confirmados;
12. os efeitos não reiniciam ao reconectar e têm preset econômico/reduced-motion legível.

**Fim de jogo desejado:** uma pessoa passeia pelo pulmão e vê um contexto em andamento, com células que têm tarefas compreensíveis, respostas individuais e efeitos sistêmicos — não um corredor de NPCs com símbolos de exclamação.

## 10. Crescimento de catálogo e atualização científica

Separar **dados científicos reais** de **metáforas de gameplay**. Valores de velocidade, metabolismo, oxigenação, tempo de trabalho e competência real exigem validação de fonte; números de equilíbrio aqui são abstrações ajustadas por testes de jogo. Guardar fontes em `HostScience.md` e nos comentários de config conforme padrão atual. Mecânicas de fantasia podem extrapolar biologia, mas a interface nunca deve afirmar que são comportamento médico literal.

Conteúdo vem após o primeiro corte funcional de Rubra/Neva/Dendra + infecção pulmonar. Não criar 20 tipos de célula com árvore de comportamento vazia para cumprir catálogo. Acrescentar 1–2 famílias por iteração e provar papel distinto, desempenho e impacto sistêmico.
