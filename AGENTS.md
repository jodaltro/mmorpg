# Mmorpg — instruções para agentes

## Direção vigente (19/10/2026)

O projeto foi refeito a partir do zero como **World Simulation Engine**: um motor de mundo vivo para MMORPG, **agnóstico à interface** (Unity, Unreal, Godot, 2D, 3D, web). Inspiração: *Shangri-La Frontier* e *Overgeared*: história fixa do mundo, cenários únicos que só um jogador conclui, continuações dinâmicas para os demais, missões pessoais e NPCs que agem pelo que sabem. Leitura obrigatória antes de mudar regras: `Docs/GameVision.md` e `Docs/Architecture.md`.

O usuário autorizou **refatoração destrutiva**: pode remover, reescrever e simplificar qualquer parte para chegar à melhor arquitetura, sem compatibilidade com versões anteriores. O projeto Unity 2D/3D, sprites, arte e o backend antigo foram removidos; estão recuperáveis no branch `archive/unity-2026-10-19` e nas tags `archive/valdoria-2d-2026-10-19` e `checkpoint/pre-worldsim-2026-10-19`.

## Repositório

- `jodaltro/mmorpg`, branch de trabalho **`main`** (a padrão da API é `master`: sempre especificar `main`).
- Antes de começar: conferir o worktree e rodar `git pull --ff-only origin main`.
- Ao concluir: commit e push das alterações pertinentes para `main`, informando o SHA. Havendo impedimento, informar sem alegar sucesso.

## Arquitetura (resumo)

- `engine/core`: **só biblioteca padrão**, puro e determinístico (`Step(state, command)`). Nada de rede, banco, engine gráfica, combate ou gênero. O teste `TestCoreHasNoInfrastructureImports` garante isso.
- Regras específicas de um jogo ficam **no universo JSON** (`universes/<id>/universe.json`), validado por `core.Compile`. Não codificar conteúdo no motor.
- **A verdade do mundo é separada das crenças.** Objetivos de NPC usam `knows`; a autoridade valida contra a verdade.
- **Jev é consultivo e assíncrono:** escolhe entre opções já validadas, a resposta é revalidada e, no prazo, vale o padrão determinístico. Nunca colocar chamada de IA dentro do lock ou do `Step`.
- Clientes enviam **intenções** (`player`); o servidor de jogo envia **acontecimentos confirmados** (`adapter`). Nunca aceitar dano, HP ou inventário declarados pelo cliente.
- O log de comandos é a fonte da verdade; o replay precisa reproduzir o `Digest`. Mudança que quebre o determinismo é defeito.

## Engenharia

- Go 1.23+ (validado com 1.27.2 em `D:\tools\go\bin`; pode não estar no PATH). Rodar `gofmt -l .`, `go vet ./...` e `go test ./...` em `engine/` antes de commitar.
- Todo comportamento novo do motor precisa de teste em `engine/scenarios` (sobre universos reais) ou no pacote correspondente.
- **Registrar só testes realmente executados**, em `Docs/Validation/`. Nunca declarar como aprovado o que não rodou.
- Universo novo ou alterado: `worldsim validate` e um `worldsim simulate` para conferir que a história não trava.
- Preferir contratos pequenos e versionados. Mudança incompatível no contrato HTTP exige nova versão (`/v2`).

## Segurança e segredos

- Nunca versionar segredos, `.env`, logs de mundo (`data/`), executáveis ou caches. A chave do Jev fica em `engine/.env` (ignorado) ou na variável `OPENROUTER_API_KEY`.
- **Chamadas ao Jev estão liberadas** (decisão do usuário em 19/10/2026: o Jev é um dos corações do sistema e precisa ser validado de verdade). Os testes automáticos usam `httptest`; os ao vivo rodam com `JEV_LIVE=1` ou `simulate -advisor jev`. Registrar latência, custo e taxa de resolução no prazo em `Docs/Validation/`.
- **Autenticação e publicação online ficam para depois**, por decisão do usuário. Não priorizar agora.
- O `serve` de desenvolvimento só escuta em loopback, porque a origem ainda vem no corpo. Antes de expor em rede: autenticação que derive `player`/`adapter` da credencial.
- Segredos e materiais do projeto antigo estão fora do repositório, em `D:\unity\Mmorpg-archive-2026-10-19` (inclui `secrets/`). Não apagar sem pedido do usuário.
- Respeitar licenças de assets e bases de engine; não redistribuir conteúdo com licença restritiva neste repositório público.

## Ambiente

- Disco D: com pouco espaço livre; evitar caches grandes. Unreal não está instalada (exige 40–70 GB+).
- Shell: Git Bash e PowerShell 5.1. Heredocs muito longos podem falhar no Bash; dividir em blocos.
