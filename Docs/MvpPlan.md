# Da spike ao MVP: "Ninguém sabe seu nome"

Plano de 22/10/2026. Nada aqui foi implementado ainda. Gráficos e modelos ficam fora: o foco é **sensação de mundo novo, vontade de explorar, enigma, surpresa, fluidez e interações variadas**.

## 1. Diagnóstico: por que a spike ainda não é um jogo

O motor já guarda muito mais do que o jogador sente. Valdoria tem 40 modelos de missão (9 ocultas), 3 arcos, 12 acontecimentos do diretor, 19 habilidades descobertas por hábito, crenças com procedência, boatos, testemunhas e cenários únicos. O problema está em **como** isso chega ao jogador:

1. **O mundo conta em vez de mostrar.** Quase tudo chega como texto: a janela do Sistema, um toast ou um menu de ações ("Examinar a água do poço"). O espaço físico não muda com o que está acontecendo. O poço envenenado parece igual ao poço limpo.
2. **Nada está escondido.** Todo ponto de interesse tem rótulo visível através das paredes. O minimapa mostra as seis regiões desde o primeiro minuto, inclusive a Toca dos Lebrinos, que deveria ser um segredo. Não há o que descobrir no espaço.
3. **A vila é um cenário, não um lugar.** É uma praça com quatro casas simétricas, sem funções nem bairros. Não tem marcos, e os NPCs ficam parados num ponto fixo. Não há motivo para entrar numa rua e não em outra.
4. **O mapa é um corredor.** Vila, estrada, floresta, mina e ruínas ficam em linha reta. Não há vista de longe, bifurcação, atalho nem algo que chame o olho.
5. **A interação é um menu.** O único verbo em tempo real é lutar. O resto é escolher uma linha de uma lista. Nenhum verbo se combina com outro.
6. **A chegada é igual à décima visita.** O jogador aparece na praça. Ninguém reage e não há ritual de chegada.
7. **A separação entre verdade e crença, o diferencial do motor, é invisível.** O jogador não vê o que sabe, de quem soube nem o que está errado. Ainda não existe enigma porque não existe "não sei" visível.

Resumo: **o coração já existe; falta a pele.** O plano é mais cliente e conteúdo do que motor. Mesmo assim, faltam ao motor cinco peças: sinais, rotinas, contar/mostrar, marcas e a chegada.

## 2. O que a pesquisa trouxe

| Fonte | Ideia | Como entra em Valdoria |
|---|---|---|
| *Outer Wilds* | Progresso medido só por conhecimento. O registro da nave é um grafo de pistas, com "há mais aqui" e sem marcador de objetivo | O **Caderno**: crenças do motor, com fonte, ligadas entre si; perguntas abertas como nós "?" |
| *Tunic* | Achar uma parede quebrável ensina que *toda* parede pode ser uma pergunta | Cada verbo funciona em qualquer lugar. Ao descobrir um uso, o jogador passa a olhar o mundo inteiro de outro jeito |
| *Zelda BotW* (regra do triângulo, química) | Marcos visíveis de longe deixam a curiosidade escolher o caminho. Elementos mudam o estado dos materiais (efeito multiplicativo) | Um mirante com três chamados: torre das ruínas, fumaça da mina e luz roxa do selo à noite. Fogo, água e ervas como estados que se combinam |
| Harvey Smith e Matthias Worch, GDC 2010 (narrativa ambiental) | "Tem de ser possível perder coisas para que achá-las tenha valor" | Sinais físicos das verdades escondidas, que dá para ignorar |
| *Gothic* | Vila com rotinas, facções, sem marcadores; habilidades ensinadas por pessoas | Rotinas por hora no motor. Habilidades raras vêm de gente e de lugares |
| *Majora's Mask* (Caderno dos Bombers) | Agenda das pessoas: quem está onde e quando algo acontece | A aba **Pessoas** do Caderno: o que você sabe da rotina de cada um |
| *Hollow Knight* (Cornifer) | O mapa é ganho, não dado; é feito aos poucos | Névoa no mapa. Tomas vende um esboço da região e o jogador completa andando |
| *Elden Ring* (mensagens) | Multijogador assíncrono: deixar avisos e pistas para quem vem depois | **Marcas de viajante**: símbolos fixos, sem texto livre, deixados num lugar e vistos por outros jogadores |
| *Sea of Thieves* (garrafas, Tall Tales) | Achados aleatórios que valem mais do que a rotina; histórias escritas sobre um mundo emergente | Achados raros por sorte determinística (moeda, bilhete, pegada branca) |
| *Asheron's Call* (Shard of the Herald) | Evento vivo que muda o mundo para sempre, com monumento aos participantes | O primeiro a cumprir um cenário único ganha marca permanente na vila: estátua, placa, música |
| *Shadows of Doubt*, *Return of the Obra Dinn* | Cidade com vidas próprias e pistas que se cruzam. Ver não é saber: o jogador deduz | Pistas com procedência, que podem estar erradas. Mostrar uma pista ao NPC certo destrava |
| *Caves of Qud*, *Dwarf Fortress* | Boatos e segredos como moeda; NPCs não são oniscientes | Segredos como itens: contar, trocar, vender. Jogadores trocam o que sabem |
| *Shangri-La Frontier* | Monstros únicos, cenários achados por acidente ou por informação; a maldição de Lycagon muda como NPCs e inimigos tratam o personagem | **Estigmas**: marcas no corpo que mudam reações (a Marca do Selo) |
| *Overgeared* | Classe lendária achada num lugar esquecido por quem não era ninguém | O legado do ferreiro (já no universo) ganha lugar físico, inscrições e um caminho de "ninguém" para "herdeiro" |
| *Log Horizon* | NPCs são gente: lembram e morrem; tratá-los como objetos tem preço | Relação e memória já estão no motor. A vila lembra em público: cumprimentos, recusas, fofoca |

