# Marco 06B.1 — expansão action explorável

Data: 14/10/2026. Unity 6000.6.5f1. Entrega para avaliação manual; esta inspeção rápida não é aprovação final de arte, balanceamento ou gameplay.

## Cena e execução

Cena principal: `Assets/Mmorpg/Scenes/Marco06B1World.unity`.
Abra a cena no Editor e pressione Play. Não exige login, Go, Supabase ou Jev. `ActionVerticalSlice.unity`, `Marco05World.unity` e `OfflineClearing.unity` continuam como pontos de recuperação.

| Controle | Ação |
|---|---|
| WASD / setas | Movimento físico em oito direções |
| Mouse + clique esquerdo / J | Mira e ataque básico |
| Clique direito | Golpe pesado com preparação |
| Espaço / Shift | Esquiva |
| E | Coletar, examinar ou conversar junto do alvo; fechar diálogo |
| Esc | Fechar diálogo; fora dele, pausar/continuar |
| I | Abrir/fechar inventário |
| Tab | Abrir/fechar diário |
| Q / F / C | Técnicas do 06A, com os desbloqueios existentes |
| R após morrer | Recarregar no ponto seguro da região persistida |

R não viaja quando o jogador está vivo. O reinício destrutivo por N da cena anterior está desabilitado nesta cena. F9 permanece ferramenta de técnicas isoladas exclusiva do Editor; não grava desbloqueios.

## Pronto e navegável

As cinco regiões ocupam uma cena contínua. Não há botão de viagem ou teletransporte de borda. Triggers apenas registram a região e seu ponto seguro; não reposicionam o jogador durante a exploração.

| Região | Identidade e conteúdo físico | Conexões |
|---|---|---|
| Valdoria | Centro protegido pela autoridade offline, casas, caminho central, NPCs, bancada da forja, recursos e boneco existente | Leste: floresta. Norte: minas |
| Floresta Cinzenta | Árvores sólidas, rastros existentes, ervas, nascente, musgo e lobo | Oeste: vila. Leste: ponte ao pântano |
| Minas de Kharum | Piso rochoso, túnel, formações sólidas, ferro/carvão/cobre/quartzo, NPCs e sentinela | Sul: vila. Leste: túnel a Asterion |
| Pântano dos Ecos | Vegetação tóxica sólida, lodo que reduz velocidade a 60%, ingredientes, NPC e aranha venenosa | Oeste: floresta. Norte: ruínas |
| Ruínas de Asterion | Pilares antigos, inscrições examináveis, fragmentos, Soren, altar do farol e criatura ancestral | Oeste: minas. Sul: pântano |

Pisos e limites sólidos usam Tilemaps; a arte provisória nova usa sprites de 16×16, filtro Point, sem mipmaps ou compressão. Sprites e construções anteriores foram reutilizados. Prefabs reutilizáveis: `Resource.prefab` e `MarshTerrain.prefab`, em `Assets/Mmorpg/Prefabs/Exploration`. Campos serializados definem identidade, quantidade e diálogo dos pontos.

## Criaturas realmente espaciais

Quatro criaturas, três comportamentos de combate reutilizados:

- **Lobo corrompido**, floresta: patrulha, detecção, perseguição, preparação, investida e recuperação do 06A. Sua derrota narrativa continua no JourneyEngine existente.
- **Aranha tóxica**, pântano: reposicionamento em tempo real, preparação e projétil físico com veneno temporário do 06A.
- **Sentinela de pedra**, minas: comportamento do golem, couraça, aproximação lenta e área de impacto preparada.
- **Guardião de pedra ancestral**, ruínas: variante visual/espacial do golem, com o mesmo impacto e couraça. Não implementa a proteção frontal específica do guardião do catálogo Go.

Todos usam ActorHealth, ActorMotor, Rigidbody2D, colisão e OfflineAuthority. Dano e cooldowns continuam validados localmente. Valdoria impede dano de combate entre jogador e hostis; o boneco de treino permanece utilizável. Não foram convertidos os nove arquétipos do catálogo, nem foi incluído combate por turnos.

