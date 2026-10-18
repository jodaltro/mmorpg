# Evidências visuais — originais e ReviewLite

A partir de Ground12, toda validação visual importante deve entregar capturas PNG integrais de Play, imutáveis, e cópias PNG para revisão no GitHub, cada uma com no máximo **750KiB (768.000bytes)**. Preferir300–700KiB quando isso conservar leitura útil; o limite não garante que o conector funcionará. Nunca substituir a autoridade original pela versão de revisão.

Estrutura: `Original/`, `ReviewLite/`, `Details/` e `QA/`. Não mover ou apagar evidências históricas. Capturas offline/Editor são identificadas separadamente e não substituem Play. Comparações usam câmera, ator, escala, resolução e luz equivalentes; a transformação de revisão também deve ser equivalente.

```powershell
python Tools/ArtPipeline/review_lite.py build --root Docs/Validation/REGIAO --index Docs/Validation/REGIAO/QA/capture-index.json
python Tools/ArtPipeline/review_lite.py verify --root Docs/Validation/REGIAO --manifest Docs/Validation/REGIAO/QA/image-manifest.json --report Docs/Validation/RELATORIO.md
```

O índice contém `images`, cada uma com `original` relativo à raiz de evidências, `scene`, `state`, `comparison`, `camera` e `integral`. Recortes incluem `crop:{source,boundsLTRB,sampling}` e `integral:false`. Câmeras fixas registram posição, ortográfica,32PPU, resolução e escala do ator; sequências móveis referenciam também o trace por frame. O manifesto acrescenta dimensões, bytes, SHA256, método, divisor, informações de paleta e integridade.

O compositor tenta recompressão PNG sem perda, remove metadados e elimina alfa redundante somente quando totalmente opaco. Se necessário, usa nearest com divisores inteiros2/3/4, sem distorcer aspecto. Nunca suaviza, altera saturação, contraste ou iluminação, nem adiciona dithering.

Quando a cópia a1/2 ainda ultrapassar o limite e a1/4 prejudicar a leitura, pode-se autorizar **somente na cópia de revisão** `--allow-quantization`. Nesse modo, a1/2 usa paleta comum de256cores calculada para todo o grupo comparativo, sem dithering. O erro médio absoluto por canal deve ser≤3 e o percentil95≤9; os valores são registrados e verificados. Isso não prova equivalência artística: inspecionar contra os originais e oferecer recortes1:1 dos detalhes importantes. Não usar quantização silenciosa.

O script recusa destino existente e falha para arquivos ausentes, PNG inválido, limite excedido, transformação/câmera incompatível no par, aspecto distorcido, hashes/bytes divergentes, alpha alterado, paleta/erro fora do contrato ou imagens quebradas no relatório. Testes: `python -m unittest discover -s Tools/ArtPipeline -p test_review_lite.py -v`.

Depois de publicar, recuperar pelo menos um ReviewLite pelo mecanismo disponível. Se houver conector GitHub, chamar `github_fetch_file` com `encoding:base64`, repositório e `ref:main` explícitos; conferir assinaturaPNG e SHA256 contra o manifesto. Registrar separadamente publicação, tamanho, recuperaçãoBase64 e inspeção visual. Não afirmar que o ChatGPT abriu a imagem pelo conector sem essa inspeção. A validação local não equivale à recuperação remota.