### A combinação que nenhum deles faz junto

> **Em Valdoria, segredos são crenças, e crenças são objetos.**
> O mundo **mostra** sinais da verdade. O jogador **forma crenças**, que podem estar erradas, ao examinar, ouvir e ler. Ele **carrega** essas crenças no Caderno e pode **mostrá-las, contá-las ou trocá-las** com NPCs e com outros jogadores. **O Sistema só fala depois que o mundo falou.**

Isso une três coisas que já existem separadas:
- o progresso por conhecimento de *Outer Wilds*, num jogo para um jogador;
- a verdade separada da crença, que o motor já faz;
- um mundo compartilhado e persistente de MMO.

O resultado:
- **Dois jogadores podem ver a mesma vila e saber coisas diferentes.** Um descobriu o veneno, o outro acha que é maldição.
- **Conhecimento tem valor social.** Quem sabe primeiro decide se conta, vende ou guarda.
- **Quem chega depois herda o que o mundo virou:** o monumento, o poço limpo, a floresta replantada, as marcas.
- **Ser o primeiro a saber é diferente de ser o primeiro a fazer.** É um segundo eixo de fama, ao lado dos cenários únicos.

## 3. Pilares do MVP

1. **O mundo mostra antes de contar.** Toda verdade escondida que importa tem um sinal perceptível no espaço.
2. **Saber é progredir.** O Caderno é a ficha de personagem que importa. Habilidades também mudam o que se percebe.
3. **De estranho a alguém.** A chegada é um ritual. Ninguém te conhece, e o mundo passa a te conhecer pelo que você faz na frente dele.
4. **Uma vila que vive sem você.** Rotinas, conversas, trabalho e noite.
5. **O mundo guarda o que os outros fizeram.** Monumentos, marcas, mudanças permanentes e fofoca sobre jogadores.
6. **Surpresa com regra.** O raro existe, é justo e se repete de forma determinística, nunca por sorte pura no cliente.
7. **Nada para o jogador.** Não há janela modal, espera nem tela de carregamento. A resposta à entrada é imediata, e a confirmação do motor chega em menos de meio segundo.

## 4. Definição do MVP

**Uma hora de jogo para quem nunca viu Valdoria**, em que a pessoa:
- chega como estranha;
- vira alguém na vila;
- encontra por conta própria ao menos dois segredos;
- sai com uma pergunta sem resposta e um motivo para voltar.

Deve funcionar para **2 a 4 pessoas ao mesmo tempo** no mesmo mundo, com o Jev ligado, e continuar jogável com ele desligado.

**Dentro:** a Vila Cinzenta reestruturada, as regiões externas (estrada, floresta, selo, mina, ruínas e toca) com enigmas, verbos sistêmicos, o Caderno, sinais, rotinas, conversas, mapa com névoa, chegada, marcas, monumentos e push por SSE.

**Fora:** arte final, modelos novos, interiores detalhados (bastam "cômodos-caixa"), autenticação, publicação web, servidor de jogo autoritativo de combate, economia completa e PvP.

## 5. A primeira hora (roteiro de experiência)

O tempo do mundo é compartilhado: a chegada pode ser de dia ou de noite. As duas versões precisam funcionar e oferecer coisas diferentes.

| Minuto | O que acontece | O que o jogador sente | Peça que sustenta |
|---|---|---|---|
| 0 | Tela escura, som de estrada e de rodas. Texto curto: "Valdoria. Ninguém sabe seu nome." O jogador está **na carroça da caravana de Lia**, chegando pela estrada leste | Chegada, não spawn | Efeitos de chegada (`onJoin`): começa na estrada e conhece Lia |
| 1–3 | **Portão.** Orin pergunta o nome. É a primeira vez que o mundo ouve o nome do personagem. Ele avisa: "Fique longe do poço. Tem gente adoecendo." Lia segue para o mercado | Uma regra, e regras atiçam a curiosidade | `conversar`, o fato `met orin` e uma crença dada por Orin (fonte: conversa) |
| 3–12 | **Vila livre, sem janela do Sistema.** Tosse perto do poço, Mira apressada entre casas, o martelo de Brom (o som guia), Nino brincando de "lobo" e o quadro de avisos na taverna. À noite: janelas acesas, a taverna cheia e Tomas contando uma história | Um lugar vivo que não precisa de mim | Rotinas, conversas ouvidas e sinais da doença |
| 12–20 | **Primeiro feito testemunhado.** Ajudar alguém, examinar o poço ou ler o quadro. Quem viu passa a conhecê-lo. Só então aparece **a primeira janela do Sistema**, com cerimônia ("O Sistema percebeu você") | "O mundo me notou" | `witness` e `acquaintance` (já existem). A primeira oferta exige um feito (ver §10.1) |
| 20–35 | **O mirante.** Do alto: a torre quebrada das ruínas, fumaça na colina da mina e, à noite, uma luz roxa no meio da floresta. Três perguntas, três direções. A primeira missão aponta para uma delas, e as outras ficam no Caderno como "?" | Escolha, não corredor | Marcos de longe, perguntas no Caderno e névoa no mapa |
| 35–50 | **Primeira saída e primeiro perigo.** Javalis na mata e lobos à noite. A tocha espanta os lobos e acende sarças. Um rastro que só aparece para quem sabe olhar | Risco e domínio | Verbos (tocha, rastrear) e sinais condicionados a habilidade ou crença |
| 50–60 | **Primeira surpresa.** Algo que o jogador não sabia que existia: a toca sob a raiz, a pegada branca ou a moeda de Asterion. Às vezes, uma habilidade estranha por hábito ("Cochilo Estratégico") | "Este mundo tem fundo" | Missões ocultas e habilidades por hábito (já existem) e sinais raros |
| Saída | Fica uma pergunta sem resposta no Caderno. Ao voltar, um resumo **"Enquanto você esteve fora"** mostra o que mudou | Motivo para voltar | Eventos desde a última visão (já existem) apresentados como resumo |

