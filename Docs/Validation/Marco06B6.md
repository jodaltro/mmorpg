# Marco 06B.6 — experimento PixelLab

2026-10-15. **Geração concluída; caminhada rejeitada artisticamente pelo agente.** Não integrada na Unity e sem aprovação definitiva do usuário. O resultado não alcançou a caminhada profissional solicitada. Nenhum retry foi consumido.

## Resultado para revisar

- [Comparação animada: anterior à esquerda, PixelLab à direita](../../ArtSource/References/PixelLab/Marco06B6/previews/old-vs-pixellab-two-cycles.gif).
- [Prancha dos oito quadros](../../ArtSource/References/PixelLab/Marco06B6/previews/walk-south-contact-sheet.png), [GIF PixelLab](../../ArtSource/References/PixelLab/Marco06B6/previews/walk-south-two-cycles.gif), [rotações](../../ArtSource/References/PixelLab/Marco06B6/previews/rotations.png).
- [PNGs originais](../../ArtSource/References/PixelLab/Marco06B6/walk_south/original/Idle/animations/Mmorpg_Hero_Walk_South/south), [QA e hashes por frame](../../ArtSource/References/PixelLab/Marco06B6/qa-report.json).

Prévias em nearest 4×, fundo neutro, sem novos desenhos/interpolação. Mesma densidade de pixels, sem redimensionar personagens independentemente. Uma translação fixa `(0,+12)` de todo o ciclo novo alinha a referência de chão y76 a y88. Os PNGs originais não são editados. Não há estabilização individual que esconda tremor. A prancha também usa essa translação. O GIF codifica dois ciclos, 90 ms/frame, 720 ms/ciclo; a versão antiga mantém suas duas poses, cada uma durante 360 ms para comparar ciclos de igual duração. **Essa cadência comparativa é mais lenta que os 125 ms/pose da versão antiga no jogo.** Não usar a fluidez dessa comparação como medição de FPS de gameplay. O GIF não solicita repetição infinita.

## Ferramentas e orçamento real