Consequências de derrota: corpo deixa de bloquear e material físico aparece somente após `HitConfirmed` de ataque do jogador que tenha causado a morte. E próximo do material coleta a quantidade uma única vez por fonte no save.

## Recursos e inventário

Quinze fontes fixas e quatro fontes de criaturas; IDs canônicos do catálogo preservados:

| Região / fonte | IDs e quantidades |
|---|---|
| Valdoria | `gray-herb` ×2; `pure-water` ×2 |
| Floresta | `gray-herb` ×3; `ember-seed` ×2; `pure-water` ×2; `ancient-moss` ×2 |
| Minas | `iron-ore` ×3; `coal` ×2; `quartz` ×3; `copper-ore` ×2 |
| Pântano | `toxic-reed` ×3; `echo-lotus` ×2; `salt` ×2 |
| Ruínas | `historical-fragment` ×2; `asterion-glyph` ×1 |
| Lobo / aranha / sentinela / variante ancestral | `wolf-fang` ×2 / `spider-venom` ×3 / `stone-core` ×2 / `guardian-fragment` ×2 |

A amostra corrompida continua na investigação original, com suas condições e entrega a Mira. O inventário action existente mostra tanto essa evidência quanto a mochila de materiais; nenhum inventário online é importado. Coleta gera aviso de quantidade e o recurso esgotado fica apagado. Não existe recompensa administrativa. Madeira não foi adicionada porque não há esse ID no catálogo atual.

## NPCs e acontecimentos

Nove NPCs físicos: Mira e Orin preservados, mais Helena, Brann, Selka, Dorin, Tessa, Nera e Soren reutilizados do catálogo. Aproximação, alcance e linha de visão validam E; diálogo pode ser fechado para continuar andando. Mira/Orin mantêm memória, relações, opções de entrega contextual e consequências existentes. Os demais oferecem informação local determinística e registram contato no diário, sem novas quests ou habilidades. As inscrições e o local do farol também registram exame local.

O altar reserva espaço para `asterion-beacon`; não ativa outro motor de acontecimentos, nem produz um evento mundial online a partir do save offline. Comércio/fabricação/equipamento completo **não estão prontos**: Brann é o ponto físico da forja e informa essa limitação no diálogo. Não foram convertidos todos os NPCs ou oportunidades do Marco 05.

## Persistência offline

Arquivos próprios em `Application.persistentDataPath`:

- `marco06b1-journey.json`: adaptador/checksum/fila existentes, fatos da investigação, acontecimentos existentes e técnicas desbloqueadas.
- `marco06b1-exploration.json`: região, ponto seguro regional, IDs/quantidades da mochila, fontes esgotadas e contatos/exames/visitas do diário. Escrita temporária com substituição e `.bak`; arquivo incompatível bloqueia gravação para evitar sobrescrevê-lo.

Na recarga, a região é preservada e o jogador nasce no ponto de entrada seguro definido pela autoria; não se restaura uma coordenada arbitrária possivelmente dentro de obstáculo. Durante a caminhada, retorno é contínuo e conserva posição real e estado local. Vida e cooldowns são transitórios.

Política simples: criaturas comuns reaparecem ao recarregar a cena, e permanecem derrotadas ao apenas caminhar entre regiões. O lobo narrativo mantém a derrota registrada. Recursos e materiais de cada criatura são únicos por fonte nesse save, mesmo quando uma criatura comum reaparece: não há farming ilimitado ou duplicação. Não há temporizador de respawn neste ciclo.

Saves anteriores não são carregados/importados. Todos os Plays desta validação usaram `Temp/Marco06B1/<identificador>/`, com adaptadores e dispositivos de inspeção restaurados ao terminar. A sessão do usuário que já estava aberta no início foi encerrada normalmente; nenhum save pessoal foi editado, apagado ou substituído pelas inspeções.

## Validação executada

Sem suites EditMode/PlayMode, testes Go/SQL, simulações extensas ou chamadas pagas. Testes existentes foram mantidos.