## 6. A Vila Cinzenta reestruturada

Cada lugar precisa de **função, dono, horário, verbo e segredo**. O que importa é a planta; os modelos atuais bastam.

```
                        N
              (colinas: fumaça da mina; torre das ruínas a leste)
     [Mirante] ─── trilha ─── [Capela de Elena] ── [Cemitério]
         │                          │
 [Horta e casa de Mira] ── Rua Alta ── [Taverna do Javali] (quadro de avisos)
         │                          │
 [Paliçada com brecha] ─── PRAÇA DO POÇO ─── [Pátio do mercado] ─── PORTÃO LESTE ── estrada
  (saída escondida              (poço, sino,            (caravana de Lia)        (Orin)
   para a floresta)              bancos)
         │                          │
   [Forja de Brom] ─── Rua Baixa ── [Casa do Velho Tomas]
         │
   [Celeiro e moinho] ── ponte ── riacho ── borda da floresta (raiz gigante)
```

| Lugar | Função | Quem e quando | Verbos | Sinal ou segredo |
|---|---|---|---|---|
| Portão leste | Entrada; guarda | Orin de dia; à noite, a tocha da guarita | conversar, mostrar | Orin lembra quem chegou e quem saiu à noite. Fofoca sobre jogadores |
| Praça do poço | Centro; encontro | Aldeões buscando água de manhã e ao entardecer | examinar, tirar água, tocar o sino | Água turva, peixes mortos, tosse (veneno). O sino reúne a vila em emergências |
| Taverna do Javali | Rumores, histórias, quadro de avisos | Tomas ao anoitecer; caçadores; Kael às vezes | escutar, sentar, ler o quadro, servir chá | A lenda do Javali Branco. O quadro mostra necessidades sem NPC (telhados, ervas) |
| Horta e casa de Mira | Cura, ervas | Mira na horta de manhã e nos doentes à tarde | dar ervas, examinar a horta, usar Florescer | Cenouras roídas e pegadas pequenas: a trilha dos lebrinos. O segredo de Mira |
| Forja de Brom | Trabalho, encomendas | Brom de dia; à noite, a brasa acesa | forjar, entregar minério, examinar a bigorna | Uma marca antiga na bigorna, igual às inscrições das ruínas (o legado) |
| Capela e cemitério | Bênção, canto, memória | Elena ao amanhecer (canto) e à noite (vela) | receber bênção, escutar, acender vela, ler lápides | A canção da alvorada. Uma lápide sem nome ligada a Asterion |
| Casa do Velho Tomas | Memória da vila; mapas | Tomas em casa de manhã e na taverna à noite | conversar, servir chá, comprar esboço de mapa | Os esboços de mapa (estilo Cornifer). As histórias puxam para lugares |
| Pátio do mercado | Comércio quando a caravana está | Lia quando a caravana chega (acontecimento) | trocar, mostrar moeda, vender segredo | A moeda de Asterion vale um mapa. A feira dos magos (rara) acontece aqui |
| Mirante | Vista; orientação | Vazio; Nino às vezes | olhar longe, deixar marca | Os três chamados. À noite, a luz roxa do selo |
| Paliçada com brecha | Atalho escondido | Ninguém | passar agachado | Saída secreta para a floresta, achada por quem anda pela borda |
| Celeiro e moinho | Trabalho, esconderijo | Nino se esconde aqui quando some | procurar, carregar sacos | "Onde está Nino?" ganha lugar físico e rastros |

### Rotinas (exemplo do dia de 12 minutos)

| NPC | Madrugada | Manhã | Tarde | Anoitecer | Noite |
|---|---|---|---|---|---|
| Mira | dorme | horta | casas dos doentes | casa (preparos) | dorme; às vezes vai ao poço escondida (segredo) |
| Brom | dorme | forja | forja | taverna | forja apagando |
| Tomas | dorme | casa | praça (banco) | taverna (histórias) | casa |
| Elena | capela (vigília) | capela (canto ao amanhecer) | visita doentes | capela | capela |
| Orin | guarita | portão | ronda | portão | guarita |
| Nino | dorme | praça | celeiro, mirante | casa | dorme (ou some: acontecimento) |
| Lia | só com a caravana | mercado | mercado | taverna | carroça |

