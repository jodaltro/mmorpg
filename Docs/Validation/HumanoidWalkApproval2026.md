# Aprovação da caminhada e continuidade do modelo humanoide

Data: 16/10/2026. Projeto Mmorpg, Unity 6000.6.5f1.

## Decisão do usuário

Após testar pessoalmente o personagem maior controlável em Valdoria e receber a correção das direções laterais, o usuário declarou: “Ficou boa a animacao da caminhada” e pediu para seguir com esse modelo, aguardando novas instruções para aprimorá-lo.

**Caminhada aprovada pelo usuário. A base Quaternius masculina testada é a referência escolhida para continuar o desenvolvimento.** Essa decisão confirma a continuidade do modelo; não equivale à aprovação final de roupas, rosto, identidade, combate ou apresentação de todos os humanoides. A direção geral continua sendo adotar uma família maior para protagonista e NPCs, com cenário adaptável.

## Versão de referência

- Integração no mundo: commit `1379c96`.
- Jogador controlável: commit `91ef7c1`.
- Correção lateral avaliada: commit `dc36f56`.
- Cena: `Assets/Mmorpg/Scenes/HumanoidScale2026.unity`.
- CharacterSet: `Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset`.
- Fonte: Quaternius Universal Base Characters, corpo Superhero_Male_FullBody; animação Walk_Loop da Universal Animation Library Standard. Proveniência/licença CC0 e hashes: `ArtSource/Labs/Humanoid2026/provenance.json`.
- Editável: `ArtSource/Labs/Humanoid2026/Preview/Male/Male.aseprite`.

## O que está funcionando

O jogador usa o motor, a autoridade, as colisões e os controles existentes. WASD/setas movimentam o corpo maior; há intenção diagonal, apresentação em quatro direções e retorno a idle ao soltar as teclas. O render mantém pixels nativos com filtro Point, 32 PPU, canvas 128×160 e pivô Unity (64,34). O conjunto possui 52 sprites: 48 de caminhada, 12 por direção, e quatro poses de idle. São oito clips.

A caminhada usa 111 ms por amostra no asset exportado, aproximadamente 1,332 s por ciclo; o animador ajusta a cadência pela velocidade do motor. Não alterar arbitrariamente esses timings ou refazer a caminhada aprovada nos próximos aprimoramentos. Mudanças necessárias devem ser identificadas e novamente avaliadas visualmente.

Os rótulos laterais do estudo indicavam o lado da câmera: fonte east olha à esquerda, fonte west olha à direita. O CharacterSet corrigido mapeia direção Unity 1 para east e direção 3 para west. Não reinverter ao importar novas roupas ou reconstruir o asset; revisar a orientação visual, não apenas o nome do clip.

O teste manual do usuário complementa o QA técnico já executado: quatro direções, mudança de frames, parada, diagonal, frames avançando e console sem erros/avisos. [Evidências da correção](HumanoidScale2026/player-direction-fix/qa.json) e [relatório técnico completo](HumanoidScale2026.md). Nenhum novo teste Unity foi executado para produzir este documento; esta etapa registra a aprovação recebida.

## Pontos ainda pendentes

| Área | Estado ao receber a aprovação |
|---|---|
| Roupas, cabelo, rosto e identidade final | Ainda não preparados para o novo corpo; a base usa a roupa original de estudo |
| Espada e mãos | Espada oculta na cena experimental; âncoras históricas ainda não recalibradas |
| Ataques, esquiva, dano e morte | Não convertidos para esta base; ausência de clip usa fallback de idle, sem validar apresentação de combate |
| Corpo feminino e NPCs | Família disponível e exibida na cena; aprovação explícita recebida refere-se à caminhada do jogador testado |
| Cenário e etiquetas | Ainda na escala anterior; ampliar/retrabalhar conforme a direção autorizada |
| Pivô e contato dos pés | Calibração inicial fixa; refinamentos de contato, deslize e terreno ainda possíveis |
| Produção | Mundo oficial e Iron Knight continuam na entrada principal; o novo jogador permanece na cena experimental |
| Vestuário procedural complexo | Ainda não adaptado nem validado sobre o novo canvas/esqueleto |

## Continuidade

Preservar essa versão como referência ao receber as próximas instruções. Partir desta base para os aprimoramentos pedidos; não iniciar outra busca ou substituir o modelo sem motivo alinhado ao usuário. As fontes articuladas permitem estudar roupas por malha/esqueleto e exportação em sprites; a capacidade de produzir qualquer roupa animada ainda não foi demonstrada.

Manter a separação entre apresentação e regras: proteger identidade, persistência, missões e autoridade. No Editor, esta cena usa o perfil separado `Temp/HumanoidScale2026/ManualPlayerProfile`, ativado por `HumanoidScalePreviewProfile`; não copiar esse perfil para os saves pessoais. Nenhuma promoção global, nova roupa ou mudança de gameplay foi realizada nesta etapa de documentação. Próximas alterações ficam aguardando as instruções do usuário.
