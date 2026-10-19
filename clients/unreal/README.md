# Cliente Unreal do World Simulation Engine

`WorldSim/` é um plugin de runtime (C++) que conecta qualquer projeto Unreal 5 ao motor pelo contrato HTTP v1. Ele não contém regras do mundo: envia intenções (`player`) e acontecimentos confirmados (`adapter`), e apresenta o que o motor diz que o jogador pode ver.

| Peça | Uso |
|---|---|
| `UWorldSimSubsystem` | Entra no mundo, consulta a visão do jogador a cada `PollInterval`, dispara `OnQuestOffered`, `OnQuestChanged`, `OnWorldEvent` e mostra mensagens na tela |
| `AWorldSimRegionVolume` | Ao entrar, informa a região (`move`) |
| `AWorldSimOccurrenceVolume` | Ao entrar, informa uma ocorrência confirmada (ex.: `seguir-rastro`) |
| `UWorldSimDefeatReporter` | Num inimigo: ao ser destruído, informa a derrota (ex.: `cacar-lobos`) |
| Console | `ws.join`, `ws.move <região>`, `ws.act <ação> [k=v]`, `ws.occur <ação>`, `ws.accept`, `ws.decline`, `ws.status` |

Configuração: Project Settings > Plugins > WorldSim (`ServerUrl`, `PlayerId`, `PlayerName`, `bAutoJoin`, `PollInterval`, `bOnScreenMessages`).

O projeto de demonstração fica fora do repositório (conteúdo de template da Epic não é redistribuído aqui) e recebe este plugin por junction em `Plugins/WorldSim`.
