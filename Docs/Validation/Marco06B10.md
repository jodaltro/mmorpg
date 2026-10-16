# Marco 06B.10 — cadência, empunhadura e fases do Iron Knight

16/10/2026. **Funcionamento técnico verificado; melhoria artística preliminar, aprovação definitiva do usuário pendente.** Cena isolada: `Assets/Mmorpg/Scenes/Marco06B10CombatPolish.unity`. B9, produção e cena inicial preservadas. Sem mudanças em código de Runtime/Domain, autoridade, dano, cooldown, alcance, velocidade ou calibração da espada.

## Para avaliar

- [Caminhada real B9 × B10](Marco06B10/previews/walk-b9-vs-b10.gif).
- [Básico real B9 × B10, quatro vistas](Marco06B10/previews/basic-b9-vs-b10.gif).
- [Pesado real B9 × B10, quatro vistas e diagonal](Marco06B10/previews/heavy-b9-vs-b10.gif).
- [B10 nas quatro direções, com espada](Marco06B10/previews/b10-four-directions.gif).
- [B10 pesado diagonal com F7](Marco06B10/previews/b10-f7-heavy.gif), [frame completo sem crop](Marco06B10/candidate/f7-heavy-full.png).
- [Captura parada no cenário](Marco06B10/candidate/idle.png), [poses/fases reais lado a lado](Marco06B10/previews/attack-contacts-real.png).
- Contatos: [idle](Marco06B10/previews/hand-contacts-idle.png), [44 walk](Marco06B10/previews/hand-contacts-walk.png), [60 Slash](Marco06B10/previews/hand-contacts-attack.png). Magenta = B9; verde = B10.
- [Cadência e deriva](Marco06B10/cadence-report.json), [alinhamento e fases](Marco06B10/alignment-report.json), [correções das mãos](../../ArtSource/Labs/IronKnight2026/B10/hand-changes.json).
- [Aseprite editáveis B10](../../ArtSource/Labs/IronKnight2026/B10/editable), [manifesto B10](../../ArtSource/Labs/IronKnight2026/B10/manifest.json), [revisão anatômica/fases](../../ArtSource/Labs/IronKnight2026/B10/hand-review.json), [revisão dos pés e incertezas](../../ArtSource/Labs/IronKnight2026/B10/foot-review.json).

## Baseline e diagnóstico

A B9 foi gravada novamente **antes de alterar arte, metadados ou importador**. O harness novo reutiliza a inspeção por Input System real, com perfil isolado, dispositivos temporários e ScreenCapture após LateUpdate/end-of-frame. [Movimento baseline](Marco06B10/baseline/movement.json), [ataques baseline](Marco06B10/baseline/attacks.json), [telemetria por captura](Marco06B10/baseline/capture-metadata.jsonl). Capturados: cardinais, diagonais, mira contrária, parar/retomar, básico nas quatro vistas, pesado nas quatro vistas/diagonal, ataque em movimento, após esquiva e F7.

Cada captura registra frame Unity, relógio, timeScale, posição/velocidade, source frame, vista, estado, progresso confirmado do ataque/fase, mão mundial, âncora transformada, ângulo, ponta real, comprimento e histórico real do Sweep. `sweep` é a fila do SwordSweepDebug, alimentada pelos callbacks do loop OverlapCapsule existente, não uma curva reconstruída. O campo bruto `clipTime` é o relógio de caminhada lido do animador, inclusive quando parado/atacando; não deve ser confundido com tempo de Slash. O [relatório de relógios selecionados](Marco06B10/clip-clock-report.jsonl) fornece o tempo do clip correto, derivado dos progressos confirmados e das durações reais usando a mesma fórmula do animador. O relógio de ataque é **derivado**, não um novo campo gravado diretamente do Runtime.