PixelLab MCP foi realmente utilizado, diretamente, após consultar [a documentação oficial](https://api.pixellab.ai/mcp/docs) e as descrições das ferramentas expostas. `get_balance` e `list_characters` iniciais: trial, US$0,00, 40 gerações, nenhuma usada, nenhum personagem existente. Limite desta execução: 12 gerações; sem compras, upgrade, pro/pro_flash, ImageGen ou geração REST.

| Operação | Resultado | Consumo |
|---|---|---|
| `mcp__pixellab__create_character` | v3 por referência pública, 4 vistas, low top-down, 96×96 | 2 |
| `mcp__pixellab__animate_character` | template `walking-8-frames`, somente `south`, ai_freedom=0 | 1 |
| Total | 8 frames sul gerados | **3** |

Saldo confirmado após criação: 38; após animação: **37**, US$0,00. Bônus diário inicial 5, final 2; a documentação da ferramenta explica que esse contador cai com a mesma cobrança, não é consumo adicional. Restaram 9 do teto autorizado para esta execução, deliberadamente não utilizados.

- Personagem `Mmorpg_Hero_Master`: `f104ef15-9fad-4dce-8cfd-215cec6f8763`.
- Job de criação: `9649cdab-cbd2-4e3f-b0a8-8793d766748f`.
- Job de caminhada sul: `2be84341-e0db-4828-a3dc-b7c8f35149dc`.
- Grupo da animação: `1248e95a-cf6a-4155-bb66-2798c829916f`.
- Animação: `5a687413-25fb-4333-bc84-2a890ef911ea`.

[Log de geração e argumentos](../../ArtSource/References/PixelLab/Marco06B6/generation-log.json), [pedido da animação](../../ArtSource/References/PixelLab/Marco06B6/animation-request.json), [resultado do MCP](../../ArtSource/References/PixelLab/Marco06B6/character-result.json). Downloads oficiais dos resultados prontos foram usados, sem autenticação adicional ou segredos no repositório.

## Revisão artística

A referência local está frontal para sul. Cabelo castanho, roupa/capa azul, ombreiras cinza e couro continuam reconhecíveis no personagem gerenciado. A vista sul não contém lâmina longa; não é idêntica pixel a pixel ao original. **Oeste/norte/leste vieram com espadas embutidas**, apesar do prompt sem armas: rejeitadas, sem importação. A causa provável é a interpretação dos pixels dourados junto à luva como arma; é hipótese. Esse defeito foi informado antes de consumir a geração sul. Apenas a vista sul foi admitida preliminarmente para o experimento; o conjunto de rotações nunca foi aprovado como produção.

Os oito frames foram inspecionados individualmente em ampliação nearest, além da prancha sequencial:

| Frame | Observação |
|---|---|
| 000 | Pé do lado direito da imagem adiante; identidade reconhecível |
| 001 | Mesmo pé adiante; pouca absorção legível |
| 002 | Mesmo pé dominante; passagem da perna oposta não convincente |
| 003 | Repete leitura do apoio anterior; pouca mudança corporal |
| 004 | Ainda mesmo pé adiante; fragmento claro junto à mão direita anatômica |
| 005 | Pé oposto passa a ficar adiante; reversão existe, sem oito fases claras |
| 006 | **Rosto desaparece/cabeça aparenta vista traseira; massa cinza estranha junto à bota** |
| 007 | Rosto reaparece; pé oposto adiante; retorno a 000 troca silhueta perceptivelmente |

Não há evidência convincente das oito fases contato/absorção/passagem/elevação. Há alternância parcial da perna dianteira, insuficiente para aprovar transferência de peso natural. Cabeça não mantém continuidade em 005→006→007, e capa/braços são rígidos em várias poses. Fragmentos claros sugerem contaminação de arma/pose, mas não foi feita atribuição técnica definitiva da causa. A falha principal é **artística na saída gerada**; padding ou pivôs não corrigem rosto, desenho e apoios.

**Não aprovado artisticamente pelo agente.** Não é uma melhoria suficiente para substituir o ciclo antigo. Não se declara reprodução em tempo real inspecionada pelo agente: a avaliação foi dos PNGs individuais e da sequência; o GIF fica disponível para revisão visual do usuário. A aprovação do usuário continua pendente e não foi presumida.

## Validação técnica e Unity

Validados: oito PNGs RGBA 96×96, transparência real, oito conteúdos distintos por hash RGBA e dimensões consistentes. Altura visível 51–53 px, contra 50 px do idle original: sem necessidade de escala fracionária. O deslocamento vertical no canvas é tratável por translação fixa e foi documentado exclusivamente na prévia. Transparência válida não elimina a massa cinza desenhada no 006.

**Pivôs e mão direita por frame não foram aprovados.** O [manifesto candidato](../../ArtSource/References/PixelLab/Marco06B6/manifest-candidate.json) tem status rejeitado e âncoras nulas, intencionalmente não importável como produção. Não foram copiadas coordenadas antigas nem fabricadas âncoras para uma arte rejeitada. A espada do jogo permanece no sistema existente; seu contato com esta animação nova **não foi validado**.

A cena `Marco06B6PixelLabPreview.unity` não foi criada, pois o gate artístico preliminar falhou. Cena B5, prefabs, fontes aprovadas, ProductionCharacterSet, ProductionSpriteAnimator, SwordSwing, Rigidbody2D, input e autoridade ficaram intactos. `production.py` não foi executado ou modificado. Não foi necessário criar adaptador de importação para um candidato rejeitado.

Editor conectado: Unity 6000.6.5f1, CLI 1.0.0-beta.13 atualizada. Já estava em Play na cena B5 ao começar; mantido nesse estado. `set_autotick`: habilitado a 16 ms. Leituras de frame avançaram de **4828110 para 4879447**. Console após cursor 21080 da sessão `403fa373779c44ccb34bfb5592223b5b`: nenhuma entrada nova de erro; console atual com zero erros, compilationFailed=false. Erros de 14/10 e de marcos anteriores existem no buffer histórico e não são desta execução.

Não houve alterações C#/Assets; **recompile/recompile_status, teste de input da caminhada nova, parada/retomada, mira contrária, empunhadura nova e inspeção em cena experimental não foram executados**, pois a integração foi barrada antes deles. Nenhuma suíte EditMode/PlayMode/backend ou build foi executada. Essa leitura do Editor existente não valida gameplay do novo material.

## Reprodução e pendências

`python Tools/ArtPipeline/pixellab_preview_b6.py` refaz prévias e métricas exclusivamente dos PNGs baixados, sem qualquer chamada de geração e sem escrever em Assets ou nas fontes do Hero. Originais e ZIPs estão separados em `character/original` e `walk_south/original`.

Uma futura tentativa poderia investigar skeleton-v3 para maior estabilidade, custo anunciado de 2–4 gerações/direção. Isso é hipótese a avaliar, não foi executado nem reservado. Antes de outra geração, revisar estas evidências e decidir como retirar a ambiguidade de arma da referência e corrigir a continuidade da cabeça. Não reutilizar automaticamente as rotações reprovadas. O objetivo de uma caminhada profissional permanece pendente.
