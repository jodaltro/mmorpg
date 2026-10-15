# Marco 06B.5 — movimento, animação e empunhadura

Implementação técnica e inspeções curtas concluídas; **aprovação artística definitiva pendente**. Cena: `Assets/Mmorpg/Scenes/Marco06B5Animation.unity`. B4 e assets originais preservados. O diretório estava limpo no início; não houve descarte de alterações do usuário.

## Diagnóstico confirmado antes da implementação

`ProductionSpriteAnimator` escolhia caminhada pela mira e voltava a idle ao iniciar recuperação. `ActorMotor.SetIntent` e `Aim` escreviam no mesmo Facing. `SwordSwing.LateUpdate` escalava horizontalmente WeaponPivot por alcance. O debug amarelo reconstruía a ponta pelo comprimento físico e por isso mascarava o esticamento. A inspeção do Editor confirmou raiz/VisualRoot em escala 1, um corpo, uma espada, filho calibrado em ~0,978/-38,8° e pivô local do filho em zero. Não existia cena posterior à B4.

## Direções e mudanças

| Conceito | Dono/política |
|---|---|
| MovementDirection | Alias de ActorMotor.Direction; intenção livre normalizada/clampada. Velocidade física seleciona a vista/cadência quando há deslocamento |
| AimDirection | ActorMotor.Facing continua a API compatível de mira; depois de Aim válido, SetIntent não a sobrescreve. Criaturas sem Aim continuam orientadas pelo movimento |
| VisualFacing | ProductionSpriteAnimator; caminhada pelo deslocamento, idle conserva última vista, ataque pela direção confirmada, dodge pela intenção aceita |
| AttackDirection | SwordSwing.aim, fixado por Begin; mover o mouse durante o golpe não muda o Sweep |
| DodgeDirection | PlayerController, somente após RequestDodge aceito; motor recebe essa direção durante o estado confirmado |

Quatro vistas artísticas, deslocamento físico em 360°. Histerese angular de 15% junto do empate entre eixos evita oscilação sem adicionar temporizador. Colisão pode mudar o eixo predominante da velocidade e, corretamente, mudar a vista. Não há animação de strafing inventada.

Classes alteradas: ActorMotor, PlayerController (exposição somente leitura de dodge), ProductionSpriteAnimator, SwordSwing e SwordSweepDebug. GameplaySpriteAnimator e DirectionalSpriteAnimation preservam o uso da direção confirmada nas cenas antigas. ProductionCharacterSet/ProductionClip, ProductionVisualSync, SwordPresentationEffects, autoridade, Domain e regras de habilidades não precisaram de alteração.

`ProductionFrame.hand` é convertido pelo transform real do corpo; a mesma âncora fornece o offset físico. Escala de WeaponPivot constante 1; escala uniforme calibrada do filho preservada. Ponta visual real do IronSword em aproximadamente 1,02149 u. Sweep conserva `range - 0,25`: básico 1,0 u e pesado 1,4 u; cápsulas, padding, amostragem de translação, LOS, limite pela raiz e prevenção de múltiplos acertos continuam. O F7 mostra a diferença real entre o comprimento do desenho e o alcance físico. Não se força coincidência aumentando a espada.

Preparação parte do ângulo mostrado; corte acompanha o progresso confirmado; recuperação mantém stance final com retorno angular SmoothStep. Clips completos opcionais por fase são suportados; clip legado com mais quadros usa durações relativas autoradas ao longo do golpe. As duas stances atuais não são uma animação corporal completa. A seleção terminal usa o clock confirmado para evitar um frame extra de recuperação após Busy terminar. Nenhum evento visual causa dano.

## Verificação executada

Unity conectada **6000.6.5f1**, autotick 16 ms. Recompile/recompile_status final: completed, failed=false, zero erros. Avisos CS0618 de APIs obsoletas em testes existentes foram observados durante compilação; Console em Play na leitura final não mostrou erros novos. Buffer histórico contém ocorrências de marcos anteriores e não equivale a falhas desta execução. [Compilação](Marco06B5/compile.json), [Console](Marco06B5/console.json).

