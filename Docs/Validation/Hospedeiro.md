# Validação — Hospedeiro (cliente Godot, modo offline)

Só testes realmente executados. Godot 4.7.2 (`D:\tools\godot\bin\Godot_v4.7.2-stable_win64_console.exe`), Windows 10, AMD RX 5700 XT (Vulkan, Forward+).

## H0 — protótipo trazido para `clients/hospedeiro/` (22/10/2026)

Import limpo (`--headless --import`, sem cache `.godot/`) e runner headless:

```bash
G="/d/tools/godot/bin/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path clients/hospedeiro --import
"$G" --headless --path clients/hospedeiro --script res://tests/run_tests.gd
```

Resultado: **31 testes, 0 falhas**, sem `SCRIPT ERROR` nem `ERROR` na saída do import ou do runner.

| Suíte | Testes | Cobre |
|---|---|---|
| `test_domain.gd` | 8 | ATP, membrana, recarga, dano vindo do catálogo, i-frames do impulso, nutrientes, morte |
| `test_genome.gd` | 12 | Genes com benefício e custo, espaços, ataques moldados pelo genoma sem alterar o catálogo, pressão evolutiva, oferta única, recusa sem repetição imediata, semente determinística, salvar e carregar |
| `test_world.gd` | 11 | Mundo sobe e os frames avançam; chicote de cauda (acerto pela frente, não por trás, recarga, varredura da cauda); projétil de toxina; nutriente; vírus telegrafa e acerta; morte e renascimento; impulso; oferta de mutação aplicada à célula; genoma persiste entre sessões |

Validação visual anterior (mesmo código, no protótipo antes da mudança de pasta): `tests/capture.gd` com renderer real gerou screenshots conferidos à mão (corpo com cauda numa silhueta única, golpe de cauda, vírus telegrafando, painel de mutação). Não repetida após a mudança de pasta.

### Motor Go no mesmo commit

`go test ./...` em `engine/` (Go 1.27.2): `advisor`, `api` e `sim` passam. **`scenarios` falha em `TestClientPresentationMatchesTheUniverse`**, porque `clients/godot/data/presentation.json` não está versionado: a regra `data/` do `.gitignore` o ignora. A falha já existe na `origin/main` (61426263) e não tem relação com o Hospedeiro, que não altera o motor.

### Não testado

- Gamepad real e sessão longa de jogo interativo.
- Conexão com o motor (não existe ainda; marco H1).

## H1 — universo no motor e cliente conectado (22/10/2026)

**Motor (Go 1.27.2):**

- `worldsim validate ../universes/hospedeiro/universe.json`: ok.
- `worldsim simulate -ticks 240 -players 3 -advisor deterministic`: o corpo alterna surto, resposta imune, cura e novo surto; refeição, sono e febre acontecem; o cenário único foi reivindicado e o capítulo compartilhado concluído; genes descobertos por hábito; boatos correram.
- `go test ./scenarios -run Hospedeiro`: 4 testes passam (primeiro feito antes da oferta e mergulho; contar à Dendra arma a defesa; autorregulação sem jogadores; cenário único).
- `go test ./...`: tudo passa, exceto `TestClientPresentationMatchesTheUniverse`, a falha anterior descrita no H0.

**Cliente (Godot 4.7.2):** 38 testes headless, 0 falhas, sem `SCRIPT ERROR`. Os 7 novos (`test_host.gd`) cobrem modo offline, troca de região, chamado e células NPC, febre pelas crenças, eventos que só reagem quando novos e gene descoberto.

**Ponta a ponta com o motor real e o Jev ligado** (`worldsim serve ... -tick 500ms -advisor jev`, cliente com renderer real, `tests/e2e_engine.gd`): 7 passos ok, duas vezes (a segunda depois dos últimos ajustes de menu, feed e acentos):

1. Conecta e entra no mundo.
2. Um nutriente absorvido no combate é confirmado ao motor.
3. Osteia chama: oferta "O primeiro mergulho" na janela do Sistema.
4. Aceita.
5. Ao entrar no sangue, a missão é concluída.
6. Destruir um vírion ensina a assinatura dele.
7. O menu oferece "Contar a Dendra: como é o Vírion Espinhoso"; contado, Dendra arma a defesa (evento público).

Screenshots conferidos à mão: janela do Sistema, menu de ações, residentes (Osteia, Neva), estado "O HOSPEDEIRO DORME", oferta do cenário único.

**Não testado:** gamepad real; várias pessoas ao mesmo tempo no mesmo mundo; sessão longa com tick real de 4 s.

## Evolução guiada pelo Jev (22/10/2026)

**Motor:** decisão nova `evolution` em `core/evolution.go` (pressão, candidatas, `fit` pelo estilo, oferta com destaque, verbos `evoluir` e `recusar-evolucao`, genoma no estado e na visão) e instruções do Jev em `advisor/jev.go`.

- `go vet ./...` ok; `go test ./...`: tudo passa, exceto a falha anterior de `presentation.json` (H0).
- 6 testes novos em `engine/scenarios/evolution_test.go`: sem pressão não há oferta; o padrão segue o caminho do jogador (um lutador recebe só mutações de combate); a escolha do Jev é revalidada e lidera a oferta; escolher expressa o gene e reforça o caminho; oferta recusada não volta logo; espaços reabsorvem o gene mais antigo.
- `worldsim simulate -ticks 120 -players 3 -advisor jev -pace 800ms`: **3 decisões `evolution` resolvidas pelo Jev** (latência média 386 ms, confiança média 0,67) e 14 `world`, todas no prazo.

**Cliente:** com o motor ligado, genoma, pressão e oferta vêm do motor; o gene escolhido pelo Jev aparece com "◆ o corpo pende para cá"; escolher e recusar viram os verbos do motor; esquivas são confirmadas (`esquivar`). Offline, o laço local continua. 38 testes headless, 0 falhas.

**Ponta a ponta com o Jev** (`e2e_engine.gd`, servidor de teste em tick de 0,5 s): os 7 passos do H1 e mais 2: três vírions confirmados estouram a pressão; a oferta chega com o destaque **escolhido pelo Jev** (no log do mundo, `resolve` de `evolution` com `provider: jev`: Flagelo Calejado, com Cauda Longa e Vesícula Tóxica, todas do caminho de combate); escolhido, o gene é expresso no corpo.

## Missões com recompensas de jogo e corpo procedural pelo Jev (22/10/2026)

**Missões:** 12 no universo (6 novas): "O primeiro gene", "Caça no capilar", "Banquete no sangue", "Dançar com o perigo", "Caçador veterano" e "Linhagem definida", com metas em feitos de jogo (abates, nutrientes, esquivas confirmadas, genes expressos). As recompensas agora são sentidas: **pressão evolutiva** (as de 10 garantem uma mutação), reparo da célula (evento `bonus-reparo`), chuva de nutrientes (`bonus-nutrientes`) e títulos; o cenário único também paga em evolução. `evoluir` virou feito nativo do motor, para missões poderem pedir genes.

**Aparência:** decisão nova `appearance` (`core/appearance.go`): eixos calculados do comportamento (ataques usados, esquivas, exploração, relações com quem fala, genes), variantes candidatas e o Jev escolhe; todos veem o corpo de todos. A mudança é lenta e em segundo plano: reavaliação a cada 45 ticks com pelo menos 20 feitos novos; no cliente o corpo escorre até os valores novos em cerca de 30 s e o comportamento é relatado em lotes de 3 s, sem esperar a rede.

- `go vet ./...` ok; `go test ./...` passa, exceto a falha antiga de `presentation.json`.
- Novos testes: 3 de aparência (o corpo segue como cada um joga e outros jogadores o veem; a escolha do Jev é revalidada; sem feitos novos não muda) e 3 de missões (caça paga evolução e reparo; missões de evolução; esquiva confirmada).
- `simulate -advisor jev -ticks 100 -players 3`: 30 decisões `appearance` resolvidas pelo Jev (~406 ms, confiança 0,65), antes de espaçar as reavaliações.
- Godot: 41 testes, 0 falhas (inclui: genes mudam o corpo; o corpo do motor aparece gradualmente, não estala; comportamento relatado em lote sem bloquear o quadro).
- Ponta a ponta com o Jev ligado (`e2e_engine.gd`): os 9 passos anteriores e mais o novo: o cliente relata ataques em segundo plano e o **Jev decide o corpo "Caçador"** (log do mundo: `resolve` de `appearance` com `provider: jev`).
- Capturas conferidas: quatro corpos distintos (caçador de espinhos, andarilho de cílios e cauda longa, erudito com halo e partículas violeta, banqueteiro grande com grânulos) e as marcas de cada gene (cílios, vesículas de toxina, mitocôndrias, grânulos, anel do núcleo, parede dupla, cauda blindada e longa).

## H2 — diferenciação em classes (22/10/2026)

**Conceito:** o jogador nasce como uma **esfera** indiferenciada (sem cauda) e cresce em dois passos: **progenitor** (mieloide ou linfoide) e **classe**, reinventando as clássicas com células reais do sistema imune: Macrófago (guerreiro, o Devorador), Neutrófilo (ladino, o Armadilheiro, que mantém a cauda), Dendrítica (bardo/explorador, a Cartógrafa), Linfócito B (mago, o Anticorpomante), T citotóxico (caçador, o Executor) e T auxiliar (clérigo, o Maestro das Citocinas). Cada classe tem 2 mutações próprias, que só ela encontra e que levam a forma mais longe (12 no total).

**Motor:** `core/lineage.go` (maturidade, níveis, decisão `lineage` pelo Jev, verbo `diferenciar`, tags `lineage`/`tier`, visão `lineage`), 8 linhagens e 12 mutações de classe no universo, instruções do Jev em `advisor/jev.go`.
- `go vet ./...` ok; `go test ./...` passa, exceto a falha antiga de `presentation.json`.
- 4 testes novos (`lineage_test.go`): nasce indiferenciada e a maturidade abre o 1º nível; a escolha do Jev é revalidada e o jogador vira aquilo; o 2º nível oferece só as classes do progenitor escolhido (mieloide: macrófago, neutrófilo, dendrítica); mutações de classe só aparecem para a classe certa.

