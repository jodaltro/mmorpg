# Cena offline e motor de acontecimentos

## Marco 05A — camada persistente em validação

[SupabaseIntegration](SupabaseIntegration.md) descreve a nova autoridade Go/pgxpool, autenticação JWKS/Auth Server, schema game privado e RLS, HTTP v1, encontro mínimo por turnos simulado no servidor, transações e importação explícita de saves em mundos de teste. SupabaseSession/OnlineAuthorityClient são adaptadores opt-in separados da cena offline. Não há sincronização automática de recompensas locais. O serviço Go/Jev anterior continua consultivo e preservado.

O encontro Go é uma demonstração discreta de obtenção legítima; não substitui movimento, colisão ou combate em tempo real da Unity. A agenda Go depende de tick autenticado, o outbox ainda não tem consumidor e não há interface de login no HUD. A expansão 05B e o simulador 05C aguardam validação completa do 05A. [Auditoria/plano](Marco05Plan.md), [evidências e impedimentos](Validation/Marco05.md). Não há XP/níveis nem Nakama nesta entrega.

### Modo expandido

`Backend/authority/journey` carrega o cat?logo versionado e executa consequ?ncias, encontros distintos, habilidades, materiais, equipamento, oportunidades e agenda por a??es. `Store.Apply` usa o mesmo motor e grava proje??es normalizadas, fatos/outbox/decis?es em transa??o com revis?o/receipts. O simulador executa Catalog.Step sem banco/rede; n?o h? outro motor de recompensas. Regras do mundo s?o selecionadas pelo servidor, preservando a demonstra??o 05A e os saves offline. Aus?ncia da proje??o obrigat?ria do mundo expandido falha fechada.

`WorldJourneySession` usa SupabaseSession/OnlineAuthorityClient; `WorldJourneyHud` apresenta a??es e invent?rio; `WorldJourneyView` apresenta a regi?o confirmada e movimenta??o visual local. A cena nova n?o possui JourneySession nem sincroniza saves. As cinco ?reas s?o salas conectadas na mesma cena, com sprites originais e placeholders. `BuildExpandedWorld.Build` recusa sobrescrita; ajustes de apresenta??o usam opera??es espec?ficas.

O farol de Asterion e consequ?ncias regionais s?o ?nicos por mundo e possuem autoria. Lock transacional mundial + UNIQUE protegem ativa??es; reservas de agenda cancelada s?o devolvidas uma vez. Esse lock ? uma escolha do prot?tipo de teste, n?o um desenho de escala MMO. O Jev existente segue consultivo para candidatos do Marco 04; a expans?o permanece determin?stica e revalida toda inten??o.

## Marco 04

[WorldEventOrchestrator](WorldEventOrchestrator.md) descreve acontecimentos opcionais derivados das a??es existentes: alerta persistente, pista interativa e treino por esquiva confirmada. Domain permanece C# puro; JourneyEngine conserva invent?rio, rotas e Leitura de Fraquezas. WorldEventSession adapta agenda, rel?gio e apresenta??o na mesma cena. Save v3 aceita v1/v2. O servi?o Go existente recebe m?ltiplos candidatos pela pol?tica world-context-v1, com Jev consultivo e fallback sem backend. [Valida??o](Validation/Marco04.md) registra regress?o e chamadas reais autorizadas. Sem Nakama, multiplayer, XP ou n?veis.

## Marco 02

Atualização Marco 03: [JevIntegration](JevIntegration.md) descreve o serviço Go local e a seleção assíncrona de reações de Mira, revalidadas/persistidas no Domain. Rotas A/B e técnica mantêm a política síncrona anterior. Consulte [validação Marco03](Validation/Marco03.md). Trechos abaixo sobre ausência de integração correspondem aos marcos anteriores.

A cena existente recebeu a história **A Corrupção da Floresta**, com Mira, Orin, rastros, amostra, memória persistente, diário e a técnica Leitura de Fraquezas. Consulte [Event System](EventSystem.md) para arquitetura, arquivos, caminhos A/B, persistência e limitações; [contrato Go preliminar](GoEventContract.md) para envelopes e validação futura; [validação do Marco 02](Validation/Marco02.md) para resultados executados.

