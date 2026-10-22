# Autoria de universos

Um universo é um único JSON validado por `core.Compile` (decodificação estrita: campo desconhecido é erro). Valide com:

```bash
cd engine && go run ./cmd/worldsim validate ../universes/valdoria/universe.json
```

## Blocos

| Bloco | Conteúdo |
|---|---|
| `kinds`, `predicates` | Vocabulário. Todo fato usa um predicado declarado |
| `playerKind`, `player` | Tipo e modelo de entidade criados em `join` (com `region` inicial, se houver lugares) |
| `regionKinds` | Tipos cujas entidades são lugares. Entidades podem ter `region` |
| `perceivers` | Tipos que recebem crenças quando um evento `reveals` um fato |
| `entities`, `facts`, `beliefs` | Estado inicial |
| `schedules` | Regras disparadas em ticks absolutos (eventos iniciais do mundo) |
| `rules` | Dinâmica autônoma: `every`, `forEach`, `when`, `effects` |
| `actions` | O que pode ser feito, por quem (`player`, `adapter`, `agent`), com `params`, `requires`, `effects` |
| `agents` | NPCs: objetivos com `priority`, `when`, `action`, `args`, `cooldown` |
| `arcs` | Histórias: `start` e `beats` com `unique`, `opens`, `goal`, `claim`, `rival`, `next`, `advanceWhen` |
| `quests` | Modelos de oportunidade: `giver` (NPC que chama, literal ou parâmetro), `eligible`, `params` (`where` com `$it`), `goal`, `rewards`, opcionalmente `arc`/`beat` e `region` (raro: só quando a missão só faz sentido naquele lugar) |
| `happenings`, `director` | Acontecimentos opcionais (`when`, `effects`, `cooldown`) e o ritmo do diretor (`every`, `allowNone`). O Jev escolhe qual ocorre |
| `limits` | `maxActiveQuests`, `decisionTimeout`, `declineCooldown`, `offerExpiry`, `maxEvents`, `allowAbandon`, `questGap` |
| `acquaintance` | predicado "S conhece O" (ex.: `met`). Com ele, missão com `giver` só é oferecida a quem o giver acredita conhecer. O motor cria essa crença quando um jogador age numa região (todos os perceptores ali testemunham); incluí-lo em `gossip.predicates` faz a fama correr por boato. Missões sem `giver` não são afetadas |
| ação `title` | rótulo curto da ação para menus (aceita `{param}`); sem ele, o id vira o rótulo |
| `tickSeconds` | duração de um tick para a qual o universo foi calibrado; o `serve` usa como padrão (o `-tick` explícito vence). O núcleo só conta ticks |

Campos de missão para a janela do sistema e missões vivas: `rank`, `objective`, `reward`, `penalty` (texto renderizado), `stages` (`id`, `when`, `title`, `desc`, `objective`, `rank`, `goal`, `effects`; só avançam, o primeiro que valer entra), `fail`, `failEffects`, `timeLimit` (ticks após aceitar), `onDecline`. Em capítulos: `contender` define quem, mesmo sem a missão, vira rival.

Mente do mundo: `tags` em ações e missões; `intensity` em acontecimentos; `director.peak`, `calm`, `decay`; `gossip` (`every`, `kinds`, `predicates`, `texts` com `{from}` e `{s}`); efeito `relate` e condição `rel`; `chance` (`seed`, `permille`) e `time` (`from`, `to`) com `dayLength`. Para raridade, um efeito `if` grava um sinal durável e a missão oculta depende do sinal.

Habilidades: `skills` (`id`, `name`, `desc`, `rarity` em comum/incomum/rara/epica/lendaria/absurda, `learn` opcional); condição `{"has": {"skill"}}`; contagem `{"deeds": {"action", "op", "v"}}` (ids de ação e também `move`, `rumor`, `decline`, `quest`); efeito `{"op": "grant", "v": "skill"}`. **Sorte nunca vai em `learn`** (o validador recusa): a descoberta é reavaliada o tempo todo e a chance se acumularia; use `grant` com `if` e `chance` dentro do efeito de uma ação. Habilidades raras ou melhores viram evento público `fame`; épicas e lendárias melhoram a relação com os NPCs do lugar.

Condições de lugar: `{"in": {"e": "$self", "region": "floresta"}}` e `{"near": {"a": "$self", "b": "poco"}}` (mesmo lugar, ou dentro de `b` quando `b` é um lugar). Efeito `relocate`: `{"op": "relocate", "e": "$self", "to": "reator"}`.

## O que o validador recusa

Predicado, tipo ou entidade desconhecidos; variável não ligada; operador de efeito desconhecido; nó de condição com dois operadores; ação de jogador usada por agente; argumentos de objetivo faltando ou sobrando; missão apontando para capítulo inexistente; ciclo em arco; capítulo inalcançável; capítulo único com `advanceWhen`; limites inválidos.

## Boas práticas aprendidas nos testes

