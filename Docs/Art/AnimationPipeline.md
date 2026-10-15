# Pipeline de arte e animação — 06B.3

## Arquivos e reprodução

Originais somente leitura em `assets_para_usar/`. Instalar as dependências de `Tools/ArtPipeline/requirements.txt` em um ambiente Python local. Não executar a auditoria novamente para substituir o baseline SHA de uma revisão existente.

```powershell
python Tools/ArtPipeline/audit.py          # inventário inicial / pranchas de propostas
python Tools/ArtPipeline/build_manifest.py # decisões explícitas de recorte e máscaras
python Tools/ArtPipeline/process.py        # derivados, padding, pranchas e GIFs
python Tools/ArtPipeline/terrain.py        # terrenos periódicos e três auxiliares locais
python Tools/ArtPipeline/verify.py         # QA estrutural rápido, sem suítes de gameplay
```

O manifesto canônico é `Tools/ArtPipeline/frames.json`. A cópia de saída `Assets/Mmorpg/Art/Processed/manifest.json` acrescenta caminho, hash e bounds dos PNGs. Coordenadas são x/y/w/h a partir do canto superior esquerdo da fonte; pivô Unity é normalizado a partir de baixo. Cada entrada tem fonte, personagem, ação, direção, quadro, canvas, escala, âncora, duração de referência, máscaras e status. As durações de ataque/esquiva em jogo vêm do estado real, não da duração sugerida do recorte.

Não há Grid Slice. Componentes alfa≥32 propõem regiões; os cortes finais são explícitos e corrigidos manualmente. Resíduos de alfa≤7 são zerados, preservando o restante do canal alfa, as cores escuras, sombras e partículas. Máscaras de lâminas são polígonos em coordenadas da fonte com expansão de 3 px para a franja; aplicadas somente aos derivados aprovados. Pés normalizados por âncoras manuais; nearest a 1/3 no humano. O QA exige o mesmo último pixel dos pés nas oito poses de caminhada.

## Importação e authoring no Editor conectado

Todas as chamadas usam `--caller plugin --skill unity-pipeline`. Nenhum arquivo `.meta` foi editado manualmente. Sprite Single, 32 PPU, Point, Uncompressed, mipmaps desligados, Clamp, Alpha Is Transparency, max 512, FullRect; os canvases transparentes são preservados. O painel uGUI tem border de 4 px e multiplicador de PPU adequado ao Canvas existente.

```powershell
unity command set_autotick --caller plugin --skill unity-pipeline
unity command recompile --caller plugin --skill unity-pipeline
unity command recompile_status --caller plugin --skill unity-pipeline
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.Import
# Somente na primeira criação, com B2 limpa e fora de Play:
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.CreateScene
# Com a cena B3 aberta, fora de Play:
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.Player
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.Wolf
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.Environment
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.Interface
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.Finishing
unity command run_script --caller plugin --skill unity-pipeline --file AgentScripts/IntegrateArt06B3.cs --entry IntegrateArt06B3.FinalPolish
```

`CreateScene` recusa arquivo existente. Os demais passos atualizam os próprios assets mantendo GUIDs. Em uma reprodução completa, executar na ordem acima; `FinalPolish` restaura os ajustes de limites/NPCs ao fim. `Environment` conserva células/regiões e cria um tile por máscara de conexão do caminho, sem matrizes 2×. Não usar `CreateScene` para substituir a cena B3 já produzida.

## Controlador equivalente a Animator

`GameplaySpriteSet` contém poses serializadas em ordem S/O/N/L e velocidades. `GameplaySpriteAnimator` observa ActorMotor, ActorHealth, SwordSwing e WolfBrain. Não decide dano nem move colliders. Relógio de caminhada reinicia ao parar; ataque e dodge não possuem loop autônomo. Dano vem de Changed, morte de IsAlive. `ActorVisual` mantém flash e Y sorting pelo pé. Novas opções têm defaults que preservam as cenas anteriores.

O humano tem idle estático, caminhada de **duas poses reais**, stances de ataque, uma pose de esquiva por direção e flash de dano. A espada separada faz o movimento contínuo completo do golpe. As poses originais de ataque foram reprovadas para integração porque braços elevados, dupla lâmina ou mãos muito afastadas não correspondem à empunhadura física. Reutilizar stances compatíveis não cria novos desenhos de ataque. É necessário redesenho para um ataque corporal de acabamento final e caminhada mais rica.

`SwordSwing` mantém a varredura, filtros, LOS, limite de alcance, cooldown e HashSet por golpe. Quatro âncoras locais de empunhadura foram calibradas na cena B3 e são compartilhadas por `Grip`, desenho e Sweep. Não há hitbox paralela, dano calculado pela animação, espelhamento da arma nem segunda espada. A futura autoridade remota continua responsável por validar geometria independentemente.

VFX: `SwordPresentationEffects` exibe corte somente em SwordSwing.Active e poeira somente ao iniciar dodge. `SheetImpactFeedback` continua escutando HitConfirmed. O rastro geométrico anterior foi desativado na apresentação B3. `ActionTargetVisual` consulta as marcas existentes, com arte específica; indicadores antigos permanecem referenciados, com sprite vazio para evitar duplicação. Nenhuma regra de habilidade mudou.

Lobo: duas poses compatíveis para locomoção lateral, windup/charge observados, reação curta, fade na morte. Norte sem ataque coerente conserva o corpo norte; frente tem pouca variação. **Não há morte nativa de lobo nem ciclo completo de corrida.**

## Prefabs e expansão

Nove prefabs em `Assets/Mmorpg/Art/Prefabs/`: PlayerVisual, Enemy_Wolf_Visual, Enemy_Spider_Visual, Enemy_Golem_Visual, Enemy_CrystalBat_Visual e quatro NPCs. São visuais, sem authority, IA, inventário ou duplicação de colliders. Os quatro conjuntos de personagens apontam para GameplaySpriteSet através de SpriteVisualDefinition. A cena mantém os componentes físicos legados e recebe as referências preparadas sem uma migração ampla da hierarquia.

NPCs têm idle estático honesto. Humanos de ExplorationNode usam filhos com escala compensada, preservando a proporção sem alterar roots/colliders. Morcego tem VisualSpriteLoop com duas poses frontais e sombra em filho separado abaixo da âncora aérea; não é inimigo jogável. Aranha e golem possuem poses, reação e estágios de colapso preparados, mas as sequências/direções não passaram por gameplay neste marco e não substituem seus adaptadores antigos. Não usar a ordem de direções das poses de morte como uma timeline aprovada.

## Inspeção curta e evidências

`AgentScripts/InspectArt06B3.cs`: Prepare → editor_play → Setup → Player / Village / Fight / AbilityVisuals / HunterOnDummy → editor_stop → Cleanup. Prepare usa um diretório único sob Temp/Marco06B3 e restaura configurações de input/Play em Cleanup. Os passos caminham com Input System; não teletransportam o personagem. AbilityVisuals/HunterOnDummy usam o modo isolado de habilidades já existente, sem persistir unlocks. Um pedido de marca rejeitado não deve ser contado como validação visual positiva.

Capturas reais via ScreenCapture no Editor em `Docs/Validation/Marco06B3/`. GIFs de pranchas são previews de assets; GIFs com prefixo `gameplay-` são sequências das capturas reais. O Pipeline desta instalação salva capture_game_view sob Assets mesmo com outro caminho; cópias finais são organizadas em Docs. Windowbox pode exibir barras em Game views que não comportam um múltiplo inteiro de 640×360. Não confundir o padding/barras com resolução da arte.
