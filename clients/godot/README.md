# Cliente Godot do World Simulation Engine

Spike de um cliente **3D com câmera isométrica fixa** (ortogonal, -35,264° / 45°) em Godot 4.7. Não contém regras do mundo: envia intenções (`player`), apresenta a `view` do observador e usa `join`/`move` como `adapter` (em desenvolvimento o próprio cliente faz o papel do servidor de jogo; antes de expor em rede isso precisa vir de autenticação).

| Peça | Uso |
|---|---|
| `scripts/world_client.gd` | Contrato HTTP v1: `join`, `move`, `act`, `accept`, `decline`, consulta periódica de `GET /v1/views/{id}` |
| `scripts/actor.gd` | Personagem Quaternius (corpo + outfit) com as animações da Universal Animation Library: mesmo esqueleto de 65 ossos, sem retargeting |
| `scripts/enemy.gd` | Inimigos (bandido, corrompido) como dados + IA simples: parado, perseguir, atacar, recuar; reação a golpe, morte, barra de vida |
| `scripts/main.gd` | Vila, estrada, floresta, câmera, clique para mover/falar/atacar, combo, esquiva, HUD, NPCs e ameaças vindos do motor, teste automático |
| `shaders/toon_post.gdshader` | Pós-processo: faixas de luz suaves e contorno fino só nas silhuetas (profundidade), sem linhas nas normal maps |
| `tools/fetch_assets.py` | Copia os pacotes CC0 do Quaternius para `assets/` (ignorado pelo git) |
| `tools/measure.gd` | Mede o tamanho das peças modulares |

## Rodar

1. Baixar os pacotes em quaternius.com (Medieval Village MegaKit, Stylized Nature MegaKit, Fantasy Props MegaKit, Universal Base Characters, Modular Character Outfits Fantasy, Universal Animation Library 1 e 2) e rodar `python tools/fetch_assets.py [pasta-dos-pacotes]`.
2. Subir o motor: `cd engine && go run ./cmd/worldsim serve -universe ../universes/valdoria/universe.json -data ../data -tick 1s -advisor deterministic`.
3. `Godot --path clients/godot` (a primeira abertura importa os assets; antes disso rode `Godot --headless --path clients/godot --import` uma vez para registrar os `class_name`).

Argumentos do jogo (depois de `--`): `--server=URL`, `--player=ID`, `--name=Nome`. Controles: clique mover/falar, clique no inimigo atacar, `E` falar com o mais próximo, `Espaço`/`Q` golpe (combo de 3), `R` rolar (esquiva com invulnerabilidade curta), `Y`/`N` aceitar/recusar a missão oferecida. `--nopost` desliga o estilo; `--threat=estrada,vila` força um acampamento (só desenvolvimento).

## Combate e o motor

O combate (vida, dano, IA) é papel do servidor de jogo; neste spike o cliente faz esse papel. O motor só ouve resultados confirmados: os bandidos aparecem na região `estrada` quando o mundo emite o evento público `bandits` (somem em `bandits-left`) e as criaturas corrompidas na vila com `wolves`/`wolves-left`. Ao cair o último inimigo do grupo, o cliente reporta `enfrentar-bandidos` ou `cacar-lobos` como `adapter`, e o motor aceita ou recusa conforme a verdade do mundo.

## Teste automático

```bash
Godot --path clients/godot --resolution 1280x720 -- --autotest --player=gd-1 --server=http://127.0.0.1:8095 --out=clients/godot/.shots
```

Entra no mundo, fala com Orin, aceita a missão oferecida, vai à estrada, luta contra o grupo de bandidos e grava capturas em `--out`. A saída `AUTOTEST {...}` resume o resultado. Precisa de janela (não funciona com `--headless`, que não renderiza).

## Limites conhecidos

- **Navegador:** o Godot exporta para web, mas o `guard` do servidor recusa qualquer requisição com `Origin` (403). Exige proxy ou ajuste do `guard`, o que depende da autenticação (adiada). Os export templates (1,28 GB) não foram baixados.
- A atualização é por consulta (1 s); o `HTTPRequest` não lê SSE. Trocar por `HTTPClient` quando precisar de stream.
- Casas são blocos sólidos (não dá para entrar); sem pathfinding (linha reta, desiste ao bater em parede, inimigos também).
- Árvores altas podem esconder personagens na câmera fixa; só a estrada e o acampamento têm corredor livre. Falta transparência de oclusores.
- Sem modelo de lobo ou javali: as "criaturas corrompidas" da vila usam o corpo humano com animação de zumbi. `cacar-javali` e lobos de verdade pedem outro pacote de criaturas.
- O combate é local, sem sincronização entre jogadores.
