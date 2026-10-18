# NatureReference — suplemento experimental v1

Consumidor offline dos contratos WorldRegion, Organic Roads, materiais, hidrologia, EnvironmentBoundary e vegetação/arquitetura existentes. Não substitui nem reescreve esses produtores. Implementação: `Tools/ArtPipeline/WorldGen/nature_reference10.py`; padrão artístico candidato: `Docs/Art/NaturalEnvironmentProduction.md`.

- `valdoria-authored-nature-source/v1`: ID, kind, fonte Aseprite, canvas,32PPU, groundAnchorPixels, camadas, footprintPixels para pedras ou physicalRadius para troncos. Coordenadas de pixels têmY para baixo. Footprint relativo à âncora; na Unity divisão por32 e inversãoY. Camadas descrevem propriedade exterior, não faces ocultas.
- `valdoria-nature-sprites/v1`: atlas1024² e sprites com rectPixels, sourceRect, offsetUnits, asset/part. Rects no arquivo têmY para baixo; Unity converte ao importar. Sprite pivô0,0 e offset de recorte preservam o chão autorado. Não reescalar em packing.
- `valdoria-nature-composition/v1`: seed910210, região64×48, substituições explícitas de IDs/raios e instâncias rochosas com posição/asset. `physicalChange` é obrigatório nesta referência. Não tratar mudança de arte como permissão implícita de mudar circulação.
- `valdoria-nature-material-composition/v1`: boundsPixels/sizePixels, seed, estágios base/transitions/final e inputs por caminho+SHA256. Campos em coordenadas globais; patch deve igualar o recorte do full render.
- `valdoria-nature-build/v1`: arquivos por SHA256, inputs por caminho+hash, versão `valdoria-authored-nature/1.0.0`. Destino ausente; input modificado invalida o consumo. Fontes editáveis são retidas; reconstrução determinística começa nos Aseprite, não na pintura IA inicial.

Posições da receita usam o mesmo domínio64×48 dos especialistas: Unity `(x,48-y)`. Ocupação usa malha .25u, centros de amostra. Reconstruir árvores sobre a base de navegação/arquitetura/água existente, depois aplicar somente os footprints declarados; preservar caminho até a entrada com clearance mínimo .57u. Pedras não podem intersectar ocupação anterior, água, relevo sólido/reservas ou ficar a menos de .7u da estrada nas amostras de footprint. Esta verificação é raster/subcélula, não uma prova contínua de clearance para qualquer ator.

`NaturePropDepth` deriva o envelope frontal do mesmo polígono do collider; sorting usa atorX/pés. `NatureReferenceLab` alterna visual, colisores e bytes de navegação conjuntamente entre estado anterior e candidato. Malhas físicas dos produtores permanecem iguais. Uma mudança futura de footprint exige nova ocupação e QA, não apenas reexportPNG.

Prefabs são instâncias reutilizáveis de autoria, não um sistema de spawn que modifica navegação em runtime. Para consumidores futuros, contato visual, ocupação física e bounds da copa são campos/conceitos distintos. Vegetação/construção devem consumir o footprint, não a área inteira de uma copa ou o PNG de solo. Nenhum novo sistema de gameplay é prometido neste suplemento.