Rotinas são **interrompidas pelo mundo**: em surto, Mira não vai à horta; com lobos, Orin fecha o portão; na tempestade, todos se recolhem. É aí que a vila parece viva, porque reage.

## 7. O mapa de Valdoria fora da vila

Do corredor atual para **centro e raios, com atalhos**:

- **Estrada Leste**: a chegada da caravana, uma encruzilhada e o acampamento de bandidos. Sinal de longe: fogueira à noite. Atalho: nenhum; é o caminho "seguro".
- **Floresta Cinzenta**, ao norte da vila: árvores secando na direção do selo, o que forma uma trilha natural para quem repara.
  - O **Selo** fica no coração da mata. Luz roxa à noite, visível do mirante.
  - A **Toca dos Lebrinos** fica sob uma raiz gigante na borda oeste, perto da horta de Mira. **Não aparece no mapa** até ser achada.
- **Mina de Kharum**, nas colinas a nordeste: fumaça de dia e lanternas à noite. Lá dentro é escuro (tocha). Veios roxos, desabamento e Garrick.
  - Atalho: um túnel antigo que sai nas ruínas, aberto pelo mapa de Lia ou ao explorar o fundo da mina.
- **Ruínas de Asterion**, numa colina a leste: a torre quebrada é o marco de qualquer ponto do mapa. Pela estrada, a ponte está caída e a entrada exige rodear o morro.
  - Inscrições numa língua que se lê aos poucos (*Heaven's Vault*). Cada palavra aprendida é uma crença.
  - O salão e a forja antiga, ligados ao legado do ferreiro.

Regra de composição: **de qualquer lugar aberto, ao menos um marco visível que o jogador ainda não visitou.**

## 8. Os enigmas: cadeias de pistas

Cada enigma segue a forma **sinal → verbo → crença → mostrar ou usar → abre**. Quase todos os finais já existem no universo; o que falta é o começo físico.

| Enigma | Sinal (perceptível) | Verbo | Crença formada | Quem ou o quê destrava | Abre (já existe?) |
|---|---|---|---|---|---|
| O poço | Tosse, água turva, peixes mortos | examinar | `poisoned poco` | Contar a Mira | `investigar-poco` e `avisar` (sim) |
| A luz roxa | Luz noturna do mirante; árvores secas apontando | olhar longe, seguir | `seal-revealed` | Ir ao selo; consultar Tomas | arco da Maldição: `cenario-origem` (sim) |
| As cenouras roídas | Horta mordida, pegadas pequenas na lama | examinar, rastrear | `found-den` (ao seguir até a raiz) | Dar ervas a Pipo | `lebrinos-gentileza` e `cenario-guardiao` (sim) |
| A pegada branca | Rastro claro que só aparece à noite, na mata | rastrear (melhor com Andarilho) | `white-boar-sign` | A lenda contada por Tomas na taverna | `javali-branco` (sim; falta o sinal) |
| A moeda | Brilho raro num veio da mina (sorte determinística) | minerar, pegar | `old-coin` | Mostrar a Lia quando a caravana está | `colecionador` e `ruins-map` (sim) |
| A bigorna | Marca na bigorna de Brom igual a uma inscrição das ruínas | examinar, ler | `legacy-hint` | Mostrar a Brom; explorar o salão | `cenario-bigorna` e `lamina-proibida` (sim) |
| Os veios roxos | Minério que brilha roxo; Brom recusa | examinar, mostrar | `ore-cursed` | Mostrar a Garrick | `veios-roxos` (sim) |
| A canção | Canto ao amanhecer vindo da capela | escutar (estar lá na hora) | `heard-song` | Ajudar a vila de "corpo e alma" | `cancao-alvorada` (sim) |
| A lápide sem nome | Lápide gasta no cemitério | ler | nova: `nameless-grave` | Mostrar a Elena ou a Tomas | **novo**: liga o arco do selo a Asterion |
| Nino sumido | Mãe chamando, pegadas até o celeiro | procurar, rastrear | `child-lost` (local) | Achar e trazer (carregar) | `nino-perdido` (sim; falta o caminho físico) |
| Os botões | Botões brilhando na grama da praça | pegar (hábito) | contador de feitos | — | `achar-botoes` (habilidade, sim) |

**Pistas erradas de propósito:** algumas crenças podem ser falsas ou velhas. Por exemplo, um aldeão diz que a doença é castigo da capela. O motor já separa verdade de crença. Mostrar a crença errada não destrava nada, e o NPC pode corrigir ("Bobagem, eu vi o poço"). Isso dá peso à procedência no Caderno.

## 9. Verbos

O menu de ações vira **verbos contextuais** que funcionam em qualquer lugar. O motor continua decidindo. O cliente pede as possibilidades em `/v1/affordances` e mostra o verbo certo no lugar certo.

| Verbo | Entrada | Onde serve | No motor |
|---|---|---|---|
| Andar, correr, esquivar | WASD, R | Sempre | Cliente |
| Golpear e habilidades | botão esquerdo, 1–4 | Combate | Cliente; o motor recebe o acontecimento |
| Interagir | E (o alvo mais próximo, com destaque) | NPC, objeto, porta | Escolhe a affordance principal |
| **Examinar** | segurar Alt ou o botão do meio; o cursor vira lupa | Qualquer sinal, objeto ou lugar | Ação genérica `examinar` sobre um sinal (§10.2) |
| **Escutar** | ficar parado perto de quem conversa | Taverna, praça, portão | Conversas ouvidas (§10.5) |
| **Contar ou mostrar** | segurar E perto de um NPC; abre uma roda com o que você sabe ou carrega | Qualquer NPC | Parâmetro do tipo crença (§10.3) |
| Dar | na mesma roda, aba itens | NPC | Ação com custo em `num` (ervas, minério) |
| Pegar, carregar, largar | E; o personagem leva o objeto nas mãos | Sacos, ervas, Nino, minério | Cliente para o objeto; o motor para o feito ("entregou") |
| Tocha | T | Noite, mina, sarças, lobos | Cliente (luz, fogo) e acontecimento confirmado (sarça queimada abre caminho) |
| Rastrear | segurar Shift parado | Mata, lama, neve | Sinais visíveis só com habilidade ou crença (§10.2) |
| Sentar, dormir | E no banco ou na cama | Banco, taverna, casa | `descansar` e `sonhar` (já existem); o tempo passa para o jogador |
| Ler | E em placa, lápide, inscrição ou quadro | Vila, ruínas | Ação `ler` que gera crença |
| Tocar o sino | E no sino da praça | Praça | Acontecimento: a vila se reúne; mau uso dá infâmia |
| Deixar marca | M; escolhe um símbolo da lista fixa | Qualquer lugar | Comando de marca (§10.7) |
| Olhar longe | Z no mirante ou num ponto alto | Pontos altos | Cliente: câmera abre e revela marcos; o motor registra "avistado" |

Regra *Tunic*: **todo verbo tem resposta**, nem que seja uma frase ("A água tem cheiro de ferro."). Tentar nunca é desperdício: é assim que o jogador aprende que o mundo responde.

## 10. Sistemas novos

### 10.1 Chegada e primeiro feito (motor + universo)
- O universo ganha `player.onJoin`: efeitos aplicados no `join` (região inicial `estrada`, fato `met lia`, crença inicial "Valdoria tem uma vila a oeste").
- Novo limite `firstOfferAfterDeed: true`: nenhuma oferta antes do primeiro feito do jogador. O motor já conta feitos (`Deeds`).
- Teste: `TestNewcomerGetsNoOfferBeforeFirstDeed`.

### 10.2 Sinais (motor + universo): a peça central
Um sinal é a **consequência perceptível de uma verdade escondida**, que não revela a causa.

```json
"signs": [{
  "id": "agua-turva", "region": "vila", "spot": "poco",
  "when": {"fact": {"p": "poisoned", "s": "poco"}},
  "look": "water-murky",
  "text": "A agua do poco esta turva e cheira a ferro.",
  "perceive": {"any": [{"num": {"e": "vila", "k": "health", "op": "<", "v": 80}}, {"has": {"skill": "olho-de-curandeira"}}]},
  "examine": [{"op": "observe", "fact": {"p": "poisoned", "s": "poco"}}],
  "farFrom": ["estrada"]
}]
```

- A visão ganha `signs`: os sinais ativos na região do observador, mais os de `farFrom` (vistos de longe), filtrados por `perceive`. Os dados são só `id`, `spot`, `look` e `text`, nunca o fato.
- `examinar` com o sinal como argumento aplica `examine` (crença por observação). Sinal + verbo dá crença: é o "mostrar antes de contar".
- Habilidades mudam a percepção: Olho de Curandeira vê sinais de doença, Andarilho vê rastros e Passo Leve ouve mais longe.
- Testes: `TestSignsAppearWithoutRevealingTheCause`, `TestSkillRevealsHiddenSign` e `TestExamineSignCreatesObservedBelief`.

### 10.3 Contar e mostrar (motor)
- Novo tipo de parâmetro `belief` em `ActionDef.Params`: liga o parâmetro a uma crença que o ator **tem** (filtrável por predicado). Ninguém conta o que não sabe; mentir fica para depois do MVP.
- Efeito: o NPC recebe a crença com fonte `communication` e `From` = jogador. Agentes que dependem de `knows` reagem sozinhos, como Mira prepara o antídoto quando sabe do veneno.
- Reações declaradas (`reactions`) por NPC e predicado: falas, relação, missão oculta. Contar algo que o NPC já sabe ("Eu sei, criança.") ou que é falso tem resposta própria.
- `contar-veneno` e `mostrar-moeda` viram casos de uma ação genérica `contar`/`mostrar`, sem perder os títulos.
- Testes: `TestTellOnlyWhatYouBelieve`, `TestToldNpcActsOnNewBelief` e `TestWrongBeliefIsCorrected`.

### 10.4 Rotinas (universo + motor)
- `routines` por NPC: faixas de hora → região e `spot` (um nome; o cliente sabe onde fica). O motor aplica nas viradas de hora, de forma determinística. Objetivos urgentes de agentes têm prioridade, e acontecimentos podem suspender a rotina (`suspendWhen`).
- `Seen` na visão ganha `spot` e `doing` (rótulo da atividade: "martelando", "cantando").
- Testes: `TestRoutineMovesNpcByHour` e `TestOutbreakSuspendsRoutine`.

### 10.5 Conversas ouvidas (universo + motor)
- `chatter`: falas entre NPCs presos a um `spot`, com condição sobre **o que os falantes acreditam**. O que se ouve é coerente com a mente deles, não com a verdade.
- A cada N ticks, o motor escolhe uma fala elegível por lugar (padrão determinístico). O Jev pode escolher entre as elegíveis, como já faz no diretor.
- Quem está na região recebe a crença com fonte `communication` (ouvida) e o evento `chatter`. O cliente mostra um balão sobre os NPCs.
- O boato (`gossip`) passa a ter voz: hoje ele só muda crenças em silêncio.
- Testes: `TestChatterFollowsSpeakerBeliefs` e `TestOverheardBeliefHasSource`.

### 10.6 Lugares descobertos e mapa com névoa (motor + cliente)
- Predicado `discovered` (jogador → região ou marco), afirmado ao entrar, ao avistar (`olhar longe`) ou por esboço comprado de Tomas.
- O cliente só mostra no minimapa, e só rotula, o que foi descoberto. Os rótulos 3D somem; o destaque aparece só ao chegar perto.
- A Toca e a brecha da paliçada ficam fora do mapa até serem achadas.

### 10.7 Marcas de viajante (motor + cliente)
- Comando `mark` (origem `player`) com `glyph` de uma lista fixa do universo ("perigo adiante", "olhe para cima", "algo escondido", "descanse aqui", "não confie") e `spot`.
- O motor guarda o fato público com autor, região e validade, limitado a N marcas ativas por jogador. Outros jogadores na região veem a marca e podem "concordar", o que aumenta a validade.
- Não há texto livre, o que elimina o problema de moderação.
- Testes: `TestMarksAreSeenByOthersInRegion` e `TestMarkLimitPerPlayer`.

### 10.8 Mudanças permanentes e monumentos (cliente + universo)
- Tabela de **apresentação** no cliente (`clients/godot/data/presentation.json`): fato, sinal, evento ou capítulo → mudança de cena. Exemplos: poço limpo com flores, telhados consertados, floresta replantada, estátua com o nome de quem restaurou o selo (capítulo `By`), portão reforçado depois da Resistência.
- É regra de apresentação, não do jogo: outro cliente (Unreal, web) faria a própria tabela.

### 10.9 Estigmas (universo + cliente)
- Fatos privados com efeito público, por exemplo `seal-touched`. NPCs reagem pela regra de reações (§10.3): Orin desconfia, Elena oferece purificar. Lobos evitam o jogador, e ele ouve sussurros à noite.
- O cliente mostra no personagem: um brilho na mão e um sinal visível a outros jogadores (um sinal do tipo jogador).

### 10.10 Cliente: fluidez e apresentação
- **SSE** (`/v1/stream/{id}` já existe) no lugar do polling de 1 s. A visão completa só ao entrar e ao reconectar.
- **Animação otimista:** o personagem já age ao pedir. Recusa do motor vira uma reação suave ("hm, não deu"), nunca um travamento.
- **Sistema não modal:** a oferta é um cartão lateral que espera; Y/N ou clique. Uma por vez, com entrada bonita na primeira vez.
- **Caderno** (J), com abas:
  - **Pistas**: crenças com fonte e momento, ligadas entre si, e perguntas "?".
  - **Pessoas**: quem conheço, relação, rotina observada.
  - **Lugares**: o mapa desenhado.
  - **Feitos**: missões e habilidades.
- **"Enquanto você esteve fora":** resumo ao entrar, a partir dos eventos desde a última revisão vista.
- **Balões de fala** acima dos NPCs (conversas, cumprimentos de quem te conhece) no lugar do log lateral.
- **Hora e clima:** noite escura de verdade (tocha útil), chuva na tempestade e lanternas acesas pelas rotinas.
- **Vila em cômodos-caixa:** portas abrem para interiores simples (forja, taverna, capela) sem carregamento; o teto some.

### 10.11 Ferramentas de conteúdo e garantia
- **Bot de descoberta** (`engine/scenarios`): um jogador que só usa affordances, sinais e verbos, sem ler o universo, precisa alcançar cada enigma dentro de N ticks. Garante que tudo tem solução sem informação externa (o princípio de *Blue Prince*).
- **Lint do universo** (`Compile` ou `worldsim lint`): toda missão oculta tem pelo menos um caminho de sinal ou conversa até a crença de que depende. Todo sinal tem `examine`. Todo `spot` citado existe na tabela de lugares do universo.
- **Telemetria de playtest** no cliente (JSONL local): tempo até o primeiro feito, verbos usados, tempo parado sem ação nova, segredos achados, onde a pessoa morreu e o que abriu no Caderno.

## 11. Fluidez: metas técnicas

| Meta | Valor |
|---|---|
| Entrada → resposta visual | < 100 ms (local, otimista) |
| Ação → confirmação do motor visível | < 500 ms (SSE em loopback) |
| Quadros | 60 fps estáveis na máquina atual; nenhuma travada > 50 ms ao trocar região |
| Janelas que param o movimento | zero |
| Cliques até uma interação comum | 1 (E ou clique) |
| Tempo de carregamento após entrar | 0 (mundo inteiro carregado; interiores sem cena separada) |

## 12. Fases

Cada fase termina **jogável**, com validação registrada em `Docs/Validation/` e commit no `main`. Tamanho: P (uma rodada), M (duas a três), G (quatro ou mais).

| Fase | Objetivo | Motor | Universo | Cliente | Pronto quando | Tam. |
|---|---|---|---|---|---|---|
| **F0 Base** (feita em 22/10) | Fluidez e dados no lugar | Lugares e `spot` no universo; `onJoin` | Tabela de lugares (spots) da vila e das regiões | SSE; tabela de apresentação; POIs lidos do universo; rótulos e mapa só para o descoberto; telemetria | Mesma jogabilidade de hoje com push e sem segredos expostos; telemetria gravando | M |
| **F1 Vila viva** (em grande parte feita em 22/10, ver Validation/Godot.md) | A vila parece um lugar | Rotinas, `spot` e `doing`; conversas | Rotinas dos 7 NPCs da vila; 30–40 falas; quadro de avisos | Nova planta da vila; cômodos-caixa; balões; noite e tochas; sino | Um observador parado na praça por 12 min vê o dia acontecer e ouve 5 crenças diferentes | G |
| **F2 Chegada** (feita em 22/10, com lacunas listadas em Validation/Godot.md) | De estranho a alguém | `firstOfferAfterDeed`; reações de cumprimento | Chegada pela caravana; falas de Orin, Lia e aldeões para estranhos e conhecidos | Abertura; primeira janela do Sistema com cerimônia; "Enquanto você esteve fora" | Playtest: ninguém recebe missão antes de agir; todos sabem dizer quem os conhece | M |
| **F3 Saber** (feita em 22/10; faltam só a lupa e NPCs que erram de propósito, ver Validation/Godot.md) | Conhecimento como progresso | Sinais; `examinar`; parâmetro `belief`; reações; `discovered` | Sinais dos 11 enigmas; pistas erradas; reações de cada NPC | Caderno (4 abas); roda contar/mostrar; lupa; mapa desenhado e esboços de Tomas | O bot de descoberta resolve poço, cenouras e moeda só com sinais; o jogador vê a fonte de cada crença | G |
| **F4 Lá fora** (feita em 22/10; falta só playtest, ver Validation/Godot.md) | Vontade de explorar | Sinais de longe (`farFrom`); acontecimento "sarça queimada" | Regiões redesenhadas; inscrições de Asterion; atalho mina→ruínas | Mapa de centro e raios; mirante; tocha; rastrear; mina escura; ruínas com leitura progressiva | De qualquer lugar aberto se vê um marco não visitado; 4 enigmas externos solúveis | G |
| **F5 Surpresa e permanência** (feita em 22/10; falta só playtest, ver Validation/Godot.md) | O mundo muda e lembra | Estigmas (reações a fatos privados); validações | Acontecimentos com presença física (caravana, tempestade, feira, desabamento); monumentos por capítulo | Presença física dos acontecimentos; monumentos; estigma visível; sinais raros noturnos | Em 3 sessões seguidas, cada uma traz algo que a anterior não tinha | M |
| **F6 Os outros** | MMO de verdade | Marcas; segredos como item de troca entre jogadores | Glifos; reações a jogadores famosos | Marcas no mundo; fofoca sobre outros jogadores; 2–4 clientes simultâneos | Dois jogadores veem crenças diferentes da mesma vila e a mesma marca e monumento | M |
| **F7 Playtest do MVP** | Validar com gente | Ajustes de ritmo | Ajuste de conteúdo | Polimento de sensação | Critérios do §13 atendidos com 3–5 pessoas novas | M |

Ordem e dependências: F0 → F1 → F2 → F3 → F4. F5 e F6 podem andar em paralelo depois de F3. F7 fecha.

## 13. Critérios de aceite do MVP

Medidos no playtest (telemetria + conversa) e nos testes automáticos:

1. Ninguém recebe oferta do Sistema antes do primeiro feito (teste no motor e telemetria).
2. Em 60 min sem ajuda externa, cada pessoa acha **pelo menos 2 de 4 segredos ocultos** (toca, pegada branca, moeda, canção ou lápide), e **duas pessoas acham coisas diferentes**.
3. Cada pessoa usa **6 ou mais verbos distintos** na primeira hora.
4. Ninguém fica **mais de 3 min sem uma ação nova** sem saber o que fazer (tempo parado na telemetria; pausa voluntária não conta).
5. Ao fim, cada pessoa sabe dizer **uma pergunta que ficou aberta** e **o que quer fazer ao voltar**.
6. Zero janelas modais que param o movimento; metas de fluidez do §11.
7. Dois jogadores simultâneos: crenças diferentes, sinais e monumentos iguais.
8. O bot de descoberta alcança todos os enigmas; `gofmt`, `go vet` e `go test` passam; o teste de imports do núcleo continua passando.
9. Jev ligado em todos os playtests (latência, custo e taxa no prazo registrados); com o Jev desligado, a hora inteira continua jogável.

## 14. Riscos e decisões

| Risco | Mitigação |
|---|---|
| Custo de escrever conteúdo (sinais, falas, reações) | Formatos pequenos e reutilizáveis; lint; bot de descoberta. Depois do MVP, o Jev pode **propor** falas, sempre validadas pelo `Compile` e revisadas |
| Sinais vazarem a verdade | O sinal mostra efeito, nunca causa; teste dedicado; visão sem o fato |
| Rotinas e conversas quebrarem o determinismo | Tudo dentro do `Step`, por hora e ordem de ID; o Jev só escolhe entre opções, fora do lock |
| Excesso de UI (Caderno, roda, mapa) | Uma tecla por função; nada modal; a primeira hora ensina uma coisa por vez |
| Jogadores travados num enigma | Mais de um caminho por enigma (sinal, conversa, esboço de mapa); falas de Tomas como dica tardia |
| Combate dominar a sessão | Na primeira hora, o perigo é ocasional; a exploração é o centro |

**Decisões para o usuário (podem esperar até a fase indicada):**
1. **Mentiras (F3):** o jogador pode contar algo que não acredita? Proposta: não no MVP; depois, como habilidade (Língua de Prata).
2. **Mapa (F3):** só desenhado andando, ou também esboços comprados de Tomas? Proposta: os dois.
3. **Perda ao cair (F4):** hoje volta à vila sem custo. Proposta: perde o que carrega nas mãos e uma crença "fresca" vira "confusa".
4. **Tamanho do playtest (F7):** quantas pessoas e se joga junto ou separado. Proposta: 4 pessoas, 2 sessões de 2.

## 15. Fontes da pesquisa

- [GDC: Curiosity-Driven Exploration, the design of Outer Wilds](https://www.gdconf.com/news/attend-gdc-and-learn-how-outer-wilds-nailed-curiosity-driven-game-design) · [GDC Vault: Sparking Curiosity-Driven Exploration Through Narrative](https://gdcvault.com/play/1027008/Independent-Games-Summit-Sparking-Curiosity) · [Xbox Wire: dicas dos criadores de Outer Wilds](https://news.xbox.com/en-us/2019/05/30/outer-wilds-available-today-xbox-game-pass/)
- [Game Developer: entrevista com Andrew Shouldice (Tunic)](https://gamedeveloper.com/design/tunic-interview)
- [GMTK: How Nintendo Solved Zelda's Open World Problem](https://gmtk.substack.com/p/how-nintendo-solved-zeldas-open-world) · [GamesBeat: química em Breath of the Wild](https://gamesbeat.com/the-legend-of-zelda-breath-of-the-wild-makes-chemistry-just-as-important-as-physics/)
- [GDC Vault: What Happened Here? Environmental Storytelling](https://gdcvault.com/play/1012647/What-Happened-Here-Environmental) · [Nieman Storyboard: Harvey Smith sobre narrativa ambiental](https://niemanstoryboard.org/2011/01/14/harvey-smith-on-environmental-storytelling-and-embedding-narrative/)
- [RPG Codex: Making of Gothic Remake, Bringing the World to Life](https://rpgcodex.net/article.php?id=12763)
- [Zelda Wiki: Bombers' Notebook](https://zeldawiki.wiki/wiki/Bombers%27_Notebook)
- [Superjump: Getting Lost (by Design) in Hollow Knight](https://www.superjumpmagazine.com/getting-lost-by-design-in-hollow-knight/)
- [The Ringer: Elden Ring multiplayer subculture](https://www.theringer.com/2022/07/18/video-games/elden-ring-multiplayer-subculture-lingo-let-me-solo-her) · [arXiv: The Dark Souls of Archaeology](https://ar5iv.labs.arxiv.org/html/2204.10949)
- [Rare: mudanças no mundo emergente de Sea of Thieves](https://rarethief.com/changes-to-the-emergent-world-of-sea-of-thieves/) · [Windows Central: entrevista com a Rare](https://www.windowscentral.com/sea-thieves-anniversary-update-interview)
- [MassivelyOP: Shard of the Herald](https://massivelyop.com/2018/01/30/re-examining-the-significance-of-asherons-calls-shard-of-the-herald-event-on-its-first-deathiversary/)
- [PC Gamer: Shadows of Doubt](https://www.pcgamer.com/au/shadows-of-doubt-is-a-wildly-ambitious-murder-mystery-set-in-a-fully-simulated-sci-fi-city) · [Shadows of Doubt DevBlog #18](https://colepowered.itch.io/shadows/devlog/111292/shadows-of-doubt-devblog-18-scripted-missions-in-a-procedural-world) · [Archania: Return of the Obra Dinn](https://archania.org/p/the-symbolic-world/symbolic-works/video-games/return-of-the-obra-dinn)
- [Unity: Systems-driven design in Caves of Qud](https://activation.unity3d.com/resources/systems-driven-design-in-caves-of-qud) · [AAAI: boatos em Dwarf Fortress](https://cdn.aaai.org/ojs/12963/12963-52-16480-1-2-20201228.pdf)
- [Thinky Games: entrevista com Tonda Ros (Blue Prince)](https://thinkygames.com/features/interview-how-myst-riven-and-tabletop-games-built-the-foundation-of-blue-prince/)
- [The Review Geek: Shangri-La Frontier, episódio 3](https://www.thereviewgeek.com/shangrila-frontier-s1e3review/) · [Dashtoon: guia de personagens de Shangri-La Frontier](https://dashtoon.com/blog/shangri-la-frontier-character-guide)
- [Wikipedia: Overgeared](https://en.wikipedia.org/wiki/Overgeared) · [TV Tropes: Overgeared](https://tvtropes.org/pmwiki/pmwiki.php/Literature/OverGeared)
- [Anime News Network: primer de Log Horizon](https://www-d.animenewsnetwork.com/feature/2021-01-12/back-to-the-horizon-a-beginner-primer-on-log-horizon/.166964)
- [Unwinnable: Heaven's Vault, A History in Translation](https://unwinnable.com/2018/10/25/a_history_in_translation_108/)
