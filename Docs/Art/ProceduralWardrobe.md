# Vestuário procedural — capacidades e evolução além do Marco 06B.13

**Atualização R4:** a calibração explícita agora foi exercitada em Mira e Orin, preservando a reprodução R3. O [relatório R4](../Validation/Marco06B13R4.md) registra essa entrega e o QA. O usuário considerou as roupas pequenas simples e priorizou uma [família humana maior, inclusive para o protagonista](HumanoidStandard.md), permitindo adequar o cenário. O registro abaixo descreve a etapa R2/R3; o registro histórico R2/R3 abaixo não descreve a implementação maior. A evolução R5 posterior já possui figurino articulado profissional sobre Quaternius, aprovado pelo usuário e testado no jogo: [R5](../Validation/HumanoidOutfit2026.md).

Registro de 16/10/2026. Implementação de referência: `336b27c` (R3); biblioteca e combinação de peças: `7e65525` (R2). Este documento descreve capacidades verificadas, extensões possíveis e trabalho ainda pendente. Evidências completas: [B13 R2](../Validation/Marco06B13R2.md) e [B13 R3](../Validation/Marco06B13R3.md).

## O que ultrapassou o pedido inicial

O pedido inicial do B13 era pesquisar NPCs profissionais para Mira e Orin, verificar licença/estilo, preparar fontes editáveis e avaliar os candidatos em uma cena experimental, preservando o jogo oficial. A criação de uma ferramenta própria de modelagem de roupas não fazia parte dessa entrega inicial.

As orientações posteriores do usuário ampliaram o escopo: aproveitar anatomia e movimentos profissionais, adaptar a aparência no Aseprite, selecionar fontes publicáveis como arquivos no GitHub e criar roupas por código. A meta de longo prazo passou a ser variedade de vestuário e eventual animação de tecido; a prioridade imediata foi explicitamente reduzida à forma da roupa. A mochila acrescentou o requisito de visibilidade conforme a direção e a correção de oclusão do braço.

