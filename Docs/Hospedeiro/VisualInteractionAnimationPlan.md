# Hospedeiro Vivo — PLANO DE ARTE, ANIMAÇÃO E INTERAÇÕES DE ALTO IMPACTO
**27/10/2026 | branch `main` | Especificação de produção para Claude Code | Ainda não implementado**

**Objetivo:** ao ver Rubra transportar oxigênio, Neva defender um vaso, Dendra investigar um antígeno ou uma plaqueta reparar uma lesão, o jogador deve compreender imediatamente o que acontece, sentir prazer em participar e perceber **uma transformação real do ambiente** quando a intervenção funciona. O aumento de autonomia dos NPCs exige um salto igualmente significativo de **qualidade audiovisual, clareza e responsividade**.

**Dependências:** [AutonomousBodyImplementationPlan.md](AutonomousBodyImplementationPlan.md), [ClaudeCodeAutonomousBodyRunbook.md](ClaudeCodeAutonomousBodyRunbook.md), [AutonomousBodyQualityGates.md](AutonomousBodyQualityGates.md), [AutonomousCellBehaviorAtlas.md](AutonomousCellBehaviorAtlas.md), [LivingWorldConflicts.md](LivingWorldConflicts.md), [JevCognitiveArchitecture.md](JevCognitiveArchitecture.md), [CombatPresentation.md](CombatPresentation.md), [JevDesign.md](JevDesign.md), [MobileUX.md](MobileUX.md). Este documento é requisito de implementação; não declara que o visual novo já existe.

## 1. Direção de arte: biologia sombria, luminosa e expressiva

Preservar a estética autoral do Hospedeiro: **microcosmo orgânico, onírico, bioluminescente, procedimental e com sombras profundas**. Não transformar as células em humanos fantasiados nem copiar personagens, uniformes, layouts ou assets de *Cells at Work!*. Melhorar forma, material, profundidade, resposta ao ambiente e expressão não verbal, sem romper os corpos celulares desenhados por `BioCellBody` e `BioCellForms`.

Princípios:
1. **Silhueta funcional** — distinguir hemácia, plaqueta, neutrófilo, macrófago e dendrítica sem depender de rótulo. Forma do núcleo, membrana, organelas, deformação e tipo de movimento comunicam função.
2. **Ação antes do brilho** — o núcleo da interação é uma mudança visível no tecido/objeto/estado; partículas e flashes apenas acentuam. Luz não substitui feedback de trabalho.
3. **Antecipação → execução → contato → consequência → recuperação** — todas as intervenções importantes precisam de começo, confirmação e desfecho visual; um som/partícula isolado é insuficiente.
4. **Leitura por camadas** — próximo da câmera: detalhamento, expressividade e rastro; distância média: silhueta e ação; fora da tela: apenas estado lógico, nenhuma VFX.
5. **Escala dinâmica** — um único NPC pode comunicar detalhes; dezenas colaborando parecem um ecossistema através de movimento coreografado, sem confusão e sem centenas de partículas por indivíduo.
6. **Interação gratificante, não enganosa** — antecipação curta, reação imediata ao input local, confirmação autoritativa distinguível, atualização fisiológica perceptível. Nunca mostrar cura, entrega ou conclusão como sucesso definitivo antes do servidor confirmar.
7. **Acessibilidade** — alternativa a cor, ajuste de shake, vibração, flash, densidade de partículas e movimento; leitura em tela pequena; hitbox de interação clara e controle desimpedido.

### 1.1 Paleta, linguagem e identidade por função
- **Hemácias:** rubro orgânico translúcido, brilho interno suave e pulsação de transporte; carga de O2 indicada por microvesículas/fios de luz, não números flutuando continuamente.
- **Plaquetas:** pequenas, ágeis, agregadas em grupos coesos; filamentos/ponte de fibrina, tampão que progride em camadas.
- **Neutrófilos:** membrana rápida/deformável, núcleo multilobulado; prolongamentos e granulações; explosão defensiva distinguível de efeito mágico genérico.
- **Macrófagos:** corpo pesado, pseudópodes e vacúolos internos; engolfamento gradual, desgaste/limpeza de detritos.
- **Dendríticas:** ramificações táteis que varrem meio, vesículas de captura e sinais em direção ao sistema de comunicação.
- **Estroma/Osteia:** mais ancorado no nicho; contatos com matriz e transferência pulsante de nutrientes.
- **Outros tipos futuros:** assinatura própria para linfócitos, mastócitos, Treg, glia, hepatócitos, enterócitos, células renais. Respeitar catálogo de papéis.
- **Patógenos/tecido:** ameaça reconhecível por alterações de textura, comportamento e contaminação; **dano e recuperação transformam o cenário** de maneira legível e progressiva.

