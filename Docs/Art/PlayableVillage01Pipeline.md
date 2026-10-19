# Produção da vila jogável 01

Editar `ArtSource/World/PlayableVillage01/recipe.json`: cinco lotes, ramais, árvores/rochas e seed. O envelope defensivo e o domínio são fixos na primeira versão; mudanças nesses limites exigem revisar o contrato e as provas de entrada única.

Gerar em destino novo:

```powershell
python Tools/ArtPipeline/WorldGen/playable_village01.py build --output Temp/Village01/new-region
python Tools/ArtPipeline/WorldGen/village_structures01.py export --output Temp/Village01/new-structures
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_playable_village01.py -v
```

O segundo comando lê `StructuresV1/village-structures-v2.aseprite`: cinco camadas de módulos, 512×640. `nativeRects` define os recortes. A fonte conserva parede longitudinal, frente de muralha, tabuleiro e dois guarda-corpos. Os scripts `author/refine` registram a montagem inicial e recusam sobrescrita; não executá-los sobre uma fonte editada. Masters ImageGen e proveniência estão preservados. Não se promete repetir uma imagem generativa por seed; exportação e composição são reproduzíveis a partir das fontes assinadas.

Muralha frontal: enquadramento alpha explícito remove margens que criavam frestas. Peças finais são recortadas, não comprimidas, preservando dimensões das ameias. A ponte usa arte própria; portão reutiliza arco e madeira do castelo aprovado. Fontes aprovadas não foram redesenhadas. A peça lateral foi estudada separadamente para evitar rotação de luz pintada.

Para outra revisão, atualizar destinos/versionamento no importador e verificar manifests antes da integração. Importação inicial via `BuildPlayableVillage01.Main`; não executar contra a cena já existente. Os métodos explícitos de revisão documentam as alterações desta entrega e não são comandos genéricos de sobrescrita.

Unity: Point, 32 PPU, sem mipmaps/compressão, câmera de gameplay ortográfica 14,0625 em 1600×900 (32 pixels por unidade de tela). O grupo visual Quaternius mantém 1,25. Física deriva de polígonos; telhado/copa não são retângulos de colisão. Profundidade e cutaway reutilizam os componentes existentes.

QA: percurso completo com Input System e teclado sintético, sem teletransporte; fixtures dirigidas de colisão/oclusão são identificadas separadamente. Capturas após `WaitForEndOfFrame`, originais imutáveis, [ReviewLite](VisualReviewEvidence.md), manifesto, índice e recuperação remota após push. Timings medidos durante geração/compressão não servem como benchmark limpo.

Não automatizar aprovação artística, reorientação de faces já iluminadas, dimensionamento de portas sem referência ou mudanças silenciosas de topologia. Expandir o envelope defensivo exige provar novamente que rio, muralha e limites impedem acessos alternativos.