- **Elegibilidade de cenários deve usar memória durável** (fato privado como `noticed`), não uma crença passageira que pode mudar antes de a oferta chegar.
- **Sintomas podem voltar enquanto a causa existir** (regra `ressurgir`), para a história não travar quando alguém resolve só o sintoma.
- **Limite ações repetíveis** (`relics < 1`, `infamy < 1`), porque servidores e robôs podem reenviá-las.
- **Capítulos compartilhados devem avançar por uma condição coletiva** (`selo.forest >= 3`), não por um estado que já pode ser verdadeiro.
- **Missões avulsas precisam continuar fazendo sentido:** quando a `eligible` deixa de valer para uma missão ativa (a caravana partiu, o poço está limpo), ela vira `obsolete` e libera a vaga. Escreva `eligible` como "isso ainda faz sentido", não só como "pode começar".
- **Acontecimentos devem criar algo a fazer** (uma missão, um estado temporário com regra de fim agendada), senão o Jev escolhe entre opções sem consequência.
- **Coerência, não distância:** não limite ofertas por proximidade. Escreva a `eligible` a partir da situação e do conhecimento, e escolha um `giver` que faça sentido (quem pediria aquilo). Use lugar nas **ações** (seguir o rastro exige estar na floresta), não nas ofertas.
- Objetivos de NPC devem usar `knows`. Assim o NPC age pelo que sabe e o mundo fica coerente com a informação de cada um.

## Lugares, rotinas e conversas ouvidas

- **`spots`**: lugares nomeados dentro de uma região (`{id, region, name}`: o poço, a forja). O motor nunca posiciona nada; o cliente mapeia cada spot a coordenadas.
- **`routines`**: onde cada NPC está a cada hora (`slots` com `from`/`to`, que podem cruzar a meia-noite, mais `region`, `spot` e `doing`). `overrides` com `when` vencem os slots (a curandeira não sai do poço com a vila muito doente; Nino se esconde em casa se sabe de lobos). A cada tick o motor põe o NPC no lugar do dia. A visão mostra `spot` e `doing` de cada pessoa, nunca o porquê.
- **`chatter`** (+ `chatterEvery`, padrão 3): conversas que se ouvem. Só acontecem com todos os falantes no spot e `when` valendo (`$self` é o primeiro falante), então **o que se diz segue o que eles acreditam**. Uma por spot a cada rodada, em rodízio determinístico. `hear` roda para cada jogador na região (`$self` = ouvinte, `$speaker` = primeiro falante); o efeito `observe` aceita `source: "communication"` e `to` (quem disse) para o jogador formar crenças pelo que ouviu.
- **`discovered`** (predicado privado do jogador, afirmado ao entrar numa região) e **`onJoin`** (efeitos ao criar o personagem).

## Chegada (F2)

- **`limits.firstOfferAfterDeed`**: nenhuma oferta antes de o jogador fazer algo (qualquer ação do universo; mover, boato e o ciclo de missões não contam). O recém-chegado também é um estranho para o Sistema.
- **`join` com `region`**: o servidor de jogo diz onde o recém-chegado aparece (Valdoria: a estrada, na carroça de Lia).
- **Falas por conhecimento:** a ação `conversar` ramifica pela etiqueta `voice` do NPC (`tag: {"voice": "orin"}`) e por `knows {who: $npc, p: met, s: $npc, o: $self}`: uma fala para estranhos e outra para quem já foi visto.

## Saber (F3): sinais e reações

- **`signs`**: `{id, region, spot, title, look, text, when, perceive, examine}`. Existe enquanto `when` vale (`$self` é o observador); só quem satisfaz `perceive` o vê. `look` é o que se vê de longe, `text` o que o exame revela, `examine` são efeitos (`observe` para formar crença por observação, ou `assert` privado para um indício). Um vestígio **mostra o efeito, nunca a causa**: o validador não deixa dois com o mesmo id, exige região e spot coerentes e valida as condições e efeitos.
- **`reactions`**: como as pessoas respondem quando o jogador lhes conta uma crença (`p`, `s` opcional, `who` opcional): `told` (novidade: passam a acreditar), `known` (já sabiam), `stale` (já não é verdade: não aceitam) e `effects` (com `$self` = quem contou, `$npc` = quem ouviu). Só crenças com reação aparecem como opção de contar.
- Os ids `examinar` e `contar` são do motor e não podem ser ações do universo.

## Lá fora (F4)

- **`signs[].farFrom`**: regiões de onde o vestígio ainda se vê como marco (uma torre, uma coluna de fumaça, um brilho noturno). De lá ele aparece na visão com `far: true` e não pode ser examinado.
- **Tocha:** um fato privado confirmado pelo servidor de jogo (`acender-tocha`, origem `adapter`) com regra agendada para apagar. Vestígios podem exigi-lo em `perceive` (a corrente de ar na galeria escura).
- **Leitura progressiva:** o `perceive` de um vestígio pode depender de indícios anteriores, e os efeitos `if` do exame mudam o que se entende conforme o que o jogador já carrega.

## Surpresa e permanência (F5)

- **`visibleMarks`**: predicados que se mostram em quem os carrega (marca, bênção). O fato continua privado, mas quem vê a pessoa recebe `others[].marks`.
- **Acontecimentos visíveis:** um vestígio (`signs`) com `when` ligado ao fato do acontecimento e, se quiser, `farFrom` para ser marco de longe; o cliente monta a cena enquanto ele durar e a remove ao fim.
- **Raros:** uma regra periódica com `chance` e fato agendado para se apagar (estrela cadente) dá vestígios raros e curtos; o exame pode conceder uma habilidade rara com `grant`.
