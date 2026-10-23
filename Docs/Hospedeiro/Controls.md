# Hospedeiro — como jogar (H1)

## Abrir o jogo (PowerShell)

O backend (motor com o universo `hospedeiro`, porta **8096**, Jev ligado) fica rodando à parte. Para jogar, só o cliente:

```powershell
& "D:\tools\godot\bin\Godot_v4.7.2-stable_win64.exe" --path "D:\unity\Mmorpg\clients\hospedeiro"
```

Sem o backend, o jogo abre em **modo offline**: combate, nutrientes e mutações funcionam, sem missões nem história. O canto superior esquerdo mostra `● CONECTADO AO HOSPEDEIRO` ou `○ OFFLINE`.

Subir o backend à mão, se precisar (a chave do Jev fica em `engine\.env`, ignorado pelo Git):

```powershell
cd D:\unity\Mmorpg\engine
go run ./cmd/worldsim serve -universe ../universes/hospedeiro/universe.json -data D:\unity\hospedeiro-data -listen 127.0.0.1:8096 -advisor jev -env-file .env -on-universe-change new-world
```

## Controles

| Ação | Teclado/Mouse | Gamepad |
|---|---|---|
| Mover | WASD / setas | Analógico esquerdo |
| Mirar | Mouse | Analógico direito |
| Chicote de cauda (corpo a corpo, 8 ATP) | J / botão esquerdo | Botão X (oeste) |
| Cuspe de toxina (projétil, 15 ATP) | K / botão direito | Botão B (leste) |
| Impulso de membrana (dash + i-frames, 12 ATP) | Espaço / Shift | Botão A (sul) |
| Aceitar / recusar um chamado | Y / N | — |
| Ações do lugar (examinar, contar, farejar, decifrar) | E, depois 1–9 | — |
| Escolher / recusar mutação | 1, 2, 3 / X | — |
| Renascer na medula | R | — |
| Habilidades de classe (4 espaços, na ordem em que você as adquire) | Q, F, C, V | — |

## Reiniciar o mundo

O botão **REINICIAR MUNDO** (canto superior esquerdo, só com o mouse) apaga o corpo e a história: aperte uma vez para armar (o texto vira "CONFIRMAR? apaga tudo") e outra vez em até 4 s para confirmar. O motor começa um mundo novo (o antigo fica arquivado no servidor) e você volta como uma esfera, sem genes, classe nem habilidades, na medula.

## Habilidades de classe

Cada classe nasce com **1** habilidade; as outras 3 vêm do que você faz: a prova da classe (missão dada por Neva, Dendra ou Rubra), feitos que combinam com ela e o **despertar** que o Jev decide de tempos em tempos olhando como você joga. Elas ocupam Q, F, C e V; quem tem alvo exigido (marcas, Apoptose) não gasta nada sem alvo. Resumo: Macrófago (engolir cura, onda, ácido, muralha), Neutrófilo (rede, investida, NETose, degranulação), Dendrítica (antígeno, chicote, esporos, mapa), Linfócito B (anticorpo Y teleguiado, salva, opsonização, plasmócito), T citotóxico (perforina, golpe lítico, apoptose, sinal de morte), T auxiliar (citocina curativa, canto, chamado, febre).

## O mundo (H1)

- Duas regiões: a **Medula Óssea** (onde você nasce) e a **Corrente Sanguínea**, ligadas pela sinusoide. No sangue há correnteza.
- **Membrana** é a vida; **ATP** é o recurso. Glicose (âmbar) devolve ATP; lipídio (verde) repara a membrana.
- Vírions espinhosos vivem no sangue: perseguem, brilham em vermelho por 0,65 s antes de avançar e ficam expostos por cerca de 1 s.
- O motor decide missões e história. Células como Osteia (estroma), Neva (neutrófila) e Dendra (dendrítica) só chamam quem já viram agir. Nada é oferecido antes do seu primeiro feito.
- O corpo vive sozinho: surtos virais, febre (vírions lentos), refeições (glicose no sangue), sono (tudo escurece). O Jev escolhe os acontecimentos.
- Conhecimento muda o mundo: destruir um vírion ensina o "rosto" dele. Contar à Dendra arma as defesas do sangue. Conhecer o vírion também permite decifrar o fragmento de código que aparece no nicho (cenário único: só a primeira célula recebe o título).
- **Evoluir é o objetivo de todo jogador.** Cada feito confirmado (vírion destruído, nutriente, esquiva, código decifrado) soma pressão evolutiva e ensina o seu caminho (combate, metabolismo, resistência, exploração, conhecimento). Quando a pressão estoura, o motor oferece 3 mutações; o Jev escolhe para onde o seu corpo pende (marcada com ◆) lendo como você vive. Você escolhe com 1, 2, 3 ou recusa com X. Escolher aprofunda o caminho; o genoma tem 3 espaços e o gene mais antigo é reabsorvido.

## Arquivos

- `universes/hospedeiro/universe.json`: o mundo no motor.
- `clients/hospedeiro/scripts/domain`: vitais, ator, ataques, genoma (puro).
- `clients/hospedeiro/scripts/runtime`: corpo procedural, combate, mapa do corpo (`bio_body_map.gd`), ligação com o motor (`bio_engine_link.gd`, `bio_host_sync.gd`), janela do Sistema.
- `clients/hospedeiro/tests`: runner headless, testes de regras, mundo e ponte com o motor; `e2e_engine.gd` (ponta a ponta) e `capture.gd` (screenshots).