### 1.2 Materiais/cenografia biológicos (melhorias grandes, mas graduais)
Camadas propostas: (a) fundo orgânico de baixa frequência, (b) vasos/tecidos com profundidade e paralaxe moderada, (c) fluxo local de partículas com orientação física, (d) membranas/microestruturas, (e) células interativas, (f) sinais químicos e efeitos contextuais, (g) HUD. Profundidade 2.5D por shaders Godot 2D somente se benchmarks aprovarem; não trocar de engine nem criar render 3D obrigatório.

Shaders/materiais candidatos: brilho de borda ligado a condição celular, distorção membranar, refração leve opcional, ruído procedural temporal, variações de tecido saudável/inflamado, transparência orgânica controlada, occlusion fake/soft sombras e variação de fluxo sanguíneo. Evitar uso indiscriminado de `CanvasItemMaterial` aditivo que “lava” a silhueta. **Nenhum efeito decorativo pode modificar collider ou regra de dano**.

## 2. O contrato de animação de interação (uma linguagem única)

Introduzir uma gramática consistente para interações de trabalho:
- **IDLE** — respiração orgânica, atenção visual discreta, deslocamento da membrana; nunca todo NPC em idle se possui tarefa.
- **NOTICE** — célula detecta pista: orienta núcleo/pseudópode, brilho direcional e pequena alteração da rota.
- **APPROACH** — deslocamento condizente com linhagem, desaceleração e ajuste ao alvo.
- **ANTICIPATE** — sinal curto e legível antes do trabalho (contração da membrana, posicionamento de organelas, filamentos).
- **ACT** — visualização de uma ação autorizada ou intenção ainda pendente; amostras de material/vesículas/membrana deslocadas.
- **CONTACT** — ponto de contato entre duas entidades com vínculo visual (filamento, fluxo, captura, fagocitose).
- **PROGRESS** — feedback contínuo que corresponde ao progresso canônico, inclusive progresso parcial e bloqueio.
- **CONFIRMED** — consequência material após ACK servidor (carga entregue, obstrução aberta, tecido selado, foco contido).
- **CANCEL/FAIL/INTERRUPT** — interrupção coerente, recuo/rompimento do vínculo e indicação visual do motivo quando pertinente.
- **RECOVER/RETURN** — relaxamento, retomada de rotina e retorno de materiais à pose.
As transições são combináveis (movimento+carregar+alarme) sem explosão combinatória de animações; usar camadas/procedural + máquina hierárquica de estados, com prioridades e interruptibilidade. **A representação não decide o fato.**

### 2.1 Temporizações iniciais de protótipo (não contratos de simulação)
- Reação local perceptível ao input: **idealmente no frame visual seguinte**, sem prometer latência de servidor.
- Anticipation de ação pequena: referência 0,10–0,22 s; trabalho pesado 0,25–0,55 s quando não prejudicar responsividade.
- Feedback de contato: pulsos curtos 0,08–0,20 s, seguido de decaimento de 0,2–0,6 s.
- Intervenção sustentada: duração vem do trabalho/snapshot; não de temporizador cosmético.
- Conclusão: enfatizar visualmente 0,35–0,8 s, respeitando velocidade da ação e configuração de animação reduzida.
- Se a condição canônica mudar no meio, a animação **faz blending para o estado correto**, não conclui uma ação cancelada.
Estes valores são hipóteses de produção a validar em jogo e mobile, não benchmark existente.