| Extensão solicitada durante o trabalho | Entrega efetiva | Onde conferir |
|---|---|---|
| Bases profissionais editáveis com redistribuição dos arquivos | Quatro bases de personagens e uma biblioteca de efeitos; licenças/limitações individualizadas | [Pesquisa R2](../Validation/Marco06B13R2.md#biblioteca-efetivamente-preparada) |
| Adaptar vestimenta sem refazer movimentos | Quatro receitas Mira/Orin com peças existentes e paletas determinísticas; seis camadas por documento | [Roupas por camadas R2](../Validation/Marco06B13R2.md#roupas-procedurais-prova-concreta) |
| Criar formas de roupa por procedimento | Biblioteca Lua de painéis e volumes, receitas JSON e geração no Aseprite | [Biblioteca de geometria](../../Tools/ArtPipeline/Aseprite/garment_geometry.lua) |
| Colocar capa e chapéu em Mira | Receita composta de capa, gola, fecho, aba e copa; 44 poses exportadas | [Receita de viagem](../../Tools/ArtPipeline/garment_recipes/mira_traveller.json) |
| Respeitar peças traseiras e preservar o braço | Regra `back_mounted`, mochila em quatro direções e teste de regressão nas 22 poses laterais | [Correção e imagens](../Validation/Marco06B13R3.md#correção-do-braço-da-mochila) |
| Conferir o resultado dentro do jogo | Cena R3, capturas reais, interação, colisão, sorting e save/load isolado | [QA Unity](../Validation/Marco06B13R3/gameplay/qa.json) |

Essas extensões não significam que Mira e Orin novos foram aprovados ou promovidos. A cena oficial mantém seus NPCs anteriores. Orin tem propostas por camadas no laboratório R2; o gerador de geometria R3 foi calibrado e demonstrado em Mira.

## O que é possível fazer agora

| Capacidade | Estado e alcance comprovado |
|---|---|
| Combinar peças desenhadas e variar cores | R2: MiraIvory, MiraSage, OrinForest e OrinUmber; 176 quadros comparados com a composição esperada |
| Criar novas silhuetas parametrizadas | R3: painéis e volumes por revolução; variação de medidas mudou a silhueta nos 44 quadros do teste |
| Controlar detalhes de forma | Perfil de largura/raio/profundidade, comprimento, deslocamento, pregas, profundidade de pregas, barra ondulada, fenda, achatamento do volume e inclinação |
| Compor acessórios | Componentes independentes com âncora, material e regra de oclusão próprios; até 16 componentes por receita no validador atual |
| Definir aparência do material | Paletas de contorno, luz/sombra e acabamento; sombreamento quantizado com iluminação fixa. Não corresponde a uma simulação física de materiais |
| Acompanhar poses existentes | Cabeça, ombros e cintura medidos por pose; 44 quadros, oito sequências idle/walk nas quatro direções da base de Mira |
| Resolver apresentação traseira | Mochila atrás do corpo nos perfis e na frente; sobre as costas na vista norte. Não se exige visibilidade frontal de um acessório traseiro |
| Continuar a edição manual | Novos documentos `.aseprite`, preservando os seis layers originais e acrescentando três layers gerados separados |
| Exportar para revisão/importação | Atlas PNG, manifesto, receita/âncoras, hashes, métricas, oito GIFs de dois ciclos e pranchas direcionais |
| Reproduzir e verificar | Mesma receita produz os mesmos 44 frames; saídas existentes são recusadas; receitas inválidas e recorte de geometria são verificados |
| Conferir integração no mundo | Cena experimental com importação Point, alfa, 32 PPU, canvas 64×64 e pivô explícito; testes reais registrados |

Exemplos entregues: capa com gola/fecho, chapéu com aba/copa/faixa e mochila de couro. Novas medidas, cores e combinações desses componentes podem ser descritas em receitas e submetidas ao mesmo processo de revisão. Isso é autoria de assets antes da execução do jogo; não há troca procedural de equipamento pelo jogador em runtime.

## Arquitetura reutilizável

O fluxo separa cinco responsabilidades:

1. **Base profissional e proveniência:** documentos e peças imutáveis do R2, com créditos e licença.
2. **Receita:** componentes, medidas, materiais, âncoras e oclusão em JSON.
3. **Geometria e desenho:** Lua no Aseprite gera superfícies trianguladas, projeta as quatro direções e rasteriza pixels no canvas nativo. Python mede referências, orquestra e monta prévias.
4. **Saída editável e QA:** camadas originais conferidas, exportações, hashes e teste de oclusão/repetibilidade.
5. **Inspeção Unity:** importador de laboratório e cena copiada do mundo oficial; apresentação avaliada junto de colisão, interação e persistência existentes.

| Ponto de extensão | Arquivo |
|---|---|
| Primitivos, projeção, sombreamento, oclusão e validação da receita | [garment_geometry.lua](../../Tools/ArtPipeline/Aseprite/garment_geometry.lua) |
| Camadas geradas e preservação da base | [generate_garments_b13r3.lua](../../Tools/ArtPipeline/Aseprite/generate_garments_b13r3.lua) |
| Fonte, medição das âncoras e exportação | [generate_garments_b13r3.py](../../Tools/ArtPipeline/generate_garments_b13r3.py) |
| Receitas de exemplo | [Viagem](../../Tools/ArtPipeline/garment_recipes/mira_traveller.json), [mochila](../../Tools/ArtPipeline/garment_recipes/mira_backpack.json) |
| Regressões do gerador | [validate_garments_b13r3.py](../../Tools/ArtPipeline/validate_garments_b13r3.py) |
| Autoria/importação e QA de jogo | [BuildGarmentLab06B13R3.cs](../../AgentScripts/BuildGarmentLab06B13R3.cs), [InspectGarmentLab06B13R3.cs](../../AgentScripts/InspectGarmentLab06B13R3.cs) |

O backend aceita as três âncoras, mas o orquestrador atual usa explicitamente `MiraIvory.aseprite` e sua calibração. Adaptar outro corpo exige revisar fonte, proporções, âncoras e oclusão; trocar somente o nome da receita não transforma a base em Orin ou no Iron Knight.

## Como reutilizar

Na raiz do repositório, com Python/Pillow e Aseprite local disponíveis, copie uma receita para um novo JSON e ajuste seus componentes. Use um destino novo para preservar editáveis anteriores:

```powershell
python Tools/ArtPipeline/generate_garments_b13r3.py --recipe Tools/ArtPipeline/garment_recipes/mira_traveller.json --output ArtSource/Labs/NpcResearch/NovaRoupaMira
python Tools/ArtPipeline/validate_garments_b13r3.py
```

O primeiro comando reproduz a receita de exemplo em outra pasta; para uma roupa diferente, passe o caminho da receita alterada. O segundo executa as regressões das receitas de referência. Uma receita nova precisa também de inspeção dos seus próprios resultados: não recebe aprovação automática por as referências passarem. Aseprite padrão: `D:/Aseprite/Aseprite.exe`, substituível por `--aseprite`.

Revisar silhueta em todas as direções, mãos/braços, contato dos pés, recorte pelo canvas, continuidade entre poses e aparência no cenário. A roupa acompanha movimentos já desenhados; não se devem fabricar poses faltantes ou ajustar cadência para disfarçar defeitos.

O importador/cena R3 é uma ferramenta de laboratório com destinos explícitos. As rotinas de primeira criação recusam sobrescrita; não são um comando universal para publicar qualquer receita no mundo oficial. [README técnico e licença](../../ArtSource/Labs/NpcResearch/Marco06B13R3/README.md).

## Evidência e limites

Na implementação R3 foram verificados: repetibilidade dos 44 frames, mudança geométrica nos 44 frames do teste de parâmetros, quatro receitas inválidas rejeitadas, zero fragmentos recortados nas duas receitas finais e preservação da fonte/camadas. A mochila manteve os **17.758 pixels opacos originais nas 22 poses laterais**. [Resultado do gerador](../Validation/Marco06B13R3/generator-checks.json).

Em Play houve inspeção das quatro direções de cada roupa, oito poses de caminhada, diálogo de Mira/Orin, colisão comparada ao mundo oficial, sorting frente/trás e save/load com F5. Frames avançaram de 894 a 3232 na execução completa; console sem erros/warnings. Foram comparados e preservados 60 arquivos oficiais e cinco arquivos pessoais. [Relatório completo](../Validation/Marco06B13R3.md), [preservação](../Validation/Marco06B13R3/preservation.json).

| Objetivo futuro | Situação atual |
|---|---|
| Criar qualquer roupa a partir de uma frase | Ainda não implementado. É necessário traduzir o pedido em receita e, quando preciso, ampliar os primitivos |
| Vestidos, mangas ajustadas, armaduras articuladas e cortes complexos | Não demonstrados pelo R3; podem exigir topologia, máscaras e regras novas, além de revisão artística |
| Usar automaticamente em qualquer anatomia | Ainda não implementado; calibração e validação específicas por base |
| Tecido com inércia, vento ou colisão física | Adiado por orientação do usuário; nenhum solver ou shader de tecido adicionado |
| Novas animações de corpo, combate ou oito direções no R3 | Não implementadas; este gerador usa idle/walk cardinais existentes |
| Profundidade exata por membro | Não reconstruída; as camadas e a regra semântica resolvem os casos testados, outros acessórios podem precisar de máscaras |
| Equipar/trocar roupas no jogo, inventário ou persistir equipamento | Não implementado; saída atual são assets compostos e editáveis |
| NPCs animados automaticamente na cena salva | Não adicionado; Mira permanece estática em idle sul. As demais poses foram inspecionadas temporariamente em Play |
| Promover os novos NPCs para produção | Pendente de aprovação artística; mundo oficial e Iron Knight preservados |

Os sprites compostos de Mira usam a base selecionada sob **OGA-BY 3.0**, com créditos e indicação de alterações nos READMEs R2/R3. Editar ou gerar roupa sobre a base não remove sua atribuição. A biblioteca também contém fontes CC0 identificadas individualmente; não se deve generalizar essa licença a todos os resultados.

Este registro será atualizado quando novas categorias, anatomias ou comportamentos forem efetivamente implementados e validados. Os próximos incrementos possíveis são extensão de componentes, calibração de outra base e animação secundária; permanecem propostas, não capacidades entregues.

## R5 — nova família articulada

O backend maior usa Blender e skin weights das malhas profissionais, com ajustes de bind pose e acabamento Aseprite em 128×160. Não é adaptação automática do rasterizador 64×64. Foi demonstrado um figurino masculino completo nas 52 poses aprovadas, mantendo o corpo original, com receitas/metadados em `ArtSource/Labs/Humanoid2026/R5/`. Isso amplia a capacidade de autoria sobre rig; não comprova criação universal de qualquer roupa, simulação física ou equipamentos dinâmicos em runtime. [QA e limites](../Validation/HumanoidOutfit2026.md).
