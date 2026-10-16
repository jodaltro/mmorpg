# Marco 06B.7 — redesenho sul e quatro poses experimentais

**Resultado: protagonista redesenhado, caminhada ainda não aprovada. Sem integração Unity.** O novo desenho tem clusters mais nítidos que o original reamostrado e supera o laboratório geométrico em identidade, mas não atingiu a caminhada natural solicitada. A expansão para outras vistas e a cena experimental foram interrompidas no gate B. Não há protagonista definitivo aprovado nesta entrega.

## Arquivos para revisar

- [Idle, comparação com anterior e guias](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/idle-comparison.png).
- [Quatro poses da revisão 2](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/walk-poses.png).
- [GIF ampliado, dois ciclos](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/walk-4x-two-cycles.gif), [GIF nativo](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/walk-native-two-cycles.gif).
- [Comparação com anterior](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/old-vs-b7.gif).
- [Silhuetas](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/walk-silhouettes.png), [apoios e mãos](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/walk-anchors.png).
- [Master sul editável](../../ArtSource/Labs/Aseprite/HeroB7/hero-master-south.aseprite), [caminhada revisão 2 editável](../../ArtSource/Labs/Aseprite/HeroB7/hero-walk-south-r2.aseprite).
- [QA de documentos, mãos e GIFs](../../ArtSource/Labs/Aseprite/HeroB7/qa-report.json), [QA de frames](../../ArtSource/Labs/Aseprite/HeroB7/review-r2/qa.json), [âncoras experimentais](../../ArtSource/Labs/Aseprite/HeroB7/hero-walk-south-r2.aseprite.anchors.json).

`hero-walk-south.aseprite`, `walk/` e `review/` conservam a primeira tentativa desta execução; `-r2` identifica a revisão recomendada para continuar editando. As duas versões têm quatro poses cada; não são oito fases de uma animação. `walk-r2/` contém PNGs RGBA, sheet e JSON nativos Aseprite. Nenhum desses arquivos substitui os PNGs de produção.

## Desenho e organização

Canvas 96×96, 32 PPU, altura visível do idle 54 px (y35–88). Pivô (48,70); chão de referência (48,88), não uma afirmação de contato de ambos os pés em todos os quadros. Cabelo castanho com mechas, rosto frontal, túnica azul sem capa, correia diagonal de couro, cinto, bolsa lateral, calça escura, botas, luvas e ombreiras pequenas de aço. Nenhuma espada incorporada. Cabeça tem aproximadamente 17 px incluindo rosto/pescoço; a proporção e a vista ainda precisam de avaliação artística no cenário.

