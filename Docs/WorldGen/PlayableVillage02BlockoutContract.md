# Village02 — contrato do marco layout/blockout

Escopo: fases A–D do pedido; sem sprites finais, interiores, NPCs, monstros ou nova mecânica. Planta deliberada, bake reproduzível, cena isolada `Assets/Mmorpg/Scenes/ValdoriaVillage02Blockout.unity`. Não está no Build Settings. Cena01 e `MmorpgWorld` permanecem recuperáveis e intocadas.

`ArtSource/World/PlayableVillage02/recipe.json` → `village02_blockout.py` → `BlockoutV1/{layout,manifest,navigation-proof}.json` → `BuildVillage02Blockout.cs`. Receita e gerador têm SHA256 no manifesto; importador verifica os arquivos e a receita. Alterar fonte exige novo destino e revisão, nunca sobrepor a fonte anterior. O seed identifica a composição; não promete criar cidades aleatórias de qualidade.

Camadas explícitas: zonas/lotes e funções → ruas/acessos → footprint projetado → faces/altura aparente → colisores e navegação → apresentação neutra → detalhes futuros. O desenho do chão usa x leste/y norte. A projeção do edifício tem fachada inclinada -0,18, profundidade com shear0,35 e altura visual em +Y. Não é terreno físico 3D. Curvas de relevo são estudo de implantação; ainda não há rampa jogável, degraus ou física de elevação.

`volumes.footprint` produz as paredes/telhados neutros, o polígono de chão e a linha de profundidade. `physical` mantém um collider separado por polígono; spans elevados dos portões não criam collider no vão. Água bloqueia margem a margem fora da ponte; guarda-corpos limitam o tabuleiro. `VillageBlockoutDepth` mantém exterior opaco e ordena pela frente do footprint no X do ator. Nenhum sistema de cutaway01 é reutilizado na cena02. Uma construção opaca pode esconder o ator atrás dela — isso é uma decisão explícita deste estudo, não interior jogável.

O gerador atual copia a receita antes de acrescentar derivados e recusa mover uma casa sem reautorar sua aproximação à porta. Acesso e lote continuam decisões explícitas, não um resolvedor universal. `generator-at-bake-v1.py` é o arquivo de proveniência cujo SHA corresponde ao manifestoV1, preservado como arquivo, não como novo comando de execução. Após essas duas guardas, um replay emTemp confirmou os mesmos quatro outputs byte a byte; recibo no relatório. Nenhum original de imagem foi substituído.

Os volumes cinza são geometria editorial, não um novo gerador de arte acabada. Portas são marcas de escala de4,85u, sem interação. Variações de altura/largura existem na planta; aprovação do estudo não aprova automaticamente essas formas como sprites.

## Reprodução

```powershell
python Tools/ArtPipeline/WorldGen/village02_blockout.py build --recipe ArtSource/World/PlayableVillage02/recipe.json --output Temp/Village02/new-bake
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_village02_blockout.py -v
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/BuildVillage02Blockout.cs --entry BuildVillage02Blockout.Main --timeout 120 --format json
```

O builder acima aponta para o bakeV1 e **recusa** cena/arte existentes. Para nova revisão, versionar os destinos no script e manifesto. O primeiro import levou mais de30s e a chamada inicial expirou; a conclusão foi confirmada posteriormente pelo recibo `QA/build.json` e inspeção da cena. Timeout de transporte não foi tratado como sucesso.

## Promoção

1. Revisão explícita da planta, entrada, vista interna e silhueta do castelo pelo usuário.
2. Revisão de layouts/volumes se pedida; nenhuma produção completa de sprites antes disso.
3. Produção artística em novas fontes Aseprite, QA de encontros e relação arte/footprint; consumir Ground11–13R sem alterar as fontes aprovadas.
4. Integração/Play com evidências de todas as construções, câmera, circulação e profundidade na arte final.
5. Somente após essa validação, promoção explícita da candidata final e documentação do rollback. O builder02 não possui método de promoção.

Pesquisa: `Docs/Validation/ValdoriaVillage02-References.md`. Diagnóstico: `Docs/Validation/ValdoriaVillage02-Diagnosis.md`. Apresentação/QA: `Docs/Validation/ValdoriaVillage02.md`.
