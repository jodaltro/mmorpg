# Assets fornecidos pelo usuário — Marco 06B.2

Origem: arquivos locais em `assets_para_usar`, enviados e autorizados pelo usuário em 14/10/2026. Nenhum download ou chamada paga foi realizado. Não foi fornecido um texto de licença separado; a autoria/licença externa não foi verificada independentemente.

Os seis PNGs originais foram preservados byte a byte. Cópias importadas em `Assets/Mmorpg/Art/Provided06B2` usam Sprite Editor Data Provider, identidades estáveis, Point, sem mipmaps/compressão e 128 pixels por unidade. Recortes e pivôs vivem nos importadores; os PNGs não foram redesenhados.

| Arquivo | Uso neste marco |
|---|---|
| personagem.png | Personagem existente: oito orientações, idle e duas poses de locomoção |
| efeitos_habilidades_e_icones.png | Espada equipada, quatro frames de impacto e ícones dos seis slots existentes |
| npcs.png | Aparência de curandeira, caçador, ferreiro e estudioso nos NPCs existentes |
| monstros.png | Lobo e aranha existentes, com animação de locomoção |
| monstros_2.png | Sentinela e guardião de pedra existentes; nenhum morcego adicionado |
| cenarios.png | Pisos, casas, árvores, rochas, vegetação e pilares das regiões existentes |

O personagem possui uma espada embutida nos frames originais. Outlines da malha dos sprites de locomoção ocultam essa região para evitar duplicação; a espada separada acompanha o mouse e a varredura física. O arquivo original continua intacto. As poses de ataque embutidas na sheet não controlam dano: preparação, janela ativa e recuperação são animadas pelo mesmo relógio da espada e da hitbox.

A escala dos pisos foi aplicada também às matrizes das células do Tilemap. Os limites sólidos, os colliders, os NPCs, os IDs de coleta, as conexões das cinco regiões e os saves continuam usando os sistemas existentes. A escala visual dos props é ajustada em filhos, sem redimensionar suas colisões.

Os pixels dos novos assets são mais finos que os placeholders de 16 PPU. O tamanho em unidades do mundo foi ajustado; a câmera continua com enquadramento equivalente e grade de acompanhamento de 16 PPU. Esta entrega não afirma que todos os sprites têm o mesmo tamanho físico de pixel: refinamento artístico das sheets, outlines e transições continua sujeito à avaliação manual.
