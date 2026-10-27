# Hospedeiro — NPCs vivos e Conflitos Globais
**Decisão de produto: 26/10/2026 — branch main.**  
**Estado: especificação aprovada como direção de design; NÃO é implementação concluída.**
> **Complemento técnico de 27/10/2026:** [JevCognitiveArchitecture.md](JevCognitiveArchitecture.md) registra as pesquisas recentes, as capacidades reais do Jev 1.13/1.14 e o desenho de memória seletiva, avaliação em lotes e decisões de NPCs/conflitos. Aumentar dados coletados e contexto relevante sem criar outra autoridade ou usar o Jev como simulador físico.


## 1. Mudança de direção
O Hospedeiro deixa de usar masmorras instanciadas como ciclo central. Toda crise importante acontece no mapa vivo do corpo, permanece enquanto sua causa existir, afeta NPCs e jogadores, e pode ser enfrentada por qualquer pessoa do mesmo mundo. Os locais biológicos chamados antigamente de masmorras (granuloma, tumor, biofilme, centro germinativo, barreira hematoencefálica e núcleo) continuam como territórios físicos, fenômenos e acontecimentos do mapa; não como salas privadas, runs, portais, chefes repetíveis ou sequências de limpar salas.

**Regra inegociável:** nenhum conflito é encerrado porque um jogador desconectou, completou um objetivo pessoal ou entrou em outra região. Só transita quando as condições do próprio mundo o justificam. Não há necessidade de vencer toda luta: o organismo também pode conter, transformar ou conviver com algumas situações.

O sistema de missões tradicionais perde o protagonismo. O jogador enxerga o conflito global que escolheu acompanhar, seus objetivos coletivos e, quando fizer sentido, um pedido direto de um NPC. A contribuição em um conflito é livre e não exige aceitar missão. Os modelos de quest do motor continuam disponíveis internamente para tutoriais, arcos pessoais e pedidos; não precisam ocupar uma lista extensa no HUD.

## 2. Uma sociedade celular com vida própria
Cada NPC importante tem identidade, função biológica, local de trabalho, rotas possíveis, condição física simplificada, necessidades, conhecimento parcial, relações e uma memória compacta de encontros significativos. Não precisa simular cada uma das bilhões de células do corpo: populações de fundo podem ser agregadas e só personagens próximos, relevantes ou envolvidos em conflitos recebem simulação individual detalhada.

Perfis mínimos:
- **Hemácias**: coletam e distribuem oxigênio, seguem a circulação, percebem obstruções; pedem escolta quando uma rota segura é interrompida.
- **Plaquetas**: detectam lesão, migram, constroem e reforçam o tampão; pedem materiais, proteção e cooperação.
- **Neutrófilos**: patrulham, migram por quimiotaxia, priorizam focos agudos; chamam reforços ao avaliar desvantagem.
- **Macrófagos**: fagocitam resíduos e invasores, limpam tecido, sinalizam problemas persistentes; precisam de ajuda quando a capacidade local satura.
- **Dendríticas**: observam padrões, levam informação sobre antígenos aos linfonodos e conectam grupos defensivos.
- **Glia e células de suporte**: mantêm condições locais de tecido, reagem a perturbações e comunicam necessidades de reparo.

### 2.1 Ciclo individual
**Perceber → lembrar/aprender → avaliar necessidade e dever → escolher ação permitida → agir e gastar tempo/recursos → observar resultado → ajustar plano.**
Atividades habituais acontecem sem jogadores por perto; os NPCs não são pontos de exclamação esperando interação. Alguns NPCs podem recusar ajuda inadequada, mudar de prioridade, pedir outro tipo de auxílio ou agradecer depois. Um NPC pode estar enganado, mas o servidor nunca confunde suas crenças com a verdade do mundo.

### 2.2 Solicitação espontânea de ajuda
Um NPC pode:
1. Ver um jogador ajudá-lo ou se aproximar de uma situação crítica e fazer um convite contextual.
2. Pedir socorro quando seu trabalho foi interrompido e ele conhece alguém capaz de ajudar.
3. Oferecer participação em uma tarefa coletiva, incluindo transportar, escoltar, defender, examinar, reparar, comunicar ou recuperar.
4. Reagir ao auxílio não solicitado: agradece, ajusta relação, relata o resultado e passa a confiar mais.
5. Deixar uma necessidade latente no painel do conflito quando não encontra ninguém; os pedidos não devem desaparecer porque o NPC saiu do enquadramento.