Problemas encontrados: a caminhada leste tinha âncoras abaixo da luva, sobre a região da perna; algumas coordenadas do Slash incidiam em punho, ombro ou bota em vez da palma. O clip longo de Slash era distribuído sobre o ataque inteiro, fazendo a preparação/corte/recuperação confirmados selecionar poses anatômicas de outra fase. A comparação por intervalos manuais encontrou **66/192 amostras de ataque B9 fora da fase anatômica escolhida**. Isso é uma medida de correspondência com o mapa autorado, não uma avaliação independente da qualidade de cada pose.

## Caminhada — medição e solução

Mantidos os 11 desenhos, canvas 256×256, 32 PPU, pivô `(128,114)`, escala 1 e velocidade física de **3,5 u/s**. Não há root motion, offset animado da raiz, alteração do motor ou trajetória para compensar pixels.

| Parâmetro visual | B9 | B10 |
|---|---:|---:|
| Duração por quadro | 66,667 ms | 53,333 ms |
| Ciclo de 11 quadros | 0,733333 s | 0,586667 s |
| Frequência | 15 FPS | 18,75 FPS |
| Distância da raiz por ciclo a 3,5 u/s | 82,13 px | 65,71 px |
| Translação durante um quadro sustentado completo | 7,47 px | 5,97 px |

Foi escolhido **1,25× visual**, incorporado às durações do manifesto. É um compromisso limitado, mantendo ordem/ritmo relativo dos desenhos; não se tentou igualar toda a translação com a pequena passada do sprite. Um ajuste muito maior seria necessário para aproximar alguns apoios de foot lock e tornaria os passos excessivamente rápidos. O multiplicador de velocidade observada já existente no ProductionSpriteAnimator continua funcionando; `referenceSpeed` permanece 3,5. A política de retomada existente (reset após parada >0,18 s) foi preservada e exercitada.

### Como a deriva foi medida

Os 11 quadros de cada vista foram examinados em exports do Aseprite e pranchas nearest. O ciclo mostra duas alternâncias de passo. Foram marcados **pontos de uma mesma região de sola** dentro de intervalos de apoio candidatos, com identidade/confiança explícitas; não se usou a menor borda alfa como se fosse o mesmo pé. A outra bota, fases aéreas e oclusões sem identidade confiável ficam sem ponto (`null`). No sul a alternância aparece nas botas separadas; no norte o tabard cobre as canelas; nas laterais há superposição e um pé elevado à frente. A identidade e o instante exato de contato não são igualmente confiáveis nas quatro vistas.

Intervalos comparados: sul 1→4, oeste 6→9, norte 6→9, leste 1→4, índices desde zero. Fora desses intervalos os pontos não são tratados como apoio confirmado. A vista norte tem **confiança baixa**. As marcações são estimativas visuais de sola/apoio, não dados biomecânicos ou um pé físico do Rigidbody.

Uma segunda inspeção, sem screenshots no loop, registrou **803 amostras renderizadas B9 e 830 B10**, nas mesmas quatro intenções a 1×. Amostras com velocidade <3,4 u/s foram excluídas; as fixtures terminam antes/ao aproximar obstáculos. Para cada ponto identificado, `soleWorld = rootWorld + ((x-128)/32,(114-y)/32)`. A posição real da raiz foi lida a cada end-of-frame, conservando a translação/interpolação do jogo. Mediram-se separadamente: deslocamento entre o primeiro quadro de apoio e o último, e deslocamento enquanto a imagem permanece igual. [Trace B9](Marco06B10/baseline/foot-trace.json), [trace B10](Marco06B10/candidate/foot-trace.json).

| Vista | Deriva estimada da sola no intervalo B9 | B10, média dos intervalos completos | Confiança |
|---|---:|---:|---|
| Sul, 1→4 | 16,15 px | 11,89 px | média |
| Oeste, 6→9 | 13,18 px | 8,82 px | média no intervalo; identidade incerta fora dele |
| Norte, 6→9 | 21,60 px | 17,38 px | baixa, oclusão pela roupa |
| Leste, 1→4 | 16,32 px | 11,83 px | média no intervalo |

