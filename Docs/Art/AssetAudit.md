# Auditoria inicial — 14/10/2026

Origem real: `D:/unity/Mmorpg/assets_para_usar`, fora de Assets. Seis originais preservados. Inventário quantitativo, SHA-256 e propostas de componentes em [Audit/inventory.json](Audit/inventory.json). Pranchas `Audit/*-components.jpg` mostram os componentes sobre fundo escuro; componentes são sugestões, não poses aprovadas.

Todas as imagens são PNG RGBA 1448×1086. A maior parte dos pixels do desenho tem alfa ~221–252; contar semitransparência não equivale a contar ruído. Existem centenas de milhares de pixels de alfa 1–7 por imagem. O pipeline remove apenas essa faixa quase invisível. Sombras, bordas e glows acima dela são preservados. Não há color-key nem threshold de opacidade total.

| Arquivo | Alfa zero | Alfa parcial | Alfa 255 | Auditoria visual / decisão |
|---|---:|---:|---:|---|
| personagem.png | 685861 | 886595 | 72 | 52 componentes grandes: 8 idle, 16 locomoção, 16 poses de combate, 12 poses baixas/rolamento. Não são 52 frames de um ciclo. Oito vistas aproximadas. Priorizar quatro vistas coerentes. Ataques sul têm duas lâminas; norte tem mãos elevadas incompatíveis com o grip atual. Reprovados para uso direto. |
| npcs.png | 693671 | 877799 | 1058 | 4 identidades × 3 vistas × ~5 linhas de poses. 60 componentes grandes, alguns com figuras vizinhas unidas. Curandeira, caçador, ferreiro, pesquisador aproveitáveis; retângulos manuais obrigatórios. Idle inicial estático; não afirmar ciclo de respiração nativo. |
| monstros.png | 440575 | 1131361 | 592 | Lobo: 10 vistas idle, 9 corrida, 8 ataques, 9 reações; não uma matriz 8×N. Ataques com corrupção misturada. Não há morte completa inequívoca de lobo. Aranha: vistas/locomoção, cuspe misturado e colapso/piscina final; não tratar mudança de vista como sequência temporal. |
| monstros_2.png | 549187 | 1022809 | 532 | Golem: 8 vistas por estado, ataque com cristais anexos, queda e escombros. Componentes de partículas alteram a indexação. Morcego: asas abertas/baixas, ataques e queda; perspectiva compatível, sem gameplay existente específico. Exige âncora aérea própria. |
| cenarios.png | 161484 | 1410798 | 246 | Terrenos, bordas, props e construções de cinco biomas. Muitos componentes encostam. Tiles têm molduras/bordas escuras e não passam como piso repetido sem tratamento. Casa, árvore, pinheiro, arbusto, rocha e pilar aproveitáveis com cortes explícitos; recorte anterior incluía vizinhos. |
| efeitos_habilidades_e_icones.png | 428582 | 1143334 | 612 | Espada avulsa, cortes, impactos, poeira, marcas, veneno, pedra, cura, cristal, corrupção e 12 ícones. Tamanhos e espaçamento variam; partículas separadas fazem parte de efeitos. Ordem só deve ser definida por inspeção, não pela quantidade de componentes. |

## Compatibilidade e riscos

As fontes compartilham paleta e iluminação, mas têm densidade de detalhe e proporções variáveis. Escalar cada bounding box à mesma altura destruiria identidade/tamanho: normalizar pelo corpo e âncora, com padding. Armas e efeitos extrapolam o corpo. Alfa não pode servir sozinho para detectar os pés.

Integração anterior `Provided06B2`: 128 PPU, cortes presumidos, lobo com linhas repetidas, outline ocultando espada, piso com matrizes 2× e câmera em grade 16. Não modificar PNGs/metas antigos. O marco B3 tem derivados, manifesto e cena própria; cenas anteriores continuam disponíveis.

## Seleção inicial

Manifesto reproduzível em `Tools/ArtPipeline/frames.json`; revisão de resultados em `Previews/`. Os status diferenciam processamento, revisão e validação real. Somente o conjunto conectado e inspecionado no Editor deve ser descrito como integrado. Cortes de expansão ainda podem ser rejeitados. Não há licença externa incluída: estes são arquivos locais fornecidos e autorizados pelo usuário; nenhum recurso externo foi baixado.
