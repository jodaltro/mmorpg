# Ground13R — processo de refinamento

O [feedback Ground13R](Approvals/Ground13R-Direction-2026-10-18.json) reprova o platô Ground13 e preserva a direção aquática. A [extensão de apresentação](../WorldGen/Ground13RPresentationContract.md) delimita o que pode mudar.

## Produzir uma revisão

1. Conferir worktree, pull de main, Editor e destino. Preservar dados/arte aprovados por hashes.
2. Estudar a forma neutra em Play. Trabalhar contornos, estratos e fraturas na receita antes da pintura. Fonte física é somente leitura. Nesta rodada, não foi necessário Blender: a inspeção neutra ocorreu sobre a malha efetivamente usada na Unity.
3. Contornos superiores são curvas dirigidas, com recessos e bocas de fratura específicos. Uma superfície contínua substitui as extrusões de altura constante. Ruído não decide a silhueta.
4. Compor áreas calmas, bolsões de vegetação, terra e substrato em Aseprite. Orientar materiais segundo a superfície. A textura mineral deve manter tamanho de pixel nas faces íngremes.
5. Exportar a fonte final, importar na cena experimental e comparar A/B/C e ambos os neutros com a mesma câmera. Reprovar internamente estiramento e sobreposição; não disfarçar com decals.
6. Validar pé físico, navegação, personagem, ordenação e custos. Compactar atributos idênticos preservando a ordem; não aproximar posições ou suavizar seams para economizar memória.

## Reconstrução das saídas finais

Usar destinos **novos**. As fontes Aseprite versionadas são autoridade; não executar bootstrap sobre trabalho revisado.

```powershell
python Tools/ArtPipeline/WorldGen/ground13r.py relief --output Temp/Ground13R-Rebuild/Shape
python Tools/ArtPipeline/WorldGen/ground13r.py export --output Temp/Ground13R-Rebuild/Export
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_ground13r.py -v
```

`relief()` aceita uma receita alternativa pela API Python. `recipe`, `author`, `refine-contacts` e `bedrock` conservam o procedimento de construção dos estudos e recusam destinos existentes. Não são comandos para sobrescrever uma pintura manual. O arquivo `SourceV4/contact-recipe.json` registra as línguas minerais e a fonte anterior; o layer final permanece editável independentemente do gerador.

Para reconstrução Unity em checkout de autoria com novos caminhos, definir `Art` e `Scene` no importador e executar `BuildGround13R.Main` via Unity CLI conectada, `--caller plugin --skill unity-pipeline`. Ele lê ShapeV6/ExportV4 e compartilha os assets anteriores. `BuildGround13R.Shape` atualiza explicitamente apenas a malha do próprio laboratório; `Painting` recusa textura de destino existente. Não apagar os destinos para contornar a recusa.

## Evidência temporal

`Ground13RWaterCapture` é uma sonda **somente de Editor**, adicionada temporariamente durante Play. Aguarda `WaitForEndOfFrame`, observa `FrameIndex` e os PNGs efetivamente ligados aos property blocks e captura a tela. Não força fase. Registra doze mudanças reais, frames Unity, tempo e caminhos dos seis chunks. É removida ao terminar; não está salva na cena.

`ground13r_evidence.py temporal()` valida 3→0, sincronismo e repetição; deriva os GIFs dos PNGs observados, com tempos medidos, paleta compartilhada e sem interpolação/dithering. `index()` reconstrói o índice e os recortes 1:1 sem sobrescrever originais. Os GIFs são auxiliares; PNGs integrais permanecem a autoridade.

Usar o pipeline ReviewLite compartilhado e nomes explícitos para capturas homônimas. Comparações recebem transformações equivalentes. Cópias de revisão inéditas geradas durante o trabalho podem ser reconstruídas a partir dos originais; evidências históricas publicadas e originais nunca são apagados. Testar recuperação real pelo GitHub depois do push.

## Pontos de direção artística

Decisões de silhueta, posicionamento de fraturas, leitura mineral e equilíbrio de pigmento exigem inspeção artística. Não automatizar aprovação por densidade de manchas, número de testes ou taxa de compressão. As bordas posteriores e o pé histórico continuam exigindo avaliação na composição e em aproximação. Uma alteração física futura continua dependendo de proposta e autorização próprias.