Os valores são deslocamentos resultantes de um ponto estimado no mundo, **não percentuais globais de foot sliding do ciclo inteiro**. Há apenas um/dois intervalos completos por vista: não são estatística de longa duração. A soma vetorial inclui deriva transversal quando a bota muda de silhueta. Relatório preserva separadamente a projeção na direção de avanço.

Média observada de deriva durante cada quadro sustentado: sul **6,90→5,54 px**, oeste **6,99→5,53**, norte **7,02→5,53**, leste **6,92→5,51**. A amostragem não inclui exatamente ambas as bordas temporais de cada quadro; por isso fica ligeiramente abaixo dos limites completos teóricos 7,47/5,97 px. Houve redução próxima de 20% nesse componente, sem prometer zero. Nas trocas de pose, a mudança local das botas compensa parte da translação, mas não toda.

A geometria/alternância e o loop 10→0 continuam os originais, sem poses removidas, duplicadas ou redesenhadas. As mesmas variações verticais do topo da silhueta (aproximadamente 1–2 px na caminhada) permanecem; somente o tempo muda. Não se introduziu oscilação procedural. **O compromisso parece mais responsivo e reduz a deriva estimada, mas a naturalidade definitiva e o ritmo de passos ainda precisam da avaliação do usuário em Play.**

## Empunhadura — revisão dos 108 quadros

Revisados quatro idle, 44 walk e 60 Slash sobre as imagens nativas. Foram alteradas **99 coordenadas**; muitas correções são de 1–2 px para mover o contato da borda/punho ao interior da região da luva. A correção maior é oeste Slash 11: `(107,130)→(95,114)`, retirando a âncora da região da bota e colocando-a no braço/mão frontal. Exemplo leste walk 0: `(127,124)→(135,118)`, da região da perna para a palma visível. A lista completa antes/depois está em `hand-changes.json`.

A seleção foi manual, por anatomia/região da luva, com inspeção nearest; a checagem de opacidade apenas encontrou coordenadas inconsistentes para reexaminar, **não escolheu automaticamente pixels opacos**. Pontos inicialmente fora da silhueta foram revistos nas pranchas detalhadas. Em partes do Slash norte/oeste e ao girar para trás no leste, a mão é parcialmente ocluída: `handVisibility` registra inferência por continuidade anatômica, sem declará-la certeza absoluta.

`ProductionFrame.hand`, pivô corporal, transformação do BodySprite, calibração da lâmina e espada separada foram mantidos. A âncora nova move a origem visual e a origem de empunhadura que o Sweep existente já consulta; não se modificou o algoritmo físico para esconder uma mão incorreta. Não há interpolação isolada do cabo para fora da luva.

### Profundidade

A hierarquia já permite `ProductionFrame.depth`; portanto não foi criado outro sistema de sorting, arma ou Animator. Idle/walk: norte atrás, demais à frente. Slash por índice:

| Vista | Atrás do corpo | À frente |
|---|---|---|
| Sul | — | 0–14 |
| Oeste | 0–5 e 14 | 6–13 |
| Norte | 0–6 e 12–14 | 7–11 |
| Leste | 8–10 | 0–7 e 11–14 |

Isso acompanha a passagem do braço entre planos. O sorting usa o corpo inteiro, não uma máscara individual de dedos/tronco. Oclusão fina do cabo pela luva e algumas poses de giro continuam uma limitação; não se declara anatomia ou ocultação perfeita em todos os quadros.

## Slash — sincronização com o combate

Os 15 desenhos de cada Slash continuam em ordem. Os novos clips compartilham os mesmos sprites/quadros da sequência original; não são desenhos duplicados para cumprir contagem. O clip legado completo é conservado como fonte/fallback, e o animador seleciona **um único clip de fase** por vez.

