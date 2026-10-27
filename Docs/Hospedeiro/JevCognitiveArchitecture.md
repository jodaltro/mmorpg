# Hospedeiro — Jev como avaliador cognitivo de NPCs e conflitos
**Pesquisa e arquitetura proposta em 27/10/2026** | **Branch:** `main` | **Estado:** design e plano experimental; não implementado.

Documento complementar a [LivingWorldConflicts.md](LivingWorldConflicts.md), [JevDesign.md](JevDesign.md), [GameStructure.md](GameStructure.md) e [Architecture.md](../Architecture.md).

## 1. Decisão de produto
Usar **muito mais Jev**, mas no papel que o modelo realmente desempenha: **avaliação estruturada de situações e escolha entre opções válidas**. Não tentar transformá-lo num gerador de prosa, simulador físico, executor de tarefas arbitrárias ou banco de memória. O Hospedeiro deve gerar muitos **dados de mundo e experiências verificáveis**, organizar estes dados por relevância e submetê-los em **lotes de decisões contextualmente relacionados** ao Jev. Os jogadores sentem a inteligência pelas consequências, e não pela quantidade de chamadas.

Manter a arquitetura existente: `engine/core` Go puro e replayável como autoridade; Godot/headless como autoridade de combate; Nakama como transporte; Jev/Decisions API fora de `core.Step` e de locks, com escolha revalidada e fallback determinístico; `universes/hospedeiro/universe.json` para conteúdo e regras biológicas. Não criar uma segunda autoridade em Java.

**Não autorizar modificações do mundo baseadas em inferência não verificada.** A IA recomenda intenções e prioridades; fatos biológicos, HP, dano, recursos, recompensas, relações persistidas e estados dos conflitos só mudam por comandos/evidências validados.

## 2. Diagnóstico verificável na main (27/10)
Arquivo `engine/advisor/jev.go`:
- Modelo fixo em `typesafe/jev-1.13`; endpoint `https://openrouter.ai/api/alpha/decisions`.
- Uma pergunta `choice` por requisição, usando `questions.choice`; código não interpreta `noul`, `score` nem `box`.
- Máximo de 64 opções e 32 linhas de contexto de até 256 caracteres cada. O corte é imposto pelo nosso adaptador, não pelo limite de contexto publicado do modelo.
- Decodifica `probabilities`, mas não as preserva no `Answer`; só devolve opção escolhida, confiança, metadados e custo.
- Revalida a escolha e registra resolução determinística, que deve continuar.
- Jev já tem responsabilidades reais em `offer`, `world`, `story`, `evolution`, `appearance`, `lineage`, `ability`, `evolution-slot`, `design` e `rota`. Não reescrever essas integrações antes de comparação experimental.

**Atualização do provedor:** Jev 1.14 foi lançado em 14/10/2026, com 262.144 tokens de contexto anunciados no OpenRouter e entrada de imagens; fazer A/B offline contra o 1.13 fixado antes de mudar a versão em produção. Contexto anunciado não é meta de prompt e não comprova precisão em grandes volumes.

## 3. Evidências publicadas estritamente no período 27/07–27/10/2026

1. **OpenRouter, 22/09 (atualizado 16/10), Jev versus Claude Opus 5:** 3.080 casos, 77 intenções; Jev 1.13 com 81,0% de acurácia, p50=175 ms e custo US$ 0,11/mil chamadas. Opus 5: 84,4%, p50=2.266 ms e US$ 2,42/mil; resultados daquele benchmark, não desempenho do Hospedeiro. https://openrouter.ai/blog/insights/jev-vs-claude-opus-5-classification/
2. **PriorBench, 20/09, avaliação reproduzível Jev 1.13:** 5.721 chamadas; 800 perguntas na mesma chamada em 985 ms e US$ 0,000747 (uma medição exploratória). Advertência crítica: na ausência de resposta correta entre as opções, o modelo ainda escolhe e pode apresentar alta confiança. Uma opção `nenhuma/aguardar` é mandatória em perguntas abertas. Bench não demonstra “milhões de decisões em milissegundos”. https://github.com/priorbench/jev/blob/main/paper/REPORT.md
3. **He et al., MemoryArena, PMLR 306, 2026:** benchmark mostra que desempenho em lembrança textual não implica boas ações posteriores; avaliar **memória → decisão → consequência**. A conferência foi em julho (06–11/07); portanto **não usar como evidência principal do intervalo estrito**, mas como referência prévia para método: https://proceedings.mlr.press/v306/he26am.html
4. **Huang et al., Harness the Memory, 15/08/2026:** comparação de substratos de memória relata que recuperação excessiva pode prejudicar decisões sequenciais. https://arxiv.org/abs/2608.15008
5. **Cao et al., MemCalib, 21/09/2026:** agentes grandes têm dificuldades em ponderar a relevância real de memórias; podem sobreusar ou subusar evidências. https://arxiv.org/abs/2609.24259
6. **Guo et al., Memory as a Shared Space, 09/10/2026:** compartilhar memórias por visões filtradas de permissão/escopo, mantendo separação entre acessos, pode reduzir tempo e tokens comparado a solicitar informação a cada agente. Trabalho específico ainda sujeito a generalização. https://www.ai-dc.ai/research/shared-memory-space/paper
7. **Li et al., Same Attack, Different Judge, 13/10/2026:** Jev resiste a determinados ataques de entradas estruturadas, mas desempenho/robustez variam conforme a tarefa; não usar confiança como verdade. https://arxiv.org/abs/2610.17820
8. **Xu & Mei, Jev para tráfego de rede, 30/09/2026:** em classificação de tráfego, métodos clássicos treinados venceram Jev no experimento; não usar Jev para problemas determinísticos/numéricos que Go já resolve melhor. https://arxiv.org/abs/2610.00376
9. **OpenRouter, Jev 1.14, 14/10/2026:** contrato e metadados públicos da nova versão. https://openrouter.ai/typesafe/jev-1.14