**Cliente (Godot):** catálogo de linhagens com bônus de classe (ex.: macrófago +50% de membrana e -15% de velocidade; neutrófilo +30% de velocidade); formas procedurais por classe (`bio_cell_forms.gd`: pseudópodes, núcleo multilobulado, dendritos fractais, anticorpos em Y, agulha e grânulos, anéis de citocinas) que se transformam em segundos; painel de escolha da linhagem com a classe que o Jev destaca; mutação de classe amplia a forma (teia de DNA, árvore de dendritos, coroa de anticorpos...). 44 testes, 0 falhas.
- Capturas conferidas: as 9 formas (esfera, os 2 progenitores e as 6 classes) e as 6 com as duas mutações de classe. São silhuetas e apêndices claramente diferentes.
- Ponta a ponta com o Jev ligado: os passos anteriores e mais: a maturidade estoura, o motor oferece a linhagem, o **Jev escolhe (Mieloide) em decisão `lineage` com `provider: jev`**, o jogador diferencia e o corpo muda.

**Não feito nesta etapa:** habilidades ativas próprias de cada classe (hoje a classe muda forma, bônus passivos e mutações; o chicote, a toxina e o impulso continuam os mesmos; o neutrófilo bate com a cauda e as outras classes com um arco de choque). E o modo offline não diferencia (fica esfera): a diferenciação é decidida pelo motor.

## H3 — habilidades de classe com efeitos de partículas (22/10/2026)

**Conceito:** cada classe nasce com 1 habilidade ativa e adquire as outras 3 jogando: por missão (`prova-<classe>`), por feitos (`learn`) e pelo **despertar decidido pelo Jev** (decisão `ability`, a cada 40 ticks se os feitos cresceram 12). 24 habilidades em Q/F/C/V, cada uma com efeito próprio (partículas `CPUParticles2D` aditivas, anéis, feixe, sigilo de marca, zonas animadas).

**Motor:** `core/ability.go` (starter ao diferenciar, candidatas por classe, decisão `ability` revalidada, padrão por `fit`), `SkillDef` com `class/starter/offer/tags`, 6 missões e 24 habilidades no universo, instrução do Jev em `advisor/jev.go`.

**Cliente:** `bio_ability_catalog.gd` (dados), `bio_ability_runner.gd` (execução, custo/recarga pelo ator de domínio, sem alvo não gasta), `bio_ability_zone.gd`, `bio_ability_bolt.gd`, `bio_mark_glyph.gd`, `bio_pfx.gd`, `bio_targeting.gd`; estados de marca/guarda/pressa no `BioCombatant`; barra de habilidades no HUD.

**Executado:**
- `go test ./...` em `engine/`: todos passam, exceto `TestClientPresentationMatchesTheUniverse`, que já falhava antes (procura `clients/godot/data/presentation.json`, arquivo que não está no repositório; não relacionado). 4 testes novos em `ability_test.go`.
- Godot headless: 52 testes, 0 falhas, sem `SCRIPT ERROR` (8 novos em `test_abilities.gd`: catálogo, ids do motor, slots pela visão, engolir cura, marca amplifica 1,4x e sem alvo não gasta, armadilha explode após o atraso, anticorpo teleguiado acerta, muralha reduz dano a 30%).
- Captura com renderizador real (`tests/capture_abilities.gd`): as 24 habilidades conferidas visualmente (Apoptose exige alvo ferido, por desenho).
- Ponta a ponta contra o motor com Jev ligado: mieloide, classe (neutrófilo), nasceu com Rede de DNA, usou, o corpo foi decidido pelo Jev (Caçador) e uma segunda habilidade (NETose) foi adquirida jogando (~tick 40, recibo `ability:<jogador>:40` no log). Não verifiquei neste registro o `provider` dessa decisão de habilidade.

**Não feito:** aquisição por missão de classe não foi exercitada ao vivo (só em teste do motor); balanceamento dos números; masmorra e multijogador visíveis.

### Botão de reiniciar o mundo (22/10/2026)

`BioHud.press_restart` (duas pressões para confirmar) -> `BioWorld.restart_world` -> `BioEngineLink.reset_world` (`POST /v1/world/reset`, `confirm: new-world`) e zera genoma, classe, habilidades, aparência, vírions e nutrientes. Executado: Godot 54 testes, 0 falhas (2 novos); `tests/e2e_restart.gd` contra o motor com o Jev ligado: tick 369 -> 0, a célula reentrou e voltou sem habilidades nem classe (RESTART OK).

### Habilidades que usam o corpo (22/10/2026)

**O que mudou:** as habilidades e o ataque inicial deixaram de ser efeitos soltos e passaram a ser gestos do corpo. A membrana é **elástica** (`BioCellBody.elastic/swell`: mola com recuo, estica, passa do ponto e assenta, preservando o volume) e **brotam membros** dela (`BioLimb`, cadeia elástica com ponta; `BioLimbs` os gerencia). O estilo do membro é uma função pura (`domain/bio_limb_style.gd`) da **forma** (classe), do **visual procedural** do Jev (ferocidade dá farpas e ponta fina, agilidade alonga e afina, robustez engrossa, metabolismo põe grânulos, sociabilidade ramifica, mistério solta luz) e dos **genes** (agulha lítica, dendritos ramificados, anticorpos em Y...).

**Ataque inicial (chicote):** o recém-nascido projeta um pseudópode rombudo; mieloide, dois lóbulos alternados; macrófago, um braço largo em concha que varre; neutrófilo, a cauda; dendrítica, leque de dendritos finos; linfócito B, filamento com anticorpo Y; T citotóxico, lança rígida; T auxiliar, tentáculo macio com bulbo. O **arco do golpe também muda com a forma** (lança estreita, braço largo): `BioAttackExecutor.half_angle_source`.

**Habilidades:** engolir (braços em concha + corpo que se estica e engole), onda e plasmócito (corpo incha e projeta membros em todas as direções), perforina e golpe lítico (corpo vira lança; o golpe comprime como mola antes de lançar), anticorpos (brotam Y da membrana e saem da ponta, com coice), marcas (membros finos alcançam cada alvo), zonas (um membro estica até o ponto), muralha (corpo engrossa e membros blindados), canto (tentáculos balançando), chamado (bulbos brotam e viram sentinelas).

**Executado:** Godot 57 testes, 0 falhas (3 novos: o estilo segue a forma, os eixos mudam o membro, o corpo estica e assenta). Capturas com renderizador real: `tests/capture_body.gd` (chicote das 8 formas, sem e com visual feroz/ágil) e `tests/capture_abilities.gd` (as 24 habilidades); ajustei o brilho aditivo que estourava com muitos membros sobrepostos. Não medi desempenho com muitos jogadores nem testei em controle.

### Mutações: pool ampliado e ligado a cada classe (22/10/2026)

**O que mudou:** de 20 para **48 mutações**: 12 genéricas (4 novas: Citoesqueleto Elástico, Receptores de Quimiotaxia, Peroxissomos, Espinhos de Quitina) e **6 por classe** (36, 24 novas). Cada mutação de classe **remodela uma habilidade da própria classe** (um "perk": os números que a habilidade lê), tem uma troca (custo), e uma **marca visível** no corpo (órgão: orbes, anéis, espinhos, filamentos, cristais, crescentes, tentáculos, pulsos, vacúolos, cada um com cor e quantidade próprias). Exemplos: Vacúolo Digestivo faz o Lisossomo Ácido crescer 35%; Granzima B torna a Perforina mais letal contra feridos; Hipermutação Somática acrescenta 2 anticorpos à salva; Pirogênio amplia a Febre Dirigida.

**Como:** uma única tabela (`clients/hospedeiro/tools/gen_mutations.py`) gera o universo do motor (cartas com o efeito escrito) e o catálogo do cliente (`bio_gene_catalog.gd`), então os dois não divergem. Novos estatísticos gerais: poder, recarga, custo e alcance das habilidades. `BioGenome.tune` aplica os perks nos parâmetros da habilidade e `modify` leva dano/custo/recarga à definição validada pelo ator de domínio.

**Executado:** Godot 61 testes, 0 falhas (4 novos: seis por classe e só toca habilidades da própria classe, cada classe só encontra as suas, perks mudam a habilidade e o dano de domínio, o resumo nomeia a habilidade). Go: tudo passa exceto `TestClientPresentationMatchesTheUniverse` (já falhava, arquivo ausente); novo `TestEveryClassHasSixOwnMutationsThatNameTheirAbility`; `worldsim validate` ok. Capturas reais: cada classe com 3 mutações próprias e a carta de oferta (`tests/capture_marks.gd`). Não balanceei os números e a combinação de 3 genes iguais por classe ainda não foi testada em partida longa.

### Núcleo por classe, silhuetas marcantes e ascensão humanoide (22/10/2026)

**Núcleo:** deixou de ser um círculo igual para todos (`BioNucleusShapes`): esfera, redondo macio; mieloide, feijão; macrófago, rim grande; neutrófilo, três lóbulos ligados por fios; dendrítica, flor irregular; linfócito B, núcleo enorme e redondo com nucléolo brilhante; T citotóxico, hexágono compacto com ponto quente; T auxiliar, trevo de quatro folhas. O núcleo também é puxado para onde um membro brota.

**Silhuetas:** novos parâmetros de forma (`poly`, `poly_amp`, `oval`): neutrófilo alongado, dendrítica de 7 pontas, B perfeitamente redonda, T citotóxico hexagonal com 6 espinhos, T auxiliar quadrada arredondada.

