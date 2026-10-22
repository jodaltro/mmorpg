# Versão 2 — Hospedeiro (MMORPG dentro de um corpo humano)

> Estrutura completa do jogo (RPG → MMORPG, evoluções, builds, missões, masmorras, mundo reativo, Jev): [GameStructure.md](GameStructure.md). Dados científicos: [HostScience.md](HostScience.md). O roteiro H0–H7 de GameStructure substitui a tabela de marcos B abaixo.

Documento de visão. O protótipo jogável vive em `clients/hospedeiro/` (Godot 4.7). A "v1" citada abaixo é o antigo RPG Unity (floresta, Mira, Orin), arquivado na branch `archive/unity-2026-10-19`; o Hospedeiro convive com o universo Valdoria do motor.

## Premissa (direção 2: o mundo é um corpo humano)

O mundo inteiro do MMORPG é **um corpo humano vivo, o Hospedeiro**. Os habitantes são as coisas que vivem dentro dele: células, micróbios, vírus, neurônios, glóbulos. Cada jogador é algo minúsculo nascido ali (uma célula-tronco jovem) que evolui. Não existe "humano com espada": existem membranas, enzimas, sinapses, hormônios e tecidos.

A biologia real fornece a estrutura (DNA, RNA, proteínas, mitose, diferenciação, sinapses, hormônios, sistema imune). A fantasia entra por cima: telepatia, poderes, habilidades. A estética bioluminescente procedural continua a mesma.

### O Hospedeiro está vivo

O corpo tem ritmo próprio, que funciona como clima e relógio do mundo: **batimento** (pulso de luz global, o "tick" do mundo), **sono e vigília**, **fome**, **febre**, **estresse** (adrenalina e cortisol), **ferimentos** e **envelhecimento**. Esses estados mudam as regiões e geram eventos para todos os jogadores. O Jev faz o papel de consciência do Hospedeiro: avalia o estado do corpo e escolhe quais acontecimentos válidos oferecer. O domínio valida e aplica, de forma assíncrona e opcional, como na GameVision.

### Regiões = órgãos e sistemas (crescimento horizontal)

Cada nova região é um "continente" com paleta, física e ecologia próprias, publicada em atos:

| Região | Papel no jogo | Estética procedural |
|---|---|---|
| Medula óssea | Berço: nascimento das células-tronco, tutorial | Cavernas porosas e quentes, âmbar |
| Sangue | Rios navegáveis com correnteza, transporte rápido, vírus à solta | Vermelho-escuro pulsando com o batimento, fluxo contínuo |
| Coração | Pulso global do mundo, região de eventos periódicos | Câmaras que contraem, ondas de luz |
| Pulmões | Oxigênio como recurso, ventos, câmaras de ar | Prateado e frio, sopros |
| Fígado e rins | Fábricas: craft, filtragem, alquimia de metabólitos | Verde-âmbar, filtros e dutos |
| Intestino | Microbioma, biofilmes, território de facções, nutrientes | Verde e âmbar, colônias vivas |
| Pele | Fronteira com o mundo externo, ferimentos como portais | Penumbra, camadas, feridas abertas |
| Sistema linfático e imune | Guerra permanente, patrulhas, anticorpos | Azul-aço, gânglios como fortalezas |
| Ossos e músculos | Estruturas, contração e força | Fibras, tensão |
| Cérebro | Neurônios, sinapses, telepatia, sonho | Azul e violeta, faíscas elétricas |
| Núcleo celular (DNA) | Região mais profunda e de fim de jogo: o código do corpo | Cromossomos como labirintos, hélices |

Também há **escala interior**: dá para entrar dentro de uma célula e depois do seu núcleo. Células de órgãos viram cavernas procedurais, e cromossomos viram dungeons de profundidade infinita.

### Biologia real como mecânica

- **DNA → RNA → proteína**: genes são habilidades. Transcrever é ativar um gene. O genoma do B3 é literalmente o DNA do jogador. **Epigenética** liga e desliga genes sem perdê-los.
- **Diferenciação celular** em vez de classes: neurônio, macrófago, hemácia, osteoblasto, linfócito, célula-tronco. Cada linhagem é uma especialização com estilo de luta próprio.
- **Mitose e apoptose**: clonar-se, e morte programada que serve de execução e de renascimento (a linhagem herda parte do genoma).
- **Sinapses e neurotransmissores**: dopamina, adrenalina e serotonina como buffs de área e sinais de grupo. **Hormônios** são sinais globais. **Citocinas** são alarmes e convocações. **Quimiotaxia** (seguir gradientes químicos) é o rastro das propostas de missão.
- **Potencial de ação**: eletricidade como dano e como velocidade.