**Síntese operacional:** a oportunidade real não é “mais tokens sempre” ou “um agente LLM por célula”. É **melhor seleção e armazenamento de sinais, bateladas de decisões relacionadas, raciocínio probabilístico verificável e memória temporal**.

## 4. Arquitetura cognitiva de três escalas

### 4.1 MACRO — Jev interpreta o estado do Hospedeiro
A cada mudança relevante, e não a cada frame:
- Avalia qual conflito merece destaque; quais cadeias fisiológicas plausíveis devem ser intensificadas ou investigadas; qual comunidade celular precisa de reforços; se um fato descoberto justifica a abertura de uma frente.
- O diretor fornece **somente candidatos que satisfazem gatilhos, limites e invariantes em Go**; Jev pode optar por `nenhum/aguardar`.
- Uma febre, um tumor ou uma intoxicação jamais surge porque a IA “inventou” um acontecimento sem evidência no estado.

### 4.2 MESO — Jev coordena regiões, células e tarefas
Para um grupo de NPCs de um mesmo órgão/conflito, avaliar **conjuntamente** quais tarefas são prioritárias, se a equipe está em desvantagem, se pedir reforços é apropriado, onde comunicar descoberta e como reduzir desperdício de recursos. Resolver escolhas em uma etapa de compromisso com conflitos de recursos e capacidades, evitando 20 NPCs no mesmo destino indisponível. Deixar opções de aguardar/continuar o trabalho.

### 4.3 MICRO — Jev influencia indivíduos
Cada NPC possui sua função e opções de intenção: `continuar_rotina`, `inspecionar`, `transportar`, `patrulhar`, `defender`, `reparar`, `recusar`, `pedir_ajuda`, `avisar_grupo`, `descansar`, `recuar`. As opções **dependem da linhagem, local, equipamento, crenças, urgência e recursos**. Jev ranqueia ou seleciona; a autoridade decide execução e impacto material. NPC distante e estável **não precisa de chamada** a cada atualização.

## 5. Fontes de dados: observar mais, consultar melhor
Aumentar sensivelmente a telemetria autoritativa, com tipagem, timestamps, unidade e procedência:
- **Global/fisiologia:** temperatura, inflamação, oxigenação, pressão, transporte, toxicidade, fluxo sanguíneo, disponibilidade de nutrientes, carga de patógenos por região, integridade de tecidos, gravidade e duração de conflitos.
- **Região:** caminhos transitáveis, gargalos de fluxo, perigos, densidade de NPCs, demanda/suprimento, ferimentos, fontes de sinais químicos, tarefas abertas, mudanças nos últimos ticks.
- **NPC:** identidade e linhagem, papel/turno, posição/região, estado físico, ATP/recursos, necessidade dominante, tarefa em andamento, metas, competências, promessas, cooldowns, histórico de sucessos e fracassos.
- **Memória individual:** observações `(fato, origem, instante, validade, confiança subjetiva)`, relações com jogadores, últimas interações significativas, dívidas de ajuda e riscos percebidos.
- **Conhecimento social:** notícias públicas, boatos recebidos por encontro ou sinal químico, reputações **com proveniência**, diferenças entre crença e mundo real.
- **Jogador:** escolhas, estilo efetivo medido no servidor, contribuições verificadas, contatos com NPCs, objetivos voluntários acompanhados e histórico de descobertas, **sem misturar informação de outros jogadores que ele não deveria saber**.
- **Acontecimentos e consequências:** quem observou, quem participou, o que foi confirmado, o que mudou, que hipótese falhou, qual tarefa perdeu sentido.

