# Cliente Godot do World Simulation Engine

Spike de um cliente **3D com câmera isométrica fixa** (ortogonal, -35,264° / 45°) em Godot 4.7. Não contém regras do mundo: envia intenções (`player`), apresenta a `view` do observador e usa `join`/`move` como `adapter` (em desenvolvimento o próprio cliente faz o papel do servidor de jogo; antes de expor em rede isso precisa vir de autenticação).

| Peça | Uso |
|---|---|
| `scripts/world_client.gd` | Contrato HTTP v1: `join`, `move`, `act`, `accept`, `decline`, consulta de `GET /v1/views/{id}` e `GET /v1/affordances/{id}` |
| `scripts/places.gd` | Mina, ruínas, toca, poço e selo; pontos de interação (veio, escombros, ervas, salão...) e a animação de cada ação |
| `scripts/actor.gd` | Personagem Quaternius (corpo + outfit) com as animações da Universal Animation Library: mesmo esqueleto de 65 ossos, sem retargeting |
| `scripts/hud.gd` | Interface: estado e vida, minimapa, rastreador de missões, cartão de oferta (aceitar/recusar/depois), diário (`J`), avisos de missão e habilidade, log que se apaga sozinho, dica de interação |
| `scripts/enemy.gd` | Inimigos (bandido, corrompido, lobo, javali) como dados + IA simples: parado, perseguir, atacar, recuar; reação a golpe, morte, barra de vida |
| `scripts/main.gd` | Vila, estrada, floresta, câmera, clique para mover/falar/atacar, combo, esquiva, HUD, NPCs e ameaças vindos do motor, teste automático |
| `shaders/toon_post.gdshader` | Pós-processo: faixas de luz suaves e contorno fino só nas silhuetas (profundidade), sem linhas nas normal maps |
| `tools/fetch_assets.py` | Copia os pacotes CC0 do Quaternius para `assets/` (ignorado pelo git) |
| `tools/measure.gd` | Mede o tamanho das peças modulares |

## Rodar

1. Baixar os pacotes em quaternius.com (Medieval Village MegaKit, Stylized Nature MegaKit, Fantasy Props MegaKit, Universal Base Characters, Modular Character Outfits Fantasy, Universal Animation Library 1 e 2) e rodar `python tools/fetch_assets.py [pasta-dos-pacotes]`.
2. Subir o motor: `cd engine && go run ./cmd/worldsim serve -universe ../universes/valdoria/universe.json -data ../data -tick 1s -advisor deterministic`.
3. `Godot --path clients/godot` (a primeira abertura importa os assets; antes disso rode `Godot --headless --path clients/godot --import` uma vez para registrar os `class_name`).

Argumentos do jogo (depois de `--`): `--server=URL`, `--player=ID`, `--name=Nome`. Controles: **WASD** move (relativo à câmera: W sobe na tela); **botão esquerdo** golpeia na direção do cursor (segurar mantém o combo de 3; uma leve assistência de mira puxa para o inimigo próximo nessa direção); **botão direito** anda até o ponto ou abre o menu do NPC clicado; **1–4** habilidades (Golpe Giratório, Investida, Lâmina de Energia, Fôlego) e **R** esquiva, com recarga na barra inferior (passe o mouse para ver a descrição); **K** painel de habilidades (as de combate e as aprendidas no mundo, vindas do motor); `E` usa o NPC, ponto ou vestígio mais próximo (os vestígios aparecem como uma luz pálida com uma frase curta de perto); **`C` abre o Caderno** (pistas com a fonte, perguntas em aberto, pessoas e lugares); `F` lista tudo o que dá para tentar na região; `Y`/`N` aceitar/recusar a missão oferecida; `J` diário. Conversar faz quem está por perto conhecer o personagem, e só então NPCs aparecem nas missões dele.

## O mapa e a vila

`scripts/layout.gd` guarda todas as coordenadas (origens das regiões, caixas de região, estradas, spots). A vila é murada e tem 13 spots que o motor nomeia nas rotinas; os NPCs andam até o spot do momento, e as falas ouvidas viram balões. O mapa em centro e raios: vila no centro, estrada leste até o cruzamento, mina a nordeste, ruínas a leste, floresta ao norte, toca a oeste (pela brecha da paliçada). Autotestes: `--autotest=layout` (capturas aéreas), `--autotest=tour` (percorre as regiões), `--autotest=f1` (um dia na praça; precisa de servidor com `-tick 500ms`).

## Saber

Vestígios que o motor diz que o personagem pode perceber aparecem no mundo (`E` para examinar). O exame vira crença ou indício no Caderno (`C`). No menu de um NPC, "Contar a X: ..." passa ao NPC o que o personagem acredita; o NPC reage pela situação (já sabia, está desatualizado, novidade). `--autotest=saber` percorre: vestígio, exame, Caderno, contar pelo menu.

## Chegada