### Fantasia sobre a base real

- **Telepatia** é a rede sináptica: jogadores ligados por axônios compartilham visão, fala e buffs, mesmo longe.
- Poderes ficam ancorados em biologia: Febre (calor em área), Adrenalina (explosão de velocidade), Cicatrização, Memória celular (conhecimento persistente), Sinapse (ligação com aliados), Anticorpo (marcar e neutralizar alvos).

### Facções e ameaças

Sistema imune (ordem, mas paranoica: pode atacar o que é seu), microbioma (simbiontes e colônias), neurônios (mentes coletivas e oníricas), células-tronco (renascimento), e as ameaças: vírus, bactérias, parasitas e **câncer** (células rebeldes que crescem sem controle e funcionam como eventos de mundo e chefes). Doenças são eventos globais que reconfiguram regiões.

### Escalas anteriores (resumo)

As antigas "escalas de existência" (caldo primordial, colônias, hospedeiros) foram substituídas pelas regiões do corpo acima. O caldo primordial vira a **medula e o sangue** do início do jogo.

## Decisões fechadas

- **Estilo visual**: bioluminescente vetorial/procedural (malhas deformáveis, flagelos em cadeia de segmentos, membrana desenhada por código, glow aditivo e bloom do Godot). Hitbox lógica (círculo/cápsula) separada do visual.
- **Tom**: sombrio-onírico. Mundo escuro e profundo, luz como recurso e perigo, acentos saturados só no que é interativo ou ameaçador. Beleza inquietante, não horror gráfico.
- **Escala**: MMO, com crescimento horizontal da história e conteúdo vertical infinito (abaixo).

## Escala MMO

### Crescimento horizontal (a história se expande)

O mundo cresce abrindo **novas regiões do Hospedeiro** (veja a tabela na premissa) e novos acontecimentos do corpo, em atos publicados. Atos futuros podem ir além: outros Hospedeiros, a mente do corpo (sonho) e o que existe fora dele. Novas regiões, facções e arcos se somam sem invalidar os anteriores; jogadores antigos e novos coexistem. O estado do mundo é compartilhado e persistente (surtos, conquistas de território, extinções), com o Jev avaliando consequências de forma assíncrona e o domínio validando.

### Conteúdo vertical infinito (sem níveis tradicionais)

O poder cresce em profundidade, nunca por XP ou nível:

- **Genoma profundo**: camadas de genes por raridade, mutações instáveis, sinergias e "linhagens" de build. Sempre há uma variante mais rara ou arriscada.
- **Maestria por uso**: conhecimentos e técnicas aprendidos praticando e descobrindo (como a Leitura de Fraquezas da v1), não por nível.
- **Cavernas vivas procedurais**: dungeons geradas em hospedeiros, com dificuldade crescente por profundidade, modificadores e chefes rotativos.
- **Raids e eventos de mundo**: surtos virais, invasões do sistema imune, guerras de facção, para grupos grandes.
- **Linhagem e renascimento**: ao morrer ou transcender, o legado genético passa à próxima célula, com ciclos de dificuldade e recompensas ascendentes.
- **Construção e economia**: colônias de jogadores, biofilmes, rotas de nutrientes, mercado de metabólitos.
- **Temporadas e pressões ambientais** que reembaralham o que é forte.

### Consequências de arquitetura

- Conteúdo guiado por dados (genes, regiões, criaturas, eventos) para publicar sem recompilar.
- Autoridade de servidor para movimento, colisão, acertos e vida; o cliente envia só intenção.
- Shards/regiões desacoplados; o B1–B6 constrói offline com a mesma separação Domain/Runtime para migrar à autoridade Go sem reescrever regras.
- Como na [visão do motor](../GameVision.md): sem XP/níveis; a progressão vertical é por genes, conhecimento e acontecimentos.

## Diretriz de tom: biologia fantástica