### 2.2 Máquina de estados — proposta de implementação
```text
BioInteractionState = {
  entity_id, interaction_id, kind, actor_id, target_id,
  phase, start_tick, phase_revision, logical_progress,
  animation_variant_seed, world_position, world_direction,
  effects_flags, requested_at, ack_state
}
```
**Fonte canônica:** motor e servidor confirmam começo/efeito/progresso/conclusão. **Fonte visual:** `BioInteractionPresenter` consome snapshot e eventos relevantes, calcula transição e desenha pose. Uma nova apresentação nunca altera ATP/HP/material do core. Usar `interaction_id` + revisão para dedupe, `seed` estável para variante procedural e reconstrução após reconexão; não enviar 60 snapshots de animação quando basta estado e marcos esparsos.

## 3. Storyboards — intervenções que o jogador vai querer fazer

**Cada storyboard inclui** gatilho material, personagem, antecipação, gesto, consequência confirmada, feedback de falha, câmera/UI, áudio opcional e versão LOD.

### V01 — Transporte de oxigênio por Rubra (prioridade máxima)
- **Gatilho:** hemácia recebe carga validada e destino acessível.
- **Antecipação:** Rubra reduz velocidade, membrana inclina, vesículas luminosas entram e núcleo/corpo pulsa.
- **Movimento:** formato de disco deformável responde ao fluxo; carga interna acompanha a física, filamentos suaves no deslocamento; sem partículas cobrindo o caminho.
- **Entrega:** ao chegar, há alinhamento com o tecido, vesículas percorrem um vínculo capilar → tecido; o tecido ganha pulso/brilho gradual conforme indicador real sobe.
- **Confirmação:** somente evento de entrega autoritativo aciona luz de recuperação, som baixo e atualização de déficit local; carcaça da carga se esvazia.
- **Falha:** vaso obstruído, Rubra desacelera e procura rota; aparece vínculo quebrado/fluxo interrompido, sem inventar entrega.
- **Jogador:** liberar obstrução ou escoltar cria resposta visual conjunta, não apenas `+1` no HUD.
- **LOD:** distante: ponto rubro com carga pulsante; perto: membrana deformada e vesículas detalhadas; fora de tela: nenhuma partícula.

### V02 — Pedido espontâneo e aceitação de ajuda
- **Gatilho:** `HelpRequest` válido de NPC com causa, audiência e estado.
- **Antecipação:** célula volta-se ao jogador, emite sinal químico discreto, sinal no ambiente aponta origem (não "!" permanente).
- **Apresentação:** mensagem curta próxima ao NPC, ícone de necessidade, palavra de ação (`ajudar`, `investigar`, `escoltar`); grande popup apenas para crise global, não para cada pedido.
- **Interação:** resposta acessível por aproximação/tecla/toque; animação de ligação/ressonância quando há cooperação real.
- **Confirmação:** vínculo se torna estável e começa tarefa; progresso passa a representar ação confirmada.
- **Interrupção:** mensagem desaparece se necessidade acabou; aceno de agradecimento contextual após ajuda verificada.
- **LOD:** pedidos distantes entram em painel/contexto, não desenham balões no mapa inteiro.

### V03 — Limpeza e fagocitose por macrófago
- Pseudópodes envolvem alvo de maneira gradual com tensão de membrana; vacúolo absorve o alvo quando resultado é confirmado.
- Resíduo removido transforma a textura local, deixando área mais limpa; tremor pesado leve opcional, sem `shake` obrigatório.
- Se falhar por resistência, alvo escapa e membrana relaxa; nunca teletransportar inimigo para dentro sem confirmação.
- Jogador participa limpando área/recolhendo recurso; progresso compartilhado altera o cenário.

### V04 — Neva e defesa coletiva
- Detectar quimiotaxia: membrana orienta-se para trilha química, núcleo acelera pulso; deslocamento com elasticidade e giros.
- Antes do ataque: telegraph distinto e honesto sobre raio/direção/duração; ataque existente `BioAbilityRunner` continua autoritativo.
- Reforços: outras células chegam por rotas reais, sem spawn por VFX; formação dinâmica ao defender área; sinais curtos de coordenação.
- Contenção: campo visual diminui quando a carga cai; tecido reequilibra brilho, ameaça recua biologicamente.

### V05 — Dendra reconhece e comunica antígeno
- Filamentos dendríticos varrem, encostam e recolhem microvesícula; momento de reconhecimento com mudança de padrão de luz, não um texto "descobriu".
- Dendra percorre rota viável; mensagem via sinais/vesículas movendo-se por caminho. Ao chegar, célula receptora muda de comportamento **só após informação registrada**.
- Se notícia obsoleta, gesto de revisão e comunicação corrigida; evitar painel falso de alerta global.