**Ascensão (evolução máxima):** `BioGenome.ascension()` = parcela dos 3 espaços ocupada por mutações da própria classe (0 a 1). A própria membrana se **deforma numa única silhueta de fantasma** que sugere uma pessoa, sem adicionar braços nem pernas (`BioGhostForm`: soma de calombos no raio, por ângulo; um calombo para cima é a cabeça, outros alargam ombros e mangas, o pescoço e a cintura apertam e o corpo inferior escorre em barra ondulante ou rastro). Cresce de forma contínua com a ascensão, então a célula vai ficando mais humanoide a cada mutação de classe. O núcleo sobe para dentro da cabeça (com o formato do núcleo da classe), o corpo se inclina com o movimento e flutua. Cada classe curva a silhueta do seu jeito: macrófago, fantasma massudo de ombros imensos; neutrófilo, esguio inclinado com um rastro longo; dendrítica, esbelta com mangas de membrana caídas; linfócito B, cabeça enorme sobre uma túnica em sino; T citotóxico, elmo pontudo, ombros angulosos e afilamento; T auxiliar, cabeça redonda e túnica serena. Os lóbulos de pseudópode e as pontas das silhuetas antigas se dissolvem na figura. Reduzi os brilhos aditivos (núcleo, preenchimentos e lóbulos).

**Executado:** Godot 65 testes, 0 falhas (ascensão por parcela de mutações próprias; núcleos e silhuetas distintos; o fantasma cresce de forma gradual e continua sendo um corpo só). Capturas reais (`tests/capture_forms.gd`) de cada classe em quatro estágios de ascensão. Uma primeira versão com braços e pernas adicionados foi descartada por pedido do usuário. Não testei em movimento prolongado com as habilidades nem no controle.

### Efeitos únicos por habilidade e mutações refatoradas (23/10/2026)

**Ideias:** a chave do OpenRouter só cobre o Jev (402 em qualquer outro modelo), então as ideias de direção de arte para as 24 habilidades vieram de um subagente LLM, com a biologia real como inspiração. Cada habilidade ganhou uma assinatura própria, sem anel que expande nem explosão de pontos: fagocitose em pinça (macrófago), coroa de pseudópodes que deixa sulcos em espiral, poça ácida com favo de hexágonos e bolhas que estouram, placas de armadura sobre treliça de actina; rede de NET de dupla hélice com rungas, diapedese com fantasmas e faixa de gelo, cápsula que treme e floresce em ganchos de cromatina, nuvem de blobs que respira; bandeira MHC, leque de dendritos que se desenrola como samambaia, jardim de vesículas que vira micélio, mapa topográfico com setas; anticorpo em Y que gira com fio duplo e fecha em pinça, salva trançada, ouriço de mini-Y, fábrica de plasmócito (cisternas, roda de carroça, crescente de anticorpos); lança de perforina que deixa poros octogonais, corte lítico em crescente, apoptose com bolhas e corpos apoptóticos, cruz de lâminas sobre ECG; hexágonos de citocina que acoplam em receptores, pauta de notas, vaso linfático com sentinelas em losango, miragem de calor. Código: `BioSignature`, `BioAbilityZone`, `BioMarkGlyph` (4 tipos), `BioAbilityBolt`.

**Mutações:** deixaram de ser 3 espaços que se substituíam com marcas girando por cima umas das outras. Agora são **6 espaços** (o motor também: `slots: 6`) e cada mutação tem seu **bolso** num lugar fixo (grade 3x2 dentro do corpo), um glifo pequeno e legível dentro de um saquinho, igual para o mesmo gene. A lista no HUD mostra só os nomes; as cartas dizem "Sem espaço: reabsorve X" quando for trocar, nunca em silêncio. A forma final exige 4 mutações da própria classe (`ASCENSION_GENES`).

**Correções achadas no teste:** vários membros brotando juntos inflavam o corpo ao quíntuplo (somatório dos calombos): agora limitado a +50%.

**Executado:** Godot 68 testes, 0 falhas, incluindo `test_every_ability.gd`: as 24 habilidades rodam no mundo com alvos e cada uma tem seu efeito (dano, marca, execução, zona, cura, pressa) e nenhum nó de efeito sobra depois. Go: passa exceto o teste antigo de `presentation.json`. GIFs de todas as habilidades (`tests/capture_gifs.gd`). Não testei com controle nem com muitos jogadores.

**Limpeza visual (23/10/2026):** com mutações equipadas, o corpo mantém o interior limpo: os grânulos, vacúolos e a teia de DNA da própria forma não são desenhados (os bolsos já contam isso), o núcleo não cresce sobre os bolsos e os bolsos ficaram na parte baixa do corpo. Macrófago e neutrófilo deixaram de ficar carregados. Godot 68 testes, 0 falhas.

### H3.5 — a primeira masmorra: o Granuloma (23/10/2026)

**Motor:** `core/dungeon.go` (`DungeonDef`, execução por jogador, verbos `entrar-masmorra`, `sala-limpa`, `falhar-masmorra`, `abandonar-masmorra`, decisão **`dungeon`** com o Jev escolhendo o modificador, revalidada e com padrão no prazo, semente do motor, recompensas, cenário único do primeiro a fechar, espera para tentar de novo, visão `dungeon`), instrução do Jev em `advisor/jev.go`, universo com o granuloma (5 salas, 5 modificadores, 2 habilidades-título).

**Cliente:** `BioDungeonPlan` (puro: o que há em cada sala a partir da semente, do tipo da sala e do modificador), `BioDungeon` (câmara, salas, inimigos, fim), `BioBossSlam` (golpe em onda com aviso e bacilos invocados), `BioGate` (a entrada na corrente sanguínea), inimigos novos (`BioFactory.spawn_enemy`), texto de progresso no HUD.

**Executado:** Go: 5 testes novos (`dungeon_test.go`: precisa de maturidade e do lugar certo; o Jev escolhe e a resposta é revalidada; o padrão no prazo; cinco salas, recompensas e primeiro título único; queda, espera e desistência), todos passam; o restante passa exceto o teste antigo de `presentation.json`; `worldsim validate` ok. Godot: 74 testes, 0 falhas (6 novos: plano determinístico e modificadores, câmara sala a sala, o motor conduz a execução, modificadores mudam a execução, o golpe do chefe só acerta dentro do raio, morrer reporta a falha). **Ponta a ponta com o motor e o Jev ligado** (`tests/e2e_dungeon.gd`): amadurece, a entrada abre, entra, o modificador é escolhido (Em febre), as cinco salas abrem uma a uma confirmadas pelo motor, o chefe cai, a execução fecha e o motor dá o Selo e o título único. GIFs e capturas reais.

**Não feito:** a ruptura do granuloma se ninguém entrar; execução cooperativa em grupo (a semente já é compartilhável); entrada de quem está em outra região; quests e ofertas continuam aparecendo por cima da câmara; equilíbrio dos números dos inimigos e do chefe. O `provider` da decisão do modificador não foi verificado neste registro (o padrão `em-febre` foi o escolhido).

### Mutações como organelas que flutuam dentro da membrana (23/10/2026)

**O que mudou:** os bolsos fixos e as bolinhas deram lugar a **organelas de verdade**, desenhadas como em microscopia de fluorescência (preenchimento translúcido e contorno brilhante), de 14 tipos: mitocôndria (dupla membrana com cristas), Golgi (pilha de cisternas que brotam vesículas), retículo endoplasmático (folhas dobradas com ribossomos), microtúbulos (feixe de fitas onduladas com motores andando), centríolo (barril de nove tripletos e o parceiro em ângulo reto), vesículas (cacho de bolhas de tamanhos diferentes com reflexo), vacúolo (bolsa irregular com grãos), cristal proteico (facetado, com brilho que passa), túbulos (rede ramificada que balança), autofagossomo (dupla membrana envolvendo carga), gotas de lipídio (com anel e reflexo), ribossomos (contas no RNA mensageiro), lisossomo (grânulo denso com halo) e peroxissomo (oval com núcleo cristalino). Cada mutação ganhou a organela que combina com ela (cílios ágeis, o centríolo; mitocôndria ávida, a mitocôndria; plasmócito, o retículo; grânulos de perforina, o lisossomo...).

**Movimento:** cada organela **boia livre e sem rumo** (caminhada aleatória com arrasto), se afasta das outras e do núcleo, atrasa quando a célula leva um tranco, e **nunca sai da membrana**: o limite é duro e segue a forma (inclusive a silhueta de fantasma). Desenhadas com mistura normal, não aditiva, então não estouram em branco.

**Executado:** Godot 76 testes, 0 falhas (3 novos: todo gene tem organela conhecida e há 12+ tipos; as organelas derivam por conta própria mas nenhuma chega à membrana em 400 quadros nem após um tranco; o mesmo dentro da silhueta de fantasma). Atlas e GIFs reais (`tests/capture_organelles.gd`). Não medi custo com muitos jogadores.

### Menos luz e a entrada do granuloma clara (23/10/2026)

**Luz:** o brilho global (bloom) do mundo estava forte demais e lavava as formas em branco. Intensidade 1,8 -> 0,55, força 1,2 -> 0,8, bloom 0,25 -> 0,03 e limiar HDR 0,45 -> 1,0, e o brilho do portal do granuloma foi reduzido. As formas, os membros e os efeitos agora se leem pelo contorno e pela cor.

**Granuloma:** o "travou" era uma espera sem aviso: ao entrar, o motor esperava até 12 s (3 ticks) pela decisão do modificador e a tela não dizia nada. Agora a decisão tem prazo de **1 tick** (a entrada leva cerca de 2,6 s medidos com o Jev ligado) e há um aviso na tela ("Entrando no granuloma... o Jev escolhe o desafio desta vez"). Entrada clara: ao ficar elegível, uma linha no feed ("O Granuloma abriu para você: siga a seta... e aperte E"), uma seta na borda da tela com o nome e a distância quando está longe, e o portal com o rótulo GRANULOMA e "Aperte E para entrar" quando se chega perto (abaixo do portal, para não ficar escondido pelas ofertas). Jogando 30 s dentro dele com a luta automática: 60 quadros por segundo, pior quadro de 80 ms, sem travar.

