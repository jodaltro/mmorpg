# Marco 06B.12 — protagonista oficial

## Diagnóstico registrado antes da promoção

Em 16/10/2026, `EditorBuildSettings` tinha oito cenas habilitadas, iniciando em `Marco06B2World.unity`. Nenhum bootstrap troca automaticamente essa entrada. O Editor estava em Play na B11, com perfil pessoal normal e sem override de validação; `playModeStartScene` estava vazio. Play da cena aberta e entrada do build divergiam.

A inspeção confirmou as mesmas cinco regiões, 28 nós de exploração e sete interações narrativas, com posições e configurações regionais iguais. A B2 tem 389 objetos; a B11 tem 502 e inclui a apresentação aprovada, arte de mundo posterior, câmera adaptativa, menu de sessão e proteções de persistência. O jogador é um objeto da cena, sem prefab físico; o prefab visual B4 antigo não define o Iron Knight.

`GameSession.Restart`, `ExplorationWorld` e `LocalSessionCommands` recarregam o caminho da cena ativa. Não há dependência de nome B2 no fluxo Runtime. Referências B2 nos scripts de autoria/validação históricos serão mantidas.

A B2 usa `marco06b1-journey.json` e `marco06b1-exploration.json` no persistentDataPath. A B11 usa o perfil protegido `DevelopmentJourneys/marco06b4` por `LocalSessionCommands`, incluindo jornada, exploração e identidade. O perfil que o usuário estava utilizando será preservado nesse mesmo caminho; não haverá renomeação, reset ou fusão automática com saves legados.

Decisão: criar `Assets/Mmorpg/Scenes/MmorpgWorld.unity` a partir da B11 limpa, com assets oficiais próprios em `Assets/Mmorpg/Art/Production/IronKnight/`. Promover essa cena ao primeiro índice de build e manter as oito entradas anteriores. B2, B10 e B11 ficam preservadas. [Diagnóstico completo](Marco06B12/entry-diagnosis.json). Nenhum Build Settings foi alterado antes deste registro.

## Execução e validação

Promoção concluída e validada em 16/10/2026. O jogador da entrada oficial usa o Iron Knight aprovado, com corpo, espada separada, caminhada, ataques, esquiva, Hurt e morte. A cena oficial fica aberta fora de Play ao final.

### Organização oficial

- `Assets/Mmorpg/Scenes/MmorpgWorld.unity`: cópia integral da B11 com referências de produção; primeiro índice de build.
- `Assets/Mmorpg/Art/Production/IronKnight/IronKnight.asset`: 36 clips, 264 sprites únicos, 324 entradas contando fases que compartilham desenhos.
- `Sprites/`: 24 sheets próprias de produção, idênticas byte a byte às aprovadas. Isso evita dependências Runtime dos diretórios experimentais sem mover ou sobrescrever B10/B11.
- `PlayerVisual.prefab`: prefab visual conectado ao Player da cena. Saúde, motor, input, autoridade e colliders continuam na raiz física existente. Não é um segundo jogador nem um novo Animator.
- `provenance.json` e README na pasta oficial: fonte Hormelz/CC0, hashes, referências e aprovação.
- `ArtSource/Characters/IronKnight/manifest.json`: manifesto canônico, com as fontes PNG/Aseprite aprovadas referenciadas nos diretórios históricos imutáveis. Sem duplicação ou regeneração das fontes editáveis.

O importador B9/B10/B11 foi estendido com um schema de produção e caminho opcional para o CharacterSet. `IronKnight06B9.ImportProduction` reutiliza o mesmo importador; não existe outro sistema de fatiamento. Point, 32 PPU, canvas 256×256, mipmaps desativados e sem compressão. A folha de morte mantém limite 8192 para conservar os 23 cels nativos.

Foram comparados todos os clips/frames com a B11: source, duração, loop, status de aprovação, mão, ângulo, profundidade, eventos, SpriteRect e pivô permanecem equivalentes. Os PNGs são idênticos. São preservados os 11 cels de walk a 53,333 ms, 15 desenhos Slash/vista com as fases aprovadas, Jump em 0,22 s, Hurt de sete cels e Death de 23 cels com pose final mantida. Nenhum redesenho, recoloração, trim, espelhamento ou root motion. Aseprite foi consultado pela skill; não foi necessário executar operações de arte neste marco.

