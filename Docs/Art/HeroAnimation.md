# Herói — situação real no 06B.4

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
