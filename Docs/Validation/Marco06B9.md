# Marco 06B.9 — Iron Knight experimental

15/10/2026. **Integração experimental executada na Unity; gate preliminar aceito pelo agente, aprovação artística definitiva do usuário pendente.** Cena independente: `Assets/Mmorpg/Scenes/Marco06B9ProfessionalHero.unity`. A B5 continua intacta e a cena inicial/build settings não foram alterados.

## Resultado para avaliar

- [Caminhada real com espada, quatro direções](Marco06B9/walk.gif).
- [Quatro direções originais, nearest 4×](../../ArtSource/Labs/IronKnight2026/review/four-directions-4x.gif), [tamanho nativo](../../ArtSource/Labs/IronKnight2026/review/four-directions-1x.gif), [sul 4×](../../ArtSource/Labs/IronKnight2026/review/walk-south-4x.gif).
- [Comparação animada B7 × B8 × B9](../../ArtSource/Labs/IronKnight2026/review/b7-b8-b9.gif), [prancha comparativa](../../ArtSource/Labs/IronKnight2026/review/b7-b8-b9.png).
- [Todos os 44 quadros de caminhada](../../ArtSource/Labs/IronKnight2026/review/all-walk-frames.png), [contatos das mãos](../../ArtSource/Labs/IronKnight2026/review/walk-hand-review.png).
- [Ataque básico real](Marco06B9/attack-f7.gif), [pesado diagonal real](Marco06B9/heavy-diagonal-f7.gif), [captura real](Marco06B9/idle.png), [prancha Unity](Marco06B9/contact-sheet.png).
- [Documentos Aseprite editáveis](../../ArtSource/Labs/IronKnight2026/editable), [manifesto por quadro](../../ArtSource/Labs/IronKnight2026/manifest.json).

## Fonte e licença

