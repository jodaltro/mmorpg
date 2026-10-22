# Validação — cliente Godot

Só o que realmente rodou. Máquina: Windows 10 19045, AMD Radeon RX 5700 XT (Vulkan 1.4.315, Forward+), Godot 4.7.2-stable em `D:\tools\godot` (SHA-256 do zip conferido com o digest do release). Assets: pacotes Quaternius CC0 já baixados em `D:\UnrealDownloads\WorldSimDemo`, copiados para `clients/godot/assets` (fora do git).

## 21/10/2026

### Rig e animações

Inspeção em Godot headless: o personagem (`Superhero_Male_FullBody`), os outfits e a UAL têm o mesmo esqueleto (65 ossos, caminho `Armature/Skeleton3D`). As 43 animações da UAL1 e as 43 da UAL2 tocam no personagem sem retargeting; os meshes dos outfits (Peasant, Ranger) se movem para o esqueleto do personagem e acompanham as animações.

### Teste automático contra o motor

Motor: `worldsim serve` (Valdoria, `-advisor deterministic`) em `127.0.0.1:8096`, com dados descartáveis. Cliente: `Godot --path clients/godot --resolution 1280x720 -- --autotest --player=gd-<timestamp> --name=Teste --server=http://127.0.0.1:8096`.

| Passo | Resultado |
|---|---|
| join + `view` | `view: true`, NPCs da região criados a partir de `others` (`npcs: 5` na vila) |
| `act examinar-poco` (Orin) | aceito; evento "Teste examina a agua do Poco Antigo." voltou na `view` |
| `act forjar` (Brom) | **recusado pelo motor** (`rejected: requirements`), mostrado no HUD |
| missão oferecida → `accept` | `quest_offered: true`, `quest_active: true` |
| entrada na floresta (volume de região) | `move` aceito; `region_local` e `region_server` = `floresta` |
| golpe | animação `Sword_Regular_A`, faíscas e tremor de câmera (capturas conferidas) |

Resumo impresso: `AUTOTEST {"npcs":5,"quest_active":true,"quest_offered":true,"region_local":"floresta","region_server":"floresta","skills":0,"view":true}`.

### Defeitos encontrados e corrigidos na validação

- `HTTPRequest` com timeout de 5 s expirava na primeira requisição, presa pela compilação de shaders do primeiro frame (`result=13`). Passou a 15 s, com início da rede adiado e `join` repetido até 5 vezes.
- `walk_to` era ignorado durante um clipe pontual, e o teste travava esperando `arrived`. Andar agora cancela o clipe.
- Em mundo persistido o jogador começava na vila com o servidor dizendo "floresta". O cliente passou a se posicionar pela região da primeira `view`.

### Não validado

Export web, stream SSE, pathfinding, estilização, mais de um cliente simultâneo, desempenho com muitos NPCs.
