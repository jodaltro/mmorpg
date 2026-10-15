# Empunhadura e Sweep — 06B.4

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
