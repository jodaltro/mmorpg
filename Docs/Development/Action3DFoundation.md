# Fundação Action RPG 3D —19/10/2026

Esta entrega cobre as Missões1 e2 da reorientação. A simulação de mundo vivo e o experimento da rota comercial aguardam avaliação da experiência Action. Não há promessa de escala MMORPG nem implementação de multiplayer nesta arena.

## Auditoria inicial

- Projeto: `D:\unity\Mmorpg`; Unity6000.6.5f1; CLI1.0.0-beta.13 (atual na consulta); Pipeline0.8.0-exp.1 conectado ao Editor.
- `main` atualizada com `git pull --ff-only origin main`, sem divergência. Base anterior `88ad73f7`; checkpoint remoto `archive/valdoria-2d-2026-10-19`.
- Cena anterior aberta: `ValdoriaVillage02Anime.unity`, fora de Play, sem alterações não salvas. Quatro entradas locais não versionadas foram preservadas.
- Pipeline anterior: URP17.6.0 com Renderer2D, definido nos níveis de qualidade; GraphicsSettings não tinha override global. Input System1.20.0; uGUI2.6.0; Timeline6.6.0; Test Framework1.8.0. Offline sem necessidade de backend.
- Ferramentas disponíveis: Git/Git LFS, Python, Unity CLI e Editor real. Aseprite/Blender/fontes 2D não são necessários para esta entrega.

## Comparação das bases

Comparação documental e de código; somente a opção escolhida é importada e exercitada neste projeto. Qualidade aqui descreve recursos observados na base, não uma avaliação artística ou um benchmark entre jogos.