### Granuloma: por que "não conseguia mover nem atacar" (23/10/2026)

Reproduzido com teclado e mouse reais (`tests/e2e_dungeon_input.gd`): a célula **se movia e atacava**, mas só andando ela morria em cerca de 8 s e, depois de morrer, ficava invisível e parada até apertar R, sem explicação. Ajustes: os inimigos esperam 3,5 s no início de cada sala (contagem "Prepare-se"), os primeiros são menos e mais lentos e batem mais fraco (cada inimigo tem um fator de dano), a febre drena menos, limpar a sala devolve 40% da membrana e todo o ATP, a legenda dos controles aparece na tela, e cair no granuloma mostra "Você caiu no granuloma, pressione R para voltar ao portal" e renasce no portal, não na medula. Teste novo: uma célula que só anda por 12 s na primeira sala continua viva. Godot 79 testes, 0 falhas.

### Balanceamento de habilidades e incrementos (23/10/2026)

Régua única (`BioBalance`), números afinados em `data/balance.json`, testes que seguram as faixas (`tests/test_balance.gd`) e um duelo prático (`tests/balance_duel.gd`). Detalhes em `Docs/Hospedeiro/Balance.md`. Antes, o valor por preço das habilidades ia de 0,75 a 3,98; depois, todas ficaram em ±18% da meta de sua classe, e as 48 mutações a cerca de 1 ponto da meta da raridade. No duelo, o tempo para limpar a mesma sala: 15,6 a 20,5 s entre as seis classes (antes 10,1 a 22,7 s). Godot 83 testes, 0 falhas; Go passa, exceto o teste antigo de `presentation.json`; `worldsim validate` ok. Os testes antigos que repetiam números de mutações à mão passaram a ler o catálogo.



## E0 — corpo como dados, mapa 10x (23/10/2026)

- Godot headless: 94 testes, 0 falhas (inclui `test_anatomy.gd`: determinismo, ~10x de área, membrana única fechada, vasos sinuosos dentro da membrana, fluxo e batimento, atlas persistente; e `test_body_world.gd`: streaming de regiões, paredes, descoberta no atlas e travessia medula→aorta pelos vasos).
- Travessia medula→aorta com renderizador real (`tests/capture_crossing.gd`): 40/40 waypoints, ~28 s; FPS médio 44,6, pior 25 antes da otimização. Depois (fluxo em grade de 3 amostras do batimento, membrana e alvéolos desenhados uma vez, partículas a meia taxa): médio 58,6, mínimo 55 (medula 60, vênula 60, endocárdio 57, artéria 59).
- `worldsim validate` do universo com as novas regiões: ok. `go test ./...`: só falha o já existente `TestClientPresentationMatchesTheUniverse`.


## E1 — corpo vivo (23/10/2026)

- Go: novo teste `TestHospedeiroLungInfectionBecomesFeverAndPasses` (900 ticks sem jogadores: infecção pulmonar, febre e fim da febre ocorrem; temperatura ≥ 38,0, pulso ≥ 85, oxigênio ≤ 70; toda visão traz 8 sinais vitais). `go vet` limpo; `go test ./...` só falha o já existente `TestClientPresentationMatchesTheUniverse`. `worldsim validate` ok.
- Godot headless: 97 testes, 0 falhas (novo `test_body_state.gd`: corpo saudável não pesa; febre + hipóxia + adrenalina + insulina viram modificadores; o mundo aplica o corpo à célula e ao pulso).
- Capturas: `Docs/Validation/e1/vitals_healthy.png` e `vitals_fever.png`.


## E2, parte 1 — exploração (23/10/2026)

- Go: `exploration_test.go` (3 testes): o pulmão recusa o `move` sem o gene e abre depois do nicho da vênula, com replay do log reproduzindo o `Digest`; nicho único só para o primeiro (o segundo recebe `nicho-vazio`, e jogador ou região errada é recusado); descoberta (`visitou`) e dicas só nas regiões conhecidas e vizinhas. `go vet` limpo; `go test ./...` só falha o já existente `TestClientPresentationMatchesTheUniverse`. `worldsim validate` ok.
- Godot headless: 101 testes, 0 falhas (`test_exploration.gd`: a membrana segura a célula e some com a chave; nichos só onde o motor sussurra e tocados uma vez; bússola leva ao nicho alcançável, nunca para o pulmão fechado; atlas aceita a memória do motor).
- Ponta a ponta com motor real (`tests/e2e_explore.gd`, renderizador real, motor `-advisor deterministic` na porta 8099): conecta, recebe nichos e a passagem fechada, acha o nicho do estroma e o da vênula, recebe `cilios-ageis` e `citoesqueleto-elastico`, a membrana do pulmão some, o motor aceita o move ao pulmão e o atlas o conhece. Capturas em `Docs/Validation/e2/e2e/`.


## E2, parte 2 — códice, segredos, adaptação e rota (23/10/2026)

- Go (`exploration_test.go`, +5 testes): o códice desbloqueia uma vez e as entradas trancadas não vazam texto; o nicho-segredo da medula só existe com o corpo dormindo (e é recusado fora do estado); a célula se adapta à região após `adaptAfter` ticks, uma vez; a decisão `rota` (padrão = lugar mais próximo; escolha atrás de passagem fechada é recusada; a escolha do consultor vira a rota e não muda ao achar outro nicho); sem resposta o prazo decide e o replay do log reproduz o `Digest`. `go vet` limpo; `go test ./...` só falha o já existente `TestClientPresentationMatchesTheUniverse`; `worldsim validate` ok.
- Godot headless: 104 testes (`test_exploration.gd` +3: rota do consultor lidera a bússola, painel do códice, adaptação só na região). Na primeira rodada falhou `test_abilities.gd::test_body_stretches_like_rubber_and_settles` (deformação medida 0,12); passou em 3 rodadas seguintes sem mudança de código: parece teste dependente de tempo, **não investigado**.
- Ponta a ponta com motor real (`tests/e2e_codex.gd`, motor `-advisor deterministic -tick 1s`, porta 8099): o códice chega com 13 entradas (1 aberta), visitar vênula e coração leva a 3, e a rota vem do motor (`recesso-do-atrio`). Captura: `Docs/Validation/e2/e2e/e2e_codex_panel.png`. **O consultor foi o determinístico**: a decisão `rota` com o Jev de verdade (chamada ao vivo) ainda não foi exercitada.


## Jev ao vivo na decisão `rota` (23/10/2026)

- Teste opt-in `TestLiveJevPointsTheCellToAPlace` (`JEV_LIVE=1`, chave via `JEV_ENV_FILE`): monta a decisão `rota` real, pergunta ao Jev, valida a escolha e confere que o motor a aceita. Antes o Jev respondia 402 (sem créditos); depois de recarregar os créditos: **3 opções, o Jev escolheu `recesso-do-atrio` (o padrão era `bolsa-da-venula`), modelo `typesafe/jev-1.13-20260917`, latência 473–522 ms (3 rodadas), custo US$ 0,00003 por chamada**, e o motor aceitou a rota.
- Ponta a ponta (`e2e_codex.gd`, motor `-advisor jev`, tick de 4 s): o log de comandos traz `resolve` com `"provider":"jev"` tanto para a `rota` (escolheu `nicho-estroma`) quanto para um acontecimento do mundo (`infeccao-pulmonar`, confiança 0,53), ou seja, as decisões foram do Jev e não do padrão.
- Pendente, anterior a esta mudança: `TestLiveJevDecidesRealWorldDecisions` (Valdoria) falha em `seguir-rastro ... rejected: requirements` (o roteiro do teste ficou defasado do universo); não tem relação com o Hospedeiro e não foi investigado.


## Jev como autor: dicas removidas e design procedural (23/10/2026)

- **Achado:** com a nota `[fit N]` nas opções, o Jev escolheu exatamente o padrão do motor em 100% das decisões de mutação e de linhagem (2 de 2 cada), isto é, só confirmava. Sem a nota, em 2 jogadores com vidas diferentes, 1 de 2 mutações e 1 de 4 missões passaram a divergir do padrão. A nota foi removida de mutação, linhagem, habilidade, aparência e missão.
- **Novo `design`** (traços núcleo, membrana, organelas, brilho, sabor dos efeitos), testes Go `design_test.go` (padrões diferentes para vidas diferentes; a escolha do consultor é revalidada, mantida e reproduzida no replay).
- **Ao vivo** (`TestLiveJevHospedeiroPlayerDecisions`, 2 jogadores, 20 rodadas): design 10 decisões, 5 diferentes do padrão, latência média 353 ms, US$ 0,0005 no total; evolução 2 (1 diferente), linhagem 2 (0), aparência 2 (0), missão 4 (1), rota 2 (1). Escolhas do lutador: núcleo estrela, membrana espinhosa, grânulos, brilho carmim, efeito chama; do andarilho: núcleo feijão, espinhosa, vacúolos, carmim, efeito orgânico (o Jev achou o andarilho espinhoso e carmim também, o que é discutível).
- Godot: 107 testes, 0 falhas (`test_design.gd`). Capturas: `Docs/Validation/design/designs_sheet.png` (cinco células com designs diferentes: corpo, habilidade e segunda habilidade). **Limitação:** o sabor dos efeitos (cor e forma dos membros) é pouco visível nas capturas de feixe; o corpo, bem visível.
- Linhagem e aparência seguem sem divergir do padrão no cenário testado (poucas opções e sinais fortes): ainda é preciso um cenário com vidas ambíguas.


## Jev: oferta composta, núcleo por partes e sensação dos efeitos (23/10/2026)

