# Arco R7 V4 — mão fora da cabeça e continuidade do cotovelo

O usuário rejeitou a revisão V3: a mão atravessava a cabeça e braço/cotovelo tinham movimento estranho. O teste anterior media contato com a corda, mas não impedia interseção com o corpo. Contato correto com a arma não garantia uma pose válida.

Reprodução no arquivo V3: 18 dos 37 quadros apresentam vértices da luva do lado interno da superfície da cabeça; menor distância assinada medida -0,09688 m. Flexão máxima do cotovelo 156,49°. A mão se aproximava demais do ombro, e a escolha do plano da dobra produzia uma mudança acentuada do cotovelo.

## Mudança

- Perfil explícito em `ArtSource/Labs/Humanoid2026/R7/bow-anatomical-profile-v4.json`: plano de tiro, posição da arma, profundidade da puxada e polos dos cotovelos.
- Profundidade da deformação do arco adaptada a 72% da translação original. Tamanho do arco e comprimentos dos braços preservados; a corda efetivamente muda junto, sem deslocar apenas a mão para esconder a interseção.
- Puxada termina à direita do rosto; polo do cotovelo direito mais lateral e baixo. A mão acompanha a corda até o quadro 30; depois abre a pinça e retorna sem seguir o rebote.
- Cada pose é rejeitada se a amostragem da luva ficar a menos de 1,5 cm da superfície da cabeça, se a flexão direita exceder 125° ou se o cotovelo avançar mais de 10 cm entre quadros consecutivos. Alvos inalcançáveis continuam rejeitados, sem esticar ossos.

`bow_pose_constraints_r7.py` usa a superfície deformada dos polígonos com peso Head e os vértices reais da luva direita. Distância assinada pela normal mais próxima é uma verificação localizada; não é um detector universal de colisões de todo o corpo, cabelo, roupa ou de todas as armas.

Na passagem completa de geometria, 37 quadros por vista, a distância mínima amostrada foi 4,08 cm; não houve vértices penetrantes. Flexão direita entre 29,89° e 103,09°; maior passo do cotovelo 7,33 cm durante o retorno. Os números são geométricos, não aprovação artística.

## Feedback durante a revisão

Prancha de quatro momentos, frontal/lateral, mostrada antes da animação completa. Resposta do usuário: **“Melhorou; seguir com a animação”**. Isso autoriza continuar com a calibração mostrada; não registra aprovação da sequência final ou do combate de arco completo.

V3 permanece preservado como revisão rejeitada. V4 usa fonte e atlas próprios, sem modificar caminhada/figurino R5, espada, física, mundo ou saves. Ainda é estudo de composição para duas vistas, com corpo inferior em idle; equipamento separado em runtime, demais direções e combate à distância continuam fora deste ajuste.

## Validação final e aprovação

- Aseprite: 74 sprites (37 quadros × duas vistas), 24 fps, canvas 128×160, 32 PPU e pivô (64,34), em `BowAnatomyStudy/`. Os originais R5/R6 e o arquivo CC0 do arco não foram modificados. Render CPU com limite de textura de 1024 nesta fonte derivada para reduzir memória; imagens originais mantidas.
- Fonte Blender editável: 145 amostras, incluindo subquadros, sem vértices da luva penetrantes; menor distância 4,0809 cm e maior flexão 103,097°. `HumanoidSwordR7/bow-v4-baked-geometry.json`.
- Unity: 74 poses exibidas no jogador em Play, frames 2685→3334. Capturas após fim do frame. Corpo/espada/posição restaurados ao terminar, perfil de QA isolado; console corrente zero erros e zero avisos. `bow-anatomy-unity.json` e `console-bow-v4-play.json`.
- Durante a geração foram mostradas a prancha, uma prévia frontal e a sequência completa. Após a sequência e a captura no jogo, o usuário respondeu **“ficou bom”**. **Aprovados a puxada, a posição da mão e o movimento do braço/cotovelo desta revisão nas duas vistas.** Não estender essa aprovação a combate à distância completo, outras direções ou promoção oficial.

Registro de aprovação com hashes: `HumanoidSwordR7/bow-v4-artistic-approval.json`. Prévia completa: `HumanoidSwordR7/previews/bow-draw-v4.gif`; captura no mundo: `bow-v4-unity.png`. `bow-v4-unity-keyframes.gif` contém seis momentos de cada vista, não gravação contínua.