| Base | Controle/câmera/animação | Combate/IA/recuperação | Compatibilidade e modificação | Licença e multiplayer | Decisão |
|---|---|---|---|---|---|
| [3D Game Kit](https://github.com/Unity-Technologies/Gamekit3D) | Terceira pessoa, CharacterController, root motion, Cinemachine FreeLook, personagem e animações completos | Melee, Chomper, outros inimigos, dano/feedback, checkpoints/respawn e interações prontos | Checkout oficial usa Unity2020.2.0b13/Built-in e Input Manager; requer adaptação de input e namespaces. Código acessível e prefabs funcionais, com acoplamento a Animator | Aviso incluído remete à Asset Store EULA. Offline; autoridade de dano e rede precisam de separação | Escolhido para reutilizar a maior parte da experiência pedida |
| [3D Game Kit atual na loja](https://assetstore.unity.com/packages/templates/packs/3d-game-kit-3d-sample-project-115747) | Mesmo propósito; conteúdo da loja não foi importado | Projeto completo | Loja anuncia1.9.5,07/09/2026, URP em6000.3.17f1. Não confundir com checkout2020 do GitHub | Gratuito, EULA padrão; distribuição de fonte restrita | Possível atualização futura; compatibilidade não testada aqui |
| [Starter Assets / Character Controllers](https://assetstore.unity.com/packages/3d/characters/first-person-third-person-character-controllers-196526) | Foco moderno em locomoção/câmera/animação; adequado a protótipos | Não entrega esta arena com combate/IA/morte prontos | Integração de controle menor, composição do restante maior. [Pacote URP267961](https://assetstore.unity.com/packages/essentials/starter-assets-character-controllers-urp-267961) consta como descontinuado na consulta | Conferir licença da versão adquirida; não equivale a base multiplayer completa | Perde por exigir compor sistemas básicos ausentes |
| [Boss Room](https://github.com/Unity-Technologies/com.unity.multiplayer.samples.coop) | Controle por clique e câmera de RPG cooperativo; classes e animações completas | Habilidades, inimigos e fluxo de partida prontos | README declara6000.0 LTS; NGO, fluxo de sessão e controle exigiriam adaptação para terceira pessoa | Unity Companion License; coop de até8 clientes com host. Pode funcionar sem UGS; não demonstra escala MMORPG | Referência de rede posterior; altera demais a experiência de controle agora |
| [Dynamic Character Controller](https://github.com/ALI-QADIR/Dynamic-Character-Controller) | Rigidbody, Input System, Cinemachine e Blend Trees; câmera livre e combate de personagem | Documentação não comprova jogo completo com todos os requisitos | Autor declara alpha; controle extensível, mas ainda exige compor IA/recuperação/interações | Código MIT; modelo/animações vêm de Mixamo e exigem respeitar termos próprios | Menor completude e maturidade para esta entrega |
| [Unity CharacterController Samples](https://github.com/Unity-Technologies/CharacterControllerSamples) | Exemplos Basic/Platformer e controle moderno do pacote DOTS | OnlineFPS é outra experiência; não entrega melee Action RPG completo | Introduzir Entities/DOTS mudaria mais a arquitetura inicial | Licença do repositório/pacotes; exemplo online não comprova MMO | Referência técnica, não menor esforço para esta arena |
| [Invector Melee Combat Template](https://assetstore.unity.com/packages/tools/game-toolkits/invector-third-person-controller-melee-combat-template-44227) | Terceira pessoa com locomoção, câmera e animações | Melee e IA com NavMesh, bloqueio/esquiva/waypoints segundo [manual do fabricante](https://www.invector.xyz/_files/ugd/f7eaa8_0dbfe781a8ce49b7b12107e806c10f24.pdf) | Loja anuncia3.0.0,09/09/2026 e URP em6000.0.67f1; alteração e compatibilidade6000.6 não testadas | US$69,99 antes de impostos na consulta; EULA padrão por assento. Rede exigiria integração própria | Alternativa paga plausível, não adquirida nem dependência; exigiria aprovação antes da compra |

A decisão privilegia completude observável, acesso reproduzível e ausência de compra. Não foi demonstrado que o Game Kit é universalmente melhor ou o mais barato em qualquer projeto. O custo real de importação e a validação estão no relatório de execução. A versão GitHub antiga é uma limitação concreta; adotar Built-in neste checkpoint evita converter toda a biblioteca durante uma avaliação de gameplay.

## Instalação e execução

1. Preparar Git/Git LFS, Python e Unity6000.6.5f1. As dependências Cinemachine2.10.7 e Post Processing3.5.4 estão fixadas no manifest/lock via Package Manager.
2. Antes da primeira abertura, executar `python Tools/Action3D/install_gamekit.py`. O instalador baixa o repositório oficial, fixa `b718622e98eb1a403a4f64d77e448639717d50ec`, resolve LFS e recusa sobrescrever instalação existente. Também recupera o pacote oficial Cinemachine2.10.7 e verifica SHA-1 `631385387c5a6b317ceb9e4a4687ee55bdaa3565`. Requer acesso ao GitHub/registro Unity e uso sob a licença aplicável.
3. Esperar importação e compilação. Abrir `Assets/Mmorpg/Scenes/ValdoriaAction3D.unity` e entrar em Play.
4. Caso seja necessário criar uma nova arena em uma cópia sem a cena, executar `AgentScripts/BuildAction3DFoundation.cs`, entrada `BuildAction3DFoundation.Build`, via `unity command run_script --caller plugin --skill unity-pipeline`. O builder recusa sobrescrever a cena.

Controles: WASD mover, mouse câmera, clique esquerdo atacar, Espaço saltar, E próximo ao pedestal recuperar vida e abrir passagem, R reiniciar arena, Esc liberar mouse, botão direito recapturar. Gamepad tem mapeamento de movimento/câmera/salto/ataque; validação de gamepad não está presumida.

## Reutilizado e adaptado

Reutilizados: Ellen e seu rig/animações/root motion, arma e áudio, Chomper e seus estados de percepção/perseguição/navegação, Damageable e feedback, morte/respawn/checkpoint, Cinemachine/collision camera, ScreenFader, pedestal e módulos ambientais. Nenhuma arte própria criada.

Adaptações:

- API `PlayerInput` preserva GUID do prefab e lê Input Actions em vez de Input Manager; interação usa E.
- Namespaces removidos pela Unity atual são corrigidos no instalador. Ferramentas antigas de Editor e cenas enormes de demonstração não são importadas.
- O agente do Chomper usa o tipo0 do NavMesh gerado. A referência da câmera do céu é explícita. No retorno à base, o agente é reativado antes de receber um destino, corrigindo uma ordem problemática no exemplo original.
- Unity6000.6 inicialmente resolveu Cinemachine6.6 embutido apesar do pedido2.10.7, quebrando APIs FreeLook. A dependência agora usa o tarball oficial2.10.7 por caminho relativo, recuperado pelo instalador, para fixar também o conteúdo efetivo. O atualizador automático chegou a modificar namespaces locais durante a tentativa; esses arquivos foram restaurados do checkout fixado antes de recompilar.
- `MeleeWeapon.FixedUpdate` original deixa de ser chamado. `GamekitCombatAuthority` valida intenção, cooldown, windup, vida, alcance, cone e LOS em coordenadas do ator, e reutiliza saúde/feedback do kit. Eventos de animação continuam para apresentação. Esta pequena substituição é necessária para cumprir o contrato de autoridade do projeto.
- Cena autoral pequena compõe prefabs existentes, chão/limites de blockout, NavMesh, HUD de controles e pedestal de recuperação. `Action3DSession` conecta interação e reinício.
- Built-in é selecionado para os shaders originais. O projeto anterior com URP2D continua recuperável integralmente pela tag; não se promete apresentação2D correta sob a configuração3D.
- Assets licenciados, inclusive a cópia local adaptada do kit, ficam ignorados. Fontes próprias dos adaptadores/instalador e cena de composição ficam versionadas. GUIDs dos adaptadores são determinísticos.

## Licenças e origem

Origem oficial: Unity-Technologies/Gamekit3D, revisão acima. `Assets/3DGameKit_Third-PartyNotice.txt` original declara Asset Store EULA e lista Cinemachine, Rajdhani (OFL), EmojiOne, Roboto (Apache2), WebGL noise e texturas CC0. Os avisos permanecem na instalação. Não se concede aqui licença adicional nem direito de redistribuir esses assets. [EULA oficial](https://unity.com/legal/as-terms).

A revisão do GitHub não é a versão1.9.5 da loja. Nenhum recurso pago foi adquirido ou tornado obrigatório. O Git público recebe ferramentas de integração e referências, não uma nova distribuição da biblioteca do kit. Builds locais ficam em `Builds/`, fora do versionamento.

## Aproveitamento do projeto anterior e próximos passos

O domínio C# puro, os contratos de autoridade, isolamento de perfil e práticas de save/backup continuam úteis. O componente existente de isolamento foi reaproveitado, configurado para `Temp/Action3D/IsolatedProfile`. Runtime de física2D, animação por sprites e pipeline de cenário pixel art não alimentam a nova arena. Nenhum backend ou formato de save antigo foi conectado à nova base; a arena não grava perfil pessoal.

Após avaliação do usuário: definir comandos/eventos estáveis para combate, interação e resultado de encontros; extrair estado do mundo para domínio puro; testar relógio, recursos e NPCs sem Unity; implementar uma vila/rota com ataque de bandidos e consequências de intervenção/omissão; salvar/carregar esse estado com allowlist e backup; só depois conectar autoridade de servidor. Sem LLM obrigatório. A interface futura deve consumir acontecimentos confirmados pela autoridade, não nomes de cenas, animações ou prefabs.

Maturidade: fundação de experimentação, com movimento e IA ainda acoplados ao Animator do kit. Não é uma arquitetura de servidor pronta, nem um teste de escalabilidade. A migração URP e a troca de conteúdo permanecem decisões posteriores à avaliação do controle/combate.
