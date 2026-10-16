# Roupa paramétrica — B13 R3

Documentos finais desta prova: `MiraTravellerCorrected/MiraTraveller.aseprite` e `MiraBackpackFinal/MiraBackpack.aseprite`. Ambos têm 44 poses, oito tags idle/walk cardinais, canvas RGBA 64×64 e layers gerados separados do corpo. Aprovação artística pendente.

O gerador cria **formas novas**, em vez de apenas recolorir peças prontas: painéis com perfil de largura/profundidade, pregas, barra, fenda e acabamento; volumes por revolução com perfil de raio/altura, aba, copa e faixa. São componentes parametrizados em JSON, projetados em quatro direções e rasterizados no Aseprite local, com paleta quantizada e luz fixa. Não há IA generativa, serviços pagos ou novas poses do corpo.

A malha se prende a âncoras medidas nos desenhos originais de cada pose (cabeça, ombros, cintura). A roupa acompanha essas poses; **simulação secundária do tecido está adiada**, conforme a orientação de começar pela roupa. A posição dos pés e o corpo permanecem os da fonte.

## Oclusão e correção do braço

`occlusion: "back_mounted"` identifica peças presas às costas. Norte mostra a peça sobre o tronco de costas; sul e perfis mantêm o corpo/braços à frente dela. O volume continua visível onde ultrapassa a silhueta. A primeira aproximação usando apenas profundidade da malha cobriu parte do braço lateral: essa versão foi rejeitada e mantida somente em Temp.

O teste final verifica todos os pixels opacos originais em 22 poses laterais, incluindo braços e roupa. Nenhum desses pixels é apagado pela mochila. Na pose idle frontal a mochila altera zero pixels visíveis; de costas altera 112 e nos perfis 36. Não se força uma peça traseira a aparecer na frente.

A gola e o fecho da capa são componentes próprios, opcionais na receita, não uma correção para tornar a parte traseira visível. O chapéu utiliza volumes distintos para aba, copa e faixa. A receita de mochila usa o mesmo primitivo de volume, montado nos ombros com deslocamento posterior.

## Reproduzir e editar

```powershell
python Tools/ArtPipeline/generate_garments_b13r3.py --recipe Tools/ArtPipeline/garment_recipes/mira_traveller.json --output ArtSource/Labs/NpcResearch/NovaRoupa
python Tools/ArtPipeline/validate_garments_b13r3.py
```

Requer Aseprite local (`D:/Aseprite/Aseprite.exe`, ou `--aseprite`) e Pillow existente. A saída deve ser nova: o gerador recusa sobrescrever documentos ou edições manuais. Originais são abertos para leitura e salvos em outro destino. O Python mede âncoras e monta prévias; toda a nova geometria e seus pixels são produzidos pelo backend Lua no Aseprite.

Campos principais: `kind` (`panel`/`revolve`), `anchor`, `profile`, `length`, `offset`, `folds`, `foldDepth`, `scallop`, `slit`, `trimBand`, `depthRatio`, `lean`, `material`, `occlusion`. O perfil usa nós `[posição 0..1, largura/raio, profundidade]`, ordenados. Materiais definem contorno, rampa de luz e acabamento. A geometria deve caber no canvas; o QA rejeita fragmentos recortados.

Esta primeira implementação calibra as âncoras para a base LPC de Mira. Outras anatomias precisam de calibração; categorias com topologia, recorte corporal ou ajuste diferente podem exigir novos componentes/regras. Não é um interpretador universal de qualquer descrição de moda, nem um simulador de costura completo.

## Fonte, autoria e licença

Corpo e roupa base: `../Marco06B13R2/Wardrobe/MiraIvory.aseprite`, derivados de LPC Revised, sob **OGA-BY 3.0**. Preservar as atribuições, fontes e licença da [biblioteca B13 R2](../Marco06B13R2/README.md) e de `../Marco06B13R2/Licenses/`. Base corporal/cabeça: Stephen Challener (Redshrike), Eliza Wyatt (DeathsDarling), com créditos completos de animação na biblioteca; roupa por Eliza Wyatt; cabelo Bangs & Bun por BlueCarrot16 e Eliza Wyatt.

Alterações do projeto em 16/10/2026: geometria nova de capa/gola/fecho/chapéu/mochila, materiais, projeção e composição nas poses existentes. Os sprites compostos são publicados sob OGA-BY 3.0, com indicação dessas mudanças, sem endosso dos autores originais. Não apresentar a composição como CC0.

Cada pasta contém o editável, receita/âncoras e hashes em JSON, atlas, oito GIFs de dois ciclos e pranchas. Os GIFs usam os 125 ms de inspeção herdados do laboratório; não são timings autorais certificados. Sem trim das fontes, resampling, caminhada inventada ou mudança da aparência do Iron Knight.