**Armazenagem por camadas:**
1. **Journal imutável dos acontecimentos** (fonte da verdade / replay).
2. **Estado materializado** atual do corpo, regiões e NPCs (consulta rápida).
3. **Índices temporais, por região, entidade, conflito, causa e relevância** para recuperação seletiva.
4. **Memória episódica compacta por NPC** + memória social compartilhável por audiência.
5. **Resumo de decisão com limite rígido e rastreabilidade**, produzido para cada lote de perguntas; referências a eventos originais quando necessário.

Nunca passar o journal inteiro ao Jev. Memórias antigas contraditórias devem carregar status/sobrescrita e jamais prevalecer sobre os fatos validados. Quanto maior a coleta de dados, **mais seletivo deve ser o contexto**.

## 6. Protocolo JevBatch — proposta (sem alterar o contrato atual)
Introduzir uma camada de avaliação separada do adaptador legado:
- `EvaluateBatch(snapshot, questions)`: uma única estrutura `state` coerente com a mesma versão de mundo e um mapa de perguntas `questions`.
- Tipos suportados: `choice` (seleção), `noul` (probabilidade de condição), `score` (rubrica ordenada). `box` só se houver caso claro de imagem capturada/permitida; não necessário para NPCs.
- **Preservar o vetor completo de probabilidades por questão**, além da resposta e confiança, com identificador estável da pergunta e versão do estado.
- Candidatos curtos, não enganosos, sem alternativa impossível; opção `nenhuma / prosseguir rotina` sempre que aplicável.
- Agregar perguntas por **mesma região, conflito, revisão e horizonte temporal**. Não fazer um mega-prompt de todos os jogadores e órgãos ao mesmo tempo.
- Começar testes com grupos de 8, 16, 32 e 64 perguntas por chamada, comparando com perguntas isoladas em dados idênticos. São tamanhos **propostos**, não promessas sobre limites ou qualidade.
- Resultado entra numa fila de propostas; na confirmação, Go revalida precondições, vaga, recursos e versões; operações incompatíveis são descartadas/replanejadas; tudo registrado como comando para replay.
- `fallback` determinístico obrigatório por pergunta, inclusive timeout, resposta inválida, baixa qualidade, indisponibilidade e conflito após revalidação.
- Sem alterar `/v1` de forma incompatível; criar tipo interno ou contrato versionado se necessário. Não elevar limites antes de testes e orçamento.

## 7. Exemplo: lote de decisões da infecção pulmonar
Estado resumido do **mesmo instante autoritativo**:
```json
{
  "revision": 1740,
  "conflict": {"id": "pulmao-infeccao-17", "phase": "critical", "burden": 76,
               "oxygenation": 51, "inflammation": 64},
  "region": {"name": "alveolos", "need": ["containment", "transport", "repair"]},
  "actors": [
    {"id": "neva", "type": "neutrophil", "task": "patrol", "atp": 32, "allies": 1},
    {"id": "rubra", "type": "red_blood_cell", "task": "transport", "route_blocked": true},
    {"id": "dendra", "type": "dendritic_cell", "task": "inspect", "antigen_known": true}
  ]
}
```
Numa única solicitação, perguntas independentes, mas sobre estado comum:
- `neva_next_action` (choice): `call_help / defend / retreat / continue_patrol`.
- `rubra_need_escort` (noul): "Rubra precisa solicitar proteção para cumprir transporte?".
- `dendra_next_action` (choice): `present_antigen / inspect / report / wait`.
- `alert_priority` (score): `0=informativo;1=alerta;2=crítico`, **se** houver uma transição real que admita classificação; limiar clínico/biológico sempre em Go.
- `need_more_reinforcements` (noul): "A atual disponibilidade de células recomenda solicitar ajuda de jogadores?".

Esses números e ações são **ilustrativos e NÃO representam estado real**. O lote não consegue sozinho completar uma tarefa, transformar hipótese em fato, criar nova doença nem enviar recompensa.

## 8. Diálogo e NPCs vivos
Jev **não escreve falas**. Um banco procedural de falas/contextos pode usar templates parametrizados pelo estado confirmado:
- "Rubra: O capilar está obstruído. Se você me proteger, consigo tentar outra rota."
- "Neva: Sozinha não vou conter esse foco. Pode segurar a frente?"
- "Dendra: Reconheci um antígeno. Preciso levar esta informação ao linfonodo."

Opcionalmente, um modelo **generativo separado** produz texto de NPC e Jev atua como verificador semântico (coerência com função, crenças e fatos). Qualquer fala gerada sem verificação conserva caráter expressivo, jamais executável; não aceitar prompt externo como nova instrução para a autoridade. Primeiro provar que os comportamentos valem a pena sem LLM generativo.