### V06 — Plaquetas selam ferimento (segunda fatia essencial)
- Fluxo de partículas passa por brecha e diminui conforme tamponamento real.
- Plaquetas convergem, aderem e criam fios de fibrina visualmente em camadas; progressão escalonada e visível, sem instantâneo mágico.
- Jogador segura invasores, entrega recurso ou reforça; cada colaboração altera velocidade/progresso confirmado.
- Tampão falha: fissura visível; doença pode entrar; não mostrar coágulo final antes do gate de resolução.

### V07 — Osteia alimenta nicho medular
- Estroma se ancora à matriz; fluxo de vesículas passa entre células com brilho pulsado; quando reserva baixa, brilho enfraquece e processo fica lento.
- Jogador entrega ferro/insumos e vê a matriz se recuperar, permitindo maturação de novas células.
- Interface comunica `medula alimentada` por mudança ambiental, não por dezenas de pop-ups.

### V08 — Reparo tecidual / fibroblastos
- Matriz e fibras se reorganizam; cor/forma de ferida regridem de modo proporcional à integridade confirmada.
- Mãos inexistentes: filamentos, pseudópodes, vesículas e depositar matriz são a linguagem celular.
- Concluir cria passagem recuperada ou ambiente estabilizado; status fisiológico acompanha.

### V09 — Investigação e exame de lesão
- Lente biológica (efeito de refração localizada), focos discretos e delineamento temporal; órgão oferece trilhas de evidência.
- Pontos de investigação têm sinais diferentes de inimigos/quest pins; revelar nova informação após ação válida.
- Falso alarme gera feedback de descoberta, não VFX de batalha.

### V10 — Fígado metaboliza toxinas
- Toxinas coloridas entram em estruturas de tecido e saem partículas transformadas com paleta controlada; estado de sobrecarga escurece pulsos.
- Jogador conduz suprimentos/desobstrui percurso; toxicidade real alimenta mudança visual e ambiental.

### V11 — Filtração renal
- Fluxos bifurcam, resíduos seguem uma via e componentes retidos outra; válvulas orgânicas respondem ao desequilíbrio.
- Sem `+ureia` flutuando como única recompensa: mostrar efeito de purificação da região.

### V12 — Regulação imune, reduzir dano colateral
- Célula reguladora libera sinal que amortece cores/agressividade; a camada visual se acalma sem esconder invasores.
- Mecânica deve representar custo e duração do trabalho de regulação, nunca remover ameaça só pela aparência.

### V13 — Emergência, conflito e alteração global da atmosfera
- Início de crise: região afetada modifica ambiente (veias pulsando, tecido inflama, citocinas visuais discretas), mapa destaca frente real.
- Alerta grande quando conflito muda de fase, sem tomar controle do personagem; no restante do tempo o conflito está no painel.
- Crise estabiliza: pulso/cor/partículas regressam gradualmente, e a recuperação continua visível por trabalho NPC.
- Se crise se espalha, mudança chega às áreas correspondentes **após** causalidade/latência; não colorir todo corpo instantaneamente.

### V14 — Cooperação de grupo NPC + jogador
- Coreografia emergente de funções: Rubra transporta, Neva protege, macrófago limpa, plaquetas reparam; efeitos se conectam sem sincronizar artificialmente todas as células.
- Reconhecer quem auxiliou: pequeno gesto/ressonância e mudança de rota ou trabalho, não título bloqueante.
- Priorizar interações entre duas ou três células próximas com efeito observável, escalando depois.

### V15 — Falha, recidiva e danos ao tecido
- Quando defesa falha, ruptura/contaminação acontece visualmente no lugar afetado com severidade progressiva.
- Ressurgimento do conflito não repete VFX de início se é a mesma crise reaberta; usar aviso e transformação coerentes.
- Dar motivo para tentar novamente sem castigo visual excessivo: feedback rápido, próximo objetivo compreensível.

