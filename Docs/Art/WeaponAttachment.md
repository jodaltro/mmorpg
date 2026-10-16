# Empunhadura e Sweep — 06B.4

## Produção oficial 06B.12

O prefab visual conectado em `MmorpgWorld.unity` é `Assets/Mmorpg/Art/Production/IronKnight/PlayerVisual.prefab`. Corpo, arma separada e sombra mantêm os transforms e a calibração da B11 aprovada. `IronKnight.asset` preserva as mãos e profundidades por cel do B10/B11; o mesmo SwordSwing continua usando essas mãos no desenho e no Sweep. Esquiva/Hurt conservam a apresentação aprovada; morte oculta a espada e mantém a pose terminal. Nenhuma dimensão física ou alcance foi alterado na promoção. As notas B4/B5 seguintes documentam a evolução anterior.

Estrutura na cena B4:

```text
Player (Rigidbody2D, collider, autoridade/adaptadores existentes)
  SpriteRenderer (proxy de cor/sorting, sem sprite)
  ProductionSpriteAnimator
  VisualRoot
    BodySprite
    WeaponPivot
      EquippedSword
    GroundShadow
```

O proxy preserva as referências usadas por `ActorVisual`, feedback e impactos. `ProductionVisualSync` transfere cor/sorting ao corpo filho. Não há segundo corpo ou segunda espada. Os originais B3 não são alterados.

Cada `ProductionFrame` contém mão local, ângulo de descanso e profundidade. A exportação define coordenadas em pixels; a importação converte pelo pivô e PPU. A revisão em prancha corrigiu especialmente a vista leste: idle `(52,70)`, walk `(54,70)` e `(57,69)`. As demais coordenadas estão no JSON e no script reproduzível, não em quatro âncoras globais compartilhadas.

Idle/walk seguram a arma com ângulo fixo por vista (sul -135°, oeste -155°, norte 90°, leste -25°), enquanto posição segue a palma por quadro. Norte ordena a espada atrás do corpo. Preparação interpola da orientação mostrada até o início do arco; corte acompanha exatamente o progresso do Sweep; recuperação volta ao ângulo de empunhadura. O corpo ainda usa stances provisórias e idle na recuperação.

Espada: PNG próprio de 80×80, pivô de importação `(31/80,35/80)` em coordenadas inferiores Unity. O filho conserva a calibração B3 (~-38,8° e escala uniforme ~0,978) para orientar o desenho original ao +X do pivô. O Swing conserva a extensão longitudinal baseada no alcance já existente; isso não é correção de escala do personagem. Esta apresentação ainda precisa de revisão artística junto aos novos ataques corporais.

O cálculo físico usa a mesma mão do frame. A amostragem interpola também entre a empunhadura anterior e atual, além da translação da raiz e do arco. Permanecem layer, cápsula, padding, alcance, visibilidade, autoridade e HashSet de alvos já atingidos. Nenhum AnimationEvent causa dano. Duração ativa 0,14 s, recuperação 0,16 s e preparação recebida do combate; não foram alteradas regras de dano/cooldown.

**F7** (Editor/Development): magenta = contato da mão; amarelo = segmento da lâmina mostrada; ciano = trajetória de pontas emitida diretamente dentro do loop de OverlapCapsule real. O histórico tem limite de 160 pontos por golpe. Oculto por padrão e sem renderizadores/código de debug nas builds finais. O overlay auxilia alinhamento, não constitui uma segunda hitbox.

## Atualização 06B.5 — escala e responsabilidades

`WeaponPivot.localScale` agora é sempre `(1,1,1)`. O filho `EquippedSword` conserva a calibração uniforme original (~0,978) e rotação ~-38,8°. Não há extensão longitudinal por alcance. Pivôs e fontes não foram alterados: a calibração existente foi verificada no Editor, incluindo posição local zero do filho.

O ponto da mão é transformado por `BodySprite.TransformPoint(frame.hand)`; o offset em relação à raiz física alimenta o Sweep, e o pivô visual é posicionado nesse mesmo ponto no LateUpdate. Isso considera posição e escala da hierarquia, mantendo Rigidbody e colliders existentes. A transformação não introduz offsets direcionais extras.

`BladeLength` mede a distância real da empunhadura à ponta do sprite IronSword (`(57-31,45-24)/32` no espaço importado). A medição é aproximadamente **1,02149 unidade**, constante. `SweepLength` expõe o comprimento físico confirmado (`range - 0,25`), que permanece 1,0 no básico e 1,4 no pesado. Alcance autorizado não obriga o desenho da espada a mudar de comprimento. O F7 amarelo usa `VisualTipWorld`, em vez de reconstruir uma ponta a partir do alcance. Ciano continua vindo do OverlapCapsule real. A diferença entre amarelo e ciano no pesado é esperada; `MaximumActiveTipError` histórico agora mede essa separação geométrica e não um erro de fixação da mão.

Preparação interpola do ângulo mostrado ao começo do arco; corte segue o progresso físico; recuperação mantém a última stance e usa SmoothStep para o ângulo de descanso. Corpo e mão mudam juntos: não interpolar a âncora isoladamente para longe da luva desenhada. Sem desenhos intermediários ainda existe troca discreta de pose no início/fim da sequência; não equivale a um braço animado profissionalmente. O salto indevido **para idle ao iniciar a recuperação** foi removido.

Input em ordem padrão; corpo/attachment em Update 40; Sweep em Update 50; espada em LateUpdate 50; sync de cor/sorting 110; efeitos 120; debug 130. Uma única seleção de frame por Update. A pose terminal usa o clock do Swing, evitando um frame extra de recuperação depois do encerramento.
