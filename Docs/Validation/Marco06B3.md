# Marco 06B.3 — entrega e validação

**Estado: primeiro conjunto integrado e inspecionado no Editor; o acabamento artístico amplo permanece parcial.** Há melhoria real de renderização, recortes, escala, cenário e feedback. Não há um ciclo corporal completo de combate ou animações finais de todas as criaturas. Essa distinção é parte da entrega, não uma aprovação automática dos atlas.

Cena nova: `Assets/Mmorpg/Scenes/Marco06B3Art.unity`, deixada aberta, fora de Play. `Marco06B2World.unity` foi preservada. A criação recusa sobrescrita. Não foi alterada a cena inicial do build.

## Inventário e produção

Seis PNGs RGBA 1448×1086 encontrados em `D:/unity/Mmorpg/assets_para_usar`: personagem, npcs, monstros, monstros_2, cenarios e efeitos_habilidades_e_icones. Nomes reais, métricas, perspectivas e limitações em [AssetAudit](../Art/AssetAudit.md). Todos os hashes originais continuam iguais ao inventário inicial, conforme [QA de derivados](../Art/Audit/processed-qa.json).

| Entrega | Local / quantidade |
|---|---|
| Direção visual | [ArtBible](../Art/ArtBible.md) |
| Processo e comandos | [AnimationPipeline](../Art/AnimationPipeline.md) |
| Scripts Python | `Tools/ArtPipeline/`: audit, build_manifest, process, terrain, verify, gameplay_previews |
| Manifesto explícito | `Tools/ArtPipeline/frames.json`; cópia enriquecida em `Assets/Mmorpg/Art/Processed/manifest.json` |
| Derivados no manifesto | 128 entradas: Hero 24, Wolf 16, Spider 22, Golem 24, NPCs 4, Environment 12, Bat 2, VFX 12, UI 12 |
| Terreno local | 40 PNGs 32×32 em `Assets/Mmorpg/Art/Tilesets`, quatro variantes de seis superfícies e 16 máscaras de caminho |
| Auxiliares desenhados localmente | Painel de UI, sombra e boneco de treino; três PNGs adicionais, com gerador reproduzível |
| Dados de animação | Quatro GameplaySpriteSets em `Assets/Mmorpg/Art/Animations` |
| Prefabs visuais | Nove em `Assets/Mmorpg/Art/Prefabs` |
| Importação e authoring | `AgentScripts/IntegrateArt06B3.cs`, executado pelo Unity CLI Pipeline |
| Passeio de inspeção | `AgentScripts/InspectArt06B3.cs`, com input real e saves temporários |

## O que está conectado

**Protagonista:** quatro orientações sem espelhar espada; idle estático, caminhada de duas poses por direção a 8 FPS, stances sincronizadas à preparação/janela ativa/recuperação, pose de dodge e flash de dano. Pés alinhados no mesmo último pixel nas oito poses de caminhada; pivot fixo, root em escala (1,1,1), Rigidbody/collider sem mudanças por quadro. Oito screenshots de ataque e a prévia real mostram a espada separada, única, com orientação contínua. As poses originais com braços incompatíveis foram substituídas por stances compatíveis; isso **não é um novo conjunto de desenhos corporais de ataque**.

**Espada:** o SwordSwing existente continua fazendo Sweep, cápsulas, LOS, checagem de alcance, janela ativa e HashSet por golpe. Foram calibradas quatro âncoras locais de mão compartilhadas pelo desenho e pelo Sweep. Nenhum dano passou a vir da animação. Os atributos antigos permanecem como fallback das outras cenas. A varredura, não uma hitbox nova, acompanha a lâmina.

**Lobo:** idle, duas poses de locomoção lateral, windup/charge observados, reação ao dano e fade após morte confirmada. Frente tem pouca variação e norte usa corpo coerente sem inventar um ataque voltado para outro lado. Não existe morte nativa completa de lobo no material; fade não é uma animação de queda desenhada.