A biologia é **inspiração, não limite**. O mundo é um RPG de fantasia em escala molecular: pode haver magia, criaturas impossíveis e regras irreais, desde que tenham um disfarce biológico coerente.

- **Magia = bioquímica sobrenatural**: "Chama de ATP", "Sussurro de RNA" (feitiços que reescrevem o inimigo), "Mitose" (clone temporário), "Apoptose" (execução), "Quorum" (invocar colônia aliada).
- **Criaturas míticas**: Dragões-Ribossomo, Golem de Queratina, Hidras de flagelos, Leviatã-Mitocôndria, Fagos cavaleiros, Reis-Prion.
- **Elementos** viram vias: Ácido, Oxidação, Eletricidade (potencial de membrana), Luz (fotossíntese), Calor (fonte hidrotermal), Esporo (veneno/controle).
- **Facções**: Colônia Simbionte, Culto do Vírus, Ordem Imune, Nômades Procariontes, Reino Fúngico.
- O rigor científico só entra onde ajuda (nomes, intuição, humor); nunca trava uma mecânica divertida.

## Compromisso: continua sendo um RPG de ação

Combate em tempo real é o centro do jogo, não um extra:

- **Ataques com hitbox e tempo**: golpe de flagelo/chicote, investida (dash), jato de toxina (projétil), explosão de esporos (área), engolfamento (agarrão).
- **Esquiva e posicionamento**: dash com i-frames curtos, empurrões de correnteza, cobertura em biofilme.
- **Cooldowns e ATP** como recurso; combos entre golpes leves e pesados; carga de feitiços.
- **Chefes com padrões** legíveis (fases, pontos fracos, telegráficos), como a Leitura de Fraquezas da v1.
- **Builds de RPG**: genes equipados em slots (ativos/passivos), raridades, sinergias, equipamento (organelas), especializações — tudo sem níveis tradicionais.
- Missões, NPCs, diário, exploração de regiões e loot continuam como na v1.

## Compatibilidade com a GameVision

Os princípios de `Docs/GameVision.md` continuam valendo:

| Princípio | Tradução na v2 |
|---|---|
| Action RPG 2D em tempo real | Movimento por flagelo/cílios, combate por contato, toxinas e fagocitose |
| Sem leveling tradicional | **Mutações** (genes) em vez de níveis; evolução por habilidades, conhecimento e especialização |
| Mundo com memória persistente | Ecossistema que muda: populações, nutrientes, pH, toxinas, antibióticos |
| Jev avalia oportunidades | Jev escolhe entre candidatos válidos de "pressão evolutiva" e propostas; o domínio valida |
| Uma missão ativa, proposta contextual | Propostas vêm do ambiente (gradiente químico, sinal quorum, ameaça), aceitar/recusar/ignorar |
| Divertido offline | Autoridade local; Jev e backend opcionais e assíncronos |

## Mapeamento do mundo antigo para o novo

| Conceito RPG | Equivalente biológico |
|---|---|
| Jogador | Célula (procarionte → eucarionte → colônia → organismo) |
| HP | Integridade da membrana |
| Mana/stamina | ATP |
| Dano | Lise, toxina, dano oxidativo, bloqueio enzimático |
| Itens/equipamento | Organelas, plasmídeos, enzimas, proteínas de membrana |
| Habilidades | Genes expressos (cadeia ativa de DNA) |
| NPCs | Células cooperantes: colônias, simbiontes, células-tronco, "ancestrais" (memória genética) |
| Monstros | Vírus, bacteriófagos, predadores unicelulares, priões, antibióticos, sistema imune |
| Fauna | Protozoários, tardígrados, nematódeos, fitoplâncton móvel |
| Flora | Biofilmes, algas, tapetes de cianobactérias, hifas de fungos |
| Engenharia/construção | Biossíntese: biofilme, matriz extracelular, esporos, colmeias de colônia, vesículas |
| Dinheiro/comércio | Metabólitos trocados (glicose, aminoácidos, nucleotídeos) |
| Regiões | Meios: sopa primordial, fonte hidrotermal, citoplasma de hospedeiro, intestino, biofilme dentário, folha, solo |

## Núcleo de jogabilidade

