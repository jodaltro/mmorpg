# Bases animadas para adaptação — pesquisa B13 R2

Biblioteca de fontes, não personagens finais de Valdoria. Nenhum arquivo desta pasta está importado pela Unity. Sem mudanças no protagonista, NPCs oficiais ou gameplay.

O usuário autorizou procurar bases pela anatomia, movimento, estrutura e licença, adaptando a aparência depois no Aseprite. Roupas e identidade visual atuais não são requisitos para selecionar uma base. Não foi fabricada data de lançamento em 2026 para materiais anteriores ou sem data comprovada.

## Fontes e condições de publicação

| Pasta | Autoria / fonte | Licença aplicável |
|---|---|---|
| HormelzGirl | [Hormelz](https://hormelz.itch.io/8-directional-girl-character), adaptação 2D de [Mari, por Styloo](https://styloo.itch.io/mari) | CC0-1.0 declarado nas duas páginas; permite editar e redistribuir, inclusive PNGs e derivados no GitHub |
| HormelzMelee | [Hormelz](https://hormelz.itch.io/8-directional-melee-character) | CC0-1.0 declarado pelo autor |
| LpcFeminine, LpcMasculine e suas pastas Body/Head | [LPC Revised — Eliza Wyatt](https://github.com/ElizaWy/LPC), commit `f07f7f5892e67c932c68f70bb04472f2c64e46bc` | OGA-BY 3.0, conforme créditos específicos dos corpos e cabeças; exige atribuição e indicação das alterações |
| MagicEffects | [Pixel Magic Effects](https://foozlecc.itch.io/pixel-magic-sprite-effects), distribuído por Foozle, encomendado a lordfitoi | CC0-1.0; README original em Licenses |

Conferência: 16/10/2026. [CC0](https://creativecommons.org/publicdomain/zero/1.0/) permite cópia, modificação e distribuição. O texto completo de OGA-BY e os créditos originais estão em `Licenses/`; os materiais LPC **não** são CC0. Sua licença não foi substituída pela licença de código do projeto. Preservar créditos/licença junto de qualquer adaptação.

### Atribuição LPC das peças selecionadas

Corpo e cabeça femininos: Stephen Challener (Redshrike) e Eliza Wyatt (DeathsDarling). Corpo masculino: Stephen Challener (Redshrike), Durrani, Eliza Wyatt (DeathsDarling) e BenCreating. Cabeça masculina: Stephen Challener (Redshrike) e Eliza Wyatt (DeathsDarling). Mantidos os créditos completos originais, inclusive colaboradores de animações adicionais, em `Licenses/LPC-Character-Credits.txt`.

Fontes anteriores: https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles e https://opengameart.org/content/lpc-jump-expanded . Licença: https://static.opengameart.org/OGA-BY-3.0.txt . Coleção: https://github.com/ElizaWy/LPC .

Alterações das bases deste laboratório: recorte de células fornecidas para timeline e composição dos desenhos existentes de corpo/cabeça em camadas separadas; sem redesenho, recoloração, resampling ou criação de poses. O estudo posterior `Wardrobe/` combina roupas/cabelo e recolore materiais, conforme descrito abaixo. Não sugerir aprovação dos autores.

## Abrir e editar

Cada candidato possui `.aseprite` e `manifest.json`. Os PNGs/JSONs originais selecionados estão nas pastas `Originals`; seus bytes foram preservados, com SHA-256 em `original-hashes.json`. A montagem não extraiu todos os pacotes nem versionou ZIPs.

- HormelzGirl: idle e walk nas quatro direções cardinais; desenhos já vestidos, cabelo/saia animados; um layer raster original. Alterações de roupa exigem edição coerente nos quadros.
- HormelzMelee: idle e walk cardinais; estrutura corporal mais livre para desenhar vestimenta, mas com bastante trabalho manual. Os JSONs do download estão vazios. Os tempos usados vêm do GIF lateral de referência e estão identificados como inferidos nas outras direções.
- LPC: body/head separados e idle/walk reais. A biblioteca oferece roupas/cabelo/acessórios separados; estes materiais adicionais não estão implicitamente selecionados nem licenciados por esta cópia. Conferir seus créditos antes de incorporar.
- MagicEffects: dez tags com os efeitos originais; potencial para apresentação de magia. Não conectado a cura, combate ou eventos. O download individual tem canvas **64×64**, apesar da descrição de estilo 32×32 na página.

Timings originais em JSON da base feminina estão no manifesto; a timeline Aseprite arredonda para milissegundos inteiros. Timings de LPC e efeitos são de inspeção e não foram apresentados como timings originais. PNGs de origem foram mantidos completos; RGB oculto sob alfa zero pode diferir na composição/exportação, sem alterar pixels visíveis ou alfa.

Editar uma **nova cópia** do `.aseprite`, mantendo este baseline e seus originais. O preparador recusa pasta existente por padrão; `--resume` apenas aproveita documentos existentes, sem sobrescrevê-los, e exige que os desenhos exportados ainda coincidam com os originais. Não usar `--resume` para regenerar trabalho artístico manual.

Faltam adaptação artística, escala final, pivôs/pés, avaliação no cenário e aprovação do usuário. O arquivo editável não equivale a aprovação para produção.

## Prova de roupas em camadas — orientação posterior do usuário

O usuário autorizou também roupas procedurais. `Wardrobe/` demonstra montagem determinística de peças profissionais já animadas e remapeamento de suas paletas. Não gera desenho corporal, poses ou caminhada. As roupas mantêm alfa, recortes e posição originais; mudam somente a composição de peças e as cores dos materiais.

Documentos editáveis: `MiraIvory.aseprite`, `MiraSage.aseprite`, `OrinForest.aseprite`, `OrinUmber.aseprite`. São sugestões de vestimenta de campo, não novos IDs narrativos nem personagens aprovados. Cada documento tem 44 quadros, 8 tags e 6 layers: Body, Pants, Boots, Shirt, Head, Hair. Os nomes das sugestões não afetam o jogo.

Roupas usadas: Longsleeve Shirt, Pants, Boots; autora Eliza Wyatt (DeathsDarling), derivadas da anatomia/animações LPC creditadas acima. Cabelo de Mira: Bangs & Bun, BlueCarrot16 e Eliza Wyatt; cabelo de Orin: Parted, Eliza Wyatt. Condições específicas em `Wardrobe/Sources/Characters/{Clothing,Hair}/Credits.txt`, **OGA-BY 3.0**. Fonte anterior do cabelo Bangs & Bun: https://opengameart.org/content/lpc-hair .

Modificações em 16/10/2026: montagem dos layers e remapeamento das cores das peças fornecidas para marfim, sálvia, verde floresta, terra e couro; cabelo convertido para castanho. Corpo/cabeça originais permanecem sem recoloração. Alterações do projeto, sem endosso dos artistas originais. Manter esses créditos nas futuras cópias/derivações e disponibilizá-los na apresentação de créditos antes de uma integração final no jogo.

Receitas e mapas RGB explícitos ficam nos JSONs correspondentes, permitindo trocar material sem variar arbitrariamente a cor entre frames. A sombra/luz já desenhada pelo artista é conservada pela rampa. Não há aleatoriedade durante a animação. Novas mangas, capas, vestidos ou acessórios com outra forma exigem um novo módulo desenhado/revisado nas poses necessárias; apenas colorir não cria uma silhueta nova.

Ferramenta: `Tools/ArtPipeline/build_npc_wardrobe_b13r2.py`, que aciona o montador Lua no Aseprite local. Recusa pasta existente por padrão; `--resume` verifica originais e desenhos resultantes sem sobrescrever os editáveis. Não aplicar esse modo sobre documentos já alterados manualmente. Fontes intactas e hashes estão em `Wardrobe/Sources/` e `source-hashes.json`. As prévias são ampliadas em nearest inteiro, sem alterar a escala relativa dos personagens.
