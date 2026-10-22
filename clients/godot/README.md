# Cliente Godot do World Simulation Engine

Spike de um cliente **3D com câmera isométrica fixa** (ortogonal, -35,264° / 45°) em Godot 4.7. Não contém regras do mundo: envia intenções (`player`), apresenta a `view` do observador e usa `join`/`move` como `adapter` (em desenvolvimento o próprio cliente faz o papel do servidor de jogo; antes de expor em rede isso precisa vir de autenticação).

| Peça | Uso |
|---|---|
| `scripts/world_client.gd` | Contrato HTTP v1: `join`, `move`, `act`, `accept`, `decline`, consulta periódica de `GET /v1/views/{id}` |
| `scripts/actor.gd` | Personagem Quaternius (corpo + outfit) com as animações da Universal Animation Library: mesmo esqueleto de 65 ossos, sem retargeting |
| `scripts/main.gd` | Vila, floresta, câmera, clique para mover/falar, golpe com faíscas, HUD, NPCs que nascem da `view`, teste automático |
| `tools/fetch_assets.py` | Copia os pacotes CC0 do Quaternius para `assets/` (ignorado pelo git) |
| `tools/measure.gd` | Mede o tamanho das peças modulares |

## Rodar

1. Baixar os pacotes em quaternius.com (Medieval Village MegaKit, Stylized Nature MegaKit, Fantasy Props MegaKit, Universal Base Characters, Modular Character Outfits Fantasy, Universal Animation Library 1 e 2) e rodar `python tools/fetch_assets.py [pasta-dos-pacotes]`.
2. Subir o motor: `cd engine && go run ./cmd/worldsim serve -universe ../universes/valdoria/universe.json -data ../data -tick 1s -advisor deterministic`.
3. `Godot --path clients/godot` (a primeira abertura importa os assets; antes disso rode `Godot --headless --path clients/godot --import` uma vez para registrar os `class_name`).

Argumentos do jogo (depois de `--`): `--server=URL`, `--player=ID`, `--name=Nome`. Controles: clique mover/falar, `E` falar com o mais próximo, `Espaço`/`Q` golpe, `R` rolar, `Y`/`N` aceitar/recusar a missão oferecida.

## Teste automático

```bash
Godot --path clients/godot --resolution 1280x720 -- --autotest --player=gd-1 --server=http://127.0.0.1:8095 --out=clients/godot/.shots
```

Entra no mundo, fala com Orin e Brom, aceita a missão oferecida, golpeia, vai à floresta e grava capturas em `--out`. A saída `AUTOTEST {...}` resume o resultado. Precisa de janela (não funciona com `--headless`, que não renderiza).

## Limites conhecidos

- **Navegador:** o Godot exporta para web, mas o `guard` do servidor recusa qualquer requisição com `Origin` (403). Exige proxy ou ajuste do `guard`, o que depende da autenticação (adiada). Os export templates (1,28 GB) não foram baixados.
- A atualização é por consulta (1 s); o `HTTPRequest` não lê SSE. Trocar por `HTTPClient` quando precisar de stream.
- Casas são blocos sólidos (não dá para entrar); sem pathfinding (linha reta, desiste ao bater em parede); sem inimigos; sem estilização (outline/toon).
