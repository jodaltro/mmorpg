# Humanoid2026 — fontes maiores e prova de pixel art

Pesquisa de 16/10/2026 para o futuro padrão de todos os humanoides, inclusive protagonista. **Candidato, sem promoção de produção.** [Direção, pesquisa e limites](../../../Docs/Art/HumanoidStandard.md).

## Conteúdo e licença

Autor: **Quaternius**. [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) e [Universal Animation Library](https://quaternius.itch.io/universal-animation-library), edições **Standard gratuitas, CC0-1.0**. Avisos originais em `Sources/License-BaseCharacters.txt` e `Sources/License-Animations.txt`. Não contém kits Source/Pro pagos.

Fontes obtidas: corpos masculino e feminino com 65 ossos, texturas necessárias e UAL1 Standard com 43 animações. Os personagens preparados aqui têm olhos/sobrancelhas e roupa base; os cinco cabelos anunciados no kit gratuito não foram todos adquiridos. A oferta de seis corpos/vinte cabelos pertence ao catálogo Source pago, não a este subconjunto gratuito.

O ZIP oficial não foi obtido: navegador não retornou o arquivo e HTTP recebeu 429. Os dados vieram de [mirror público](https://github.com/NafisRayan/Animate-Rigged-Humanoid-No-Blender) no commit `5821923af517ac5fdc82505faa92a0d575fc1b1a`. [provenance.json](provenance.json) registra caminhos do mirror, hashes Git/SHA-256 e páginas oficiais. Nenhum código desse mirror foi executado. Duas URIs de normal map com sufixo `_png` foram resolvidas copiando o arquivo correspondente para o nome solicitado, mantendo os glTF originais intactos.

## Prova entregue

`Preview/Male` e `Preview/Female`: `.aseprite` RGBA 128×160, atlas, manifesto, oito GIFs de dois ciclos e dados de exportação; 52 quadros por corpo (um idle e 12 walk por direção). `Preview/native-comparison*.png` e `directions.png` comparam pixels nativos com os NPCs pequenos, sem redimensionar os candidatos para esconder a diferença.

Altura visível: masculino 102–121 px, feminino 99–118 px. Originais 3D permanecem separados. Blender inspeciona/renderiza os movimentos existentes; Aseprite Lua aplica quantização e contorno em layer separado. Python monta as pranchas. Não houve geração externa, criação de anatomia ou simulação de tecido. Transferência de movimento é experimental; nomes de ossos iguais não certificam retarget, contato dos pés ou empunhadura finais.

Os frames renderizados de trabalho ficam em Temp. A saída editável e seu atlas são a prova versionada; não foram importados no jogo. [verification.json](verification.json) registra integridade das 19 fontes e roundtrip exato dos pixels dos 104 frames Aseprite, com oito tags em cada documento.

## Reprodução

Na raiz do repositório, usando Blender e Aseprite locais. Usar destinos novos; não sobrescrever edições manuais.

```powershell
python Tools/ArtPipeline/prepare_humanoid_study_b13r4.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python Tools/ArtPipeline/inspect_humanoid_study.py -- --output Temp/HumanoidResearch/NovaRenderizacao --frames 12
python Tools/ArtPipeline/export_humanoid_study.py --renders Temp/HumanoidResearch/NovaRenderizacao
python Tools/ArtPipeline/verify_humanoid_study.py
```

O preparador aceita apenas fontes ausentes ou idênticas. O renderizador exige pasta nova. O exportador de estudo exige `Preview` ausente: para uma nova proposta, trabalhar em cópia do laboratório ou parametrizar esse destino antes de executar; não remover o estudo revisado. A exportação atual é uma ferramenta de pesquisa com destino explícito, não um importador universal de personagens de produção.
