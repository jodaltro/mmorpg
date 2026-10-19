# Autoria de universos

Um universo é um único JSON validado por `core.Compile` (decodificação estrita: campo desconhecido é erro). Valide com:

```bash
cd engine && go run ./cmd/worldsim validate ../universes/valdoria/universe.json
```

## Blocos

| Bloco | Conteúdo |
|---|---|
| `kinds`, `predicates` | Vocabulário. Todo fato usa um predicado declarado |
| `playerKind`, `player` | Tipo e modelo de entidade criados em `join` |
| `perceivers` | Tipos que recebem crenças quando um evento `reveals` um fato |
| `entities`, `facts`, `beliefs` | Estado inicial |
| `schedules` | Regras disparadas em ticks absolutos (eventos iniciais do mundo) |
| `rules` | Dinâmica autônoma: `every`, `forEach`, `when`, `effects` |
| `actions` | O que pode ser feito, por quem (`player`, `adapter`, `agent`), com `params`, `requires`, `effects` |
| `agents` | NPCs: objetivos com `priority`, `when`, `action`, `args`, `cooldown` |
| `arcs` | Histórias: `start` e `beats` com `unique`, `opens`, `goal`, `claim`, `rival`, `next`, `advanceWhen` |
| `quests` | Modelos de oportunidade: `eligible`, `params` (`where` com `$it`), `goal`, `rewards`, opcionalmente `arc`/`beat` |
| `happenings`, `director` | Acontecimentos opcionais (`when`, `effects`, `cooldown`) e o ritmo do diretor (`every`, `allowNone`). O Jev escolhe qual ocorre |
| `limits` | `maxActiveQuests`, `decisionTimeout`, `declineCooldown`, `offerExpiry`, `maxEvents` |

## O que o validador recusa

Predicado, tipo ou entidade desconhecidos; variável não ligada; operador de efeito desconhecido; nó de condição com dois operadores; ação de jogador usada por agente; argumentos de objetivo faltando ou sobrando; missão apontando para capítulo inexistente; ciclo em arco; capítulo inalcançável; capítulo único com `advanceWhen`; limites inválidos.

## Boas práticas aprendidas nos testes

- **Elegibilidade de cenários deve usar memória durável** (fato privado como `noticed`), não uma crença passageira que pode mudar antes de a oferta chegar.
- **Sintomas podem voltar enquanto a causa existir** (regra `ressurgir`), para a história não travar quando alguém resolve só o sintoma.
- **Limite ações repetíveis** (`relics < 1`, `infamy < 1`), porque servidores e robôs podem reenviá-las.
- **Capítulos compartilhados devem avançar por uma condição coletiva** (`selo.forest >= 3`), não por um estado que já pode ser verdadeiro.
- **Missões avulsas precisam continuar fazendo sentido:** quando a `eligible` deixa de valer para uma missão ativa (a caravana partiu, o poço está limpo), ela vira `obsolete` e libera a vaga. Escreva `eligible` como "isso ainda faz sentido", não só como "pode começar".
- **Acontecimentos devem criar algo a fazer** (uma missão, um estado temporário com regra de fim agendada), senão o Jev escolhe entre opções sem consequência.
- Objetivos de NPC devem usar `knows`. Assim o NPC age pelo que sabe e o mundo fica coerente com a informação de cada um.
