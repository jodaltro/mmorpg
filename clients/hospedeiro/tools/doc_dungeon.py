"""Records the first dungeon in the docs (one-off)."""
from pathlib import Path

root = Path(__file__).resolve().parents[3]


def append(path, text):
    p = root / path
    s = p.read_text(encoding="utf-8").rstrip("\n")
    p.write_text(s + "\n\n" + text.strip("\n") + "\n", encoding="utf-8")


append("Docs/Universes.md", """
- **`dungeons`** (`{id, name, desc, region, eligible, rooms, modifiers, rewards, firstClear, firstText, retry}`). Lugares em que o jogador entra de propósito: salas a limpar em ordem (`rooms`, com `kind` guard/wall/core/boss para o servidor de jogo), e **modificadores** (`modifiers`, com `eligible` opcional). Quem entra (verbo `entrar-masmorra`, com `args: {dungeon}`) precisa estar na `region` e cumprir `eligible`. O motor prepara a execução e cria a decisão **`dungeon`**: o Jev escolhe o modificador entre os válidos, a resposta é revalidada e o padrão no prazo é o primeiro. O servidor de jogo confirma cada sala (`sala-limpa`, origem `adapter`) ou a queda (`falhar-masmorra`); o jogador pode desistir (`abandonar-masmorra`). A última sala completa a masmorra: aplica `rewards` e, só na primeira vez no mundo, `firstClear` (cenário único) com uma linha pública no cronista. `retry` é a espera antes de entrar de novo.
""")
append("Docs/Contracts/ApiV1.md", """
- `GET /v1/views/{id}` traz `dungeon`: `{available: [{id, name, desc, region, rooms, eligible}], run: {dungeon, name, state, seed, modifier, room, rooms}}`. `state` é `preparing` (o modificador está sendo decidido), `active`, `cleared` ou `failed`; `seed` vem do motor para que todos vejam a mesma masmorra. Verbos: `act` com `entrar-masmorra` (`args: {dungeon}`) e `abandonar-masmorra` (origem `player`); `sala-limpa` e `falhar-masmorra` (origem `adapter`). Eventos: `dungeon-preparing`, `dungeon-started`, `dungeon-room`, `dungeon-cleared`, `dungeon-failed`, `dungeon-left` e o público `dungeon-first`; a decisão `dungeon` aparece como `decision` com `kind: dungeon`.
""")
append("Docs/Hospedeiro/Controls.md", """
## O Granuloma (primeira masmorra)

Na corrente sanguínea há um granuloma: anéis de macrófagos em volta de um núcleo necrótico. Chegue perto (a coroa de luz acende) e aperte **E** para entrar; só abre para quem já amadureceu e só com o corpo conectado ao motor. O motor prepara a execução, o Jev escolhe o **modificador** (Em febre, Necrose viva, Guarda redobrada, Ar rarefeito ou Quórum ativo) e a câmara se forma longe do corpo: **cinco salas** (guarda de linfócitos, parede de macrófagos, anel interno, núcleo necrótico e o chefe, O Bacilo). Limpar a sala avança; o chefe faz um golpe em onda com um segundo de aviso (o anel no chão cresce) e solta bacilos. **Backspace** desiste. Morrer encerra a execução, e é preciso esperar um pouco para tentar de novo. Fechar o granuloma reduz a carga de infecção no sangue, dá o Selo do Granuloma e, para a primeira célula do mundo, o título Primeiro Selador.
""")
append("Docs/Validation/Hospedeiro.md", """
### H3.5 — a primeira masmorra: o Granuloma (23/10/2026)

**Motor:** `core/dungeon.go` (`DungeonDef`, execução por jogador, verbos `entrar-masmorra`, `sala-limpa`, `falhar-masmorra`, `abandonar-masmorra`, decisão **`dungeon`** com o Jev escolhendo o modificador, revalidada e com padrão no prazo, semente do motor, recompensas, cenário único do primeiro a fechar, espera para tentar de novo, visão `dungeon`), instrução do Jev em `advisor/jev.go`, universo com o granuloma (5 salas, 5 modificadores, 2 habilidades-título).

**Cliente:** `BioDungeonPlan` (puro: o que há em cada sala a partir da semente, do tipo da sala e do modificador), `BioDungeon` (câmara, salas, inimigos, fim), `BioBossSlam` (golpe em onda com aviso e bacilos invocados), `BioGate` (a entrada na corrente sanguínea), inimigos novos (`BioFactory.spawn_enemy`), texto de progresso no HUD.

**Executado:** Go: 5 testes novos (`dungeon_test.go`: precisa de maturidade e do lugar certo; o Jev escolhe e a resposta é revalidada; o padrão no prazo; cinco salas, recompensas e primeiro título único; queda, espera e desistência), todos passam; o restante passa exceto o teste antigo de `presentation.json`; `worldsim validate` ok. Godot: 74 testes, 0 falhas (6 novos: plano determinístico e modificadores, câmara sala a sala, o motor conduz a execução, modificadores mudam a execução, o golpe do chefe só acerta dentro do raio, morrer reporta a falha). **Ponta a ponta com o motor e o Jev ligado** (`tests/e2e_dungeon.gd`): amadurece, a entrada abre, entra, o modificador é escolhido (Em febre), as cinco salas abrem uma a uma confirmadas pelo motor, o chefe cai, a execução fecha e o motor dá o Selo e o título único. GIFs e capturas reais.

**Não feito:** a ruptura do granuloma se ninguém entrar; execução cooperativa em grupo (a semente já é compartilhável); entrada de quem está em outra região; quests e ofertas continuam aparecendo por cima da câmara; equilíbrio dos números dos inimigos e do chefe. O `provider` da decisão do modificador não foi verificado neste registro (o padrão `em-febre` foi o escolhido).
""")
print("ok")
