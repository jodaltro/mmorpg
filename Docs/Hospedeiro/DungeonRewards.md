# Masmorras e recompensas — 25/10/2026

O fluxo no cliente é **ver expedição → entrar e preparar → iniciar combate → vencer → escolher um gene**. A entrada e o atlas abrem a prévia sem iniciar combate. Ela explica o objetivo, a dificuldade, as opções de gene, os recursos garantidos e a conquista única de primeira conclusão, quando ainda disponível. Os cartões explicam a mudança funcional e indicam Corpo → Genes para expressar a recompensa conquistada.

Depois da preparação assíncrona do modificador, o jogador chega a uma sala segura com a prévia preservada, o modificador e a quantidade efetiva de salas. O botão Iniciar combate é uma intenção separada. O servidor Godot mantém essa preparação em uma instância física privada; ataques e habilidades ficam bloqueados, inclusive antes de pagar seus custos. Os botões principais ficam fora da rolagem para permanecer acessíveis no celular.

## Geração procedural

Cada definição JSON declara `rewardPools`. O primeiro conjunto reserva uma opção de transformação de classe quando elegível; o seguinte fornece as opções temáticas. A seleção limita o total a três genes distintos, elegíveis e ausentes tanto da biblioteca quanto dos genes expressos. Se houver menos opções novas, oferece menos; se não houver nenhuma, explica o esgotamento sem prometer um gene novo.

O sorteio é determinístico por jogador, masmorra e ciclo de vitórias. Esperar, reconectar, abandonar ou perder não troca os prêmios. Só uma vitória avança o ciclo. A seleção fica gravada no Delve, e um token permite recusar a confirmação de uma prévia desatualizada. O cliente apenas apresenta as opções fornecidas pelo motor.

Após vencer, o jogador escolhe exatamente um dos genes oferecidos. O motor valida autoria, conclusão, pertinência e ausência de resgate anterior. O gene entra na biblioteca sem substituir a build automaticamente. Se todos os genes daquela seleção forem conquistados por outra via durante a expedição, o painel informa a situação e permite concluir sem duplicá-los. Recursos são entregues na vitória, sem depender da escolha.

## Contrato e manutenção

As extensões são aditivas em v1: `preview`, `rewardDetails`, estado `ready`, intenções `iniciar-masmorra` e `resgatar-masmorra`. O cliente solicita o novo fluxo com `briefing: yes` na entrada. Entradas antigas preservam início e entrega automáticos (primeiro gene da seleção), evitando bloquear clientes sem a interface de resgate. Universos sem conjuntos de recompensa preservam suas regras e não passam a gravar ciclos de sorteio.

`tools/tune_rewards.py` mantém os cinco conjuntos e as explicações dos recursos no universo. O motor deriva os detalhes de missões dos efeitos configurados: não inventa benefícios a partir de frases promocionais. Alterações do universo exigem a mesma ativação explícita descrita em Progression.md; esta implementação não reinicia o mundo salvo.
