# Marco 06B.13 R10 — cenário detalhado, protagonista e proporção

Data: 17/10/2026. Registro consolidado das mudanças de direção artística, integração e calibração de escala. Este documento descreve o estado atual; os relatórios anteriores preservam resultados intermediários.

## Estado atual

O jogo principal inicia em `Assets/Mmorpg/Scenes/MmorpgWorld.unity`, primeiro índice global de build. O jogador usa o humanoide Quaternius R8; o Iron Knight saiu do slot ativo, e seus assets/cenas históricos continuam preservados. O cenário detalhado está integrado como imagem de fundo. Os NPCs estão temporariamente desativados para avaliar a proporção do protagonista usando o poço como referência.

| Elemento | Configuração vigente | Situação |
|---|---|---|
| Protagonista | `ValdoriaProtagonist.asset`, id `valdoria-protagonist-quaternius-r8` | Ativo no Player oficial |
| Conjunto visual | 64 clipes, 528 frames, oito direções | Contagem verificada; não equivale a aprovação integral de combate |
| Grupo visual do jogador | Escala uniforme 1.25 | Última calibração, aguardando feedback artístico |
| Raiz física do jogador | Escala 1 | Não foi escalada junto do desenho |
| Cenário | Sprite 1536×800, importado a 32 PPU, Point | Imagem de fundo, sem geometria própria de colisão |
| Escala do cenário | 1.74; anteriormente 0.58 | 3× nas dimensões lineares, 9× na área |
| Dimensões visuais do cenário | Aproximadamente 83.52 × 43.50 unidades | Não representam área navegável validada |
| Câmera | Ortográfica, meia-altura 7.03125 | Campo vertical 25% maior que o anterior, viewport inteiro |
| NPCs | Objetos e visuais desativados na cena | Temporário; suas interações ficam indisponíveis |

## O que foi feito

### Cenário detalhado

Após o usuário considerar os primeiros resultados simples, foi produzida uma referência de cenário por geração de imagem conforme sua solicitação. A versão integrada contém caminho de pedras, ponte, rio, vegetação, flores, cercas, construções e poço, com maior densidade de detalhes.

A referência foi preparada no Aseprite local e preservada como fonte editável. O jogo usa o recorte final como um único SpriteRenderer. A produção não deve ser descrita como desenho manual integral, tileset modular concluído ou nível físico completo.

- Referência: `ArtSource/References/Generated/ValdoriaVillageR10-Detail-LLM-v3.png`.
- Editável: `ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-detail-v3.aseprite`.
- Sprite integrado: `Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png`.
- Preparação: `Tools/ArtPipeline/Aseprite/prepare_valdoria_llm_reference.lua`.

Renderers de props antigos que sobrepunham o fundo foram ocultados, mantendo seus objetos e colisões anteriores. O fundo foi reativado após uma recarga em que estava desabilitado. Sua ordenação foi ajustada para cobrir a antiga borda visual. Os limites da câmera foram ampliados para acompanhar o cenário.

### Protagonista Quaternius no mundo oficial

O usuário identificou que a cena de entrada ainda usava o Iron Knight e determinou usar o novo protagonista. O conjunto Quaternius R8 foi copiado para `Assets/Mmorpg/Art/Production/ValdoriaProtagonist/`, com referências remapeadas para os atlas de produção. Não foram redesenhadas animações neste ajuste.

O Player existente recebeu o conjunto visual e os estados correspondentes. Foi conectado o sistema de contato dos dedos da espada, com 272 pares de máscaras corpo/dedos. A espada separada existente foi reutilizada. As fontes Quaternius e sua proveniência/licenças continuam registradas em `ArtSource/Labs/Humanoid2026/`.

Os componentes existentes de movimento, saúde, autoridade, colisão, combate, missões e persistência permaneceram no ator. Isso registra preservação estrutural, não comprova regressão funcional de todos esses sistemas após cada mudança visual.

### Ajustes sucessivos de proporção

| Etapa | Pedido/feedback | Resultado implementado |
|---|---|---|
| Redução inicial | Personagem grande em relação ao cenário | Grupo visual em 0.75, incluindo equipamento |
| Ampliação do mundo | Ainda grande; aumentar muito o mapa e afastar câmera | Fundo de 0.58 para 1.74; câmera de 5.625 para 7.03125 |
| Referência pelo poço | Jogador ficou pequeno; calibrar pelo poço e retirar NPCs temporariamente | Grupo visual de 0.75 para 1.25, mantendo mapa/câmera; NPCs desativados |

A última mudança aumenta o personagem em aproximadamente 67% sobre a etapa anterior. A referência proposta é a relação corporal com a borda e a cobertura do poço: borda aproximadamente na faixa da cintura e cobertura acima da cabeça quando comparados no mesmo plano de chão. Essa relação é uma orientação de composição; não foi certificada por medidas físicas do poço, que está desenhado no fundo.

### Câmera e enquadramento

O zoom inteiro anterior não oferecia o afastamento intermediário desejado. PixelPerfectCamera e AdaptivePixelViewport foram desabilitados somente na câmera oficial, mantendo texturas Point. A ampliação exata de pixels inteiros deixou de ser garantida nesse enquadramento.

`FullFrameCameraPresentation` restaura o viewport e as matrizes no início do jogo. Isso corrigiu a moldura preta que persistia ao entrar em Play. O quadro completo foi confirmado em execução. Um bloqueio anterior do Pipeline era um diálogo de recarga por alteração externa da cena; ele foi resolvido pela interface do Editor.

