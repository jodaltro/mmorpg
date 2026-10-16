# Marco 06B.11 — Iron Knight: esquiva, dano, morte e transições

Candidato integrado e inspecionado na Unity 6000.6.5f1 em 16/10/2026. A aprovação artística dos **novos estados permanece pendente**. A integração está exclusivamente em `Assets/Mmorpg/Scenes/Marco06B11CharacterStates.unity`, copiada da B10 limpa. A cena inicial e as regiões não foram alteradas. O gerador recusa sobrescrever o destino.

## Fonte e escolha artística

Fonte: [8-Directional Iron Knight, Hormelz](https://hormelz.itch.io/8-directional-iron-knight), pacote desarmado CC0 `Knight-Only_BlueKnightUnarmed.zip`. Original preservado fora de Temp em `D:/unity/ExternalArt/IronKnight2026/extracted/BlueKnightUnarmed`. Não houve geração de desenhos, recoloração, rig, espelhamento ou alteração dos cels originais.

O documento original foi aberto pelo Aseprite 1.3.18.6 via CLI/Lua: 256×256, 3.920 frames, 38 tags de ação. Há 35 ações exportadas em PNG/JSON, oito vistas cada. Quatro tags `Broken*` não têm diretórios exportados correspondentes; `SpinAttack` tem exportação, mas não uma tag com esse nome exato. Não presumimos equivalências. O inventário reúne 39 nomes distintos, suas vistas, quadros, durações, formatos, potencial e limitações: [source-inventory.json](Marco06B11/source-inventory.json), [tags](Marco06B11/aseprite-tags.txt), [durações Aseprite](Marco06B11/aseprite-durations.txt).

As ações exportadas são BackSlash, BigCast, Cast, Cast_001, Crouch, CrouchDamaged, CrouchGuard, CrouchInGuard, CrouchOutGuard, Damaged, Damaged_001, Die, Die_001, GuardIdle, GuardIdle_001, Idle, Idle_001, InCrouch, InGuard, InGuard_001, Jump, Kick, OutCrouch, PowerUp, Run, RunBack, RunningJump, RunStrafeLeft, RunStrafeRight, Slash, SpinAttack, StrafeLeft, StrafeRight, WalkBack e WalkFoward.

| Estado novo | Ação original | Quadros/vista | Relógio do pacote | Política B11 |
|---|---|---:|---:|---|
| Dodge | Jump | 9 | 0,600 s | Salto evasivo curto completo em 0,22 s |
| Hurt | Damaged | 7 | 0,466667 s | Recuo corporal e retorno, sem loop |
| Death | Die | 23 | 1,533333 s | Queda completa e pose terminal mantida |

Vistas selecionadas: Sul=dir8, Oeste=dir2, Norte=dir4, Leste=dir6. São 156 cels novos. Cada PNG exportado pelo Aseprite foi comparado em RGBA ao PNG correspondente do pacote: conteúdo idêntico. O JSON original usa duração nominal de 1/15 s; o documento Aseprite representa cada cel em 66 ms. O runtime usa o relógio nominal do JSON, e os documentos editáveis mantêm a quantização em milissegundos do formato.

Não existem ações chamadas Dodge, Roll, Dash ou Evade. **A esquiva B11 é uma adaptação de Jump, não um rolamento.** Há decolagem, elevação dos joelhos, aterrissagem e retorno reconhecíveis, sem deformar o desenho. RunningJump foi inspecionado e descartado por terminar agachado e retornar pior ao idle. Damaged_001 e Die_001 também foram examinados; as alternativas escolhidas têm recuo claro e morte completa mais curta. As outras ações foram catalogadas, sem alegar avaliação artística para um uso fora deste marco.

A compressão de Jump para 0,22 s torna a leitura rápida. O corpo sugere salto, mas a física continua estritamente no plano existente. A adequação desse salto como esquiva precisa da avaliação do usuário. Não há material original de rolamento identificado para oferecer uma versão de rolamento neste marco.

## Implementação e preservação

`ProductionCharacterStates` é um observador visual opcional com referências serializadas. Não mantém vida própria, dano, imunidade ou cooldown. Compara HP antes/depois de `ActorHealth.Changed`, reage apenas à redução aceita e remove a inscrição em OnDisable. A substituição do `CombatState` limpa relógios e pendências visuais. Ciclos repetidos de habilitação e reinício sem domain reload foram inspecionados sem callbacks duplicados.

Prioridade: **Death → Dodge → Attack → Hurt → Walk → Idle**. Death e Dodge consultam o estado confirmado. A esquiva calcula o tempo do clip diretamente de `(agora - (DodgeUntil - 0,22)) / 0,22`, sem timer acumulado de ação anterior. A direção vem de `PlayerController.DodgeDirection`, inclusive em diagonal e com mira oposta. A animação não move Rigidbody nem decide invulnerabilidade. A poeira existente continua dependente da borda de esquiva aceita.

Hurt usa a vista corporal vigente no impacto. O flash existente é imediato. Se houver Slash em andamento, o corpo mantém as fases e âncoras aprovadas; a pose de Hurt começa após o ataque, desde que a pendência tenha no máximo 0,8 s. A vida muda no instante real do dano. Não há hitstun, knockback ou cancelamento de autoridade novo. Uma pendência mais antiga expira, conservando apenas o feedback imediato. Um novo ataque ou esquiva tem prioridade sobre Hurt.

O seletor de Death é consultado antes do retorno por `IsAlive=false`. O relógio inicia uma vez, o clip não repete e o último cel permanece. A opção serializada `holdAnimatedDeath` em `ProductionVisualSync` está ativa somente no jogador B11: impede o fade de 0,45 s e a transparência cinza do proxy de ocultarem a queda. A pose terminal fica opaca até o sistema existente substituir/restaurar o ator. A B10 e os demais atores conservam a opção padrão desativada. Um gatilho aplicado por uma fixture entre Update e end-of-frame pode manter a pose anterior até o Update seguinte; a morte visual assume a prioridade no próximo quadro, enquanto as regras físicas e a arma já respondem à vida zero.

A espada separada acompanha novas projeções de luva por quadro em Dodge/Hurt, com profundidade traseira em Oeste/Norte. A mão posterior fica ocluída em parte da esquiva Oeste e do Hurt Oeste; nesses quadros a projeção do punho fica atrás do torso/cabeça. Isso foi registrado como limitação da vista, sem inventar uma mão visível. Em Death a espada é ocultada pelo comportamento existente de `SwordSwing`; não foi criada física de arma caída nem Sweep adicional.

O importador B9/B10 aceita a extensão B11, carrega primeiro o `ProductionCharacterSet` B10 e acrescenta 12 clips. Os 24 clips B10 e seus 108 sprites são **referências reutilizadas**, com segundos, hand, holdAngle, depth, eventos, source e status comparados campo a campo. As folhas de Death usam limite de textura 8192 para não reduzir os 23 cels de 256 px. As demais configurações permanecem 32 PPU, Point, sem compressão e sem mipmaps. [Verificação do import](Marco06B11/import.json).

Os 58 arquivos do snapshot B10, incluindo fontes Aseprite, manifestos, texturas, asset e cena, permanecem byte a byte idênticos: [antes](Marco06B11/preservation-before.json), [depois](Marco06B11/preservation-after.json). Permanecem os 11 quadros de Walk a 53,333 ms, os 15 desenhos de Slash por vista divididos em fases, empunhadura, oclusão, comprimento e calibração da espada. O código de `SwordSwing` não mudou.

## Validação real

Harness: `AgentScripts/InspectIronKnight06B11.cs`, derivado da estrutura B10. Comandos executados no Editor conectado com `--caller plugin --skill unity-pipeline`, autotick ativo. Capturas após LateUpdate/end-of-frame, dispositivos artificiais do Input System, perfis exclusivos em `Temp/Marco06B11/<id>`. Teclas/mouse, dispositivos, configurações de input/Editor, override do perfil e timeScale foram restaurados ao final. A cena B11 foi deixada aberta fora de Play. Saves pessoais não foram acessados pelo jogo durante as inspeções.

| Inspeção executada | Resultado observado |
|---|---|
| Esquiva idle, movimento, 4 vistas, 2 diagonais, mira contrária | Nove cels por ação, primeiro frame correto, vista constante na direção confirmada |
| Cooldown e repetição aceita no mesmo estado | Rejeição sem nova animação/poeira; nova ação reinicia em frame0 |
| Velocidade e relógio da esquiva | Máxima 9 u/s; janela confirmada de 0,22 s; cooldown 0,9 s preservado |
| Dano aceito e imunidade em 4 vistas | 15 HP pela regra Wolf; exatamente uma notificação e sete cels de Hurt |
| Dano recusado por esquiva ou mesma facção | Nenhuma reação adicional |
| Ataque recebido com parede / sem parede | Intenção aceita, parede bloqueia dano/Hurt; sem parede o melee espacial da autoridade aplica dano e dispara Hurt |
| Dano durante Slash | Flash imediato, Slash preservado, Hurt posterior e retorno normal |
| Morte nas 4 vistas | 23 cels, sequência completa, espada oculta, alpha 1, terminal estável |
| Tentativas de caminhar/atacar/esquivar morto | Sem movimento físico, ataque e esquiva recusados, corpo não simulado |
| Restauração do ator e reinício após morte | Idle e espada restaurados; Restart existente salva/carrega perfil isolado com nova instância viva |
| Reabrir B11 / habilitar observador repetidamente | Referências funcionais e uma reação por dano aceito |
| Walk B10 e B11, 4 vistas e mira oposta | 3,5 u/s; empunhadura com erro de ligação medido 0 u |
| Ataques básicos nas 4 vistas e pesado | Preparação, corte e recuperação; ligação da mão preservada |
| Dano físico no alvo próximo / fora do alcance / parede / pesado | 20 / 0 / 0 / 36; um HitConfirmed nos acertos, zero nos bloqueios |
| Obstáculo existente | Caminhada a 3,5 u/s e parada física a 0 u/s |
| B10 aberta isoladamente após alteração compartilhada | Observador ausente e fade antigo termina com alpha 0 |

As fixtures de dano direcional repetível chamam por reflexão o caminho existente `OfflineAuthority.ResolveDamage`, após a etapa espacial, com o TrainingDummy temporário como atacante; o dano vem de `ActionCombatRules`, sem valor de dano fornecido pelo input. A checagem adicional de ataque recebido usa `RequestAttack` e passa pelo cone, alcance, parede e aplicação real da autoridade. Nenhuma fixture foi salva na cena. No percurso Hurt Norte o obstáculo real pode resultar em idle ao final por velocidade zero; as demais vistas registram Hurt → Walk e depois idle.

Transições registradas: Idle → Dodge, Walk → Dodge → Walk em captura contínua, Dodge → Idle, Dodge → Attack, Walk → Hurt, Hurt → Idle/Walk, Attack + dano aceito → Hurt, Hurt → Death, Idle → Death e Walk → Death. Sem crossfade ou root motion. Os valores de Domain, geometria Sweep, alcance, colisões, persistência, progressão e autoridade não foram alterados. Imunidade segue 0,35 s; os demais valores constam na tabela e no código original preservado.

Evidências numéricas: [candidate](Marco06B11/candidate/), [baseline B10](Marco06B11/baseline/), em especial `dodge-results-*.json`, `hurt-results.json`, `death-results-*.json`, `combat.json`, `obstacles.json`, `regression.json`, `lifecycle.json` e `legacy-fade.json`. Os traces contêm frames crescentes, timestamps, HP, source, posição, velocidade, arma, alpha, poeira e estado real.

Compilação inicial concluída sem erros: [compile.json](Marco06B11/compile.json). Conferência final `up_to_date`, failed=false: [compile-final.json](Marco06B11/compile-final.json). Console: zero erros capturados e zero erros no Editor; o buffer conserva 29 avisos de APIs/diretivas antigas em arquivos existentes: [status](Marco06B11/console.json), [entradas](Marco06B11/console-entries.json). Não foram executadas suítes extensas EditMode, PlayMode ou backend.

## Prévias

Pranchas da fonte original: [Dodge](Marco06B11/previews/dodge-source-board.png), [Hurt](Marco06B11/previews/hurt-source-board.png), [Death](Marco06B11/previews/death-source-board.png). Pranchas com os quadros observados na Unity: [Dodge](Marco06B11/previews/dodge-unity-board.png), [Hurt](Marco06B11/previews/hurt-unity-board.png), [Death](Marco06B11/previews/death-unity-board.png).

- [Esquiva Unity, quatro vistas](Marco06B11/previews/dodge-unity.gif) — relógio do jogo; [leitura 3× mais lenta](Marco06B11/previews/dodge-unity-slow.gif).
- [Hurt por melee espacial confirmado](Marco06B11/previews/hurt-unity.gif).
- [Morte completa e terminal mantido](Marco06B11/previews/death-unity.gif).
- [Walk → Dodge → Walk contínuo](Marco06B11/previews/walk-dodge-walk.gif).
- [Attack + dano → Hurt](Marco06B11/previews/attack-hurt.gif).
- [Hurt → Death](Marco06B11/previews/hurt-death.gif).
- B10 × B11: [Walk nas quatro vistas](Marco06B11/previews/b10-vs-b11-walk.gif), [básico nas quatro vistas](Marco06B11/previews/b10-vs-b11-basic.gif), [pesado](Marco06B11/previews/b10-vs-b11-heavy.gif).

Todos os GIFs do jogo usam apenas frames capturados na Unity. O recorte acompanha o jogador, sem reconstruir poses; os recortes sem anotações são preservados em `Marco06B11/captures/`. Os arquivos `*-provenance.json` ligam os GIFs aos frames, timestamps e fontes reais. As comparações usam o mesmo tempo decorrido de cada gravação, amostrado a cada 40 ms e exibido a cada 70 ms para leitura. Os GIFs originais de Aseprite em `source-review/` são identificados separadamente. Screenshots integrais intermediários ficam em Temp e não são publicados.

Falta a avaliação artística do usuário sobre a esquiva adaptada, impacto de Hurt, queda e transições. A validação técnica não substitui essa aprovação. B10 continua aprovada e preservada; nenhum estado novo foi promovido à cena inicial.