O personagem novo chega pela estrada (o cliente pede `join` com `region: estrada`), com título "Ninguém sabe o seu nome", mapa só com o lugar de chegada e sem missões até fazer algo. A primeira janela do Sistema vem com uma cerimônia curta. Ao voltar, um resumo "Enquanto você esteve fora" lista o que aconteceu desde a última visita (estado em `user://seen-<jogador>.json`). `--autotest=arrival` percorre isso (flags `--opening`, `--ceremony`, `--recap` mostram as telas que os autotestes normalmente omitem; `--arrival=vila` muda o lugar de chegada).

## Playtest e sensação

`Docs/Playtest.md` e `tools/playtest_report.py` (lê o registro `--telemetry=...`). Flags úteis: `--profile` (passos lentos), `--verbose` (log no console), `--hints --hint_after=N` (dicas), `--sound` (liga o som nos autotestes). `--autotest=sensacao` confere sons, menus que não travam o movimento, tempo de resposta e dicas.

## Combate e o motor

O combate (vida, dano, IA) é papel do servidor de jogo; neste spike o cliente faz esse papel. O motor só ouve resultados confirmados: os bandidos aparecem na região `estrada` quando o mundo emite o evento público `bandits` (somem em `bandits-left`) e as criaturas corrompidas na vila com `wolves`/`wolves-left`. Ao cair o último inimigo do grupo, o cliente reporta `enfrentar-bandidos` ou `cacar-lobos` como `adapter`, e o motor aceita ou recusa conforme a verdade do mundo.

| Inimigo | Onde e quando | Reporte ao motor |
|---|---|---|
| Bandido | `estrada`, evento `bandits` (some com `bandits-left`) | `enfrentar-bandidos` ao cair o grupo |
| Lobo corrompido | `vila`, evento `wolves` (some com `wolves-left`) | `cacar-lobos` ao cair o grupo |
| Javali | `floresta`, sempre; volta 25 s depois de cada abate | `cacar-javali` a cada abate (cada um é uma caça confirmada) |

O lobo usa o modelo animado do Quaternius (`Attack`, `Gallop`, reações a golpe, `Death`). O javali é o porco animado do Quaternius (CC0) escurecido, maior e com presas presas ao osso do focinho: corre, dá cabeçada e morre com animação de verdade.

## Teste automático

```bash
Godot --path clients/godot --resolution 1280x720 -- --autotest --player=gd-1 --server=http://127.0.0.1:8095 --out=clients/godot/.shots
```

Entra no mundo, fala com Orin, clica em Aceitar no cartão de oferta, contorna uma casa (pathfinding), luta contra os bandidos, mede FPS, testa a transparência de uma árvore, caça 3 javalis, espera o respawn e usa os botões do diário (aceitar, recusar, abandonar), gravando capturas em `--out`. Outros cenários: `--autotest=skills` (cada habilidade num campo de treino, com o dano medido e foto do efeito; WASD e clique esquerdo pela fila de entrada), `--autotest=places` (anda até mina, ruínas e toca e usa os menus de verdade: minerar, explorar, conversar com Pipo, forjar com Brom), `--autotest=wolves` (com `--threat=vila`), `--autotest=zoo` (cada criatura parada, para conferir escala e orientação) e `--autotest=hud` (estados de missão sintéticos, sem o motor, para ver todos os avisos). A saída `AUTOTEST {...}` resume o resultado. Precisa de janela (não funciona com `--headless`, que não renderiza).

## Limites conhecidos

- **Navegador:** o Godot exporta para web, mas o `guard` do servidor recusa qualquer requisição com `Origin` (403). Exige proxy ou ajuste do `guard`, o que depende da autenticação (adiada). Os export templates (1,28 GB) não foram baixados.
- A atualização é por consulta (1 s); o `HTTPRequest` não lê SSE. Trocar por `HTTPClient` quando precisar de stream.
- Casas são blocos sólidos (não dá para entrar).
- Pathfinding: NavMesh gerada em tempo de execução a partir dos colisores (grupo `nav_source`, ~1 s em segundo plano); até ficar pronta o movimento é em linha reta. As cercas da estrada são sólidas.
- Oclusão: árvores e casas entre a câmera e o jogador ficam transparentes (a sombra continua opaca).
- O javali não tem reação própria a golpe (o porco não tem esse clipe; ele só recua). Os "corrompidos" humanoides (zumbi) continuam definidos como dados em `enemy.gd`, mas nenhum evento os usa agora.
- O combate é local, sem sincronização entre jogadores.
- Outros jogadores da mesma região aparecem (nome em azul), mas em posições fixas derivadas do id: o motor conhece regiões, não coordenadas. Posição real entre jogadores é papel de um servidor de jogo.
- Valdoria não permite abandonar missão aceita: o botão Abandonar envia a intenção e o motor recusa ("this world requires finishing the accepted quest").

## Créditos dos modelos de criaturas

Lobos e porco (javali): Quaternius, CC0, via poly.pizza. Sem obrigação de atribuição.
