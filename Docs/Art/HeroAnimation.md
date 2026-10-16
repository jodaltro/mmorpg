# Herói — situação real no 06B.4

## Estado oficial no 06B.12

Iron Knight é o protagonista oficial em `MmorpgWorld.unity`. Caminhada, básico/pesado, empunhadura/oclusão e os novos estados B11 foram aprovados pelo usuário. Produção contém 36 clips, 264 sprites únicos: idle 1, walk 11, Slash 15, salto evasivo 9, Hurt 7 e Death 23 por vista; as 12 fases de ataque reutilizam os mesmos desenhos. A cadência de walk é 53,333 ms por cel. Pixels, clocks, mãos e profundidade são idênticos aos aprovados. [Promoção e testes](../Validation/Marco06B12.md). As pendências B4/B5 abaixo são históricas e não descrevem o protagonista oficial.

**Caminhada profissional de oito poses por direção não concluída.** O conjunto integrado continua provisório: 4 idle, 8 walk (2 por direção), 8 entradas de stances de ataque e 4 dodge. As entradas de ataque reutilizam poses e não representam oito desenhos novos. Não há hurt/death desenhados novos.

A ferramenta integrada de geração visual foi verificada e utilizada duas vezes com referência fixa no herói fornecido. As propostas sul repetiram apoio e não entregaram passagem/transferência de peso confiáveis. Arquivos preservados apenas em `ArtSource/References/Rejected/hero-walk-south-attempt-{01,02}.png`. Nenhuma das propostas foi fatiada/importada como caminhada final. Nenhuma chamada OpenRouter foi feita.

O controlador `ProductionSpriteAnimator` seleciona corpo e metadados juntos após input (ordem 40), antes de `SwordSwing` (ordem 50). Movimento observado usa velocidade efetiva do Rigidbody para ajustar a cadência relativa a 3,5 u/s. O relógio não reinicia a cada pequena alteração de input/direção; uma parada maior que 0,18 s reseta o ciclo. O corpo retorna ao idle existente. A raiz física não recebe curvas de animação, bobbing ou escalas.

Dois derivados receberam **retoque manual localizado de luva**, reproduzido em `repair_glove` no Python: `Hero_walk_S_0` e `Hero_idle_W_0`. Corrigem partes do punho removidas junto da espada no recorte anterior. São pequenos desenhos de pixels no braço/mão, não novas poses de caminhada. `inputSha256` registra o PNG B3 intacto e `sha256` registra o derivado retocado. O QA exige que todas as âncoras do herói incidam em luva visível, além da inspeção em prancha.

Há quatro vistas desenhadas, com diagonais mapeadas pelo eixo dominante da orientação de combate (mouse). Não há oito direções artísticas. Sem poses de strafing/marcha à ré próprias, a orientação e a locomoção continuam uma aproximação visual. Oito frames a 10–12 FPS exigem novos desenhos, não acelerar estas duas poses.

## Encomenda dos desenhos faltantes

Produzir **32 desenhos de walk completos**, oito para cada `south/north/east/west`, com identidade/canvas/âncoras do [contrato](ProductionAssetContract.md). Substituir o ciclo provisório inteiro; não contar as duas poses atuais como oito fases aprovadas.

| Frame | Fase | Leitura exigida |
|---|---|---|
| 000 | Contato esquerdo | Pé esquerdo adiante em apoio; direito atrás |
| 001 | Absorção esquerda | Joelho flexiona discretamente, cabeça estável |
| 002 | Passagem direita | Pé direito cruza a perna de apoio |
| 003 | Elevação direita | Direito avança sem tocar o chão |
| 004 | Contato direito | Apoio oposto ao 000, silhueta distinta |
| 005 | Absorção direita | Peso sobre direito; roupa responde com continuidade |
| 006 | Passagem esquerda | Esquerdo cruza a perna de apoio |
| 007 | Elevação esquerda | Transição contínua para 000 |

Braços contrabalançam pernas; braço da arma mantém empunhadura estável. Não transladar o sprite inteiro nem deformar cabeça/tronco para fabricar fases. Capa acompanha a mesma roupa sem mudar comprimento/identidade. Confirmar linha de chão e mãos de cada desenho. Duração inicial 0,09 s/frame, ajustável após observar deslocamento real, sem mudar velocidade autoritativa.

Próximos pacotes: ataque corporal por vista (preparação, corte, recuperação); esquiva com entrada/deslocamento/saída; hurt e morte sem loops. A espada separada e o Sweep atual permanecem. Desenhar mão/cotovelo afetados em vez de apagar automaticamente a arma através do braço.

`Docs/Art/PreviewsB4/source-qa.json` conta hashes reais por clip. `hero-attachments.png` mostra pontos da mão em magenta e linha do chão em ciano; é prancha de QA, não evidência de animação natural. GIFs de gameplay ficam na validação e são explicitamente provisórios.

## Atualização 06B.5

A caminhada escolhe a vista pelo deslocamento físico observado, com intenção não nula; a mira continua livre para o combate. Diagonais usam eixo dominante com faixa angular de 15% para conservar o eixo anterior próximo do empate. Não há atraso temporal nem restrição do movimento a quatro direções. Idle conserva a última vista; girar somente o mouse não gira corpo/espada. Ataque usa direção confirmada, sem histerese; dodge usa intenção da esquiva aceita.

Clips `attack-preparation`, `attack-cut` e `attack-recovery`, se fornecidos no manifesto, são consultados por fase e têm o tempo escalado para a duração real dessa fase, preservando a proporção das durações individuais. O clip legado `attack` continua compatível: com até duas stances, conserva a primeira na preparação e a última no corte/recuperação; com mais quadros, percorre a duração autorada ao longo do ataque confirmado. Não dispara dano. O clock confirmado também encerra a pose no mesmo frame em que o Swing encerra o golpe.

`ProductionClip.At` permanece independente da contagem: aceita um, dois, quatro, seis, oito ou mais quadros, com duração individual. Walk usa esse relógio existente, sem tabelas fixas de oito fases. Dodge ainda tem uma pose; hurt/death próprios continuam ausentes.

Uma única nova proposta sul foi gerada com a skill imagegen no 06B.5. Foi reprovada por apoio/passagem pouco claros, capa e silhueta inconsistentes. [Resultado e prompt](../../ArtSource/References/Rejected/Marco06B5/review.md). Oito figuras candidatas não equivalem a oito desenhos aprovados: **zero novos frames integrados**. As 32 poses profissionais de walk e os ataques corporais completos continuam necessários.