### V16 — Gene, evolução e organismo
- Preservar os traços que Jev já escolhe (núcleo, membrana, organelas, brilho, modos/projéteis), mas enriquecer as transições e o encaixe das formas.
- Não gerar centenas de assets por combinação. Variações paramétricas usam mesma biblioteca procedural e afetam **estilo visual**, enquanto equilíbrio de habilidades permanece sob as regras.
- Evo de jogador e de NPC devem ser reconhecíveis, porém uma célula NPC não muda a própria linhagem indiscriminadamente.

## 4. Arquitetura visual recomendada para Godot 4.7

**Não substituir sistemas existentes sem inventário**. Componentes atuais vistos na main:
- `clients/hospedeiro/scripts/runtime/bio_cell_body.gd`: membrana deformável, looks, flash, hit e ataques.
- `bio_cell_forms.gd`: formas por linhagem e genes.
- `bio_ability_runner.gd`, `bio_hit_feedback.gd`: ações já reconhecidas e feedback de combate.
- `bio_fx.gd`, `bio_fx_life.gd`: efeitos de vida curta; hoje criam Nodes por partícula, candidato a pooling/LOD depois de medir.
- `bio_art.gd`, `bio_ambient_motes.gd`: brilho/ambiente procedural.
- `bio_world.gd`, `bio_game_server.gd`: apresentação e autoridade Godot/Nakama.
- `bio_hud.gd`: banner, vitais e capacidades de interação.
- `Docs/Hospedeiro/CombatPresentation.md`, `JevDesign.md`, `MobileUX.md`: restrições atuais de feedback, visual Jev e mobile.

**Módulos sugeridos (nomes revisáveis após inspeção):**
1. `BioInteractionCatalog` (`RefCounted`): descrição de tipos de interação, animações, tintas, duração visual relativa, prioridade e LOD — **sem lógica de conclusão**.
2. `BioInteractionStateMachine` (`RefCounted`): animação por fase e blend, interruptibilidade, ações sobrepostas e reconciliação; testável headless.
3. `BioNpcVisualController` (`Node2D`): corpo, orientação, apresentação do gesto por papel, indicador de ocupação, olhar/trilha.
4. `BioInteractionPresenter` (`Node`): consome estado canônico, evento e revisão, alimenta máquina e FX; dedupe por `event_id/interaction_id`.
5. `BioTaskVfx`: bibliotecas parametrizadas de transporte, ligação, fagocitose, fios, vesículas, sinal químico, matriz e recuperação; pooling/batching por benchmark.
6. `BioTissueStateVisual`: interpolação entre saúde do tecido e aparência; só altera apresentação, sem escrever vitais.
7. `BioAmbientDirector`: atmosfera visual por região/conflito com reações graduais, limites e persistência da fase.
8. `BioInteractionAudio`: trilhas curtas e discretas por confirmação; volume mixado e opção mute; sem exigir arquivos externos não licenciados.
9. `BioInteractionAccessibility`: presets `alto/padrão/econômico`, redução de movimento/flashes, legibilidade sem som.
10. **Instrumentação visual**: contadores de partículas, draw calls, nós ativos, tempo de render, replay capturado e teste headless.

**Reuso antes de criação:** catálogo e FX devem estender `BioCellBody`, `BioFx` e linguagem de habilidades, e não criar hierarquia paralela de NPCs do zero.

### 4.1 Evento → apresentação → confirmação
```text
Core Go / Godot headless
   -> evento autoritativo {id, actor, target, kind, phase, logical_progress, revision}
   -> Nakama snapshot/delta, reordenável
   -> BioInteractionPresenter (versão monotônica por interação)
   -> máquina de animação + corpo/membrana + tecidos + HUD + som
   -> visualiza feedback otimista apenas como INTENÇÃO/PREVISÃO local
   -> transição CONFIRMED somente após confirmação servidor
```
Regras:
- Reconectar em meio a uma entrega/reparo mostra o **progresso atual**, não reexecuta o começo.
- Se o evento de conclusão chegar antes de progress, processamento monotônico não permite retrocesso.
- Duplicata não duplica partícula, animação final, som nem prêmio.
- Jev nunca autoriza VFX que afirme fato não ocorrido. Seus traços podem gerar **variedade de forma/movimento dentro de parâmetros**, não substituir a verdade.
- Em batalha, priorizar telegraph de ataques e legibilidade dos jogadores; reduzir efeitos da sociedade ao fundo.