[Verificação de produção](Marco06B12/production-verification.json): zero dependências de `Assets/.../Experimental/` na cena oficial; referências do corpo, mão, espada e observador de estados corretas. [Reimportação real](Marco06B12/reimport.json): **270 identidades GUID/localID preservadas**, incluindo 264 sprites, CharacterSet e objetos do prefab. Um novo carregamento pelo índice 0 após reimportar confirmou jogador vivo, idle oficial e frames avançando.

### Entrada, mundo e saves

As listas global e ativa do Editor foram sincronizadas pela API. Nesta versão da Unity, alterar somente `EditorBuildSettings.scenes` atualizou a lista usada pelo Editor, mas não persistiu inicialmente a lista global no arquivo. `EditorBuildSettings.globalScenes` foi também atualizado, e o arquivo foi conferido em disco. A alteração versionada insere apenas MmorpgWorld antes das oito entradas anteriores, mantendo seus caminhos, flags e ordem relativa. [Antes](Marco06B12/entry-diagnosis.json) e [depois](Marco06B12/entry-final.json).

O build passa a iniciar em MmorpgWorld. No Editor, abra essa cena e pressione Play; não foi imposto override global de Play que impediria inspecionar cenas históricas. Os reinícios por F5 e após morte carregam o caminho oficial atual. B2/B10/B11 e seus assets foram preservados; 279 arquivos do arquivo aprovado foram acompanhados por hash: [snapshot](Marco06B12/approved-before.json).

A comparação estrutural usa caminhos com índice de irmão para distinguir objetos de mesmo nome e normaliza somente identidades transitórias do Editor e bookkeeping de conexão de prefab. **750 entradas de transform, configuração e referências de mundo/gameplay são equivalentes à B11**, incluindo regiões, nós, interações, NPCs, criaturas, câmera, sessões, HUD, parâmetros físicos e autoridade. A nova definição visual e as novas referências do CharacterSet são verificadas separadamente. [Preservação](Marco06B12/world-and-save-preservation.json), [diferenças finais](Marco06B12/world-structural-differences.json).

Após encerrar o Play pessoal que já estava aberto, foram calculados hashes dos dez arquivos pessoais existentes nos caminhos conhecidos de jornada/exploração/identidade e backups. Todos permaneceram inalterados durante autoria e QA. Conteúdo e snapshot pessoal ficam somente em Temp; apenas a contagem e o resultado são publicados. O perfil atual continua em `DevelopmentJourneys/marco06b4`; os saves legados B2 permanecem nos caminhos originais, sem fusão automática.

### QA executado na Unity

Editor conectado 6000.6.5f1, autotick 16 ms, comandos com `--caller plugin --skill unity-pipeline`. `InspectOfficialHero06B12` prepara perfis isolados antes de Play e inspeciona entrada, mundo e persistência. As inspeções de animação/combate reutilizam `InspectIronKnight06B11` sem alterá-lo, redirecionando suas evidências para B12. Todos os GIFs do jogo vêm de capturas reais após LateUpdate/end-of-frame.

