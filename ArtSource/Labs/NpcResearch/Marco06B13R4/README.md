# B13 R4 — duas calibrações e estudos pequenos

`Calibrations/`: fonte/manifesto, anatomia, pivô/pés e âncoras medidas separadamente em MiraIvory e OrinForest. `Recipes/`: MiraHealer, OrinTracker e duas mochilas isoladas para regressão. `Results/`: fontes Aseprite e exportações completas, 44 quadros/oito clips por proposta.

As fontes originais são referenciadas em `../Marco06B13R2/Wardrobe/` e conferidas por hash; não foram sobrescritas ou duplicadas como se fossem novas. As composições são **OGA-BY 3.0**, com base LPC, roupa por Eliza Wyatt e cabelo/partes conforme os [créditos completos R2](../Marco06B13R2/README.md) e seus arquivos de licença. Mudanças do projeto em 16/10/2026: calibrações próprias, geometria de capa/chapéu/mochila/cinto, materiais e composição por direção. Sem endosso dos autores originais.

O corpo e as seis camadas existentes são preservados. Shapes são produzidos no Aseprite/Lua. O orquestrador aceita `--character-config`; omitindo-o mantém a compatibilidade R3. O validador usa hash semântico do manifesto para tolerar finais de linha, mas hash binário exato do Aseprite. Os originais e resultados históricos R2/R3 não mudam.

**Estado artístico:** o usuário julgou simples demais e priorizou uma base maior para todos os humanoides. Estes resultados são um checkpoint técnico não aprovado, testado em cena experimental, não uma roupa final de produção. [Relatório R4](../../../../Docs/Validation/Marco06B13R4.md) e [nova direção](../../../../Docs/Art/HumanoidStandard.md).

Referências de chão (32,62) e pivô (32,44) são fixas no canvas 64×64; o limite de botas varia nas poses profissionais originais. Não recentralizar cada frame para esconder essa variação. Reproduzir para destinos novos conforme o relatório; não reexecutar a medição sobre calibrações existentes.
