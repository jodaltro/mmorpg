# R8 — feedback: esquiva expressiva e empunhadura procedural

O usuário aprovou morte e reação a dano e pediu uma esquiva mais expressiva e a técnica procedural do arco aplicada à espada. Este complemento registra a revisão posterior ao checkpoint R8 `4bd0b9f`.

## O que muda

Esquiva: participação da pose profissional Sprint_Loop passa de `0.75*sin(pi*t)` a `sin(pi*t)^0.72`, com antecipação/inclinação local do tronco de até 13°. Mantém oito poses, 0,22 s, velocidade 9, cooldown 0,9 e autoridade existentes. Sem alongar membros, modificar rig root, alterar colisões ou introduzir salto físico.

Espada: reutiliza exatamente os módulos do arco R7 V4: `procedural_grip_r7.pose_arm`, `procedural_hand_contact_r7.local_socket/conform_hand` e `bow_pose_constraints_r7.HeadClearance`. O centro da pegada vem das cadeias reais dos dedos, não da cabeça do osso do punho. Um cilindro de cabo de raio 14 mm define contato; IK de dois ossos posiciona o braço; CCD fecha os quatro dedos e o polegar. Alvos além do alcance adaptam a posição da arma ao intervalo anatômico (38–94% do alcance), sem escalar ossos. O plano do cotovelo deriva da pose profissional.

O autor procedural adapta o eixo do cabo à orientação visual de cada fase do golpe e vista. São poses discretas alinhadas aos centros dos intervalos da animação; isso não equivale a IK contínuo 3D em runtime nem a solver universal de colisão dos dedos. A posição e orientação não são copiadas de uma arma já parentada à mão: o master da arma fornece o alvo, e o braço/dedos são resolvidos a partir dele.

272 novos frames cobrem Idle (8), Walk (96), preparação (32), corte (32), recuperação (40) e esquiva (64). A caminhada conserva exatamente os esqueletos profissionais documentados no R6 fora da cadeia direita da arma. Corpo, roupa e movimentos das pernas não são redesenhados. Os 56 frames de Hurt e 200 de Death aprovados permanecem idênticos por referência, inclusive mãos, duração e depth. Durante esses clips aprovados continua a apresentação original; a nova camada de dedos só existe nos novos frames de contato.

## Oclusão e execução

A espada segue separada. Além do corpo, exporta-se uma máscara de pixels dos dedos/palma geometricamente à frente do centro do cabo, obtida dos polígonos reais da luva deformada e da profundidade da câmera. A máscara reutiliza os pixels finais do Aseprite, sem desenhar uma mão genérica por cima.

`ProceduralWeaponGripPresentation` associa sprite corporal à máscara correspondente, acompanha seu transform e aplica sorting depois da lâmina. Não submete intenções nem acertos, não altera `SwordSwing`, alcance ou autoridade. Não usa um relógio de animação separado. A máscara some na morte, na prévia do arco e nos sprites que não pertencem ao novo conjunto; não fica congelada sobre a pose seguinte.

Assets ficam em `ArtSource/Labs/Humanoid2026/R8/SwordContact/` e `Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/`. A fonte editável separada é `SwordContactR8.blend`. A cena R8 usa um novo CharacterSet, mantendo o baseline R8 e todo o histórico R5/R6/R7 para comparação. A entrada oficial não muda.

## Verificação e evidências

A prévia inicial de 26 poses teve erro máximo de contato dos dedos de 0,309 mm e nenhum alongamento dos ossos. A auditoria das 272 poses não encontrou vértices da luva atravessando a superfície amostrada da cabeça. O teste de cabeça tem o mesmo escopo explícito do arco: distância assinada à superfície ponderada da cabeça, não colisão universal de todo o corpo.

Exportação final: 48 clips/272 frames novos, zero recortes, erro máximo do socket 0,000000267 m, contato dos dedos 0,000309 m e diferença máxima nas matrizes dos ossos fora da cadeia alterada 0,000001818. A fonte editável reaberta manteve punho/cotovelo com erro máximo 0,000000387 m; ações de esquiva retemporizadas para 0,22 s e todas as ações retidas com fake user. [QA](../../ArtSource/Labs/Humanoid2026/R8/SwordContact/qa.json), [fonte reaberta](HumanoidStatesR8/Feedback/editable-source.json), [integridade Unity](HumanoidStatesR8/Feedback/integrity.json).

Capturas reais: [ataque lateral](HumanoidStatesR8/Feedback/previews/sword-basic-3-unity.gif), [ataque frontal](HumanoidStatesR8/Feedback/previews/sword-basic-0-unity.gif), [pesado lateral](HumanoidStatesR8/Feedback/previews/sword-heavy-east-unity.gif), [esquiva em oito direções, lenta 0,35×](HumanoidStatesR8/Feedback/previews/dodge-eight-unity-slow.gif). As máscaras foram verificadas a cada frame dos traces: sprite correspondente, transform alinhado, sorting sobre a lâmina e desativação nos estados sem máscara.

Os resultados finais de fonte reaberta, integridade, Play/Input System, matrizes de combate e Console ficam em `HumanoidStatesR8/Feedback/`. Previews Blender/Aseprite e screenshots reais da Unity devem ser identificados separadamente. A aprovação artística da esquiva revisada e da espada segue **pendente** até feedback do usuário.

Durante a integração houve uma execução inválida com estados não inicializados e erros repetidos em adaptadores existentes. O Play foi interrompido; a cena salva foi reaberta e iniciou com vida 100, frames avançando e Console atual 0 erros/0 avisos. Não se corrigiu esse incidente acrescentando regras ao combate nem ignorando exceções nos adaptadores. Os testes finais partem de uma nova inicialização limpa, fora de uma recompilação em Play.

## Resultado final da revisão

Verificações reais concluídas: contato Idle/Walk/básico/pesado em oito vistas; esquiva em oito vistas com cooldown/imunidade/retorno; Hurt em oito vistas com rejeições e reação única; Death em oito vistas completas; Hurt→Death, ataque→Death e demais transições; F5; menu Esc e arco South/East com V/J, pausa, dano e morte. A máscara foi validada a cada frame dos traces. [Resultados de execução](HumanoidStatesR8/Feedback/execution-results.json).

[Gate de combate](HumanoidStatesR8/Feedback/combat-gate.json): 40 casos aprovados (básico, pesado, parede, fora de alcance básico e fora de alcance pesado × oito direções), danos 20/36 ou 0 conforme o cenário, um impacto por alvo/golpe. Os mesmos 54 blocos de física da cena R7 permanecem idênticos. `SwordSwing.cs` e autoridade permanecem protegidos pelo baseline de hashes.

Integridade final: 256 frames aprovados de morte/Hurt idênticos, 272 novos frames de contato, 64 clips/528 frames, todos os tempos/eventos preservados, 74 sprites do arco V4 idênticos, 530 arquivos históricos protegidos e cinco arquivos pessoais inalterados. Dispositivos artificiais e override de perfil removidos; Editor parado na cena R8 limpa, com espada padrão. [Console em Play](HumanoidStatesR8/Feedback/console-play.json): 0 erros/0 avisos atuais, sem falha de compilação. A regressão do Iron Knight oficial pertence à validação inicial R8; esta revisão não adiciona o componente à cena oficial.

Para testar: Play em `HumanoidStatesR8.unity`, WASD, Espaço, clique/botão direito; Esc → Validar armas para alternar espada e arco; J reproduz e V alterna a vista do arco; F5 reinicia. Morte e dano continuam aprovados; a esquiva revisada e a empunhadura aguardam sua avaliação artística.