Pedidos nunca geram uma cadeia aleatória sem relação causal. Uma hemácia com rota livre não pede escolta. Uma plaqueta não anuncia uma ferida já cicatrizada. NPC que não conhece o jogador só pede ajuda direta por urgência pública evidente; pedidos personalizados exigem observação, conversa ou reputação.

### 2.3 Memória, reputação e notícias
Memorizar apenas eventos relevantes: quem ajudou, quem prejudicou, promessa feita, tarefa abandonada, antígeno descoberto e observações importantes. Rumores viajam por encontros, circulação e redes sinalizadoras; não são telepatia instantânea. A reputação modifica confiança e tipos de pedidos, mas não substitui os fatos autorizados pelo servidor. A memória deve ser limitada e compactada ao longo do tempo.

## 3. Conflitos do mundo compartilhado
Um **Conflito** é uma instância persistente de uma crise com origem, local primário, regiões afetadas, severidade, condições de progressão/estabilização, indicadores reais do mundo, estados, recursos exigidos, consequências e registro dos participantes.

Estado de ciclo:
- **Detectado**: sinais locais presentes, ainda sem anúncio global.
- **Ativo**: requer intervenção ou atividade de NPCs; aparece no painel global.
- **Crítico**: limiares fisiológicos relevantes ultrapassados; anúncio grande de escalada.
- **Expansão**: agrava-se ou cria outras frentes/efeitos em órgãos diferentes; NÃO apaga o conflito de origem.
- **Contido**: expansão interrompida, mas a ameaça pode persistir e recrudescer.
- **Resolvido**: condições sustentadas de estabilização foram verificadas pelo motor.
- **Recuperação**: sequelas e reparos ainda mudam o mundo; pode levar a novas situações.

Não é necessário forçar toda crise por todas as etapas. Uma crise pode oscilar entre contida e ativa; só fica resolvida após uma condição de estabilização sustentada, evitando piscar no HUD entre ticks.

### 3.1 Concorrência e causalidade
A primeira configuração da interface destaca **um conflito principal e até dois secundários**. Isso é um limite de destaque e uma meta de ritmo, não uma razão para esconder ou apagar crises reais. Quando houver mais, elas continuam no painel completo, priorizadas por gravidade, alcance e urgência. O diretor não gera uma nova crise por simples cooldown: cada abertura precisa satisfazer gatilhos fisiológicos e limites de coerência. Crises relacionadas compartilham causa ou estabelecem relação de dependência, evitando criar dezenas de cópias do mesmo foco.

Exemplos causais:
- Infecção pulmonar → inflamação local → citocinas circulantes → febre → menor eficiência de transporte.
- Ferimento na pele → plaquetas e defesa local → reparo ou brecha persistente → possibilidade de infecção.
- Hemólise/acúmulo de hemácias antigas → demanda de limpeza no baço → ferro reutilizado na medula.
- Disfunção hepática → toxinas circulantes → sobrecarga renal e mudanças no ambiente celular.

### 3.2 Vitória, contenção e falha
Conflitos têm **indicadores de verdade**, não uma barra arbitrária de chefe. Exemplo de infecção pulmonar: carga microbiana, integridade tecidual, oxigenação e intensidade inflamatória. A resolução pode exigir simultaneamente carga baixa, tecido estabilizado e manutenção por certo intervalo de ticks. Abates isolados ajudam somente quando o combate autoritativo confirma impacto nos indicadores. Se ninguém agir, os NPCs continuam tentando; podem controlar a ameaça sozinhos, estabilizar parcialmente ou falhar e gerar consequências. Nunca criar resolução automática só por expirar o tempo.

### 3.3 Participação global
Todos os jogadores do **mesmo mundo persistente** observam a mesma instância e os mesmos indicadores oficiais, independentemente da região em que estejam. Cada jogador pode escolher um conflito acompanhado e executar ações úteis em qualquer frente. A contribuição pessoal é anotada apenas com acontecimentos confirmados pelo servidor — combate, reparo, coleta, escolta, transporte, pesquisa, sinalização — usando IDs idempotentes e limites antifraude. Participações têm pesos por utilidade; evitar que apenas dano ou último golpe determine o reconhecimento. Contribuir sem ter recebido ou aceitado um pedido é normal. Recompensas individuais consideram feitos verificáveis e progresso coletivo, sem duplicações.

**Mundos pessoais:** mantêm conflitos próprios e separados do MMORPG. Visitas privadas seguem a autoridade do anfitrião. Não importar progresso de conflitos particulares para o mundo compartilhado.