| Inspeção real no Editor | Resultado |
|---|---|
| Norte/sul/leste/oeste e quatro diagonais | Ambas as poses observadas por vista; velocidade máxima 3,5 u/s em todas as oito intenções |
| Mira contrária, parar/retomar, girar mouse parado | Mira independente; corpo acompanha deslocamento e conserva orientação no idle |
| Frames avançando | Contadores first/last do relatório comprovam avanço durante input e capturas |
| Mão/escala | Erro de contato 0 nas amostras ao fim do frame; pivô sempre (1,1,1); comprimento visual constante dentro da precisão float |
| Ataque quatro vistas + pesado diagonal | Preparação/corte/recuperação/idle observados; direção confirmada estável |
| Ataque em movimento e após dodge | Golpes aceitos; ataque em movimento manteve direção mesmo após mover a mira para o lado oposto |
| Básico contra boneco próximo | 100→80, dano 20; nenhum segundo acerto no mesmo golpe |
| Fora do alcance | 100→100, dano 0 |
| Parede entre mão e alvo | 100→100, dano 0 |
| Pesado próximo | 100→64, dano 36; espada não esticou |
| Cena/hierarquia | Uma espada, um BodySprite, Rigidbody2D Dynamic e BoxCollider2D existentes; nenhuma colisão gerada por sprite |

[Movimento](Marco06B5/movement.json), [ataques](Marco06B5/attacks.json), [combate](Marco06B5/combat.json), [métricas](Marco06B5/metrics.json). Os JSON `*-run` registram o retorno do Pipeline (inclusive success interno).

São inspeções curtas por eventos reais do Input System, não suítes automatizadas de EditMode/PlayMode. Perfis temporários exclusivos em Temp; saves pessoais preservados. Para manter os trechos curtos e independentes, o jogador foi reposicionado **entre** cenários de caminhada; dentro de cada trecho o deslocamento foi inteiramente físico por input. O teste de alcance/LOS reposicionou somente durante Play o jogador e o boneco existente e criou uma parede temporária, removida ao final. Não são percursos completos de jornada.

Capturas de ataque usam timeScale=0,35 para tornar fases curtas inspecionáveis; dano e movimento foram verificados a 1x. Isso não altera durações configuradas ou regras de combate. Input/opções do Editor/timeScale foram restaurados. A primeira tentativa de medição assíncrona lia antes do LateUpdate e foi substituída por WaitForEndOfFrame; não é usada como evidência de defeito renderizado. Um trecho de caminhada terminou contra uma casa: a checagem passou a distinguir caminhada observada de parada por colisão.

## Evidência visual e limites

- [Caminhada](Marco06B5/walk.gif), [caminhada com mira contrária](Marco06B5/walk-opposite-aim.gif).
- [Ataque/F7](Marco06B5/attack-f7.gif), [pesado diagonal/F7](Marco06B5/heavy-diagonal-f7.gif).
- [Idle com espada](Marco06B5/idle.png), [prancha de revisão](Marco06B5/contact-sheet.png).
- [Metadados por captura](Marco06B5/capture-metadata.jsonl), [montagem e durações](Marco06B5/previews.json). GIFs montados exclusivamente de ScreenCapture real; recorte acompanha jogador apenas na prévia, sem interpolar poses. A cadência amostrada sofre custo de captura, não mede FPS normal do jogo. Algumas vistas da caminhada passam parcialmente sob copas existentes.

Quadros existentes por direção: **idle 1, walk 2, attack 2 stances reutilizadas, dodge 1; hurt/death próprios 0**. Total de entradas do herói 24. Nenhum novo quadro aprovado/integrado. Uma tentativa gerada com imagegen produziu oito figuras candidatas, reprovadas por inconsistência de apoio/passagem/capa. [Arte rejeitada, razões e prompt exato](../../ArtSource/References/Rejected/Marco06B5/review.md).

Ainda faltam os **32 desenhos de caminhada profissional**, ataques corporais com preparação/corte/recuperação por vista, dodge completo, hurt/death. Não há offsets ou interpolação isolada para esconder desenhos ausentes: as trocas discretas de pose no início/fim do ataque continuam perceptíveis, mas mão e cabo trocam juntos. A recuperação já não recolhe instantaneamente o braço para idle. Aprovação artística depende de jogar e revisar esses limites.

Contra-ataque, Leitura de Fraquezas, Marca do Caçador, NPCs, inventário/diário, F5/reset/F8, saves e cinco regiões tiveram código/referências preservados; não foram novamente exercitados em uma jornada completa neste marco. Não declarar essa cobertura como teste passado. Nenhuma suíte extensa, backend, SQL, Nakama/Jev/OpenRouter ou build de distribuição foi executado/modificado.

Autorização adicional do usuário para chamadas pagas, commit e push na main registrada em AGENTS.md. Uma chamada ao imagegen integrado foi utilizada; não houve chamada a OpenRouter. Publicação usa branch main criada a partir do checkout local master existente, sem reescrever master remoto.