**Vila e clareira:** 1154 células de terreno receberam texturas de densidade consistente, sem os ovais repetidos do piso antigo nem matrizes 2×. Cinco regiões e suas conexões permanecem. Casas, árvores, arbustos, rochas, pilar e pequenos detalhes usam recortes preparados. A inspeção focou Valdoria/Floresta Cinzenta. Os outros biomas receberam a biblioteca de piso, mas não foram percorridos/aprovados visualmente neste marco.

**NPCs:** Mira e Orin foram inspecionados com diálogo real; ferreiro/pesquisador têm recorte e prefab preparados e a representação humana da cena foi atualizada. Idle é estático, sem alegar animações inexistentes. Roots/colliders e regras de diálogo foram preservados. Humanos com root não uniforme usam um filho visual compensado.

**Profundidade:** árvores bloqueiam pelo tronco, com canopy visual maior. Sorting usa pés e âncoras no chão. Limites sólidos mantêm as mesmas células Grid; backplates antigos foram ocultados e sebes receberam arbustos. Câmera URP 640×360 / 32 PPU, Point, sem mipmaps/compressão dos principais derivados. Windowbox preserva múltiplos inteiros e pode mostrar barras no tamanho atual da Game view.

**Feedback e HUD:** corte somente na janela ativa; impacto após HitConfirmed; poeira ao iniciar dodge; retículo de Leitura e marca do Caçador observam os estados já existentes. Indicadores antigos não desenham uma segunda marca. Painéis com borda bronze, fundo carvão, texto marfim e ícones normalizados; mensagens afastadas do centro do combate. Regras/unlocks não foram alterados.

## Evidências executadas

Unity conectado: **6000.6.5f1**. `set_autotick` habilitado, recompile executado e status consultado. [Recompile final](Marco06B3/recompile-final.json): sem falha/erros. [Auditoria final do Editor](Marco06B3/editor-art-audit.json): 128 importações verificadas sem divergências, nove prefabs, câmera 32 PPU / 640×360, controlador novo ativo e animação anterior do protagonista desabilitada.

| Inspeção curta | Resultado e evidência |
|---|---|
| Idle, caminhada e ataques em quatro direções, dodge | [player-walkthrough.json](Marco06B3/player-walkthrough.json), capturas `walk-*`, `attack-*`, `dodge.png`. Cinco amostras de caminhada por direção, cobrindo mais de dois períodos do par de poses; deslocamento contínuo pelo Input System. Frames avançaram durante os passeios. |
| Combate físico com lobo | [combat-walkthrough.json](Marco06B3/combat-walkthrough.json): HP do lobo 60→40→20→0, dano confirmado no jogador 100→85, lobo derrotado. Acertos/efeitos vieram da autoridade existente. |
| Mira, Orin, proporções e árvore | [village-walkthrough.json](Marco06B3/village-walkthrough.json): interações reais e sorting observado atrás/árvore/frente 175/180/200 no passeio registrado. |
| Leitura | [abilities-visual.json](Marco06B3/abilities-visual.json): marca no boneco confirmada. O mesmo registro contém pedido de marca do Caçador rejeitado por alcance; **essa rejeição não foi contada como sucesso**. |
| Marca do Caçador | [hunter-mark.json](Marco06B3/hunter-mark.json): novo pedido confirmado no TrainingDummy; [captura](Marco06B3/hunter-mark-confirmed.png). Usado o modo isolado de habilidades já existente, sem persistir desbloqueios. |
| Console | [console-final.json](Marco06B3/console-final.json): nenhum erro novo no intervalo final consultado e consoleErrors=0 na amostra do Editor. O histórico da sessão contém erros anteriores e falhas de authoring corrigidas; não foi apresentado como histórico inteiro limpo. |
| Integridade/frames | [processed-qa.json](../Art/Audit/processed-qa.json): seis hashes inalterados, 128 canvases/pivôs/alfas verificados, nenhuma falha estrutural, mesma linha dos pés nos oito frames de walk. Isso não aprova a direção dos assets de expansão. |