### 4.2 Procedural de alto acabamento sem peso excessivo
- Combinar interpolação de formas, esqueletos simples/curvas parametrizadas, deformação por velocidade, orientações reais, squash/stretch, pose direcional e feedback de contato.
- Habilidades existentes têm assinatura Jev de trajetória/impacto e `BioAbilityMode`. Interações não combativas devem ter igual riqueza **por famílias funcionais**: `transport`, `inspect`, `adhere`, `repair`, `phagocytose`, `signal`, `shield`, `metabolize`. Variantes precisam de catálogo validável e fallback visual.
- Não deixar toda célula com o mesmo efeito de aura colorida. Movimento, silhueta, contato e objeto manipulado contam uma história única.
- Proceduralização deve ser **reprodutível** em clientes para o mesmo `seed` e variante/estado. Ruído puramente visual não entra em fatos de jogo.

### 4.3 “Juice” audiovisual: tabela de reforço
| Momento | Gesto corporal | Consequência ambiental | Som opcional | Feedback UI |
|---|---|---|---|---|
| Identificação de necessidade | orientação+pulso | sinal local surge | tom discreto | ação contextual |
| Aproximação | deformação direcional | fluxo/rastro | movimentação suave | referência do alvo |
| Trabalho em progresso | contato e ciclo | material/estado muda | textura curta | progresso verdadeiro |
| Ajuda entre células | alinhamento e troca de sinal | conexão visível | resposta tonal | cooperação confirmada |
| Conclusão | recuperação/relaxamento | ferida fecha/fluxo volta | resolução curta | mudança do conflito |
| Falha | recuo/reorientação | efeito é interrompido | som de impedimento | motivo e alternativa |

Não emitir som em cada célula de fundo. Áudio espacial/local por prioridade com limite de vozes simultâneas e controle de acessibilidade.

## 5. Vertical slice visual obrigatório — produzir antes da expansão de conteúdo

**Fase V0 — Baseline visual e perf**: capturar antes/depois no mesmo seed/hardware, contadores e UX atual, especialmente Godot mobile. Verificar se arte é procedimental e custo de Nodes `BioFxLife`.

**Fase V1 — Biblioteca de gestos**: desenho de orientação, antecipação, contato, progresso e conclusão em um `BioInteractionPresenter` testável; três temas iniciais: transporte, fagocitose/defesa e reparo.

**Fase V2 — Rubra (produção prioritária)**: primeiro storyboard V01 completo no jogo QA; carga visível, percurso, obstrução visual, pedido contextual V02, ajuda, entrega confirmada e tecido respirando; testar reconexão.

**Fase V3 — Defesa e comunicação**: V04 Neva e V05 Dendra, com telegraphs honestos, sinais químicos, confirmação e coordenação NPC-NPC.

**Fase V4 — Plaquetas e limpeza**: V03 macrófago e V06 plaquetas; prótese visual do tecido com fissura, tampão, reparo e recuperação.

**Fase V5 — Conflito atmosférico e HUD**: V13 alerta grande/ambiente por fase + progresso acessível, integrado à fase P11 do plano mestre; duas crises simultâneas.

**Fase V6 — Todas as outras funções**: V07–V12 em módulos por órgão, depois V14–V16; não criar 20 efeitos idênticos com cores diferentes.

**Fase V7 — Polimento e escala**: blending, timing de input, mixagem, material procedural, pooling, LOD e perf; golden captures por dispositivo; revisão de animação reduzida; amostras com muitos NPCs.

**Não esperar até P16 para iniciar P10/V1.** Integrar animação a cada nova ação funcional no mesmo incremento: uma tarefa não é “jogável e pronta” se, perto do jogador, não possui começo, continuidade, consequência e falha legíveis.

## 6. Fases cruzadas com o plano mestre