- **Oferta de mutações composta pelo Jev:** `evolution-slot`, uma vaga por vez, cada uma com o contexto do que já está na oferta. Na primeira versão as duas vagas eram perguntadas em paralelo e o Jev respondeu a mesma mutação nas duas (a repetição colapsava e uma vaga caía no padrão); passei a perguntar em sequência. Ao vivo (2 jogadores): 4 respostas de vaga, 2 diferentes do padrão, ofertas finais todas distintas (lutador: flagelo-calejado, vesícula-tóxica, espinhos-de-quitina; andarilho: membrana-espessa, receptores-de-quimiotaxia, núcleo-reativo). Testes Go: `TestAdvisorComposesTheWholeOffer` (uma vaga por vez, validada, sem repetir o que já foi escolhido, replay igual) e `TestComposedOfferCompletesByFitAtTheDeadline`. Custo: com o Jev fora do ar a oferta demora até 2 prazos (cerca de 24 s no tick de 4 s) em vez de 1.
- **Traços novos** (11 no total): núcleo composto (lobulação, recorte, nucléolo) e sensação dos efeitos (densidade, rastro, ritmo). Ao vivo: 22 decisões de design, 8 diferentes do padrão, 361 ms de média, US$ 0,0011 no total. **Achado negativo:** os dois jogadores receberam várias escolhas iguais (lobulação l7, nucléolo brilhante, recorte serrilhado, ritmo veloz, rastro curto, brilho carmim) e o Jev nunca escolheu o núcleo `composto`; as decisões saem ao mesmo tempo, então o aviso de "opções que os outros já usam" só ajuda a partir do segundo design de cada um.
- Godot: 109 testes, 0 falhas (o teste instável `test_body_stretches_like_rubber_and_settles` passou a amostrar por tempo e não por quadros: 3 rodadas limpas). `test_design.gd` confere que toda opção do universo tem desenho, que a sensação dos efeitos muda o número e a vida das partículas e que núcleos compostos diferentes têm contornos diferentes. Captura: `Docs/Validation/design/designs_sheet.png` (7 células; as duas últimas têm núcleo composto).


## Efeitos do design: correção e debug (23/10/2026)

- **Problema relatado:** os efeitos ficaram parecidos com os de antes. Causas medidas: (1) o design só nascia depois de ~20 atos e 45 ticks, então quase ninguém o via; (2) os efeitos das habilidades vêm sobretudo dos membros e de zonas próprias; o estilo só mudava um pouco a cor e a ponta dos membros, e as partículas do `BioPfx` quase não eram emitidas (contador: 0 a 2 por habilidade).
- **Correção:** a primeira versão do design sai cedo (6 atos, checagem a cada 5 ticks; novo teste Go `TestDesignFirstOneComesEarly`); o estilo agora muda a forma das partículas (chama sobe e tremula, cristal são lascas que giram, névoa é grande e lenta, elétrico são faíscas finas e rápidas, orgânico são gotas que incham), cada lançamento emite uma explosão e um anel no estilo da célula, as cores mudam com mais força, e `BioFx.burst` também segue o estilo.
- **Debug:** F3 painel, F4 troca o estilo, F5 sorteia um design, F6 volta ao motor, e o log `[design]` no console. Teste `test_design.gd` confere que o painel mostra o que está de fato em vigor. Folha de comparação dos cinco estilos e da base: `Docs/Validation/styles/styles_sheet.png`.
- **Limite:** os membros e as zonas de cada habilidade continuam com a forma própria (o estilo só os retinge e muda a ponta), então a diferença é clara nas partículas e no lançamento, não na silhueta do efeito inteiro. 110 testes Godot, 0 falhas.


## Efeitos físicos e desempenho em combate (23/10/2026)

- **Efeitos físicos** (queimadura, quebradiço, lentidão, cadeia, sifão): ver `Docs/Hospedeiro/JevDesign.md`. 117 testes Godot, 0 falhas; o teste pegou dois erros meus antes de entrar (o elétrico valia 130% do golpe simples, ajustado; e uma expectativa errada sobre o quebradiço).
- **Desempenho ("travado"):** `tests/perf_combat.gd` (macrófago contra 10 vírions, todas as habilidades a cada 0,33 s e o chicote; renderizador real). Antes: média 37,7 ms (26 fps), p95 49 ms. A causa era o desenho dos membros (hospedar os membros invisíveis tirava ~17 ms): um comando de desenho por quadrilátero e por segmento. Correções: uma fita por camada em uma única chamada (`canvas_item_add_triangle_array`), contorno em `draw_polyline_colors`, tabelas por ponto calculadas uma vez, nível de detalhe com muitos membros vivos (menos camadas; redesenho a cada 2 ou 3 quadros, alternado) e zonas a cada 2 quadros. Depois: média 23,0 ms (43 fps), p95 29 ms, p99 32 ms, com estilo chama 25 ms. Em jogo normal (travessia do corpo) segue 58 a 60 fps. **Ainda não chega a 60 fps no pior caso (spam de todas as habilidades contra 10 vírions)**; o resto do custo é o corpo de cada célula (64 pontos recalculados por quadro) e as partículas.


## O projétil desenhado pelo Jev (23/10/2026)

- **Problema relatado:** o estilo dos efeitos só soltava partículas (esporos) e quem fazia o dano continuava sendo o projétil, igual. **Correção:** o projétil passou a ser o objeto do design (`BioProjectileDesign`, `BioAbilityBolt`), com trajetória, calibre e impacto decididos pelo Jev (3 traços novos, 14 no total).
- Testes Godot (127, 0 falhas), `test_projectile.gd`: perfurante atravessa 3 inimigos com 100%, 75% e 56% do golpe; explosivo atinge quem está ao lado e não quem está longe; fragmentos nascem e acham outros sem bater no próprio alvo; grudento continua queimando depois do golpe; o calibre fino passa ao lado de um alvo que o grosso acerta; reta fica na linha e onda, espiral e arco a deixam; cada opção do universo tem significado; a régua de equilíbrio vale para todos os impactos.
- **Medição com corpos reais** (`capture_projectile.gd`, anticorpo contra 5 vírions de 400 de membrana, 0,9 s depois): base `[23,0,0,0,0]`, perfurante+reta+fino `[21,15,11,0,0]`, explosivo+arco+grosso `[16,9,0,0,0]`, fragmenta `[16,0,0,0,0]` (os fragmentos erraram nessa disposição), grudento `[20,0,0,0,0]` (a queimadura vem depois). Folha: `Docs/Validation/projectile/projectile_sheet.png`.
- **Jev ao vivo:** 56 decisões de design, 26 diferentes do padrão, 357 ms de média, US$ 0,0028 no total. Projéteis escolhidos: lutador trajetória espiral, calibre grosso, impacto perfurante; andarilho trajetória arco, calibre fino, impacto perfurante (os dois iguais no impacto).
- **Limites:** só `bolt` e `volley` usam o projétil desenhado; as outras habilidades (cones, zonas, golpes) não são projéteis e seguem só com o estilo dos efeitos. Os traços do projétil são pedidos a todas as células, mesmo às que não atiram.


## Sem esporos, risco e recompensa por trajetória e foco (23/10/2026)

- **Pedido:** tirar os esporos inúteis (ficam só o projétil e as consequências físicas) e fazer cada trajetória pagar pela dificuldade (a serpente, mais difícil de acertar que a teleguiada, precisa de uma vantagem), valendo também para as outras habilidades.
- **Removido:** a explosão e o anel de partículas do lançamento, o formato por estilo das partículas e os traços `densidade` e `rastro` (eram só partículas). `ritmo` passou a ser a velocidade do projétil.
- **Trajetórias** com dano, velocidade e alcance próprios (ver `JevDesign.md`); o teste exige dano x chance de acerto dentro de 12% entre as cinco, e mede que contra um alvo que se mexe a teleguiada acerta mais que a reta.
- **Foco** (traço novo, 13 traços no total): amplo, médio ou preciso para cones, estocadas, novas, investidas, zonas e devorar. `test_focus.gd`: a régua; a geometria muda e o catálogo não; numa nova real só a ampla alcança o inimigo distante e a precisa bate mais forte no próximo; o chicote e os projéteis ignoram o foco.
- 132 testes Godot, 0 falhas; Go só falha o antigo `TestClientPresentationMatchesTheUniverse`. Ao vivo (Jev, 2 jogadores): 52 decisões de design, 21 diferentes do padrão, 368 ms de média; os dois escolheram foco preciso, impacto perfurante e trajetória teleguiada (o Jev tende a repetir escolhas entre jogadores parecidos).


## Comportamento próprio por família de habilidade (23/10/2026)

- **Pedido:** o Jev escolher também um comportamento de cada família (cones que se fecham, zonas que migram), em vez de só largura, alcance e dano. Seis traços novos (`modo_cone`, `modo_nova`, `modo_estocada`, `modo_investida`, `modo_zona`, `modo_devorar`), 19 traços de design no total. Descrição e régua em `Docs/Hospedeiro/JevDesign.md`.
- 142 testes Godot, 0 falhas (`test_modes.gd`: cada modo vale 95% a 120% do golpe simples; o universo oferece exatamente os modos que o cliente conhece; cone que fecha puxa, que chicoteia bate duas vezes (0,7 + 0,5), nova de pulsos bate três vezes, a que repele joga o inimigo longe, arpão e suga puxam, investida dupla bate de novo, zona migrante anda 20 px ou mais em 1,2 s). Go só falha o antigo `TestClientPresentationMatchesTheUniverse`.
- **Ao vivo (Jev, 2 jogadores):** 76 decisões de design, 32 diferentes do padrão, 362 ms de média, US$ 0,0038. **Achado:** nos dois jogadores o Jev escolheu os modos mais elaborados (chicoteia, arpão, dupla, pulsos, migra) e só variou o devorar e a trajetória; ele tende a preferir o que parece mais interessante e a repetir entre jogadores parecidos. Vale medir com mais jogadores e talvez avisar no contexto quais modos os outros usam (já feito para os outros traços).