`Domain/JourneyEngine` separa fatos, regras de elegibilidade, seleção determinística e aplicação validada de consequências. `IJourneyPersistence` e `IConsequencePolicy` marcam pontos de substituição por backend e política futura. O domínio continua sem referência a Unity. Nenhuma API Jev, Go ou Nakama foi integrada.

Controles adicionais: **E** interage; **Q** usa a técnica aprendida; **Tab** abre o diário, pois J permanece ataque; **N** inicia nova jornada. **R** agora continua a memória salva ao recarregar a cena, restaurando as consequências narrativas do encontro. Vida/posição/cooldowns transitórios são reiniciados. A mensagem de vitória permite continuar explorando.

O combate original foi mantido, com duas extensões: callback após dano aceito para reconhecer derrota e bônus limitado da marca, consumido somente depois do acerto confirmado. `CombatState` e suas regras de ataque/esquiva/imunidade foram preservados. Os testes antigos usam persistência isolada em memória para não alterar o save do jogador.

O histórico abaixo descreve a entrega do Marco 01; o Marco 02 e seus controles prevalecem onde houve atualização.

## Ambiente inspecionado

Unity **6000.6.5f1**, CLI **1.0.0-beta.13** (atualizada na verificação), plugin Unity **0.1.8-beta**, Pipeline **0.8.0-exp.1** conectado ao Editor local na porta 7800. Projeto original mantido; `Assets/Scenes/SampleScene.unity` preservada. Input System **1.20.0**, URP **17.6.0**, uGUI **2.6.0**, Test Framework **1.8.0** já instalados. Física usada: Rigidbody2D/Collider2D, sem Physics Core.

O render pipeline ativo é UniversalRenderPipelineAsset, selecionado pelas configurações de qualidade existentes (GraphicsSettings global está vazio). As configurações URP originais foram preservadas.

## Executar

Abra `Assets/Mmorpg/Scenes/OfflineClearing.unity` e pressione Play. A cena também está em primeiro lugar em Build Settings.

| Entrada | Ação |
|---|---|
| WASD ou setas | Movimento em quatro direções; empate diagonal prioriza vertical |
| J ou botão esquerdo | Ataque na direção em que o personagem está olhando |
| Espaço ou Shift esquerdo | Esquiva na direção do movimento ou orientação atual |
| R | Reinício completo da cena, inclusive após vitória ou morte |

O jogador começa com 100 de vida, o lobo com 60. Três acertos derrotam o lobo. Ataque do jogador: 20 de dano, alcance 1,25, cooldown 0,4 s. Esquiva: 0,22 s, cooldown 0,9 s e invulnerabilidade durante toda a janela. O lobo causa 15 de dano, prepara o golpe por 0,35 s (cor laranja) e recupera por 0,8 s. Dano recebido tem imunidade de 0,35 s. Cor ciano indica esquiva; vermelho indica dano; cinza indica morte.

## Separação de responsabilidades

- `Domain/CombatRules.cs`: parâmetros de gameplay compartilháveis como especificação futura.
- `Domain/CombatState.cs`: vida, morte, cooldowns e janelas temporais em C# puro; recebe o tempo da autoridade.
- `Runtime/OfflineAuthority.cs`: decide ataques e esquivas; valida facção, estado, alcance, direção e parede; calcula dano conforme regras, sem receber valor de dano do input.
- `PlayerController`: traduz teclado/mouse em intenções.
- `ActorMotor`: converte intenção cardinal em velocidade de Rigidbody2D no FixedUpdate.
- `ActorHealth`: adapta o estado de combate a eventos Unity e desativa física na morte.
- `WolfBrain`: patrulha → perseguição → preparação → recuperação; para na morte.
- `CameraFollow`, `ActorVisual`, `HealthHud`: apresentação independente da regra de combate.
- `GameSession`: referências da partida e recarga da cena.