[8-Directional Iron Knight, Hormelz](https://hormelz.itch.io/8-directional-iron-knight), lançado em 06/08/2026. Página consultada durante a tarefa: licença **Creative Commons Zero v1.0 Universal**, pacote Knight-Only gratuito com animações do cavaleiro azul desarmado. [Termos CC0](https://creativecommons.org/publicdomain/zero/1.0/). Uso comercial e adaptação são compatíveis com o MMORPG. Nenhum termo conflitante foi encontrado; o ZIP não contém LICENSE/README/termos adicionais. Não se usou pacote pago, versão HiRez, espada ou escudo do autor.

Entrada efetivamente utilizada: `Knight-Only_BlueKnightUnarmed.zip`, 8.957.545 bytes, SHA256 `6374b94bcba7530b0ab8d0f1605d4eef07908deb02cd1d7d497a0d6973b39fc8`. O ZIP contém um documento Aseprite RGBA de 256×256, 3.920 quadros, uma camada `sweetie_plus`, tags de ação/direção, sheets PNG, JSONs e GIFs. A grafia original da pasta é **WalkFoward**. Direções conferidas pelas imagens: 1 SO, 2 O, 3 NO, 4 N, 5 NE, 6 L, 7 SE, 8 S.

A inicialização do Editor limpou a pasta Unity `Temp`; a cópia original foi localizada em Downloads e preservada em `D:/unity/ExternalArt/IronKnight2026/`, fora do projeto e de Temp. O ZIP e o documento completo não foram versionados. Somente os quadros selecionados e seus documentos editáveis entram no repositório.

## Conteúdo selecionado e Aseprite

| Clip por direção | Seleção | Quadros por vista | Total |
|---|---|---:|---:|
| idle | primeira pose de Idle, explicitamente estática | 1 | 4 |
| walk | WalkFoward completo | 11 | 44 |
| attack | Slash completo | 15 | 60 |

Quatro vistas S/O/N/L. Total: 108 imagens originais em 12 documentos editáveis e 12 sheets importadas. As outras quatro direções do pacote não foram ligadas ao animador atual; diagonais usam sua política existente de eixo dominante/histerese.

A extração real usa Aseprite local 1.3.18.6 e Lua (`extract.lua`). Documentos contêm somente os cels selecionados, sem redesenho, rig, espelhamento ou interpolação de poses. Os 108 PNGs exportados foram comparados em RGBA com os recortes das sheets do ZIP: **todos idênticos pixel a pixel**. A paleta original foi preservada para avaliar o movimento antes de retoques. As fontes originais de produção não foram alteradas.

O JSON do autor declara 1/15 s por quadro. Walk: 0,733333 s; Slash: 1 s autorado. O Aseprite armazena resolução de milissegundos (aproximadamente 67 ms); o manifesto/runtime preservam os segundos do JSON original. GIFs quantizam centésimos; a prévia de quatro direções alterna 60/70 ms, sem interpolação. A comparação B7/B8/B9 usa um relógio comum de 10 ms e as durações próprias de cada fonte, sem alongar B7/B8 para igualar ciclos.

## Gate artístico e escala

Inspeção das pranchas originais, sequências de poses e capturas Unity: alternância das pernas identificável, passagens diferentes dos contatos, mudanças contínuas da silhueta de joelhos/botas e cabeça consistente. Não há desaparecimento de rosto ou reconstrução de membros como no candidato B6. Comparado a B7/B8, há maior variedade de poses e continuidade entre elas. O gate preliminar permitiu a integração experimental.

Limites: braços flexionados/abertos dão uma postura de combate; o balanço é contido. Roupa e botas têm movimento discreto e o azul é muito saturado para a paleta atual. Sul/oeste/norte/leste têm perspectivas e larguras diferentes, próprias do asset. A continuidade do loop foi revisada na sequência de poses; não se apresenta uma medição biomecânica nem aprovação definitiva do movimento em reprodução temporal pelo agente. GIFs ficam disponíveis para revisão humana.

Canvas nativo mantido em 256×256; **não é a altura do personagem**. Alturas visíveis da caminhada: sul 47–50 px, oeste 51–52 px, norte 51–54 px, leste 50–51 px. A 32 PPU equivalem a 1,469–1,688 u; o idle antigo de referência tinha aproximadamente 50 px. Escala uniforme 1:1, sem reamostragem; NPCs permanecem proporcionais nas capturas. Pivô comum `(128,114)`, referência de chão `(128,132)`: conserva 18 px = 0,5625 u entre raiz física e chão, como o contrato anterior. O manifesto contém bounds visíveis por quadro e linha visível das solas do walk, separada da referência de chão; as solas variam durante o passo. Rigidbody/collider não foram movidos no asset/cena para compensar a arte.

Velocidade física mantida em **3,5 u/s**. Não foi aplicado multiplicador novo de cadência: walk usa 15 FPS autorados na velocidade de referência e o relógio existente se ajusta à velocidade observada. Em velocidade constante, o ator percorre cerca de 2,567 u (82,13 px) por ciclo. **Não se certifica ausência de deslizamento dos pés**: o stride visual curto e o deslocamento físico ainda podem exigir ajuste somente visual após revisão dos GIFs/jogo. Não se acelerou arbitrariamente a caminhada para esconder essa diferença.

## Mãos, espada e adaptador

Cada imagem usada tem contato da mão direita anatômica no manifesto, em coordenadas top-left, duração, pivô, referência de chão, ângulo e profundidade relativa. Contatos foram estimados nas imagens ampliadas e conferidos contra pixels opacos; a prancha usa magenta. Algumas coordenadas iniciais caíram fora da luva e foram ajustadas até os pixels visíveis. A opacidade isolada não prova anatomia correta: **revisão fina de punhos/oclusão, principalmente durante Slash e mudanças de vista, permanece pendente**. Nenhuma âncora foi herdada do herói 96×96.

Conversão: `hand=((x-128)/32,(114-y)/32)`, usada pelo `ProductionFrame.hand` existente. Descanso S/O/N/L: -135/-155/90/-25 graus. Profundidade inicial por vista: norte -1; demais +1. É uma política de apresentação conservadora, ainda sem revisão de oclusão individual completa durante o arco do Slash. O ângulo da espada em ataque segue o Sweep existente; o movimento do braço original não foi criado para esse arco, portanto sincronização artística perfeita não está aprovada.

`AgentScripts/IronKnight06B9.cs` é o adaptador específico: importa somente `ArtSource/Labs/IronKnight2026/manifest.json` em `Assets/Mmorpg/Art/Experimental/IronKnightB9`. Mantém canvas/pivô próprios, Point, uncompressed, alpha, mipmaps off, 32 PPU, SpriteRects estáveis e sheets de até 4096 px. Não modifica o contrato/importador 96×96 existente. Usa `ProductionCharacterSet` e `ProductionSpriteAnimator` já existentes, sem novo Animator ou MonoBehaviour. `Import` atualiza apenas o conjunto B9; `ImportAndCreate` exige B5 limpa fora de Play e recusa cena de destino existente. Voltar à B5 reverte visualmente todo o experimento.

SwordSwing, dano, cooldown, alcance, comprimento/escala da espada, ActorMotor, PlayerController e efeitos não foram modificados. Dodge não tem clip próprio selecionado e usa o fallback idle existente; hurt/death novos não foram integrados. Não se apresenta esse conjunto como pacote final completo de gameplay.

## QA efetivamente executado

Unity 6000.6.5f1 aberta pela CLI 1.0.0-beta.13; `set_autotick` a 16 ms. `recompile`/`recompile_status`: up_to_date, failed=false; não havia C# novo em Assets. Adaptador compilou e foi executado na criação; após extração do método Import, dry-run compilou sem diagnósticos. [Compilação](Marco06B9/compile.json), [adaptador](Marco06B9/adapter-compile.json), [Console final](Marco06B9/console.json): zero erros/avisos, compilationFailed=false.

- Input real do Input System: quatro cardinais e quatro diagonais, velocidades máximas 3,5 u/s, sprites avançando e mira oposta ao deslocamento. Parada/retomada e conservação da vista ao mover somente mouse verificadas. [Movimento](Marco06B9/movement.json), [execução](Marco06B9/movement-run.json). Frames finais desse trecho: **47375 → 49255**.
- Ataques básicos em quatro vistas e pesado diagonal: preparação/corte/recuperação observados, direção confirmada estável; ataque em movimento e após dodge aceitos. [Ataques](Marco06B9/attacks.json), [execução](Marco06B9/attacks-run.json). Capturas em timeScale 0,35 para inspeção das fases, restaurado a 1.
- Medição após LateUpdate/end-of-frame: erro máximo entre WeaponPivot e mão transformada **0**, escala `(1,1,1)` em todas as amostras. Lâmina aproximadamente **1,021488 u**, constante dentro da precisão float. [Métricas](Marco06B9/metrics.json). Isso comprova attachment à âncora, não perfeição artística do contato escolhido.
- Corte/trilha e overlay F7 aparecem nos ataques; espada única e efeitos existentes continuam renderizados nas capturas. Não se testaram novamente todos os efeitos/habilidades ou uma jornada completa.
- Perfis temporários isolados; dispositivos nativos restaurados, dispositivos de teste removidos, opções do Editor/input e timeScale restaurados ao sair do Play. Saves pessoais preservados.

As primeiras capturas tinham copas encobrindo parte do corpo. Duas tentativas de reposicionar a fixture esbarraram em rocha/NPC e reprovaram a checagem de movimento; estão registradas em `occluded-fixture-run.json` e `blocked-fixture-run.json`. Inspeção de colliders identificou os obstáculos. A execução final usou `(-2,75,0)` e passou sem mudar colisão ou gameplay. Reposicionamento ocorre **entre** trechos; o deslocamento capturado dentro deles é físico por input.

Metadados brutos preservam tentativas e nomes repetidos; os montadores usam a última amostra de cada nome. GIFs são montados exclusivamente de capturas reais, com crop acompanhando o jogador e nearest 2×, sem poses sintéticas. A taxa de amostragem sofre o custo de ScreenCapture; não mede FPS normal. PNGs brutos foram arquivados localmente em `Temp/Marco06B9/Captures`; versionados somente GIFs, captura final, prancha e relatórios. Métricas agregam também amostras de tentativas anteriores; resultados finais de movimento/ataque têm seus próprios relatórios.

Não foram executadas suítes EditMode/PlayMode/backend, build, testes novos de dano/LOS/cooldown ou persistência completa. `production.py`, PixelLab, ImageGen, geração paga e B3 não foram executados. Nenhuma mudança em Domain, progressão, XP, níveis, Nakama/Jev ou autenticação.

## Reprodução

Com o pacote extraído **fora de Temp**, `Tools/ArtPipeline/iron_knight_b9.py` extrai com Lua/Aseprite e recusa sobrescrever os documentos editáveis existentes. Para outra extração use diretório novo no script; não regenere sobre edições manuais. Fontes selecionadas já estão versionadas, dispensando o ZIP para importar. `iron_knight_b9_previews.py` monta comparações; `gameplay_previews_b9.py` monta capturas reais (requer os PNGs arquivados localmente).

Pela CLI, sempre com `--caller plugin --skill unity-pipeline`: `run_script --file AgentScripts/IronKnight06B9.cs --entry IronKnight06B9.Import` fora de Play reimporta somente B9. `ImportAndCreate` é para primeira criação, recusa substituir a cena existente. Inspeções: Prepare → editor_play → Setup → Movement → Attacks → FinalView → editor_stop → Cleanup, usando `InspectIronKnight06B9`. Se interromper uma captura, liberar inputs e executar Cleanup após parar Play.

**Estado final:** candidato integrado e tecnicamente inspecionado, disponível para avaliação artística na cena separada. Não promovido a protagonista definitivo; cadência/foot sliding, paleta e anatomia/oclusão dos ataques ainda merecem revisão humana.

Verifica��o Git: diff dos arquivos autorados sem erros; whitespace final padr�o gerado pela serializa��o Unity em `.unity/.meta/.asset` foi mantido. Nenhuma edi��o textual desses arquivos foi feita para normaliz�-lo.