Paleta intencional de 27 cores, com rampas curtas: contorno azul-carvão (#181c27), azuis (#1e314c/#2a4566/#395a7e/#517696), aço (#3a4651/#627581/#9badb3/#cbd3c8), castanhos do cabelo (#31201f/#523122/#794a2b/#a06939), pele quente, couro, calça e fivela ocre. PNGs atuais usam 26 cores opacas mais transparência. Sem dithering, gradientes, rotação fracionária, escala não uniforme ou suavização.

Doze camadas: Perna direita, Perna esquerda, Quadril, Tronco, Braço esquerdo, Braço direito, Cabeça, Cabelo, Detalhes roupa, Guias pivô, Guias contato e Marcadores mãos. As três últimas ficam ocultas ao exportar. Cada quadro de caminhada tem um cel independente em cada camada. A separação por perna anatômica permite reordenar cels/camadas depois; nesta vista sul a ordem é fixa e o cruzamento ainda precisa de acabamento.

Pixels foram construídos no Aseprite Lua com polígonos de vértices inteiros, preenchimento por ponto interno e linhas Bresenham, em `Tools/ArtPipeline/Aseprite/hero_b7.lua`. Não foram usadas imagens geradas ou serviços externos. Cabelo usa contorno assimétrico e clusters de três valores; rosto combina planos de pele e pequenos clusters dos olhos. Tronco tem ombros largos, cintura afunilada, gola em V, luz à esquerda e sombra lateral. Pernas têm coordenadas próprias de quadril, joelho, tornozelo e polígonos de botas, com solas/pontas distintas. Braços na revisão 2 têm cotovelos e mãos com variação lateral e vertical; não são imagens completas espelhadas/transladadas. O quadril desloca 1 px lateralmente nas passagens. Cabeça e tronco superior permanecem idênticos entre frames, o que evita tremor mas contribui para rigidez.

O idle foi exportado e comparado antes da animação: desenho próprio legível, suficiente para experimentar poses, sem aprovação definitiva. A primeira caminhada revelou braços quase telescópicos e quadril estático. A revisão 2 redesenhou antebraços, mudou contornos/cotovelos/mãos e recuou a bota de apoio nas passagens. Não foram adicionados intermediários para disfarçar os problemas.

## Revisão das poses

| Frame | Intenção | Avaliação e correção necessária |
|---|---|---|
| 000 | Contato esquerdo anatômico, à direita da imagem | Alternância legível; bota esquerda adiante, direita atrás. Contorno do joelho direito ainda muito simples; a mão direita baixa comunica contrabalanço, mas o antebraço é pesado. |
| 001 | Passagem direita sobre apoio esquerdo | Joelho converge para o centro, bota direita elevada. As botas ficam próximas demais e a perna esquerda de apoio não sustenta visualmente o quadril com clareza. Redesenhar separação entre joelho direito e canela esquerda em x44–55/y73–85. |
| 002 | Contato direito | Apoio oposto ao 000, braço esquerdo adiante. Mesmo problema de rigidez na ligação quadril/coxa; revisar x38–55/y68–79. |
| 003 | Passagem esquerda sobre apoio direito | Bota esquerda elevada e perna direita de apoio identificáveis por intenção; silhueta compacta e cruzamento ainda artificiais. Rever x39–53/y73–85, mantendo botas separadas. |

As pernas movem-se independentemente, com alternância explícita; isso não comprova transferência de peso correta. O contrabalanço dos braços ficou mais legível na revisão 2, mas cotovelos e mangas precisam de volumes mais orgânicos, principalmente x28–39 e x57–67/y58–76. Cabeça mantém os mesmos pixels entre os quatro quadros. O tronco superior fica parado demais: requer desenho de torção/ombros e absorção sem deformar cabeça. O retorno 003→000 troca rapidamente o pé elevado por contato e ainda parece uma marcha de quatro poses. Não declaro loop natural.

As silhuetas foram inspecionadas em prancha junto das imagens coloridas e overlays. A comparação anterior mostra ganho de nitidez dos clusters; o personagem antigo tem desenho mais inclinado/top-down e detalhes que a proposta simplifica. Não há evidência suficiente para afirmar superioridade artística global sobre o herói anterior ou sobre todos os candidatos rejeitados. O B7 evita os artefatos faciais anteriores, mas também não resolve a caminhada profissional. O padrão solicitado excedeu o resultado desta automação local; as regiões acima precisam de acabamento artístico manual.

## Mãos, espada e durações

| Quadro R2 | Mão direita | Mão esquerda | Apoio pretendido | Pé em balanço |
|---|---|---|---|---|
| 000 | (32,74) | (60,69) | esquerdo (53,88) | direito (42,83) |
| 001 | (35,72) | (61,72) | esquerdo (51,85) | direito (47,82) |
| 002 | (35,69) | (63,74) | direito (42,88) | esquerdo (53,83) |
| 003 | (34,72) | (60,72) | direito (44,85) | esquerdo (48,82) |

Todos os pontos de mão incidem em couro opaco das luvas, confirmado por pixel RGBA (94,59,40,255). Marcadores existem na camada oculta. Pivô constante (48,70); ângulo recomendado experimental -135°, profundidade +1. Isso prepara ligação futura pela `ProductionFrame.hand`, mas a espada **não foi conectada nem validada**. Esses JSONs auxiliares não têm o schema completo do manifesto de produção e não devem ser importados como Hero aprovado. O idle tem mão direita (34,72), esquerda (61,72).

Cada pose dura 120 ms; ciclo 480 ms. Cada GIF isolado de revisão codifica exatamente oito frames e 960 ms, dois ciclos, sem repetição infinita. O GIF comparativo mantém o clock nativo antigo de 125 ms/pose, ciclo 250 ms, e o candidato a 120 ms/pose, ciclo 480 ms. A amostragem de 10 ms arredonda mudanças antigas entre 120/130 ms; são 960 ms totais, dois ciclos B7 e 3,84 ciclos antigos. O encoder funde frames idênticos: 15 frames codificados na comparação, sem interpolação. Não desacelerar a versão antiga para fabricar uma vantagem. O GIF `walk-r2/preview.gif` é a exportação CLI bruta; use os GIFs de `review-r2/` para a revisão de dois ciclos.

`ProductionSpriteAnimator` foi lido: o clock soma deltaTime × clamp(velocidade observada/referenceSpeed,0.2,1.8), preserva a fase em paradas curtas e reseta após 0,18 s parado. Sua seleção é temporal ajustada pela velocidade, não um travamento exato do pé ao mundo. A 3,5 u/s e 32 PPU, são 112 px/s, 13,44 px por pose de 120 ms e 53,76 px/ciclo. A retração desenhada de apoio de apenas 3 px nas passagens é insuficiente para casar com esse deslocamento. **Cadência não calibrada; deslizamento provável.** Acelerar o ciclo para casar só esses 3 px faria a passada excessivamente rápida. É necessário ampliar/redesenhar a trajetória de apoio e testar em cena antes de ajustar duração; não alterei controlador, velocidade física ou referência de velocidade. Diagonais e idle→walk→idle não foram testados na Unity.

## Verificação executada e limites

- CLI local 1.3.18.6-x64 e Lua confirmados pelo validador existente em temporários: roundtrip do PNG original pixel a pixel, sheet/JSON e laboratório técnico.
- Master e as duas caminhadas reabertos em batch; 96×96 RGBA, 12 camadas, quantidade de cels por camada, durações e guias ocultas verificados por `inspect_b7.lua`.
- Quatro hashes RGBA distintos em cada versão, também distintos após recorte dos bounds (sem cópias apenas transladadas); alfa 0–255, sheet 384×96 e metadados de duração válidos.
- Mãos sobre pixels de luva e cabeça estável por hash de recorte. Todos os PNGs do Hero de produção ainda correspondem aos hashes de seu manifesto.
- Pranchas do idle, poses, silhuetas e apoios abertas para inspeção. A avaliação temporal se apoia na sequência e no retorno último→primeiro; não foi observado playback em tempo real do editor.
- Tentativa de inspeção pelo plugin computer-use falhou antes de inicializar: `failed to write kernel assets ... os error 3`. Não houve janela do Aseprite inspecionada; usaram-se os PNGs nativos/ampliados como alternativa solicitada.
- Unity não aberta/controlada nesta execução; nenhuma cena B7, importação, empunhadura em jogo, recompile, Play/input ou captura real Unity. Nenhuma suíte extensa, backend, build ou regra de combate alterada. Não se declara ausência de regressões por teste; o código de gameplay não foi modificado.

## Reprodução e continuação

Na raiz do projeto, use o helper existente para executar Lua com `--script-param mode=master` ou `mode=walk` e `--script-param output=<caminho-novo.aseprite>` antes de `--script Tools/ArtPipeline/Aseprite/hero_b7.lua`. O script atual gera o desenho de caminhada R2; o master inicial arquivado antecede a revisão dos gestos dos braços. Não reexecutar sobre documentos retocados manualmente. Exporte com `aseprite.py export --source <documento> --output <pasta-nova>`.

`python Tools/ArtPipeline/Aseprite/hero_b7_review.py -r2` gera as pranchas e os GIFs se `review-r2/` ainda não existir; recusa sobrescrever essa pasta. Abra `hero-walk-south-r2.aseprite` no Aseprite para continuar, mantendo camadas de guias desligadas na exportação. Não executar `production.py`.

A aprovação do usuário permanece pendente. Próximo trabalho artístico: corrigir passagens 001/003, curvas de joelho/tornozelo, torção dos ombros e trajetória de apoio; depois rever o loop e cadência. Somente após superar esse gate, preparar cena isolada e medir espada, movimento, diagonal, transições e proporção com cenário. Não houve revisão silenciosa do contrato de oito desenhos por direção: os quatro quadros continuam experimentais.

A autorização posterior do usuário para refatorar/recriar/substituir partes do projeto foi registrada no AGENTS.md durante este marco. Ela amplia liberdade técnica, sem converter este protótipo em arte aprovada. Commit/push incluem somente arquivos pertinentes ao B7 e essa memória; os experimentos PixelLab locais de outras tarefas não integram esta publicação.