## 4. Interface simples, alerta grande e informação consistente
### 4.1 ALERTA GLOBAL
Mostrar um painel modal visual **não bloqueante** (não rouba controle durante luta), com título, região, estágio, consequência e ação sugerida. Usar prioridade visual:
- Emergência CRÍTICA: vermelha, grande, entrada breve e som opcional.
- Nova crise relevante: âmbar, grande mas menos intrusiva.
- Escalada/expansão: aviso de mudança com motivo.
- Contenção/resolução: verde ou neutro, sem celebração repetitiva.
- Pequenas alterações: atualizar o painel sem pop-up.

Uma instância gera alerta grande quando nasce, muda de gravidade ou atinge um marco importante; não a cada tick nem a cada morte. Guardar por jogador a última revisão anunciada; deduplicar eventos em reconexão; respeitar fila com um alerta visual por vez e prioridade de gravidade. Oferecer histórico de alertas acessível no HUD.

### 4.2 HUD, objetivos e pedidos
Exibir **um objetivo acompanhado** ligado ao conflito selecionado, com progresso e consequências claros. Não empilhar missões tradicionais. Manter um botão/painel de **Conflitos do Hospedeiro** com lista total, severidade, região, indicadores, envolvidos e resumo de próximos passos. Os pedidos de NPC aparecem como interação contextual, notificação curta ou escolha de ajuda — **não uma segunda lista interminável de missões**.

Modelo:
- Cabeçalho: **Infecção pulmonar — CRÍTICO**.
- Localização e impacto: **Pulmão; queda de oxigenação**.
- Progresso coletivo: **carga infecciosa 76/100** (valor ilustrativo).
- Objetivo atual: **conter o foco e estabilizar os alvéolos**.
- Pedido contextual: **Neva: precisamos proteger as células de transporte**.
- Botões de navegação: acompanhar / deixar de acompanhar. A escolha não cria nem apaga conflito.

O painel deve ficar compreensível para quem chega no meio da crise: dizer o que aconteceu, por que importa, como ajudar e o que mudou recentemente. Separar urgência real da mera atividade do mundo.

## 5. Arquitetura recomendada
**Não criar um segundo cérebro obrigatório em Java.** O motor atual é Go (núcleo puro, determinístico, inclusive WASM nos mundos pessoais); o servidor autoritativo Godot confirma combate; Nakama transporta sessões e snapshots. **Jev**, já integrado, é o conselheiro de IA: escolhe entre opções válidas e pode sugerir linguagem e comportamento expressivo, sempre com fallback determinístico. Java pode ser usado futuramente em ferramenta auxiliar isolada se existir benefício mensurável, mas não como segunda fonte de verdade.

### 5.1 Motor Go — novo domínio genérico de conflitos
Estruturas a introduzir quando da implementação:
- **ConflictDef** no universo: tipo, gatilhos, indicadores, metas, estágios, efeitos, condições de término, cooldown e dependências.
- **ConflictState** no estado persistido: id da instância, definição, região, criação, fase, progresso oficial, última mudança, consequências e encerramento.
- **ConflictContribution**: ator, tipo de trabalho, evidência confirmada, valor validado e idempotência.
- **ConflictView** na visão: conflitos ativos relevantes + objetivo acompanhado + revisões/alertas públicos.
- **ConflictEvents**: conflict-started, conflict-escalated, conflict-contained, conflict-resolved, conflict-reopened e conflict-front-opened.

Toda transição é executada em core.Step sem chamadas externas nem aleatoriedade dependente de relógio. Todos os parâmetros e comportamentos específicos do Hospedeiro são declarados no universo, não codificados como doenças no motor. O journal/replay deve preservar digest e idempotência. A visão pública pode mostrar crises globais sem expor dados privados de jogadores e NPCs.

### 5.2 IA dos NPCs
Reutilizar **agents**, **goals**, **beliefs**, **relations**, **routines**, **gossip** e **quests** existentes. Incrementar tomada de decisão com pontuação de prioridades (urgência, papel biológico, distância, capacidade, recursos, relações), execução por agenda e replanejamento após falha. Cada NPC dispõe de um orçamento limitado de decisões; simulação de multidões distante é agregada. Jev pode escolher entre propostas válidas em bateladas de baixa frequência, com timeout e fallback. Nunca chamar IA no lock do mundo ou por frame da renderização.

### 5.3 Conexão com o Godot/Nakama
O cliente desenha posições, rotinas, alertas e interface. O servidor Godot confirma ações materiais; não aceitar clientes declarando dano, cura de órgão, resultado de conflito, pontos de participação ou conclusão. Nakama distribui eventos públicos com número de revisão e oferece snapshot atual ao entrar/reconectar. Alertas são derivados da mudança confirmada da instância, não de prompts livres da IA.

