# Contrato HTTP v1

Todos os corpos são JSON com `"version": 1`. Campos desconhecidos são recusados (400). Requisições com cabeçalho `Origin` (navegador cross-origin) recebem 403. Corpo máximo: 16 KiB.

| Método e rota | Uso |
|---|---|
| `GET /v1/health` | `{version, status, universe, tick, revision}` |
| `GET /v1/chronicle?limit=N` | Face pública: eventos públicos e capítulos concluídos de cada arco |
| `GET /v1/views/{id}?limit=N` | O que `{id}` pode ver: a própria entidade, outras entidades (nome/tipo), fatos privados, crenças, missões, eventos visíveis e a história (incluindo o capítulo que ele persegue) |
| `GET /v1/stream/{id}` | SSE: primeiro `event: view` (visão completa), depois `event: delta` a cada mudança, só com eventos visíveis a `{id}` |
| `POST /v1/commands` | Envia um comando (abaixo) |

## Comando

```json
{"version": 1, "requestId": "c-123", "origin": "player", "kind": "act", "actor": "p1", "action": "contar-veneno", "args": {"npc": "mira"}}
```

| Campo | Regras |
|---|---|
| `requestId` | Único por comando (`[A-Za-z0-9-_.:]`, até 128). Repetir = no-op com `duplicate: true` |
| `origin` | `player` (intenção do jogador) ou `adapter` (servidor de jogo confirmando um acontecimento) |
| `kind` | `join`, `move`, `act`, `accept`, `decline`, `abandon` |
| `actor` | Personagem que age (ou que entra, em `join`) |
| `name` | Nome exibido (`join`) |
| `region` | Lugar em que o servidor de jogo viu o personagem entrar (`move`, origem `adapter`) |
| `action`, `args` | Ação do universo e seus parâmetros (`act`) |
| `quest` | Chave da missão (`accept`/`decline`/`abandon`) |
| `expectedRevision` | Opcional: recusa (409) se o mundo mudou |

Respostas: 200 `{version, revision, tick, duplicate, events}` com os eventos visíveis ao ator; 400 contrato inválido; 409 recusado pelas regras (`rejected: requirements`, `rejected: action`...); 503 log indisponível.

`tick` e `resolve` são internos e não podem ser enviados pela API. `abandon` é recusado (409) quando o universo exige concluir a missão aceita.

## Oferta de missão no stream

```json
{"kind": "quest-offered", "actor": "mira", "holder": "p1", "text": "Os aldeoes estao adoecendo",
 "data": {"quest": "investigar-poco|p1", "giver": "mira", "region": "floresta"}}
```

`actor`/`giver` é o NPC que chama; `region` é onde o jogador está naquele momento. A distância não importa: o cliente decide como o NPC alcança o jogador. Os detalhes completos ficam em `GET /v1/views/{id}` → `quests`.

## Integração por engine

- **Cliente** (Unity, Unreal, Godot, web): envia intenções `player`, lê `views/{id}` e escuta `stream/{id}`. Não guarda regras nem decide consequências.
- **Servidor de jogo** (autoridade do combate em tempo real): envia `adapter` quando algo é confirmado, por exemplo `{"origin":"adapter","kind":"act","actor":"p1","action":"recuperar-reliquia"}` depois que o guardião morre no servidor.
- O motor nunca espera o cliente nem o Jev. A latência do Jev não afeta o combate, que nem passa pelo motor.