## Painel do Jev e menu de teste (23/10/2026)

- **Motor:** a visão do jogador ganhou `advisor` (`engine/core/advisor_view.go`): as decisões à espera e as últimas 60 tomadas para esse jogador, com provedor (jev, padrão do prazo...), modelo, latência, custo e confiança; só as decisões do próprio jogador. Teste Go `TestAdvisorViewShowsWhoAnsweredWhat`.
- **Cliente:** `BioJevPanel` (F2 + linha sempre visível) e `BioDebugMenu` (Esc, botões com mouse, cada um chama um método do mundo). 152 testes Godot, 0 falhas (`test_jev_debug.gd`: a linha, o painel, a fonte de cada traço, o menu e cada tipo de botão: lugares, salas do granuloma, classe com habilidades, vírions, vida cheia, invulnerável, design).
- **Ponta a ponta com Jev real** (`tests/e2e_jev.gd`, motor `-advisor jev`): 8 atos, e o painel mostrou **22 decisões, 22 pelo Jev, 394 ms de média, custo US$ 0,00087**, com todos os traços do design marcados "jev". Capturas em `Docs/Validation/jevdebug/`.
- **Bug achado pelo ponta a ponta e corrigido:** o motor manda `axes: null` até a célula ter uma variante, e o cliente quebrava ao ler (`apply_engine_look`); só aparecia online. Teste novo em `test_design.gd`. Também deixei de poluir o feed com o evento `design` e relaxei o limiar do teste instável da deformação elástica (o pico depende da taxa de quadros).

## E2 parte 3: chave de diapedese e missões de rastro (23/10/2026)

- **Motor:** `PassageDef.Lineages` (`engine/core/exploration.go`): a passagem abre com o gene **ou** com uma das linhagens; o universo valida a linhagem. A aorta (`aorta_ascendente`) agora exige macrófago, neutrófilo ou `citoesqueleto-elastico`. 7 missões `rastro-<nicho>` (doador Osteia, eligíveis só enquanto `rota` aponta para o nicho, meta: feito `nicho:<id>`), geradas por `clients/hospedeiro/tools/add_exploration_quests.py`.
- **Executado:** `go vet ./...` ok; `go test ./...` passa inteiro (inclui `TestHospedeiroDiapedesisOpensTheAorta`: célula comum recusada, macrófago e neutrófilo passam, dendrítica não, o gene abre; e `TestHospedeiroRouteQuestCompletesWhenTheNicheIsFound`). `worldsim validate` ok; `simulate -ticks 240 -players 3 -advisor deterministic`: sem travar. Godot headless: 152 testes, 0 falhas, sem `SCRIPT ERROR` (depois de regenerar `data/balance.json` e `data/gene_rarity.json`, que não estavam neste checkout).
- **Não testado:** ponta a ponta contra o motor com Jev ligado (o gate da aorta no cliente usa o mesmo caminho genérico das passagens, mas não rodei `e2e_explore.gd`); o texto do `hint` da aorta na tela.

## E3: o fígado (23/10/2026)

- **Motor (universo):** entidade `figado` (glicogênio, toxina), passagem `arteria_hepatica` (aorta→fígado), 2 spots, nicho único `cripta-de-kupffer` (peroxissomos), 2 sinais vitais, ações `guardar-glicogenio` e `filtrar-toxina` (adaptador, só no fígado), regras `figado-guarda`, `figado-libera` (glicose < 48), `toxina-sobe` e `figado-sobrecarregado` (toxina >= 80 inflama o corpo), missões `guardar-a-reserva` e `figado-limpo`, 3 entradas de códice. Gerado por `clients/hospedeiro/tools/add_liver.py`.
- **Cliente:** região no `BioAnatomy` (centro 268, 96; raio 40) e vaso da aorta; `BioToxin` e `BioToxinRules` (toxina custa 5 de membrana, ou dá 10 de ATP com peroxissomos); toxinas povoadas pelo streaming; nutriente absorvido no fígado dispara `glycogen_stored`; `BioHostSync` envia as duas ações; botão "Fígado" no menu de teste. O mapa passou de 10x para 12,5x (o teste de área foi alargado de 11,5x para 14x).
- **Executado:** `go vet ./...` ok; `go test ./...` passa; 3 testes novos em `engine/scenarios/liver_test.go` (verbos só dentro do fígado e só pelo adaptador; fígado repõe a glicose e toxina acumulada inflama, com replay idêntico do log; cripta única e missão `figado-limpo` concluída). `worldsim validate` ok; `simulate -ticks 200 -players 3 -advisor deterministic` e `-ticks 80 -players 2 -advisor jev`: sem travar (rota resolvida pelo Jev 3 vezes e 2 pelo prazo, ~340 ms). Godot headless: **157 testes, 0 falhas** (5 novos em `test_liver.gd`). Captura real conferida: `Docs/Validation/liver/figado.png` (toxinas verdes ao lado do nutriente âmbar).
- **Não testado:** ponta a ponta contra o motor ligado (não há `e2e_liver.gd`); a parede da membrana do fígado na tela (a captura está escura como as das outras regiões); balanceamento dos números (dano 5, ATP 10, ritmos das regras) pela régua do `Balance.md`; um teste do cliente (`test_the_test_buttons_spawn_clear_refill_and_protect`) falhou uma vez numa rodada e passou nas seguintes sem mudança minha: parece instável por tempo.

## E3: a masmorra do fígado, os Cordões Hepáticos (23/10/2026)

- **Motor (universo):** masmorra `cordoes-hepaticos` (região `figado`, maturidade 16 na época, 5 salas: sinusoides vigiados, cordão de hepatócitos, faixa de fibrose, foco tóxico, nódulo cirrótico), 5 modificadores, 2 deles condicionados ao estado do fígado (`toxinas-altas` com toxina >= 60, `glicogenio-cheio` com glicogênio >= 60, e `kupffer-aliadas` com toxina < 40), recompensa que limpa o fígado (toxina -35, glicogênio +20, inflamação -10), títulos `selo-do-figado` e `primeiro-filtro` (único). Gerado por `clients/hospedeiro/tools/add_liver_dungeon.py`. O motor já suportava várias masmorras: nenhuma mudança de código.
- **Cliente:** inimigos próprios no `BioDungeonPlan` (célula estrelada, hepatócito doente, gota de gordura, foco tóxico, o Nódulo), modificadores novos (`bile-acida`, `fibrose-ativa`, `toxinas-altas`, `glicogenio-cheio`, `kupffer-aliadas`), `hp_mult`, emissor e reforço por masmorra, `BioGate` com título e cores, segundo portão dentro do fígado e pontos de saída por masmorra (`BioDungeon.returns`), textos por masmorra. O granuloma não mudou.
- **Executado:** `go test -count=1 ./...` passa, com 3 testes novos em `liver_dungeon_test.go` (só dentro do fígado e para maduros; modificadores seguem o estado do fígado; limpar as 5 salas limpa o fígado, o primeiro título é único e o replay do log dá o mesmo mundo). Godot headless: **161 testes, 0 falhas** (4 novos em `test_liver_dungeon.gd`). **Ponta a ponta com motor real e Jev ligado** (`tests/e2e_liver_dungeon.gd`, motor na 8097): conecta, ganha a chave da aorta pelo nicho da vênula, anda vênula → coração → aorta → fígado, o portão abre, o Jev (o painel marcou 45 das 47 decisões pelo Jev, 568 ms) escolhe o modificador (`bile-acida`), as 5 salas constroem os inimigos certos e são limpas, o motor premia o selo e o título único. Repetido no novo ritmo, também passou. Capturas em `Docs/Validation/liver/` (sala 4 mostra os inimigos âmbar e o foco tóxico verde).
- **Não testado / limites:** a dificuldade real contra um jogador (comparei só o HP total por sala com o granuloma: salas 2 a 5 dentro de ±10%, a sala 1 foi reduzida de 4 para 3 estreladas); o `balance_duel` não cobre a masmorra do fígado; as janelas do Sistema (oferta de missão, escolha de linhagem) abrem por cima do combate na masmorra, o que atrapalha (já era assim no granuloma). O teste `test_the_test_buttons_spawn_clear_refill_and_protect` falhou em 3 de 12 rodadas completas sem que eu achasse a causa (sozinho, 6 repetições passam; em 3 rodadas seguidas com diagnóstico, passou): continua instável.

## Ritmo da evolução (23/10/2026)

- **Pedido:** o jogo estava frenético, evoluindo e ganhando pressão evolutiva depressa demais.
- **Mudança:** um só botão, `PACE = 3` em `clients/hospedeiro/tools/tune_pacing.py`. Limiar de pressão 10 → 30 (uma mutação a cada ~10 abates em vez de ~3, ou 30 nutrientes em vez de 10), faixas de maturidade das classes 14/40 → 42/120 (a primeira classe com ~21 abates em vez de 7), entrada do granuloma 14 → 42 e dos Cordões 16 → 48. As recompensas de missões e masmorras ficaram como estavam, então valem um terço do que valiam em relação à barra. O espelho offline do cliente (`BioMutationTracker.THRESHOLD`) foi a 30.
- **Testes:** o `fight(p, n)` do Go agora vale n abates "antigos" (multiplica por `pace`), então os testes continuam lendo igual; `go test -count=1 ./...` passa e Godot 161 testes, 0 falhas. Os e2e de masmorra passaram a confirmar 27 abates para ficar maduros.
- **Não medi** o ritmo com uma pessoa jogando, só a aritmética acima. O que ainda deixa o jogo acelerado e **não mexi**: densidade e reaparecimento de nutrientes e vírions, a frequência das ofertas de missão e das janelas do Sistema.

## Interface: janelas discretas, o Corpo e as builds (23/10/2026)