As referências estão serializadas na cena. As assemblies Domain e Runtime são separadas; Domain usa `noEngineReferences`. Não há SDK de rede, níveis, experiência, Jev ou Nakama.

## Transição para autoridade Go + Nakama

Hoje intenção e simulação rodam no mesmo processo. Esta separação é estrutural, não uma implementação multiplayer nem uma abstração de transporte pronta. O futuro servidor deve possuir posição, colisões, velocidade, alcance, tempo monotônico, cooldowns e vida. Deve receber comandos de movimento/ataque/esquiva com sequência, validar e produzir snapshots/eventos. O cliente deve apresentar esses snapshots, reconciliar previsão e nunca determinar dano ou morte. `ActorMotor` e os raycasts atuais são adaptadores offline que terão equivalentes no servidor; Rigidbody2D não roda em Go. As regras Domain servem de contrato de comportamento a portar com testes equivalentes, não de código C# executado pelo Nakama.

## Cena e placeholders

Arena limitada por colliders, quatro obstáculos, jogador e um lobo, câmera ortográfica e HUD uGUI/TMP. Arte gerada por código, sprites 16×16 com filtro Point e sem compressão/mipmaps. Câmera arredonda posição para a grade de 16 pixels/unidade. Não é uma configuração PixelPerfectCamera completa: escalas arbitrárias da Game view podem produzir pixels de tamanhos diferentes.

Camadas 8 (`Obstacles`) e 9 (`Actors`) são reservadas e verificadas pelo gerador. Paredes bloqueiam visão e ataques. O lobo usa perseguição cardinal e linha de visão simples; não há pathfinding contornando obstáculos.

`AgentScripts/BuildOfflineScene.cs` é ferramenta de autoria executada por Pipeline, fora de Assets. O gerador recusa sobrescrever a cena e recusa trocar cenas sujas. Recursos TMP foram importados sem diálogos interativos. O projeto e seus pacotes originais não foram recriados.

## Validar pela Unity CLI

Com o Editor deste projeto aberto:

```powershell
unity status --format json
unity command set_autotick --caller plugin --skill unity-pipeline
unity command recompile --caller plugin --skill unity-pipeline
unity command recompile_status --caller plugin --skill unity-pipeline
unity command run_tests --caller plugin --skill unity-pipeline -- --mode editor --filter Mmorpg.Tests --async_tests true
unity command test_status --caller plugin --skill unity-pipeline
unity command run_tests --caller plugin --skill unity-pipeline -- --mode playmode --filter Mmorpg.Tests --async_tests true
unity command test_status --caller plugin --skill unity-pipeline
unity command console_status --caller plugin --skill unity-pipeline
```

Aguarde conclusão da compilação antes dos testes e de cada suite antes de iniciar a próxima. `test_status` deve mostrar `completed`, testes executados e zero falhas. Resultados da execução desta entrega ficam em `Docs/Validation`.

Nesta versão do Pipeline, `editor_play` não habilita `runInBackground` automaticamente. Se o jogo ou os testes congelarem no frame 1 com o Editor sem foco, execute antes de iniciar:

```powershell
unity command eval --caller plugin --skill unity-pipeline -- --code 'UnityEngine.Application.runInBackground = true;'
```

Sem Editor aberto, o modo batch é uma alternativa:

```powershell
unity test . --mode EditMode --filter Mmorpg.Tests --output Docs/Validation/editmode.xml --timeout 300
unity test . --mode PlayMode --filter Mmorpg.Tests --output Docs/Validation/playmode.xml --timeout 300
```

Referências técnicas consultadas: [Rigidbody2D](https://docs.unity3d.com/6000.6/Documentation/ScriptReference/Rigidbody2D.html), [Physics2D.Raycast](https://docs.unity3d.com/6000.6/Documentation/ScriptReference/Physics2D.Raycast.html), skills `unity-cli`, `unity-pipeline`, `create-2d-physics` (referência `legacy-2d-physics.md`), `ui` e `ui-ugui`.
