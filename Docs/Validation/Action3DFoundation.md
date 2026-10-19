# Action3D — execução real,19/10/2026

Cena: `Assets/Mmorpg/Scenes/ValdoriaAction3D.unity`. Unity6000.6.5f1, Built-in, Cinemachine2.10.7 e Input System1.20.0. [Comparação, decisão, instalação, licenças e reaproveitamento](../Development/Action3DFoundation.md).

## Play Mode

O Editor conectado foi identificado pelo caminho do projeto, versão e PID. A cena anterior estava salva. Importação e compilação foram executadas; o estado final da compilação não contém erros. `set_autotick` já estava ativo; foi mantido. `wait_for(Time.frameCount changed)` confirmou avanço real, além da entrada em Play.

O [probe final](Action3DFoundation/QA/play-probe.json) concluiu dez checks. Movimento, câmera, salto, interação e ataque usam eventos de teclado/mouse sintéticos enfileirados no **Input System real**, processados pelo jogo. Colisão usa uma chamada dirigida ao CharacterController real contra o limite físico. A IA usa NavMesh e o controlador original do Chomper.

| Check | Resultado |
|---|---|
| Frames avançam | Passou |
| WASD move o personagem | Passou; distância medida no JSON |
| Mouse gira a câmera | Passou; ângulo medido no JSON |
| Salto | Passou; subida aproximada2,51u |
| Limite físico | Passou; posição final x≈15,10u, CollisionFlags.Sides |
| E no pedestal | Passou; interação registrada e passagem aberta |
| Perseguição do Chomper | Passou; alvo reconhecido e deslocamento real |
| Ataque fora de alcance | Passou; vida do alvo não mudou |
| Dano sem animação | Passou; ataque por input reduziu vida4→3 com Animator desativado |
| Dano inimigo, morte e respawn | Passou; morte observada e vida restaurada no checkpoint |

Isolamento do teste: inimigo temporariamente desativado durante locomoção; teletransportes posicionam os fixtures; apresentação do alvo congelada no teste de alcance; Animators desativados somente para provar independência do dano; vida máxima reduzida temporariamente para2 no teste curto de morte. Os valores são restaurados, dispositivos sintéticos removidos e Play encerrado. Não se apresenta isso como uma sessão inteira jogada por uma pessoa. O smoke posterior, sem esses dispositivos, também mostrou ataque do inimigo e vida4/5.

Perfil: `Temp/Action3D/IsolatedProfile`, usando o componente existente de isolamento. A arena não conecta saves anteriores ou backend. `timeScale=1`, Play encerrado e cena salva ao terminar. Uma câmera principal e uma câmera do céu compõem a apresentação; não há duplicação de protagonista ou autoridade.

## Erros encontrados e corrigidos

- Cinemachine6.6 embutido substituiu inicialmente a versão solicitada e quebrou APIs do kit. Tarball oficial2.10.7 fixado e verificado; namespaces alterados pelo atualizador foram restaurados.
- Agente do Chomper estava configurado com tipo diferente do NavMesh: alinhado ao tipo0.
- Prefab do céu tinha referência de câmera ausente: referência serializada atribuída.
- Retorno do Chomper chamava SetDestination antes de reativar o agente: ordem corrigida no instalador.
- O primeiro probe serializava classes dinâmicas com JsonUtility e omitia a lista de checks. O registro foi corrigido para Newtonsoft; a repetição final contém todos os resultados.
- O primeiro orçamento de morte terminou com vida1, antes da morte. O teste curto passou com vida2 temporária. Não se classificou a tentativa incompleta como aprovada.

O [Console do smoke final](Action3DFoundation/QA/console-smoke.json) contém `entries:[]` para erros posteriores ao cursor1851. Contagens agregadas incluem tentativas anteriores/importação; não significam erros novos do smoke. Timeouts do Pipeline durante importação e o erro de serialização de material causado pelo primeiro probe de inspeção pertencem às ferramentas do agente. Avisos antigos de importação/obsolescência e de prebake de colisões continuam como dívida do kit; não são aprovação de manutenção de longo prazo.

## Evidência visual

Originais integrais de Play, preservados separadamente das cópias ReviewLite. Câmera perspectiva, FOV55, escala do ator1. Metadados da câmera foram lidos na chamada CLI seguinte à captura; por ser câmera móvel, as imagens não são um par antes/depois.

![Play real — inimigo atinge Ellen](Action3DFoundation/ReviewLite/play-arena.png)

[Original integral](Action3DFoundation/Original/play-arena.png).

![Play após o QA — passagem aberta](Action3DFoundation/ReviewLite/play-combat.png)

[Original integral](Action3DFoundation/Original/play-combat.png).

Dimensões, bytes, hashes SHA-256 e transformação estão em [image-manifest.json](Action3DFoundation/QA/image-manifest.json). ReviewLite usa o pipeline existente, sem dithering ou redução de cores silenciosa. Estes frames demonstram a execução da fundação e o blockout; não são aprovação artística.

## Build Windows

A primeira build em `D:/unity/Mmorpg/Builds/Action3D` falhou ao copiar `sharedassets0.assets.resS`, por espaço insuficiente em disco. [Relatório real](Action3DFoundation/QA/build-failed-space.json). O executável parcial nesse diretório não é uma entrega válida. A repetição usa `C:/Users/Administrator/.codex/artifacts/ValdoriaAction3D-20261019/`.

## Limites

Validados: arena pequena, terceira pessoa, input, câmera, salto, colisão dirigida, combate local, feedback, IA/perseguição, morte/respawn e interação. Não testados nesta entrega: gamepad físico, sessões longas, matriz completa de colisões, todas as animações/combos, todos os inimigos/objetos do kit, múltiplos clientes ou carga de servidor. LOS está implementada na autoridade, mas não possui check negativo dedicado neste probe. Não há save do novo mundo, economia, NPCs sistêmicos, rota comercial, LLM obrigatório ou escalabilidade MMORPG demonstrada.

A próxima decisão do usuário é avaliar o controle e combate desta fundação. Só depois cabe integrar a camada de simulação pura e o primeiro experimento de vila/rota comercial.
