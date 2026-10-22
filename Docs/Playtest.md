# Playtest do MVP (F7)

Roteiro para rodar sessões com pessoas de verdade e medir os critérios de [MvpPlan.md](MvpPlan.md) §13. **Ninguém rodou este playtest ainda**: o que existe é o kit (registro automático, relatório e este roteiro) e as medições feitas por robôs, que não substituem pessoas.

## Antes de começar

1. Motor com o Jev ligado (`worldsim serve ... -advisor jev -env-file .env`, mundo novo: `-on-universe-change new-world`), no ritmo normal de Valdoria (15 s por tick, um dia de 12 min).
2. Um computador por pessoa (ou um só, em sessões separadas) com o Godot 4.7 e o projeto `clients/godot`. Cada pessoa joga com um nome e um `--player=<id>` próprios:
   `Godot --path clients/godot -- --player=ana --name=Ana --telemetry=<pasta>/ana.jsonl`
3. Combine antes: **nada é gravado fora do computador**; o registro (`telemetry`) guarda ações, lugares e tempos, nunca vídeo nem voz. Quem quiser pode apagar o arquivo.
4. Para sessões em dupla, os dois entram no mesmo mundo e podem se ver e conversar entre si (marcas de viajante e segredos entre jogadores valem aqui).

## Como conduzir (uma hora)

- **Não explique o jogo.** Diga só: "Você acabou de chegar a uma vila. Jogue como quiser, em voz alta se quiser. Não vou ajudar." Os controles estão no rodapé da tela (WASD, mouse, E, C, M, T).
- **Anote sem interferir:** o que a pessoa olha primeiro, quando fica sem saber o que fazer (e se as dicas do jogo aparecem), o que a faz rir, o que ela repete, o que ela evita.
- **Dicas do jogo:** depois de 2,5 minutos sem nada novo o próprio jogo sugere algo. Anote se a dica ajudou ou foi ignorada.
- **Não conte segredos.** Se a pessoa pedir ajuda, responda "o que você tentaria?".
- **Pare em 60 minutos**, ou antes se a pessoa quiser. Peça para fechar o jogo (o registro grava o fim da sessão).

## Perguntas ao final (anote com as palavras da pessoa)

1. Me conte o que aconteceu, do começo.
2. O que você descobriu sozinho(a) que mais te surpreendeu?
3. Ficou alguma pergunta sem resposta? Qual?
4. O que você quer fazer quando voltar?
5. Teve um momento em que não soube o que fazer? Quando? O que fez?
6. Em algum momento sentiu que o jogo estava te dizendo o que fazer em vez de você descobrir?
7. (em dupla) O que você viu que a outra pessoa não viu? Vocês trocaram informação?
8. Alguma coisa travou, demorou para responder ou pareceu "mole" ao controlar?

## Relatório

```bash
python clients/godot/tools/playtest_report.py <pasta>/ana.jsonl <pasta>/beto.jsonl
```

Ele confere o que um registro consegue responder:

| Critério (MvpPlan §13) | Como o relatório confere |
|---|---|
| 2. Em 60 min, ao menos 2 de 4+ segredos ocultos achados | vestígios ocultos examinados (cenouras, bigorna, lápide, canto da capela, brilho na pedra, pegada branca, laje do musgo...) mais a Toca descoberta |
| 3. 6 ou mais verbos distintos na primeira hora | ações distintas que o motor aceitou |
| 4. Nunca mais de 3 min sem nada novo (pausa voluntária não conta) | maior intervalo entre "coisas novas" (ação nova, lugar, exame, marca, passagem...), descontadas as pausas em que a pessoa ficou parada e sem mexer |
| 5. Termina com uma pergunta em aberto | perguntas no Caderno ao fechar (o que a pessoa quer fazer ao voltar só ela diz) |
| 6. Fluidez | resposta do motor (p95 abaixo de 500 ms) e quadros acima de 50 ms |

Os critérios 1 e 7 e o 8 (testes automáticos do motor e Jev) estão em `Docs/Validation/`. Sessões com menos de 55 minutos não pontuam os critérios 2 e 3 (o relatório marca "?"). **Registre os resultados reais em `Docs/Validation/Playtest.md`, com a data, o número de pessoas e o que o relatório disse; nunca marque como aprovado o que não rodou.**