| Vista | Preparação | Corte | Recuperação | Leitura da ação |
|---|---|---|---|---|
| Sul | 0–4 | 5–8 | 9–14 | braço recua/sobe até 4; aceleração 5→7; extensão baixa 8; retorno 9–14 |
| Oeste | 0–4 | 5–8 | 9–14 | mão distante sobe até 3–4; braço cruza para a frente 5–8; recuperação próxima 9–13 e retorno ao plano distante em 14 |
| Norte | 0–5 | 6–9 | 10–14 | preparação permanece comprimida/ocluída até 5; deslocamento amplo da mão em 6→7; extensão baixa 8–9; retorno 10–14 |
| Leste | 0–4 | 5–9 | 10–14 | cotovelo/mão sobem até 4; aceleração 5→7; extensão/giro em 8–9; mão retorna para frente 10–14 |

Os limites foram escolhidos pela sequência do braço, não copiados automaticamente entre direções. As durações autoradas internas continuam proporcionais. O suporte **já existente** a `attack-preparation/cut/recovery` normaliza cada subsequência para o progresso confirmado da fase: o corte de 4/5 desenhos cabe nos 0,14 s ativos; a recuperação cabe nos 0,16 s existentes; preparação básica/pesada conserva o tempo recebido da autoridade. Nenhum evento de arte aplica dano ou altera a janela ativa. O pesado continua usando o mesmo Slash adaptado com sua preparação mais longa.

Nas capturas finais, **zero amostras fora dos intervalos de fase escolhidos**, contra 66 no baseline. Esse resultado comprova a seleção temporal esperada; não prova que o ângulo original de cada antebraço coincide perfeitamente com o arco físico de 110°. SwordSwing continua controlando a rotação real. A transição rápida entre algumas poses e o retorno ao idle ainda são discretos; preservar contato à luva impede suavizar a mão independentemente do desenho. Não houve redesenho localizado nem deformação da espada para tentar esconder esses limites.

## Integração e proveniência

