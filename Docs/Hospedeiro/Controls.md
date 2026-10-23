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

## O Granuloma (primeira masmorra)

Na corrente sanguínea há um granuloma: anéis de macrófagos em volta de um núcleo necrótico. Chegue perto (a coroa de luz acende) e aperte **E** para entrar; só abre para quem já amadureceu e só com o corpo conectado ao motor. O motor prepara a execução, o Jev escolhe o **modificador** (Em febre, Necrose viva, Guarda redobrada, Ar rarefeito ou Quórum ativo) e a câmara se forma longe do corpo: **cinco salas** (guarda de linfócitos, parede de macrófagos, anel interno, núcleo necrótico e o chefe, O Bacilo). Limpar a sala avança; o chefe faz um golpe em onda com um segundo de aviso (o anel no chão cresce) e solta bacilos. **Backspace** desiste. Morrer encerra a execução, e é preciso esperar um pouco para tentar de novo. Fechar o granuloma reduz a carga de infecção no sangue, dá o Selo do Granuloma e, para a primeira célula do mundo, o título Primeiro Selador.

## Atlas do corpo

**M** abre e fecha o atlas: o corpo é uma única membrana contínua; as regiões que a célula já visitou ficam acesas e nomeadas, as outras aparecem só como contorno apagado com um "?". A descoberta é lembrada entre sessões.

## Sinais vitais

Uma linha no canto superior direito mostra temperatura, pulso e oxigênio (laranja quando fora do normal). **Tab** abre o painel completo: uma barra para cada sinal, com a faixa saudável marcada, e frases que explicam o que está acontecendo e por quê (febre, hipóxia, adrenalina, cortisol, insulina).

## Explorar

Alguns lugares do corpo escondem **nichos**: bolsas com um gene para quem as achar. Uma seta no canto da tela ("rastro químico · distância") aponta para o nicho mais próximo que você já consegue alcançar; o nicho cintila quando você chega perto, e basta tocá-lo. Os nichos únicos dão o gene só ao primeiro a chegar. Algumas passagens têm uma **membrana alaranjada** que só abre para quem tem o gene certo (o pulmão pede o Citoesqueleto Elástico); ela diz o que pede quando você chega perto. Requer o motor conectado.

## Códice

**B** abre o códice do corpo: lugares, invasores, o corpo e segredos. O que você ainda não aprendeu aparece como `???`. Também lista as regiões a que você se adaptou por viver nelas (a energia volta mais depressa lá). Há nichos-segredo que só existem em certo estado do corpo, e o rastro químico segue o lugar que o Jev apontou para você, quando há um.

## Debug do design do Jev

**F3** abre o painel de debug: de onde veio o design (motor, debug ou nenhum), cada traço, o estilo dos efeitos, os multiplicadores das partículas e quantos efeitos foram emitidos nesta sessão (e quantos com estilo). **F4** troca o estilo dos efeitos à mão (chama, cristal, névoa, elétrico, orgânico) para ver cada um sem esperar o motor; **F5** sorteia um design completo (núcleo composto, membrana, organelas, brilho, efeitos); **F6** volta ao que o motor decidiu. Cada mudança também escreve `[design] origem=... traços=...` no console. O motor desenha a célula nova depois de uns 6 atos (cerca de 20 s jogando).
