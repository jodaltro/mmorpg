# Valdoria Playable Village 01 — contrato v1

Composição autorada offline, seed `1202601`, domínio `112 × 144 u`, 32 PPU. A receita é `ArtSource/World/PlayableVillage01/recipe.json`; a revisão 2 separa celeiro e castelo. Esta é uma vila pequena com cinco construções, não um gerador universal de cidades.

`playable_village01.py` consome a receita e as referências existentes. Exporta `layout.json`, polígonos físicos identificados, navegação com clearance, cobertura de ruas, chunks de piso e quatro fases do canal. Caminhos e rio são **traçados autorados**, não novas execuções de roteamento Organic Roads ou simulação de drenagem. O acabamento do piso utiliza o compositor Ground11, suas fontes e a gramática de bordas em coordenadas globais; a água reaproveita paleta, motivos e playback Ground13.

- `physical`: único produtor dos colisores ambientais, separado dos pixels. Polígonos do castelo continuam independentes. A ponte retira bloqueio aquático apenas no vão declarado; os guarda-corpos restringem o tabuleiro útil a aproximadamente 4 u. Não há natação.
- `buildings`: posição, referência de fonte/export, entrada, aproximação e deslocamento dos contornos aprovados. Apenas orientação já desenhada, sem espelhamento da iluminação. Não há interiores.
- `paths`: rede de ruas e acessos. Mudanças de lotes exigem regenerar piso, acesso, ocupação e testes. Não mover o desenho sem atualizar o footprint.
- `props`: Nature10 reutilizado; colisores vêm dos contornos semânticos. A ordem estática de árvores é recalculada pela nova âncora, não herdada do prefab de estudo. Rochedos mantêm `NaturePropDepth`.
- Ground12: cópias derivadas dos meshes de plantas baixas, com exclusão contextual de ruas/obstáculos. Os pixels, materiais e UVs são reutilizados. O relevo Ground13R permanece além da muralha norte, inacessível; não há escalada.

O importador recusa cena/diretório existentes na criação inicial. Revisões explícitas operam apenas em seus próprios derivados. Não há geração durante Play. Prefabs visuais são saídas da montagem; a física continua no produtor semântico da região. Reposicionar um prefab isolado não atualiza a navegação automaticamente: usar receita/importador.

A vila se torna a primeira cena de inicialização somente após QA. `MmorpgWorld.unity` permanece byte a byte como rollback, junto à lista anterior de Build Settings. A promoção funcional não aprova artisticamente a nova composição.

Referências: [arquitetura](ArchitectureContract.md), [Ground11](GroundFinishContract.md), [hidrologia](WorldHydrologyContract.md), [fronteiras](EnvironmentBoundaryContract.md), [relevo](Ground13RPresentationContract.md), [relatório](../Validation/ValdoriaPlayableVillage01.md).