Fonte continua [Iron Knight, Hormelz, CC0](https://hormelz.itch.io/8-directional-iron-knight), conforme licença/proveniência já verificadas no B9. B10 deriva exclusivamente dos arquivos versionados; não usa nem exige o ZIP completo. Nenhuma geração externa, PixelLab, IA, rig, migração B3 ou `production.py`.

`ArtSource/Labs/IronKnight2026/B10` contém manifesto separado, revisão das mãos/pés, Lua de preparação e 12 cópias editáveis. Aseprite 1.3.18.6 foi usado para ler as 12 fontes, salvar as cópias, ajustar durações e acrescentar guias ocultas de mão e tags de fase. As 108 poses foram exportadas novamente com as guias ocultas e comparadas ao RGBA original: **todas idênticas pixel a pixel**. [QA de fontes/preservação](Marco06B10/source-qa.json). O Aseprite quantiza durações em milissegundos (aproximadamente 53 ms no walk B10); o runtime usa 53,333 ms do manifesto.

As sheets usadas são referências às fontes B9 preservadas; o importador copia apenas 12 sheets para a pasta Unity B10. Não se duplicaram os 3.920 quadros do pacote. Não houve recolor: a saturação continua uma questão de acabamento posterior, priorizando os limites de movimento/ataque deste marco. Não há flicker de paleta introduzido.

`AgentScripts/IronKnight06B9.cs` ganhou a pequena entrada compartilhada `ImportSet(source,output,characterId)` e a entrada `IronKnight06B10`. A antiga `IronKnight06B9.Import` continua usando sua configuração original. B10 acrescenta apenas mapas de fase e configuração separada; o contrato de produção 96×96 permanece intacto. Importação verificada: canvas 256×256, 32 PPU, Point, Uncompressed, Clamp, mipmaps off, alpha. B10 tem **24 clips** (12 originais + 12 subsequências de fase), com **108 sprites únicos**. Reimportação preservou os 108 pares GUID/fileID. [Verificação de importação](Marco06B10/import-verification.json).

A cena B10 foi copiada da B9 limpa pela API do Editor, com recusa de destino existente. Não recriou regiões, personagem, HUD/câmera, NPCs ou sistemas de persistência. Um BodySprite, uma EquippedSword, Rigidbody2D Dynamic e BoxCollider2D existentes. B9 não foi salva novamente nem sobrescrita. Hashes de todas as fontes/assets B9, cena B9, SwordSwing e SwordSweepDebug conferem com o início da tarefa. Metadados B9 foram também comparados ao manifesto original no Editor. O código compartilhado alterado é ferramenta de autoria fora de Assets; **nenhum script Runtime/Domain foi alterado**.

## Verificação real executada

Unity 6000.6.5f1, CLI 1.0.0-beta.13, autotick 16 ms. [Recompile/status](Marco06B10/compile.json): up_to_date, failed=false, compilationFailed=false; não havia mudanças C# em Assets. Ferramentas foram realmente compiladas em memória e executadas, sem diagnósticos. [Console final](Marco06B10/console-final.json): zero erros/avisos.

| Inspeção | Resultado executado |
|---|---|
| Quatro cardinais e quatro diagonais, mira oposta | B9 e B10 a 3,5 u/s; sprites/vistas avançando; mira independente |
| Parar, girar mira, retomar | Idle conserva vista; retomada observada por input/captura |
| Colisão existente | Rocha em `(-4,2)` bloqueou o jogador em x≈-5,04; velocidade máxima 3,5→0, sem alterar collider |
| Básico quatro vistas; pesado quatro vistas + diagonal | Preparação/corte/recuperação observados e direção confirmada estável |
| Ataque em movimento, após esquiva, voltar a idle/walk | Aceitos/observados; capturas próprias no candidato |
| Comprimento/attachment | Erro pivô–âncora 0 nas amostras; escala `(1,1,1)`; lâmina ≈1,021488 u constante |
| Básico próximo | 100→80, dano 20, **1 HitConfirmed** |
| Fora de alcance | 100→100, dano 0, **0 HitConfirmed** |
| Parede entre jogador/alvo | 100→100, dano 0, **0 HitConfirmed** |
| Pesado próximo | 100→64, dano 36, **1 HitConfirmed** |

[Movimento B10](Marco06B10/candidate/movement.json), [ataques B10](Marco06B10/candidate/attacks.json), [obstáculo](Marco06B10/candidate/obstacles.json), [combate](Marco06B10/candidate/combat.json), [execução com contagem de hits](Marco06B10/candidate/combat-run.json), [impacto básico](Marco06B10/candidate/impact-near.png), [impacto pesado](Marco06B10/candidate/impact-heavy.png). O teste de dano foi repetido para acrescentar contagem explícita de HitConfirmed e capturas durante o impacto, sem mudança de gameplay.

Frames avançaram: movimento B9 **976→3490**; B10 **15302→17798**, além das traces específicas de pés. Ataques usam timeScale **0,35 em ambos** para inspeção; movimento, obstáculo e dano usam **1×**. O jogador/alvo são reposicionados somente entre cenários das fixtures; dentro dos trechos, movimento é físico por input. A parede temporária existe somente em Play e é removida no finally. O boneco restaura a própria vida entre cenários conforme comportamento existente.

O Sweep permanece com extensão 1,0 u no básico e 1,4 u no pesado, enquanto a lâmina mede ≈1,021488 u; a diferença conhecida de ≈0,3785 u no pesado não foi escondida com escala. F7 amarelo representa a ponta real e ciano vem das amostras físicas. Impactos/trilhas existentes renderizaram nas capturas; não se declara regressão completa de todos os efeitos/habilidades.

Dispositivos de teste removidos e nativos reativados, timeScale 1, perfil isolado liberado e opções do Editor/input restauradas ao sair do Play. Uma pausa temporária a timeScale 0 foi usada entre chamadas para não deixar o mundo avançando enquanto se analisavam arquivos, fora dos trechos de comparação. A reserialização incidental de TimeManager pelo Editor foi revertida ao conteúdo original, sem alteração de timestep configurada pela tarefa. Saves pessoais não foram usados/modificados.

Não foram executadas suítes extensas, backend, build, jornada completa, F5/reset/F8 ou regressão completa de persistência. Esses sistemas/hierarquias foram preservados, não certificados novamente.

## Condições das comparações e arquivos

As comparações usam o **novo baseline B9 desta tarefa**, não os GIFs antigos. Mesmos sprite scale/PPU, Game View 1100×509, velocidade física 3,5 u/s e crop 180×170, ampliado nearest 2×. Cada grupo usa um relógio comum de 80 ms em tempo real desde a primeira amostra, limitado ao intervalo capturado comum. Seleciona-se o último screenshot disponível em cada instante (zero-order hold), sem interpolar poses, normalizar fases ou desacelerar apenas um lado. Condições/timeScale estão nos rótulos e em [timelines](Marco06B10/previews/timelines.json).

Câmera/mundo/NPCs não são uma simulação determinística congelada: detalhes do fundo, smoothing inicial e vida/HUD podem variar entre sessões; o candidato recebeu dano ambiental durante uma permanência em Play antes de parte das capturas. Isso não foi recolorido/retocado. As comparações focam no corpo/arma, conservando escala/velocidade e tempos reais. A janela de captura sofre custo de ScreenCapture e não mede FPS normal do jogo. As imagens de fases no contact sheet escolhem uma amostra de cada fase, portanto **não representam comparação no mesmo instante**, ao contrário dos GIFs alinhados por tempo.

PNGs brutos foram arquivados localmente em `Temp/Marco06B10/Captures/{baseline,candidate}` após a montagem. Versionados GIFs, PNGs finais/impactos/pranchas e relatórios. O montador procura primeiro a pasta de validação, depois esse arquivo local. Metadados brutos mantêm tentativas/repetições; análises usam a última captura por nome. Os tempos derivados do clip têm método explícito no relatório separado. Não confundir prévia com teste de input/dano: os JSON de execução registram os testes reais.

## Reprodução

- Fonte: `Tools/ArtPipeline/iron_knight_b10.py` usa as fontes B9 versionadas e Aseprite local, recusando sobrescrever `B10/editable`. Não requer o ZIP e não deve ser reexecutado sobre edição manual.
- QA: `iron_knight_b10_verify.py` exporta em temporários e verifica RGBA/preservação; `iron_knight_b10_metrics.py` refaz métricas/relógios; `iron_knight_b10_previews.py` monta comparações dos screenshots reais.
- Unity: `run_script --file AgentScripts/IronKnight06B9.cs --entry IronKnight06B10.Import` atualiza somente B10. `ImportAndCreate` serve para primeira criação e recusa cena existente. `VerifyImport` reimporta B10 e verifica IDs, contrato, hierarquia e metadados B9.
- Inspeções: `InspectIronKnight06B10.Prepare` na cena limpa B9/B10 → editor_play → Setup → Movement/Footfalls/Attacks; candidato também Obstacles/Combat → FinalView → editor_stop → Cleanup. Todas as chamadas usam `--caller plugin --skill unity-pipeline`. Se interromper, liberar inputs e fazer Cleanup após parar Play.

**Estado final:** integração técnica e verificações pontuais aprovadas; contato evidente da caminhada leste e seleção temporal do Slash melhorados. Deriva residual dos pés, incerteza dos apoios norte, algumas mãos parcialmente ocultas e saltos discretos do Slash continuam limitações reais. Não se declara foot lock, anatomia perfeita nem aprovação artística definitiva. A cena B10 permanece candidata isolada para avaliação do usuário.

Ap�s a aprova��o da caminhada, o usu�rio abriu/retomou Play para avali�-la. A tentativa de reimportar apenas o status textual foi recusada pelo guard `Stop Play first` ([registro](Marco06B10/play-mode-import-guard.json)); nenhum asset foi modificado por essa tentativa. A sess�o interativa foi preservada. Depois que o usu�rio informou ter parado o Play, o status tamb�m foi importado com sucesso para os quatro clips walk do CharacterSet ([registro](Marco06B10/approval-metadata-import.json)). O diff do asset cont�m somente essas quatro altera��es de texto; dura��o, sprites, m�os e visual aprovado permanecem iguais.