1. Compilação pelo Editor conectado, com autotick e consulta a `recompile_status`: sem erros.
2. Movimento observado no Rigidbody2D com teclado sintético, sem atribuição de posição durante o percurso.
3. Coleta física em Valdoria, segunda pressão de E sem duplicar e abertura do inventário.
4. Diálogo com NPC e fechamento; frames avançando.
5. Combate action do lobo, derrota confirmada e coleta de duas presas.
6. Percurso físico Valdoria → floresta → Valdoria → minas → ruínas → pântano → floresta → Valdoria; ferro coletado nas minas. Vida 85 ao concluir.
7. Recarga do save temporário: duas ervas, duas presas, três minérios, derrota narrativa e ponto seguro preservados. Nova travessia vila/floresta/retorno confirmada.
8. Cena configurada com decisões determinísticas e sem sessão online. Nenhum serviço externo é necessário ao percurso; nenhum serviço do usuário foi encerrado para produzir esse resultado.
9. Capturas do mundo e do inventário inspecionadas; debug herdado oculto. Console final verificada por cursor da sessão e contagem atual.

Evidências: `m06b1-compile-final.json`, `m06b1-village-final.json`, `m06b1-combat-final.json`, `m06b1-mines-ruins-final.json`, `m06b1-swamp-return.json`, `m06b1-reload-final.json`, `m06b1-console-final.json`, `m06b1-console-status.json`, `m06b1-world.png` e `m06b1-inventory-delivery.png`.

As primeiras inspeções revelaram acesso ruim a um drop e uma rocha invadindo o corredor das minas. O drop passou a aparecer no centro livre onde o inimigo morreu, e a rocha foi movida; os trechos seguintes concluíram. Relatórios iniciais foram conservados. Uma recompilação inadvertida durante Play também gerou referências temporariamente nulas no código existente; a sessão foi reiniciada e a validação final foi feita após compilar fora de Play. Esse histórico está em `m06b1-live-recompile-errors.json`; não é apresentado como execução limpa.

## Limitações e planejado

- Arte provisória, animações e balanceamento ainda dependem de avaliação manual.
- Três comportamentos de IA; sem navegação global em labirintos e sem os seis arquétipos restantes. A aranha/sentinela/variante ancestral estão integradas, mas não tiveram novos combates completos nesta inspeção rápida.
- Diálogos locais dos NPCs adicionados são informativos; comércio, receitas, novas quests e demais técnicas ficam planejados.
- O farol é um local investigável reservado; sua ativação compartilhada continua na infraestrutura experimental anterior.
- Dois arquivos locais independentes, sem transação conjunta. Encerramento abrupto pode perder o checkpoint mais recente da fila narrativa; o backup da expansão não possui restauração automática.
- Coleta de ingredientes/glifo deste recorte é simples por proximidade; não replica os requisitos de equipamentos/técnicas dos encontros abstratos do Marco 05.
- Sem sincronização de loot, hits ou derrota offline como fatos online confiáveis. Go/Supabase/Jev e migrações foram preservados.
- Nenhuma build standalone nova ou suite completa foi executada neste ciclo. Nenhum commit foi feito.

## Ferramentas

Autoria repetível: `AgentScripts/BuildExplorationWorld.cs`, entrada `BuildExplorationWorld.Build`; recusa cena/arte de destino existentes e cenas sujas. Ajustes incrementais da cena nova: `FinishExplorationWorld.Run`. A geração não deve ser executada novamente sobre a entrega existente.

Exemplo de comando de autoria para um destino ainda ausente:

```powershell
unity command run_script --file AgentScripts/BuildExplorationWorld.cs --entry BuildExplorationWorld.Build --caller plugin --skill unity-pipeline
```

Inspeção curta reproduzível: `InspectExplorationPlay.Prepare` fora de Play, `editor_play`, `Setup`, `Village`, `ForestCombat`, `MinesAndRuins`, `SwampReturn`; depois `editor_stop` e `Cleanup`. Todas as invocações passam `--caller plugin --skill unity-pipeline`. Não é uma suite nem deve rodar com saves pessoais. O Editor termina fora de Play, com a cena nova aberta para o usuário.