- **P0:** baseline de FPS, GPU/CPU, tempo de frame, quantidade de nós/partículas e capturas; definir performance do aparelho de teste e orçamento alvo a partir de medições.
- **P1/P2:** corpo celular rico, locomoção específica e estados `doing` para NPCs. As células de fundo permanecem agregadas.
- **P3/P4:** visual de interação NPC-NPC (pulsos, sinais, transferência de material), reconhecimento/memória discretos.
- **P5:** pedidos de socorro V02 e respostas a ajuda; CTA claro, distância e contexto.
- **P6/P7:** V13 crise mudando órgãos; material de tecido e indicadores físicos de progresso.
- **P8/P9:** variantes visuais parametrizadas por decisão Jev **dentro do vocabulário permitido**, sem chamar IA por frame.
- **P10:** visual actor/sync, presenters, animação de interações V1–V4.
- **P11:** UX premium de conflitos/pedidos, banners e vibração opcional; recompensar sucesso confirmado sem spam.
- **P12:** ampliar V07–V12 por órgão ao mesmo tempo do conteúdo, não acumular dívida de apresentação.
- **P13:** substituir experiência visual de dungeon por teatro aberto de conflito, mantendo progressão e local biológico relevante.
- **P14/P15:** observabilidade gráfica, perf em mobile real, stress e LOD; otimizar pooling sem mudar gameplay.
- **P16:** demonstração audiovisual e gates aprovados, documentação de arte + performance.

## 7. Critérios de qualidade e aceitação visual

**Gate V-G1 — compreensão**: em 5–10 segundos de observação o jogador entende que Rubra transporta e Neva defende, **sem ler texto explicativo** (teste com participantes, registrar respostas; taxa alvo definida após baseline, não inventar pesquisa).

**V-G2 — legibilidade de intervenção**: ao ajudar, o jogador percebe início, avanço, sucesso e falha; feedback de sucesso não antecede confirmação do servidor.

**V-G3 — variedade**: ao menos seis perfis iniciais possuem animações/poses/materiais/gestos diferenciáveis por função, incluindo idle e trabalho real. Proibir “um círculo com cor diferente e mesmo movimento” como final.

**V-G4 — consistência de mundo**: animar entrega não duplica oxigênio, reparar não muda indicador antes do core, telegraph corresponde à área de perigo, jogador não pode ser atingido por FX invisível.

**V-G5 — multiplayer**: dois clientes veem um mesmo NPC executando a mesma tarefa/fase, com interpolação aceitável; reordenar pacotes/reconectar não recria efeitos finais.

**V-G6 — continuidade/LOD**: quando jogador aproxima/afasta, NPC continua fase coerente e não reinicia work loop. Sem NPCs na câmera, FPS e memória não se degradam por FX distantes.

**V-G7 — legibilidade mobile**: toque e controles durante interação funcionam, alvo é distinguível, texto ajusta escala, menos brilho sobre controles.

**V-G8 — acessibilidade**: opções reduzir partículas/flash/shake, sinal não depende apenas de cor e feedback importante também funciona sem som.

**V-G9 — performance real**: medir em dispositivos alvo com 1, 20, 50 e 100 NPCs visíveis simulados (cenários QA, não metas prometidas). Capturar FPS, frame-time p95/p99, CPU/GPU, nós ativos, partículas simultâneas, uso de memória, tráfego e latência de input. Só definir budgets finais após baseline. Preset econômico funcional, mesma informação sem recursos caros.

**V-G10 — direção de arte**: iluminação, materiais e animações são coesos com estilo orgânico-onírico e originais, sem dependência de assets licenciados de terceiros.

**V-G11 — efeito com causa**: toda animação importante se conecta ao trabalho real e tem visual distinto para `pending`, `progress`, `confirmed`, `failed`.

**V-G12 — qualidade da experiência**: teste com usuários em QA: conseguem explicar o que fizeram, repetiriam a atividade, perceberam colaboração e não ficaram frustrados por animação lenta ou feedback falso. Registrar observações e mudanças.

### 7.1 Testes propostos no Godot/QA
- `test_interaction_state_machine.gd`: sequência, interrupção, replanejamento, blending, progress e seed.
- `test_npc_visual_roles.gd`: forma/movimento únicos, tabela de catálogo sem IDs de animação ausentes.
- `test_interaction_presenter.gd`: uma confirmação → um final; duplicatas/reconexão/reordenação.
- `test_tissue_visual_feedback.gd`: tecido reflete somente estado confirmado, sem avanço negativo visual.
- `test_visual_lod.gd`: spawn/despawn/reconciliação, número de nodes/FX delimitado e baixa alocação em frame.
- `test_accessibility_presentation.gd`: reduced-motion, sem sons, sem flash, versão com baixo efeito.
- Capturas de golden frames e vídeos de QA no mesmo estado/seed, antes/depois das intervenções.
- `clients/hospedeiro/tests/web/`: mobile, scale, HUD e dois clientes no Nakama QA. **Nenhum teste no servidor publicado**.
Registrar execução real em `Docs/Validation/YYYY-MM-DD-interaction-animation.md`. As sugestões de nomes são novas, não arquivos que já existem.