- **Pedido:** refatorar as janelas (ofertas de linhagem, classe, missão), mais discretas e profissionais; um sistema de builds em que o jogador edita e vê; missões podem chegar no meio do jogo, mas só fora de combate; UX mais polida no todo.
- **Motor (`engine/core/builds.go`, universo `evolution.builds: 3, rest: 10`):** o gene que sai dos espaços não se perde mais: é **silenciado** e fica na **biblioteca** (`Genome.Library`; nunca é oferecido de novo). Ações novas, todas intenção do jogador e validadas: `expressar` (gene da biblioteca; com os espaços cheios, `swap` diz qual expresso cede o lugar), `silenciar`, `salvar-build` e `aplicar-build` (3 espaços numerados). Não vale dentro de masmorra e o corpo precisa **descansar** `rest` ticks depois de cada troca (a vista traz `restLeft`). A vista de evolução ganhou `library`, `builds` e `restLeft`.
- **Cliente, peças puras:** `BioCombatState` (calma = 4 s sem ameaça), `BioBuildPreview` (o efeito de um conjunto de genes sobre cada atributo, melhor/pior), `BioBuildStore` (nome de cada build e ordem das habilidades, guardados na máquina).
- **Cliente, interface:** `BioUi` (uma paleta, uma escala de tipos, estilos), `BioThreatSensor` (inimigo que já notou a célula, golpe dado ou recebido, masmorra), `BioCallTray` (avisos pequenos no canto: nunca abrem janela sozinhos, apagam em combate e dizem "após o combate"), cartão de chamado compacto (`BioSystemPanel`), `BioMutationPanel` virou a faixa do canto (forma, pressão, um ponto por gene), `BioBodyPanel` (tecla **G**: FORMA, GENES com biblioteca e comparação antes → depois, HABILIDADES com troca de teclas, BUILDS salvar/aplicar/renomear). (Revisto no mesmo dia a pedido do usuário: **sem trava de combate**; o jogador escolhe quando abrir o Corpo. Ficaram só as travas do motor: masmorra e descanso. O sensor de combate foi removido.) Ofertas deixaram de abrir três cartões no meio da tela; 1/2/3/X só valem dentro do Corpo. Nenhum clique numa janela vira ataque. Códice (B) e Sinais vitais (Tab) no mesmo estilo; o códice agora rola com a roda. HUD: cantos limpos (título, conexão e região sem sobreposição; missão ativa à direita; o texto da missão e o da masmorra não se sobrepõem mais), rastro de mensagens que some sozinho.
- **Executado:** `go vet`, `gofmt` e `go test -count=1 ./...` passam, com 3 testes novos em `engine/scenarios/builds_test.go` (biblioteca nunca reoferece; troca com validação e descanso; builds salvas e aplicadas com replay igual). `worldsim validate` ok e `worldsim simulate -advisor deterministic -ticks 200` roda sem travar. Godot headless: **172 testes, 0 falhas** depois de remover a trava de combate (14 novos em `test_body_panel.gd`: estado de combate, prévia, armazenamento, avisos em combate, chamado que espera, sensor, janela do Corpo, trava por combate/masmorra/descanso, troca com prévia, builds, troca de teclas). **Ponta a ponta com motor real e Jev ligado** (`tests/e2e_body.gd`, motor na 8097, tick 500 ms): 7 genes escolhidos pela janela do Corpo (com 2 diferenciações no caminho), o mais antigo vai para a biblioteca, build 1 salva, troca de gene confirmada pelo motor, o corpo descansa (`O corpo ainda se acomoda`), e aplicar a build 1 devolve o conjunto antigo.
- **Capturas** (renderer real) em `Docs/Validation/ui/`: HUD calmo, HUD em combate (dois avisos esperando), cartão de chamado, as quatro abas do Corpo, sinais vitais, e do e2e a prévia de troca e a build aplicada.
- **Não testado / limites:** a calma é uma regra (4 s sem ameaça) e não foi ajustada com uma pessoa jogando; o tempo de descanso (10 ticks, ~40 s em produção) é um chute; a janela foi desenhada para 1600×900 e 1152×648 (cabe, rola), não para telas menores ou touch; sem teclado para trocar de aba (só mouse); as builds guardam os genes no motor e a ordem das habilidades só nesta máquina; a Atlas (M), o menu de teste (Esc) e o painel do Jev (F2) não foram redesenhados; a janela do Corpo mostra a prévia de atributos, não a de habilidades (perks) de cada gene.

## Masmorras procedurais e monstros próprios de cada órgão (23/10/2026)

- **Pedido:** os monstros estavam parecidos entre as regiões e as masmorras eram sempre iguais; elas precisam ser procedurais.
- **Motor:** `DungeonDef` ganhou `pool` e `depth`. A masmorra procedural abre com a primeira sala de `rooms`, fecha com a última (o chefe) e, entre as duas, a corrida **sorteia da semente** de `depth[0]` a `depth[1]` salas do `pool`, sem repetir (gerador próprio, `composeRooms`; o motor não depende da sequência de uma biblioteca). A corrida guarda as salas sorteadas (`Delve.Rooms`), a vista as mostra e quem divide a semente divide a masmorra. `Available[].Rooms` passou a ser o tamanho máximo. Granuloma e Cordões agora têm 4 salas no pool cada além das antigas (emboscada, pilares, ninho, poça) e 5 ou 6 salas por corrida.
- **Cliente, salas:** `BioDungeonPlan` gera cada sala da semente e do índice: **forma** (redonda, oval ou lobada, girada), tamanho, **pilares** com colisão, **poças** que ferem a membrana (`BioHazardPool`), e o elenco. Cada masmorra tem o seu elenco (`family`): granuloma (linfócito, bacilo, macrófago, célula gigante, bacilo cuspidor, colônia de bacilos, emissor, o Bacilo) e cordões (célula estrelada, hepatócito doente, gota de gordura, esporo de bile, plasmódio que se divide, cisto, foco tóxico, o Nódulo). Receitas por tipo de sala: guarda, parede, núcleo, chefe, **emboscada** (todos de uma vez, 1,2 s de espera), **pilares** (cuspidores atrás das colunas), **ninho** (gera mais até ser quebrado), **poças**.
- **Cliente, comportamentos novos:** `BioRangedBrain` (mantém distância, brilha e cospe um projétil que fere: `ENEMY_SPIT`), `BioNestBrain` (parado, gera cria até um limite), divisão ao morrer (plasmódio → 2 merozoítos), silhuetas por definição (comprimento dos espinhos, giro).
- **Cliente, bestiário** (`BioBestiary`): fora das masmorras cada órgão tem os seus bichos, contados com os vírions (transmitem pressão, a febre os desacelera): coração, **trombo** (lento, pesado); pulmão, **pneumococos** (em par, rápidos) e **esporo fúngico** (cuspidor); aorta, **placa de ateroma** (duro, com cacos) e **êmbolo** (investida longa, girando); fígado, **plasmódio** (divide) e **esporo de bile** (cuspidor). A vênula continua só com vírions e a medula sem monstros.
- **Executado:** `go vet`/`gofmt`/`go test -count=1 ./...` passam (novo `TestDungeonsAreProceduralPerRun`: 10 corridas por masmorra, extremos fixos, nada repete, várias sequências e 2 tamanhos). Godot headless 182 testes, 0 falhas em duas rodadas seguidas (11 novos em `test_procedural.gd`: mesma semente igual, outra diferente, personagem de cada sala, elenco próprio por masmorra, tudo dentro de qualquer formato, pilares e poças e dano, ninho gera e para, divisor, cuspidor fere, bestiário por órgão). Uma rodada anterior reprovou `test_body_stretches_like_rubber_and_settles` (0,0779), passou nas duas seguintes: teste sensível ao tempo, causa não investigada. **Ponta a ponta com motor real e Jev** (`e2e_liver_dungeon.gd`): a corrida sorteou 5 salas (guarda, parede, pilares, emboscada, chefe), cada uma construiu os inimigos certos, e o motor premiou. Capturas em `Docs/Validation/rooms/`.
- **Não testado / limites:** o equilíbrio das salas novas (a emboscada e os cuspidores podem estar duros demais ou fáceis demais, nenhuma jogada real); os bichos de cada órgão têm só a aparência por cor, tamanho e espinhos (nenhum modelo próprio); a dificuldade do chefe não mudou; nenhum bicho selvagem foi para a medula.

## E3: baço, intestino e rim (23/10/2026)