As suítes completas de EditMode, PlayMode, Go e SQL **não foram executadas**, conforme suspensão expressa do usuário. A inspeção curta não substitui essas suítes. Ocorreram rotas de inspeção bloqueadas por obstáculos e um pedido de marca fora de alcance; os trajetos/pontos de aproximação foram corrigidos, sem remover os obstáculos para fazer o passeio passar.

Saves de inspeção foram isolados em diretórios únicos `Temp/Marco06B3/<id>`; ver [isolamento](Marco06B3/isolated-save.json) e [cleanup](Marco06B3/cleanup.json). Ao terminar, factories de persistência, input e opções de Play foram restaurados. Não houve limpeza/reset de saves pessoais, alteração de backend, chamadas pagas, atualização de Unity/pacotes ou commit.

## Capturas e prévias reais

- [Composição final da vila](Marco06B3/delivery-village.png) e [corte após a última revisão de recortes](Marco06B3/delivery-slash.png). [Passeio final](Marco06B3/delivery-view.json) e [console dessa execução](Marco06B3/console-delivery.json).
- [Antes](Marco06B3/before.png) — captura do projeto antes do trabalho; região diferente da nova composição, não é comparação de câmera idêntica.
- [Casas e escala](Marco06B3/houses-scale.png), [diálogo de Mira](Marco06B3/mira-dialogue.png), [diálogo de Orin](Marco06B3/orin-dialogue.png).
- [Atrás da árvore](Marco06B3/tree-behind.png), [à frente](Marco06B3/tree-front.png).
- [Ataque ativo](Marco06B3/attack-0-active.png), [combate](Marco06B3/fight-01.png), [dano](Marco06B3/received-damage.png), [esquiva](Marco06B3/dodge.png), [lobo derrotado](Marco06B3/wolf-defeat.png).
- [Caminhada em GIF](Marco06B3/gameplay-walk.gif), [quadros principais do ataque](Marco06B3/gameplay-attack-keys.gif), [amostra do combate](Marco06B3/gameplay-combat.gif).

Essas capturas são da execução real no Unity Editor. GIFs `gameplay-*` montam as capturas sem interpolação, com recorte central e ampliação nearest para leitura; são amostras/keyframes, não vídeo de taxa de quadros exata. Pranchas de fonte e GIFs separados em `Docs/Art/Previews` documentam o tratamento dos assets, não fingem ser gameplay.

## Limites e próximos desenhos necessários

1. Humano: fornecer/desenhar um ciclo de caminhada com apoio alternado claro (idealmente 6–8 poses por vista), ataques corporais próprios da espada separada, esquiva completa e dano/morte. Manter identidade, quatro orientações e âncoras/empunhaduras documentadas. As duas poses atuais e stances são uma integração limitada, não acabamento final de um RPG profissional.
2. Lobo: completar corrida frontal/traseira, ataque norte e morte/queda coerente. Atualmente a morte é fade, e parte da locomoção tem variação pequena.
3. Aranha/golem: 22/24 entradas e prefabs preparados; ataques têm direção e partículas misturadas. Sequências de colapso existem como poses, **não foram aprovadas como timelines**, e os adaptadores antigos desses inimigos continuam na cena. Não declarar a expansão artística desses combates concluída.
4. Morcego: prefab frontal de duas poses com sombra aérea separada, sem IA/física de inimigo nova. Faltam direções, voo completo, ataque, dano e morte aprovados.
5. Ambientes: ampliar props/transições com revisão por bioma, corrigir o restante dos recortes e substituir os placeholders remanescentes fora do conjunto inicial. Não foram produzidos todos os objetos/ícones/VFX do atlas como conteúdo final.
6. VFX: corte/impacto/dodge e as duas marcas iniciais conectados; cura, corrupção animada, veneno separado e cristais ainda precisam de sequências completas e inspeção específica.

O primeiro conjunto é utilizável para continuar a revisão no Editor, com arte preparada e gameplay existente preservado. **Não considerar todo o Marco 06B.3 artisticamente encerrado.**