## 8. Critérios de entrega por intervenção (Definition of Done)

Cada nova intervenção de NPC/jogador só conta como pronta quando tem:
- [ ] Gatilho fisiológico/material documentado + tarefa real.
- [ ] ID, alvo, evento, progresso, consequência e autorização de servidor.
- [ ] Silhueta e gesto exclusivo da função, com antecipação/interrupção.
- [ ] Contato e progresso visíveis ligados ao snapshot/resultado real.
- [ ] Som opcional ou substituto visual acessível.
- [ ] Confirmação de sucesso e falha; sem “efeito sempre verde”.
- [ ] Localização/feedback de ação visível no mundo e no HUD, sem bloquear input.
- [ ] Interação NPC-NPC e intervenção do jogador ao menos no cenário QA relevante.
- [ ] LOD/off-screen sem FX e sem quebrar tarefa lógica.
- [ ] Reconexão/duplicata/reordenação testadas.
- [ ] Testes Godot + motor e captura no dispositivo-alvo registrados.
- [ ] Preset mobile econômico e preferência reduced motion preservados.

## 9. Guia de acompanhamento para Claude Code

**Antes de mexer:** ler `Docs/Hospedeiro/JevDesign.md` e `CombatPresentation.md`; levantar animações existentes, hooks de hit e `BioFx`; não destruir pipeline de desenho procedural, não misturar domínio e render, não refatorar Godot inteiro de uma vez.

**Ao criar código:** começar com uma fatia completa para Rubra e NPCs próximos, criar presenter e biblioteca reutilizável, extrair catálogo declarativo, construir testes headless e visual preview, só então adicionar outros tipos. Não empilhar efeitos de partículas para compensar ausência de gesto ou textura.

**Ao decidir escala:** profiling antes da otimização; GPU particles, MultiMesh/batching, buffers e pooling são opções mediante necessidade e suporte do Godot/web mobile, não ordens cegas. Para high-end usar qualidade adicional **sem mudar informação ou vantagem competitiva**.

**Em cada commit:** descrever storyboard implementado, estados canônicos ligados, reação a input/servidor, hardware/frames medidos, capturas de QA, impacto de GPU/CPU, limitações, testes executados, migração/rollback. Se não testou dispositivo físico, não afirmar otimização mobile comprovada.

## 10. Marco final de demonstração audiovisual

Gravar a mesma sessão QA em dois clientes do mundo compartilhado:
1. Jogador chega ao pulmão: vê Rubra carregando oxigênio e outras células trabalhando, com profundidade orgânica.
2. Fluxo obstrui; Rubra desacelera, tenta desvio, sinaliza e pede ajuda; o jogador escolhe aproximar-se porque entendeu o problema.
3. O jogador ajuda, uma célula defensora colabora; transição de trabalho é expressiva, sem perda de controle.
4. O transporte volta; vesículas chegam ao tecido, ambiente recupera luminosidade progressiva **após confirmação**.
5. Em outra região, Neva, Dendra, macrófagos e plaquetas interagem durante crise; cada papel tem ação legível.
6. Crise sobe para crítico, atmosfera muda e alerta grande é exibido uma vez; defesa coletiva apresenta telegraphs sem excesso de VFX.
7. Após contenção, tecido entra em reparação visível; NPCs retornam às rotinas.
8. Jogadores desconectam e retornam; a cena apresenta fase correta, não reproduz recompensas/VFX como novidades.
9. Repetir em preset econômico/reduced motion e no dispositivo móvel alvo; comparativo de desempenho e legibilidade.
10. Mostrar que simulação continua sem cliente e que VFX não existe fora da renderização.

**Resultado desejado:** um mundo biologicamente ativo em que **observar e ajudar é divertido por si só**, com animações expressivas e consequências reais, não apenas uma tabela de tarefas com efeitos coloridos.
