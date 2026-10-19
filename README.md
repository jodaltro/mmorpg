# Mmorpg — World Simulation Engine

Motor de mundo vivo para MMORPG, **agnóstico à interface**. O mundo tem uma história própria que avança com o que os jogadores fazem, continua vivo sem ninguém conectado e mostra a cada pessoa um mundo diferente, conforme o que ela fez e sabe. Qualquer cliente — Unity, Unreal, Godot, 2D, 3D, web ou bot — conversa com o mesmo contrato HTTP.

Inspiração de design: *Shangri-La Frontier* e *Overgeared*. Cenários únicos que só uma pessoa conclui, uma história fixa do mundo que muda de rumo conforme quem a avança, e continuações próprias para todos os outros.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `engine/core` | Núcleo puro e determinístico (só biblioteca padrão): entidades, fatos, crenças com procedência, regras, agentes NPC, histórias, missões, decisões |
| `engine/universe` | Carregamento estrito de universos JSON |
| `engine/advisor` | Conselheiro assíncrono: determinístico ou **Jev** (OpenRouter Decisions) |
| `engine/sim` | Runtime: relógio do mundo, log de comandos, despacho assíncrono ao conselheiro |
| `engine/store` | Log de comandos (arquivo JSONL com fsync; memória para testes) |
| `engine/api` | Contrato HTTP v1 + stream SSE por observador |
| `engine/cmd/worldsim` | CLI: `validate`, `simulate`, `serve` |
| `engine/scenarios` | Testes de ponta a ponta sobre os universos reais |
| `universes/valdoria` | Fantasia: *A Maldição do Selo* |
| `universes/orbital` | Ficção científica: *O Sinal de Próxima* (prova de que o núcleo é genérico) |
| `Docs/` | Visão, arquitetura, contrato, autoria e validação |

## Uso rápido

Requer Go 1.23+ (validado com 1.27.2).

```bash
cd engine && go test ./...
```

```bash
cd engine && go run ./cmd/worldsim simulate -universe ../universes/valdoria/universe.json -ticks 240 -players 4
```

```bash
cd engine && go run ./cmd/worldsim serve -universe ../universes/valdoria/universe.json -data ../data -tick 1s -advisor deterministic
```

Com o Jev: copie `engine/.env.example` para `engine/.env`, preencha `OPENROUTER_API_KEY` e use `-advisor jev`. Sem chave ou com o Jev lento/fora do ar, o mundo segue com escolhas determinísticas.

Documentação: [Visão](Docs/GameVision.md) · [Arquitetura](Docs/Architecture.md) · [Contrato API v1](Docs/Contracts/ApiV1.md) · [Autoria de universos](Docs/Universes.md) · [Validação](Docs/Validation/Engine.md).

O projeto Unity 2D/3D anterior foi removido; está recuperável no branch `archive/unity-2026-10-19` e nas tags `archive/valdoria-2d-2026-10-19` e `checkpoint/pre-worldsim-2026-10-19`.