- **Pedido:** seguir para os próximos órgãos, com monstros característicos e masmorras procedurais.
- **Motor (`clients/hospedeiro/tools/add_organs.py`, idempotente):** três regiões (`baco`, `intestino`, `rim`), cada uma com artéria a partir da aorta, 2 lugares, um **nicho único** (genes `nucleo-reativo`, `enzima-voraz`, `membrana-espessa`), um vital (hemácias velhas, microbiota, ureia), 2 verbos, regras, 2 missões da Osteia, 3 verbetes e uma **masmorra procedural** (Centro Germinativo, Criptas Profundas, Néfrons; maturidade 54, 60 e 66; 6 salas de pool, 3 a 4 por corrida, 5 modificadores cada, 2 deles ligados ao estado do órgão; selo e título único). **Cadeias entre órgãos:** o ferro que o baço recicla vira reserva na medula; o intestino despeja nutrientes **e toxinas** no fígado; a toxina que o fígado não filtra vira ureia no rim; rim sobrecarregado sobe a pressão da artéria e inflama o corpo. A veia porta ficou só no texto da regra: um anel fechado de vasos deixava um buraco na membrana do corpo.
- **Cliente:** regiões no corpo (`BioAnatomy`, mapa e menu de teste), motes que flutuam e são o verbo do órgão (`BioMote`: hemácia velha, bactéria boa, cristal de ureia), mortes no baço e no intestino e nutriente no rim contam como feito (`organ_deed`, enviado ao motor), 3 portões novos (tabela `ORGAN_GATES`), 29 bichos novos entre selvagens e das masmorras (cada masmorra com elenco, cores de parede e chefe próprios: o Clone, a Tênia, o Cálculo), 15 modificadores com regra.
- **Executado:** `go vet`, `gofmt` e `go test -count=1 ./...` passam (novos em `organs_test.go`: verbos só no órgão e só pelo servidor de jogo, cadeias entre órgãos com replay igual, nichos únicos e missões que fecham, as 3 masmorras de ponta a ponta com selo e título único, 8 corridas diferentes por masmorra, modificadores que seguem o estado do órgão). `worldsim validate` ok. Godot headless: **189 testes, 0 falhas** (7 novos em `test_organs.gd`; a área do corpo agora é 21,6x o mapa antigo e o teste aceita até 26x). O teste do elástico da membrana, que falhou duas vezes por depender da velocidade dos quadros, passou a andar com passos fixos. **Ponta a ponta com motor real e Jev** (`tests/e2e_organs.gd`, motor na 8097): o mote move o vital do órgão no motor (hemácias 48→46, microbiota 47→51, ureia 24→22) e as três masmorras são sorteadas, construídas, limpas e premiadas (corridas de 6 salas, modificadores `hipermutacao`, `disbiose-ativa` e `cristalizacao` escolhidos pelo Jev). Capturas em `Docs/Validation/rooms/`.
- **Não testado / limites:** equilíbrio de tudo (nenhuma partida real; o aumento de ureia no rim leva cerca de 700 ticks sem ninguém filtrar, o do fígado cerca de 250); a aparência dos bichos é por cor, tamanho e espinhos; o vital novo aumentou a lista dos sinais vitais (13); linfonodos como lugar separado e a veia porta como vaso não foram feitos; a migração entre órgãos não foi medida com jogador.

## Quatro classes novas (23/10/2026)

- **Pedido:** mais 4 classes únicas.
- **Classes:** Mastócito (o Alarmista) e Eosinófilo (o Caça-Colossos), da linhagem mieloide; Célula NK (o Assassino Natural) e Linfócito T regulador (o Pacificador), da linfoide. Cada uma tem 1 habilidade inicial e 3 a despertar (uma por aprendizado, uma pela prova, as outras pelo Jev), 6 mutações de classe com trade-off, corpo, núcleo, membros e figura erguida próprios, e uma missão de prova. Agora a oferta de classe mostra 5 opções para quem é mieloide (e 5 para quem é linfoide, com os 3 originais mais 2).
- **(Superado pela seção seguinte: as 16 habilidades foram refeitas e estas mecânicas saíram.)** **Mecânicas novas, não só números:** `melt` (o golpe tira uma fração da vida do alvo, com teto: o colosso paga mais que o miúdo), `chain_strike` (salta de inimigo em inimigo), `barrier` (`BioClot`: um arco de coágulos sólidos por alguns segundos), `weaken` (o inimigo atingido golpeia com menos força: em `mark`, `mark_all` e zona), zona `calm` e `edema` com desenho próprio, nuvem que persegue (`drift`), a onda de grânulos do mastócito com visual próprio. O `BioBalance` ganhou o valor de cada um e a ferramenta de ajuste os conhece; as 16 habilidades e as 24 mutações foram ajustadas com `balance_tune.gd` e ficaram dentro da faixa.
- **Dados:** `clients/hospedeiro/tools/add_classes.py` (universo: linhagens, habilidades, provas) e `gen_mutations.py` (genes, dos dois lados).
- **Defeito achado e corrigido:** a prova do T citotóxico pedia 12 abates, e uma célula chega à classe com 60 ou mais; como uma meta já cumprida nunca é oferecida, a missão não aparecia. Subiu para 120.
- **Executado:** `go vet`, `gofmt` e `go test -count=1 ./...` passam (novos: as 4 classes nascem com a sua habilidade e só a sua; cada prova fecha com o seu feito e dá a habilidade; 6 mutações por classe). `worldsim validate` ok. Godot headless: **199 testes, 0 falhas** (10 novos em `test_new_classes.gd`: cada classe com 4 habilidades, 6 genes e corpo, núcleo e membros próprios; os 4 corpos desenham; o derretimento cobra muito mais de um colosso que de um miúdo; a cadeia atinge cada inimigo uma vez; o muro sobe e se desfaz; o enfraquecimento reduz o dano de quem é atingido, por marca e por zona; a explosão de grânulos, o edema e o leque; e um teste que lê o universo e confere que toda habilidade, linhagem e mutação do motor existe no cliente com a mesma classe). Capturas em `Docs/Validation/classes/` (cada classe, simples e erguida, e cada habilidade lançada).
- **Não testado / limites:** o equilíbrio real em combate (só o modelo de valor e o duelo-base; o `balance_duel` não cobre as classes novas); o Jev nunca escolheu essas classes ao vivo (nenhum e2e com o motor real e as 5 opções); o visual é por forma, cor e acessórios (sem modelos); a oferta de 5 classes no Corpo funciona por clique ou pelas teclas 1 a 5 ou por clique.

## Habilidades das classes novas, refeitas do zero (23/10/2026)

- **Pedido:** as 16 habilidades das quatro classes novas repetiam efeitos que o jogo já tinha (cones, zonas, marcas, novas). Nenhuma podia ter a mesma mecânica de outra, nem das 24 antigas.
- **O que mudou:** cada habilidade é agora um verbo que não existia. **Mastócito:** `mines` (uma mina por passo, que explode por proximidade e em corrente), `sticky` (bomba com pavio colada ao inimigo, com pilhas), `cascade` (cada morte explode, e a explosão que mata faz a próxima), `overload` (a célula sangra a membrana, cresce o raio, a mesma tecla solta; o dano é feito da vida gasta e nunca mata a célula). **Eosinófilo:** `tether` (corda que puxa e corrói uma fração da vida do alvo), `crystal` (o inimigo para e **guarda** os golpes, e tudo sai em explosão), `grow` (cada morte faz crescer), `roll` (bola que quica, `move_and_collide` com `bounce`). **Célula NK:** `blink` (aparece atrás do alvo, golpe nas costas), `prey` (cada golpe na presa devolve recarga; a morte devolve tudo), `cloak` (os inimigos perdem a célula, o primeiro golpe é a emboscada), `recall` (âncora e volta no tempo, com cura do que se perdeu). **T regulador:** `sleep` (dorme até ser ferido, o golpe que acorda bate mais forte), `link` (a ferida de um é repartida com os outros), `decoy` (isco de si que os inimigos perseguem), `pull` (singularidade: puxa e depois colapsa).
- **Arquitetura:** os estados novos vivem em `BioCombatant` (sono, cristal, camuflagem, caça, elo, crescimento, cascata) e os cérebros dos inimigos os respeitam (`is_stunned`, `is_hidden`; `retarget` para o isco). O que cada classe faz fica num `BioKit` por classe (`BioKitMast/Eos/Nk/Treg`), com `find` (quem é alvo, antes de pagar: sem alvo não custa nada), `cast` e `repress` (a mesma tecla termina o que o kit segura). Saíram `melt`, `chain_strike`, `barrier`, `weaken`, as zonas `edema`/`calm` e `BioClot`, que nenhuma habilidade usava mais.
- **Equilíbrio:** `BioBalance` ganhou o valor de cada tipo novo e a ferramenta de ajuste os conhece; as 16 habilidades e as 24 mutações foram reajustadas (`balance_tune.gd`, abilities e depois genes, `gen_mutations.py` aplicando). Duas mutações (`peroxidase_concentrada`, `memoria_de_presa`) não alcançavam a meta da raridade e ficaram como puro ganho: ganharam perks em mais parâmetros. Três mutações mudaram de nome (`salto_em_cadeia` virou `memoria_de_presa`, `citotoxicidade_natural` virou `fita_de_retorno`).
- **Universo:** `add_classes.py` apaga as habilidades antigas das quatro classes e escreve as novas; as provas dão agora Histamina Instável, Cristal de Charcot-Leyden, Predar e Sinapse Imunológica.
- **Executado:** `go vet` e `go test ./...` passam (os testes de habilidade inicial e de prova foram atualizados); `worldsim validate` ok e `worldsim simulate -ticks 200 -advisor deterministic` sem travar. Godot headless: **218 testes, 0 falhas** (`test_new_classes.gd` reescrito, 29 testes: cada uma das 16 habilidades é **jogada** e o seu efeito conferido: trilha de minas que só nasce andando e que explode em corrente, bomba que empilha e explode pelo valor das pilhas, a fila de mortes da cascata, a anafilaxia que gasta membrana e solta com a mesma tecla e nunca mata, a corda que puxa e o colosso que paga mais que o miúdo, o cristal que guarda os golpes e fere o vizinho, o crescimento, a bola, o golpe nas costas, o salto curto sem alvo, a caça que devolve recargas, a emboscada, a âncora, o sono, o elo que não ecoa de volta e não existe com um inimigo só, o isco que atrai e devolve, a singularidade). Um teste confere que as 16 são de 16 tipos diferentes e nenhum é dos antigos, e que cada uma traz os números que o seu tipo lê. Capturas em `Docs/Validation/classes/` (cada habilidade no meio do trabalho; renderer real).
- **Não testado / limites:** o equilíbrio em combate real (só o modelo de valor; o `balance_duel` ainda não cobre as classes novas); **nenhuma partida com o Jev escolhendo essas classes** (sem e2e com o motor); a Anafilaxia, a Rolagem e a Âncora dependem de sensação (tempo de sangria, controle da bola, demora da volta) e foram ajustadas só no papel; o isco só atrai inimigos que já têm cérebro de perseguição ou de tiro (ninhos e inimigos parados não mudam); o sono dos grandes (vida ≥ 300) vale 40 % do tempo, número escolhido sem teste com chefes reais.
