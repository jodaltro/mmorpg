# Village02 — integração F

Arte aprovada pelo usuário em19/10/2026, registro em `Docs/Art/Approvals/Village02-Architecture-2026-10-19.json`. A exigência adicional é impedir travessia de construções e impedir o personagem desenhado sobre paredes/telhados. Essa aprovação não promove automaticamente a composição integrada.

`Tools/ArtPipeline/WorldGen/village02_integration.py` consome a receita revisada da fase E e as fontes aprovadas, produzindo `ArtSource/World/PlayableVillage02/IntegrationV1/`. O destino deve estar ausente. Não há geração em Play.

Distâncias de implantação do blockout recebem fator2,2 para acomodar os prédios na escala nativa das portas. **Sprites, protagonista e PPU não recebem esse fator.** O mundo mede282×335u. Ruas principais conservam a rede deliberada, com larguras explícitas; acessos são ligados às novas fundações. O rio continua sendo canal autorado, sem simulação hidráulica ou elevação física.

Fundações e planos de chão são anotações manuais em pixels do composite aprovado, origem superior esquerda. Conversão única: `world = position + (pixelX-anchorX, anchorY-pixelY)/32`. Essa conversão também posiciona os sprites. Não usar bounds do PNG ou telhado para criar o footprint. Cada polígono físico cria um `PolygonCollider2D` separado; não presumir união de paths sobrepostos num único collider.

Castelo, portão e ponte passam por uma **repartição de pixels no Aseprite**, em novas fontes `DepthArt/`. A recomposição é idêntica ao composite aprovado. As camadas são grupos de profundidade do desenho existente, sem inventar superfícies ocultas. Pátio/tabuleiro são chão; torre, salão, serviço, cortinas, arco e guarda-corpos são grupos opacos. Arco elevado não recebe collider no vão. Interiores e pisos superiores não são jogáveis.

`OpaqueStructureDepth` usa o envelope frontal projetado e o pé físico do ator para escolher ordem. A ordenação termina após a sincronização visual do protagonista, evita empates quando os bounds se cruzam e mantém alpha1. Não usa `ReferenceHouseDepth` ou cutaway transparente. Pode ocultar o ator atrás de volumes; não desenha uma silhueta sobre o telhado para compensar essa ocultação.

A muralha externa possui79 segmentos de chão, com base de1,5u. A superfície de pedra aprovada é consumida por malha seguindo a direção do perímetro; capeamento e faces fecham os trechos norte/sul que, como billboard único, ficariam de perfil. Essa montagem é apresentação nova candidata. O collider conserva o mesmo plano de chão; não é deduzido da deformação visual. Casas e castelo não são deformados.

Materiais de chão consomem as pinturas Ground11 em coordenadas globais, com cobertura de ruas e halo64px para as transições de borda;378 chunks512px no máximo. A água utiliza paleta/motivos Ground13 em quatro frames de180ms e máscara do canal. A superfície visual de água é separada dos dois polígonos de margem; a abertura física coincide com o tabuleiro interno, sem considerar o padding do PNG como espaço navegável.

Importador: `AgentScripts/BuildVillage02Integrated.cs`; cena `Assets/Mmorpg/Scenes/ValdoriaVillage02Integrated.unity`. Recusa cena/arte existentes, Play ativo ou cena suja; verifica manifests e hashes da arte aprovada. `CloseOwnedCurtains` é um reparo explícito da primeira importação, limitado às malhas dessa candidata, e recusa repetição. Não existe método de promoção.

A revisão `IntegrationV2/` acrescenta quatro planos físicos das folhas de madeira abertas, mantendo o vão central dos dois portões. `leaf-revision` produz novos grupos Aseprite para essas folhas e preserva os pixels por recomposição. O plano final tem120 polígonos físicos; os116 anteriores conservam coordenadas. `AddSolidGateLeaves` aplica essa revisão somente à candidata limpa e recusa repetição. A rodada final de `ValidateVillage02Integrated.cs` consome V2 e verifica também essas folhas. A navegação offline V2 continua exigindo a ponte. `IntegrationV1/generator-at-bake-v1.py` conserva o produtor exato cujo SHA está no manifestoV1; é proveniência, não outro comando de produção.

QA dirigido: `AgentScripts/ValidateVillage02Integrated.cs`. Percurso com Input System por todos os destinos sem reposicionamento entre eles. Depois, fixtures declaradamente reposicionadas empurram faces/cantos e executam esquiva, medindo [Collider2D.Distance](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Collider2D.Distance.html) e posição interior em vários frames. A grade de navegação usa clearance0,625u; fixtures usam o BoxCollider real do pé. O reposicionamento de fixture reinicia a participação do corpo na simulação antes do teste, evitando reaproveitar contatos da posição anterior; isso não é usado durante o percurso. Faces sem fixture externa são registradas como exclusões, nunca convertidas em aprovação implícita. Checkpoints conservam resultados e trace durante a execução. O limite temporário de60fps é restaurado depois de parar Play.

```powershell
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p test_village02_integration.py -v
python Tools/ArtPipeline/WorldGen/village02_integration.py plan
python Tools/ArtPipeline/WorldGen/village02_integration.py build --output Temp/Village02/new-integration
python Tools/ArtPipeline/WorldGen/village02_integration.py leaf-revision --output Temp/Village02/new-leaf-revision
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/BuildVillage02Integrated.cs --entry BuildVillage02Integrated.Main
```

Perfil de Play isolado em `Temp/Village02Integration/IsolatedProfile`. Ao terminar, parar Play, restaurar input/Game View e abrir a cena anterior. Evidências usam Original/ReviewLite e recuperação remota separada. Resultados reais, métricas e limitações: `Docs/Validation/ValdoriaVillage02-Integration.md`.