## 9. Scheduler cognitivo e custos
Não rodar IA por frame, nem uma chamada por NPC por tick. Avaliar quando:
- um NPC muda de trabalho, encontra obstáculo, presencia incidente, reconhece um jogador ou recebe notícia;
- uma região ou conflito muda de fase;
- um pedido anterior falha e precisa ser replanejado;
- um timer **moderado por importância** pede reavaliação de personagens próximos;
- um NPC distante é agregado numa população de fundo com resultados determinísticos.

Propor orçamentos iniciais para TESTE, não SLAs de produção: 8–64 perguntas por lote, uma fila por região, cache/agrupamento por revisão, limite global de taxa e custo, amostragem dos NPCs relevantes. Medir p50/p95/p99, throughput, custo por decisão **correta**, cancelamento por estado obsoleto, qualidade dos objetivos e diversidade comportamental. Sem prova de que várias questões aumentam qualidade, não escalar.

## 10. Segurança, qualidade e limites
1. **Modelo errado:** o código da main fixa Jev 1.13; 1.14 é candidato a A/B. Não atualizar versão sem teste de regressão em QA.
2. **Confiança ≠ acurácia:** não usar corte universal `0.9`; calibrar por tarefa com casos rotulados; opções `não há ação`, `não sei` e `manter rotina`.
3. **IA ≠ verdade:** priorização e probabilidade não determinam dano, oxigenação, cura ou conclusão. O core continua decidindo pela fisiologia e ações confirmadas.
4. **Determinismo:** a resposta **aceita** entra no log, com revisão do estado, modelo, pergunta, opção, probabilidade e ID de chamada. Replay não invoca Jev.
5. **Beliefs ≠ facts:** NPCs só recebem observações acessíveis; provedores externos não recebem identidades desnecessárias e privados indiscriminadamente.
6. **Abuso e privacidade:** limitar entrada de nomes/textos de jogadores, escape de strings, política para linguagem gerada e fronteira de permissões; inputs maliciosos nunca viram regras.
7. **Limites de falha:** possibilidade de não oferecer ajuda, não atacar, adiar e ficar incerto; maior atividade de IA não deve gerar alertas repetidos ou conflitos artificiais.
8. **Sem jogadores conectados:** população segue em tempo de mundo via regras locais; chamadas de IA de baixa frequência e opcionais, sem custos descontrolados.
9. **Sem descontinuar mode personal:** mundo pessoal WASM não deve passar a depender do Jev online ou de um serviço obrigatório externo; fallback local completo.

## 11. Teste comparativo antes da implementação em produção
Criar cenários QA congelados com rótulos de especialistas de design e critérios de plausibilidade:
- Caso A: foco pulmonar aberto sem jogadores, Neva patrulha e Rubra encontra rota bloqueada.
- Caso B: um NPC recebe rumor desatualizado e outra célula possui observação recente verdadeira.
- Caso C: jogador ajuda sem aceitar pedido; NPC deve reconhecer apenas após evidência.
- Caso D: dois conflitos simultâneos disputam reforços escassos; NPCs não podem prometer o mesmo recurso duas vezes.
- Caso E: dezenas de NPCs têm tarefas rotineiras; o Jev deve aceitar `nenhuma mudança`.
- Caso F: perigo contido e recuperação em curso; não gerar alarme global a cada revisão.

Para cada caso, comparar: **baseline Go deterministic vs Jev 1.13 pergunta isolada vs Jev 1.13 lote vs Jev 1.14 lote**; medir decisões corretas, violação de fatos, redundância, diversidade crível, p95, tokens/custo, taxa de timeout, replay idêntico e efeito da memória relevante/irrelevante. Rejeitar solução de IA que seja mais cara e menos coerente que o baseline.

**Sinal de sucesso principal:** os NPCs parecem viver e lembrar, os conflitos mudam por consequências verificáveis e um jogador pode descobrir necessidades espontâneas. A medição é **qualidade do mundo por decisão**, não número bruto de perguntas respondidas.

## 12. Ordem sugerida
**J0** Instrumentar decisões e manter distribuições sem mudar a autoridade. **J1** Construir `JevBatch` isolado e benchmark Jev 1.13/1.14 em QA. **J2** Memória tipada/proveniência e índices por conflito/NPC. **J3** NPCs de um conflito pulmonar como coorte e pedidos espontâneos com opção de nada fazer. **J4** Diretor macro/meso com múltiplos conflitos e orçamento adaptativo. **J5** Escala com observabilidade e migração segura do HUD; só então remover experiências de dungeon do Hospedeiro.

**Princípio:** processar muitos sinais, formular poucas perguntas certas e permitir que suas respostas tenham consequências **reais e verificadas**.
