# Controles e estado — B1 (protótipo da célula, Godot 4.7)

| Ação | Teclado/Mouse | Gamepad |
|---|---|---|
| Mover | WASD / setas | Analógico esquerdo |
| Mirar | Mouse | Analógico direito |
| Chicote de flagelo (corpo a corpo, 8 ATP) | J / botão esquerdo | Botão X (oeste) |
| Cuspe de toxina (projétil, 15 ATP) | K / botão direito | Botão B (leste) |
| Impulso de membrana (dash + i-frames, 12 ATP) | Espaço / Shift | Botão A (sul) |
| Ressurgir após morrer | R | — |

## Regras do B1

- **Membrana** é a vida; **ATP** é o recurso e regenera devagar. Glicose (âmbar) devolve ATP; lipídio (verde) repara a membrana.
- Dano, custo e recarga vêm de `BioAttackCatalog` (domínio). A entrada só expressa intenção.
- O vírus espinhoso persegue, brilha em rosa/vermelho por 0,65 s (telegrafia), avança em linha reta e fica exposto por ~1,1 s.
- Vírus derrotados soltam nutrientes. Hitbox lógica é um círculo; o corpo visual deforma livremente.

## Arquivos

- `clients/hospedeiro/scripts/domain`: vitais, ator, catálogo de ataques, regras de acerto e nutrientes (puro).
- `clients/hospedeiro/scripts/runtime`: corpo procedural, flagelo, executor de ataques, IA do vírus, HUD, fábrica e `bio_world.gd` (raiz).
- `clients/hospedeiro/tests`: `run_tests.gd` (runner), `test_domain.gd`, `test_world.gd`, `capture.gd` (screenshots).

## Validação (executada)

```bash
G="/d/tools/godot/bin/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path clients/hospedeiro --import
"$G" --headless --path clients/hospedeiro --script res://tests/run_tests.gd   # testes (resultados em Docs/Validation/Hospedeiro.md)
"$G" --path clients/hospedeiro --script res://tests/capture.gd -- <pasta>      # screenshots (renderer real)
```

Rodado em 2026-10-22 no Godot 4.7.2 (Vulkan, Forward+): 8 testes de domínio e 8 de integração (mundo, lash/spit/dash, nutriente, telegrafia do vírus, morte/respawn) passaram sem warnings. Screenshots conferidos visualmente. Não testado: gamepad real e jogo interativo longo.
