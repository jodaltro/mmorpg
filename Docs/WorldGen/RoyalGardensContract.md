# Recinto real ampliado — Village02

Pedido de19/10/2026: ampliar bastante a área rica do castelo e o chafariz. Em seguida, o usuário autorizou: “Pode aplicar cena principal dai”. A promoção é autorizada; aprovação estética global não é inferida.

`ArtSource/World/PlayableVillage02/RoyalGardensV1/layout.json` substitui a receita consumida pela cena `ValdoriaVillage02Anime.unity`. O castelo compacto permanece como núcleo ao fundo do novo recinto de7797u². A área é5,42× a envoltória convexa de1438,13u² dos antigos volumes de fundação do castelo; essa comparação não mede a área caminhável líquida. O novo piso formal mede96×48u, com praça central e caminhos largos. O chafariz mede12,8u de diâmetro contra3,2u antes, reautorando o master em649×432px,32PPU, Transform1.

A fonte Aseprite preserva o pixel art em resolução nativa maior; não ampliar a Transform nem deformar a pintura do castelo. Piso novo foi gerado com image_gen integrado e convertido em fonte Aseprite; prompt e referência estão em generation-provenance.json. Fonte e export devem recompor os mesmos pixels. Água do chafariz é estática.

Geometria explícita:172 polígonos; os120 arquitetônicos e os dois troncos anteriores ficam intactos. O volume do chafariz muda de posição e dimensão; seis troncos e43 segmentos de limite são acrescentados. O recinto tem uma entrada de12u ao sul. Os caminhos não podem atravessar o chafariz. Flores baixas são não sólidas. O terreno e rio fora do patch, o personagem, a câmera de gameplay e os sistemas de combate não mudam.

O produtor Python e o importador BuildRoyalGardens recusam destinos de arte existentes; o importador exige Editor parado e limpo e verifica hashes antes de editar a cena autorizada. Uma cópia temporária da cena anterior é guardada antes da integração. Promote exige QA Play concluído com resultados aprovados e configura a cena como primeira habilitada. Demais cenas habilitadas permanecem como rollback. Não reexecutar Main sobre o destino já construído.

QA: cinco testes offline verificam conservação dos polígonos, fontes/exports/hashes, dimensões, conectividade e fechamento negativo da entrada. Play dirigido verifica os172 polígonos reais, percurso contínuo, duas faces longas dos43 segmentos novos, chafariz, seis troncos, esquiva cardinal e profundidade opaca frente/trás. Fixtures indisponíveis devem ser registradas, não contadas como aprovadas. Evidências e limites em `../Validation/ValdoriaRoyalGardens.md`.
