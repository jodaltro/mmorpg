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

**Ascensão (evolução máxima):** `BioGenome.ascension()` = parcela dos 3 espaços ocupada por mutações da própria classe (0 a 1). A partir de 2 de 3 o corpo começa a se erguer; com 3 de 3 vira uma figura levemente humanoide (`BioHumanoid`): a membrana vira tronco mais alto, **o núcleo sobe e vira a cabeça (com o formato do núcleo da classe)**, e crescem braços, pernas ou túnica e equipamento próprio: macrófago, brutamontes de ombros imensos e punhos; neutrófilo, corredor esguio com cachecol de membrana; dendrítica, figura de túnica com coroa e véu de dendritos; linfócito B, mago de túnica com asas de anticorpos; T citotóxico, guerreiro de elmo com lança; T auxiliar, curandeiro com auréola e orbes. Anda, balança e vira conforme o movimento; a hitbox lógica continua circular. Perder as mutações de classe faz o corpo voltar.

**Executado:** Godot 64 testes, 0 falhas (3 novos: ascensão por parcela de mutações próprias, núcleos e corpos distintos, o corpo se ergue e volta). Capturas reais (`tests/capture_forms.gd`) de cada forma em repouso e na ascensão máxima; limpei o excesso de apêndices radiais quando a figura se ergue. Não testei em movimento prolongado com as habilidades (os membros brotam da membrana do tronco) nem no controle.