## 6. Remoção segura das masmorras
A decisão **é remover a experiência de masmorras no Hospedeiro**, NÃO excluir indiscriminadamente o sistema genérico de dungeons do motor, que pode atender outros universos e históricos. Os cinco registros atuais de dungeons e os fluxos de Godot precisam ser migrados para frentes abertas e eventos do mundo. Planejar antes uma conversão de recompensas, genes, registros de progressão, testes e personagens dentro de uma run.

A branch main atual possui mundos persistentes e journals vinculados ao fingerprint do universo. Editar/remover simplesmente a seção dungeons no JSON pode invalidar dados salvos e quebrar testes. A implementação deve introduzir migração versionada e compatibilidade temporária de leitura; nenhuma instância real deve ser resetada, e testes só em ambiente local isolado. A remoção do menu/portais deve ocorrer quando a alternativa de conflitos estiver de fato jogável.

## 7. Fatia vertical inicial — Infecção pulmonar
**Objetivo:** demonstrar que todos participam da mesma crise, com NPCs que continuam trabalhando e que pedem ajuda de maneira causal.

1. A simulação detecta condições reais para iniciar uma infecção nos alvéolos, cria uma instância global única e publica um alerta.
2. Células NPC da região observam e reagem conforme função, conhecimento, recursos e prioridades.
3. Neva ou outra célula conhecida solicita ajuda se a pressão excede sua capacidade; pedir e responder não são necessários para entrar no conflito.
4. Cada combate ou tarefa confirmada altera indicadores do mundo; o painel mostra o mesmo valor a todos os jogadores conectados.
5. Se a carga subir, a ameaça escala para circulação/febre e publica um aviso apenas na transição de fase.
6. Se carga e inflamação diminuírem e o tecido recuperar estabilidade por janela sustentada, o conflito é encerrado e entra em recuperação.
7. O mundo registra contribuição, relações com NPCs e consequência; novos conflitos podem aparecer por causas posteriores.
8. Ao reconectar, o jogador encontra a crise no estado verdadeiro e não recebe de novo os anúncios já vistos.

## 8. Fases técnicas
**C0 — Contrato e testes determinísticos:** desenhar ConflictDef/State/View, estados, eventos, gatilhos e replay, sem alterar o servidor real.

**C1 — Primeiro conflito compartilhado:** infecção pulmonar persistente, objetivos coletivos, contribuições verificadas, alertas de início/escala/resolução e HUD mínimo; coexistência temporária com dungeons legadas apenas por migração.

**C2 — Sociedade celular:** NPCs com trabalho independente, deslocamentos reais, necessidades, interações, pedido de ajuda, memória e relações; observar comportamentos em horários, com/sem jogadores.

**C3 — Ecologia de conflitos:** ferimentos, transporte de oxigênio, tumores e desequilíbrios de órgãos; cadeias causais, conflitos simultâneos, recuperação e priorização do diretor.

**C4 — Migração e limpeza de experiência:** substituir portas, menus, indicadores e recompensas de masmorras por conflitos no mapa. Remover conteúdo de dungeon do Hospedeiro após validar progresso e saves; manter motor genérico enquanto utilizado.

## 9. Critérios de pronto e QA
- Dois convidados diferentes veem o mesmo conflito, indicadores e alterações no mundo compartilhado.
- Um jogador sai: a crise e as ações de NPCs continuam. Ao voltar, recebe estado atual sem duplicação de grandes alertas.
- Ações confirmadas por servidor alteram progresso; tentativa de cliente forjar resultado, crédito ou recompensa é rejeitada.
- Sem jogadores, NPCs podem conter, agravar ou solicitar reforços com efeitos observáveis e reproduzíveis.
- NPC não oferece serviço incoerente, pedido já resolvido ou repetido de maneira incessante.
- Sucesso sustentado encerra a instância; sem solução ela persiste ou evolui, em vez de expirar arbitrariamente.
- Dois focos relacionados não criam spam nem infinitas cópias; conflitos simultâneos continuam distintos e navegáveis.
- HUD tem no máximo um objetivo acompanhado e um pedido contextual relevante, com painel para as demais crises.
- Tests de Step, simulação e replay geram digest idêntico para mesmos comandos; advisor desligado funciona.
- Testes apenas em mundo QA/local; não resetar nem usar a implantação compartilhada real como laboratório.

## 10. Regra de experiência
**O jogador não recebe tarefas porque o jogo precisa mantê-lo ocupado. Ele encontra necessidades porque o Hospedeiro está vivo.**