### Ocultação temporária de NPCs

Foram desativados 17 nós com sprites Healer/Hunter/Smith/Scholar e 10 objetos/etiquetas com nomes de Mira, Orin, Helena, Brann, Dorin e Nera. Essas contagens incluem duplicações visuais e etiquetas; não significam 27 personagens distintos.

Os objetos não foram apagados. A mudança fica na cena oficial e pode ser revertida reativando os mesmos objetos. Enquanto ocultos, suas interações ficam indisponíveis. O alvo de treino e os inimigos permanecem; eles não foram tratados como NPCs de conversa. Não foi executado reset ou migração de missões para acomodar essa pausa visual.

## Diretrizes tomadas com o usuário

1. **Quaternius como protagonista ativo.** Continuar com a nova base humana e preservar caminhada e figurino anteriormente aprovados. O Iron Knight permanece referência histórica, sem retornar ao slot ativo por reutilização de configuração antiga.
2. **Cenário rico em detalhes.** Manter como direção a densidade de elementos da imagem apresentada, que o usuário considerou boa; a proporção continua sendo ajustada. Isso não constitui aprovação de todo o nível.
3. **Proporção por referências do mundo.** Usar o poço como referência imediata e depois conferir portas, cercas e outros objetos no mesmo plano de chão. Evitar decidir apenas por percentuais isolados.
4. **Mapa adaptável à família humana.** A dimensão do cenário antigo não limita os novos corpos. A apresentação continua em pixel art, com intenção visual mais moderna.
5. **NPCs em pausa até acertar o protagonista.** Mantê-los temporariamente ocultos durante essa calibração; a escala deles não deve orientar a avaliação atual. Sua restauração/adaptação fica para depois da definição do personagem.
6. **Avaliação dentro do jogo.** Mostrar capturas reais e testar movimento para obter feedback. Uma captura estática ou teste técnico não substitui aprovação artística.
7. **Preservação das fontes e dados.** Manter editáveis, proveniência, referências aprovadas e salvamento pessoal. A geração de cenário foi solicitada pelo usuário nesta tarefa; isso não estabelece autorização artística geral para substituir personagens/animações aprovados por novas gerações.

As diretrizes acima consolidam os pedidos desta conversa. A última escala 1.25 ainda não recebeu aprovação explícita do usuário.

## Validação efetivamente executada

Unity 6000.6.5f1, Editor conectado via CLI Pipeline, autotick ativo, recompilação/status conferidos. Foram executados testes curtos em Play com perfil temporário isolado e input sintético: entrada oficial, identificação do Quaternius, animação walk, retorno a idle e frames avançando.

Na última calibração, o deslocamento medido foi 0.708 unidades. O audit confirmou corpo em 1.25, raiz física em 1, mapa em 1.74, câmera em 7.03125 e zero sprites dos NPCs selecionados ativos. O console atual estava sem erros/avisos e sem falha de compilação; o buffer histórico do Pipeline continha registros de tentativas anteriores. Play foi encerrado e dispositivos/configurações temporárias foram restaurados.

Não foram executadas regressões completas de combate, esquiva, dano, morte, missões, interações ou save/load neste ciclo de proporção. O perfil pessoal não foi renomeado, resetado ou migrado. A origem LegacyGrip continua derivada da mão visual: alterações de escala podem alterar essa origem, mesmo com parâmetros de alcance e collider intactos.

![Última captura: poço e jogador, NPCs ocultos](ValdoriaProductionR10/gameplay/well-reference125-no-npcs.png)

## Limites e continuidade recomendada

Primeiro obter feedback da proporção atual junto ao poço. Depois conferir essa mesma proporção em portas e cercas, restaurar/adaptar os NPCs e montar o cenário como nível jogável.

A imagem única ainda não fornece colisão, navegação ou oclusão por objeto. Os atores desenham sobre o fundo, sem passar entre suas camadas. A ampliação visual não alinhou automaticamente colisões antigas, destinos de interação ou posições dos habitantes. Essa construção física e visual precisa de uma etapa própria antes de considerar o mundo concluído.

Também será necessária validação de empunhadura e acertos na escala escolhida. A disponibilidade de 64 clipes não demonstra que todos os estados estejam aprovados ou tecnicamente revalidados nesta cena.

## Ferramentas e rastreabilidade

| Ferramenta | Função/etapa |
|---|---|
| `PromoteQuaterniusR10` | Cópia/remapeamento de assets e integração inicial no Player |
| `ScaleValdoriaProtagonistR10` | Experimento anterior de escala 0.75 |
| `ScaleValdoriaWorldR10` | Mapa 1.74, câmera afastada e audit da etapa anterior |
| `CalibratePlayerToWellR10` | Escala atual 1.25, NPCs ocultos e audit atual |
| `InspectQuaterniusProtagonistR10` | Preparação de perfil temporário, input, smoke e restauração |

Essas ferramentas registram etapas diferentes. Os métodos antigos possuem valores fixos e podem desfazer uma calibração posterior; não executá-los em sequência como um pipeline de atualização do estado atual.

Mudanças publicadas em `main`: `68d3ca3` (protagonista e cenário), `c8050c5` (mapa/câmera), `2b7f500` (poço/NPCs). Este relatório não acrescenta mudanças ao gameplay.

Relatórios específicos: [integração inicial](ValdoriaProductionR10.md), [redução inicial](ValdoriaProtagonistScaleR10.md), [mapa/câmera](ValdoriaWorldScaleR10.md) e [poço/NPCs](ValdoriaWellProportionR10.md).