| Inspeção executada na cena oficial | Resultado |
|---|---|
| `SceneManager.LoadScene(0)`, inclusive após reimportação | MmorpgWorld, IronKnight, 36 clips, jogador vivo, idle; frames 1103→1163 na conferência final |
| Walk nas quatro vistas com mira oposta | 3,5 u/s; contato com a âncora da mão medido em 0 u de erro |
| Básico nas quatro vistas e pesado | Fases presentes, empunhadura preservada |
| Alvo próximo, fora do alcance, parede, pesado próximo | Dano 20/0/0/36; um HitConfirmed por acerto |
| Esquiva nas quatro vistas | Nove cels, primeiro frame e reinício corretos, velocidade 9 u/s, janela 0,22 s, recusa por cooldown sem poeira/animação |
| Hurt nas quatro vistas e dano durante Slash | Uma reação por dano aceito, sete cels; imunidade/facção/esquiva recusam reação extra; Slash mantém sua sincronização |
| Morte completa na vista Sul | 23 cels, terminal estável e opaco, espada oculta, ator sem movimento/ataque; restauração volta ao idle |
| Melee recebido com/sem parede | Validação espacial existente bloqueia ou confirma o dano e Hurt |
| Ciclos de habilitação e reinício após morte | Sem callback duplicado; nova instância viva e espada visível na cena oficial |
| Obstáculo existente | Caminhada chega a 3,5 u/s e para fisicamente em 0 |
| Coleta por tecla E | Duas ervas; nova interação não duplica a coleta |
| Mira, inventário, diário e pausa | Diálogo abre/fecha e mantém política de movimento; I/Tab/Esc funcionam; timeScale retorna a 1 |
| F5 com dados de teste salvos | Mesma cena oficial, identidade, inventário, coleta e IDs dos fatos narrativos restaurados |
| Passagem física Valdoria→Floresta | Input atravessa a fronteira, muda região e sai da área segura |

Os testes de combate/Hurt/morte usam as fixtures temporárias documentadas no B11, com os mesmos caminhos de autoridade. Reposicionamentos ocorrem entre trechos; parede e reposicionamento de alvo não são salvos na cena. O ataque recebido adicional passa pelo cone, alcance e LOS reais. Não se alteraram valores de dano, velocidades, cooldowns, imunidade de 0,35 s, geometria do Sweep, regras físicas ou autoridade. Nenhum arquivo Runtime/Domain precisou mudar.

Evidências: [entrada](Marco06B12/startup.json), [mundo e persistência](Marco06B12/world-and-persistence.json), [traces e resultados de gameplay](Marco06B12/gameplay/). Recompile/status final: `up_to_date`, failed=false, sem erros, [compile.json](Marco06B12/compile.json). Console em Play sem erros; o buffer contém os 29 avisos antigos já observados no B11, [console final](Marco06B12/console-final.json).

Cleanup executado após Play: teclas e mouse artificiais liberados, dispositivos removidos, dispositivos prévios reabilitados, opções do Editor/Input System e override de perfil restaurados. O timeScale voltou a 1. A serialização incidental do TimeManager feita pela Unity durante capturas foi descartada, mantendo o arquivo original.

### Prévias e reprodução

- [Entrada oficial completa](Marco06B12/official-startup.png).
- [Caminhada nas quatro vistas](Marco06B12/previews/walk.gif).
- [Básicos e pesado](Marco06B12/previews/attacks.gif).
- [Esquiva, impacto, ataque com dano e morte](Marco06B12/previews/states.gif).
- [Diálogo](Marco06B12/npc-dialogue.png), [inventário](Marco06B12/inventory.png), [diário](Marco06B12/journal.png), [pausa](Marco06B12/pause-menu.png), [sessão recarregada](Marco06B12/saved-session-reloaded.png), [entrada na floresta](Marco06B12/forest-entry.png).

`official_hero_previews.py` monta GIFs de frames reais, com recorte acompanhando o jogador e rótulos derivados do trace. `*-provenance.json` aponta capturas, frames, tempo e cel original. Os recortes sem rótulos são preservados em `captures/`; screenshots integrais intermediários ficam em Temp. Montagens concatenam trechos de fixtures identificáveis e não representam uma única caminhada contínua por todo o mundo.

Reimportar fora de Play com `IronKnight06B9.ImportProduction`; verificar com `PromoteIronKnight06B12.VerifyProduction`. `CreateOfficial` recusa cena/prefab existentes, e `Diagnose` recusa substituir o diagnóstico inicial após a promoção. Não executar `production.py` nem gerar novamente as fontes aprovadas.

Limites de cobertura: não foi produzido ou executado um binário standalone, nem percorridas todas as missões ou cinco regiões completas. A entrada foi carregada pelo índice de build no Editor e a preservação restante foi conferida estruturalmente. Não foram executadas suítes extensas EditMode/PlayMode/backend. Não houve migração de saves, progressão, novos conteúdos, integração online ou mudança artística. As aprovações B10/B11 permanecem válidas para o conjunto promovido.
