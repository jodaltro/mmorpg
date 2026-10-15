# Boneco de treinamento

O boneco foi acrescentado à `OfflineClearing` existente em **(-4, -2)**, ao sudoeste do ponto inicial, perto de Mira. Abra a cena e Play normalmente, continuando seu save. Não é preciso iniciar nova jornada nem recriar um lobo.

Com Leitura de Fraquezas já aprendida: aproxime-se do boneco, pressione **Q**, veja a marca amarela e ataque voltado para ele com **J ou clique**. O próximo acerto causa **30** com os parâmetros padrão (20 normal + 10 de bônus); os seguintes causam 20. O texto junto ao boneco mostra vida e último dano. Alcance da técnica: 3; alcance do ataque: 1,25; marca: 5 s; cooldown: 8 s.

O boneco tem 100 de vida, fica parado e não ataca. Recupera-se automaticamente **2 s após o último dano**, inclusive depois de ser derrotado. Pode ser usado indefinidamente. Ele não fornece amostras, fatos de derrota de criaturas, oportunidades ou desbloqueios. A técnica continua exigindo uma descoberta válida na história; criar o boneco não altera o save nem concede a habilidade.

Q escolhe o alvo vivo, visível e dentro do alcance mais próximo, entre lobo e boneco. A identidade da marca distingue os alvos; marcar o boneco não bonifica um ataque no lobo. Paredes, cooldowns, vida, orientação e alcance continuam validados pela autoridade.

Criados: `Assets/Mmorpg/Runtime/TrainingDummy.cs`, `AgentScripts/AddTrainingDummy.cs`, este documento e metadados Unity. Alterados: `Runtime/ActorHealth.cs` (facção de treinamento e recuperação restrita), `Runtime/JourneySession.cs` (seleção do alvo e marca do boneco), `Tests/PlayMode/JourneySceneTests.cs` (integração real do boneco), `Scenes/OfflineClearing.unity` e `Docs/EventSystem.md`.

A autoria via Pipeline exige a cena existente limpa, recusa Play e não duplica o boneco em reexecução. O boneco usa o sistema existente Rigidbody2D/BoxCollider2D, com corpo estático. Referência consultada: [RigidbodyType2D.Static — Unity 6000.6](https://docs.unity3d.com/6000.6/Documentation/ScriptReference/RigidbodyType2D.Static.html).

Evidências desta alteração ficam em `Docs/Validation/training-*`. O teste adicional aprende a técnica pelo caminho real de Orin, derrota o lobo, marca e ataca o boneco, verifica dano 30 seguido de 20, derrota e recuperação automática e ausência de novos fatos/recompensas. Os testes usam persistência em memória isolada, preservando o save do jogador.

Validação em 13/10/2026 pelo Editor conectado: compilação concluída sem erros; **19/19 EditMode e 13/13 PlayMode passaram** (incluindo os 31 testes anteriores). A primeira execução detectou leitura de vida antes do Awake de ActorHealth; a inicialização foi corrigida e a suite PlayMode inteira reexecutada. Evidências: [compilação](Validation/training-compile.json), [EditMode](Validation/training-editmode.json), [PlayMode](Validation/training-playmode.json).

Também foi executado Q e ataque real no boneco usando a técnica já aprendida no save existente: `marked=True`, vida 70 e último dano 30. A leitura posterior confirmou vida 100 e frames avançando; o console ficou sem erros. Evidências: [acerto no Editor](Validation/training-runtime-hit.json), [recuperação e frames](Validation/training-runtime-recovered.json), [console](Validation/training-console.json). O ensaio só atacou o boneco e não alterou fatos ou save. Editor deixado fora de Play; sem commit.