1. **Metabolismo**: ATP é gasto ao mover, atacar e expressar genes; recuperado coletando nutrientes (fotossíntese, quimiossíntese, fagocitose). Fome é pressão constante, não punição.
2. **Combate**: toque, jato de toxina, engolfamento (fagocitose), escudo de parede celular, defesa por CRISPR contra vírus. Servidor/autoridade valida dano e custo, como na v1.
3. **Mutação**: ao acumular eventos (comer, sobreviver a toxina, ser infectado), surgem *oportunidades de mutação* — o jogador escolhe 1 entre candidatos (risco/benefício). Mutações são permanentes, algumas são deletérias (trade-off real).
4. **Evolução em fases**: protocélula → procarionte → eucarionte (endossimbiose: capturar mitocôndria/cloroplasto como evento) → colônia → organismo multicelular. Cada fase muda controles e escala do mundo.
5. **Especializações** (árvores, não níveis): Predador, Fotossintético, Parasita/Vírus, Simbionte/Construtor, Imune/Defensor.
6. **Construção**: secretar matriz, formar biofilmes, criar esporos como "checkpoint", comunidades de NPCs cooperantes.
7. **Mundo vivo**: populações seguem dinâmica de Lotka-Volterra simplificada, com eventos (surto viral, antibiótico, glaciação, mudança de pH) que o Jev pode orquestrar.

## Narrativa

Você é uma célula-tronco jovem na medula do Hospedeiro, a primeira capaz de **lembrar**. O DNA guarda ecos de células e linhagens que já existiram. Reconstituí-los revela por que o corpo está adoecendo: algo está reescrevendo o código, e o sistema imune já não distingue o que é próprio. A escolha final: restaurar o corpo, deixar que ele se transforme, ou assumir o controle do próprio código. Histórias secundárias vêm de linhagens celulares NPC, microbioma e neurônios.

## Arquitetura proposta

Organização do protótipo:

- `clients/hospedeiro/scripts/domain` — GDScript puro (`RefCounted`): metabolismo, genoma/mutações, combate molecular, ecossistema. Sem Nodes.
- `clients/hospedeiro/scripts/runtime` — Nodes: física 2D, apresentação, input, autoridade offline.
- `clients/hospedeiro/tests` — runner headless próprio: regras (domínio) e integração (mundo).
- Cena principal `clients/hospedeiro/scenes/main.tscn` (texto). Engine: **Godot 4.7**; o Unity da v1 é legado arquivado.
- `Docs/Hospedeiro/` — design; validação em `Docs/Validation/Hospedeiro.md`.
- Reaproveitar o contrato de autoridade (`RealtimeAuthorityContract`), o padrão de eventos (`WorldEventOrchestrator`) e a integração Jev/Go; cliente nunca envia dano como verdade.

## Plano de marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| B0 | Este documento + escolhas de estilo visual | Aprovado pelo usuário |
| B1 | Protótipo vertical: célula móvel no caldo, ATP, nutrientes, membrana | Testes headless de regras e integração passando, sem erros na saída (entregue) |
| B2 | Combate molecular: toxina, vírus com telegrafia (feito no B1) | Autoridade valida dano e custos |
| B3 | Genoma = DNA: genes com benefício e custo, pressão evolutiva, persistência (em andamento) | Escolha de mutação, salvo em disco |
| B4 | Região Sangue: correnteza, batimento do coração como pulso global, glóbulos | Fluxo físico e regiões ligadas à medula |
| B5 | Imune e infecções: eventos de doença, anticorpos, facção imune | Evento de infecção jogável |
| B6 | Cérebro e telepatia: neurônios, sinapses, rede entre jogadores | Duas células compartilhando visão e buffs |
| B7 | Estado do Hospedeiro (sono, febre, fome) e Jev como consciência, opcional | Funciona com Jev desligado |
| B8 | Multiplayer: contratos para a autoridade Go | Sem acoplamento ao cliente |

## Decisões da direção 2

- **Nome do jogo: Hospedeiro.**
- **Um único Hospedeiro para todos**: o mundo aberto do MMO é um grande ser humano, compartilhado por todos os jogadores.
- **O corpo é anônimo**: como na vida real, quem vive dentro não tem consciência de quem é aquele corpo. O "lá fora" é desconhecido e misterioso.
- **Biologia como base, não como lei**: usamos estruturas, números e literatura reais (ver [HostScience.md](HostScience.md)), mas o jogo pode quebrar regras da biologia quando isso o deixar melhor.
