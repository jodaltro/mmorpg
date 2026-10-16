# Humanoide R7 — Sweep, empunhadura procedural e estudo de arco

Cena experimental: `Assets/Mmorpg/Scenes/HumanoidSwordR7.unity`. Entrada oficial permanece `MmorpgWorld.unity`. R7 reaproveita os 264 sprites do candidato R6, incluindo os 104 de locomoção; não promove o humanoide à produção. Fontes aprovadas R5/R6 preservadas.

## Diagnóstico e correção física

1. **Causa:** o candidato alto convertia a luva projetada em origem física. No caso reproduzido, raiz (-2,75; 0), mão aproximadamente (-4,3; 2,4), alvo (-1,9; 0). Nenhuma cápsula alcançou o collider: 0 dano. Não era apenas um deslocamento vertical.
2. **Separação:** `SwordSwing.SweepOriginPolicy.PlanarSweepOrigin` usa Rigidbody2D.position, offset zero; a apresentação continua seguindo ProductionFrame.hand. Os dois extremos temporais da amostragem usam a mesma política.
3. **Legado:** valor padrão `LegacyGrip`; somente a cena R7 opta pela raiz. Caminho físico anterior mantido para o protagonista oficial.
4. **Coordenadas:** mão pertence à projeção visual, raiz ao plano do mundo. Não há correções direcionais arbitrárias na autoridade. Ver `physical-visual-profile.json` e traces reais.
5. **Gate próximo:** mesmas posições, agora 20 de dano, um HitConfirmed. `near-gate.json`.
6. **Pesado:** 36, alcance autorizado 1,65; básico 20/1,25. Comprimentos amostrados 1,4/1,0, padding total 0,16, arco 110°. Sem aumento de alcance para compensar desenho.
7. **Paredes:** bloqueiam nos oito setores; controle sem parede nas mesmas posições confirma acerto. Fixture corrigida para não interpenetrar o alvo.
8. **Fora de alcance:** nenhum dano nos oito setores, inclusive teste próprio do pesado.
9. **Duplicatas:** um evento por alvo; cooldown, facção, alvo morto, esquiva e cancelamento por morte continuam respeitados.
10. **Oito direções:** 14 cenários × oito setores = 112 casos aprovados; inclui mira contínua deslocada 13° e movimento oposto. `combat-summary.json` e `matrix-*.json`.
11. **Contato visual da espada:** erro renderizado mão/pivô zero nas 32 capturas de sequência; comprimento visual constante ~1,02149. Instantes antes de LateUpdate são identificados separadamente.
12. **Corpo/corte:** preparação, corte e recuperação observados em básico/pesado nos oito setores, além de Hurt em oito vistas. F7 usa SweepSampled verdadeiro; não reconstrói uma hitbox ilustrativa.
13. **Separação visual/física:** ainda grande (~2,89 unidades no exemplo F7), consequência da projeção alta sobre o plano. Gate físico passou; isso não constitui aprovação artística da correspondência espacial. Espada maior está apenas em prancha comparativa, sem alterar alcance ou asset.
14. **Oficial:** Regression, Combat, DodgeStates, DeathStates e RestartSession B11 executados; near/heavy/wall/outside, morte e reinício passaram. Cápsulas reais em `legacy-official/actual-sweep.jsonl`.
15. **R5/R6:** quatro caminhadas R5 e regressão R6 de oito direções, colisões, NPCs/árvore, câmera/HUD e F5 passaram. Comparação de pixels preserva os 52 cardinais aprovados.
16. **Console:** estado corrente final do gate de combate: zero erros/avisos. Histórico do conector contém três erros anteriores e um erro desta execução ao tentar salvar EditorBuildSettings com API inadequada; corrigido usando SetDirty + Save Project. Não confundir histórico com console corrente.
17. **Persistência:** 492 arquivos congelados e cinco saves pessoais conferidos por hash; perfil de QA isolado em Temp, dispositivos artificiais e override removidos ao terminar. Ver `preservation.json`.
18. **Pendências:** aprovação artística das diagonais/combate, correspondência espacial lâmina/plano, animação completa procedural para cada arma e promoção oficial. Roll/Death continuam fora do R7. Nenhuma progressão ou missão nova.

## Extensão solicitada: mãos dirigidas pela arma

`procedural_grip_r7.py` implementa IK analítica de dois ossos com comprimentos fixos; alvos inalcançáveis são rejeitados. Fonte editável `ProceduralGripStudy.blend`, dois perfis, duas vistas, três poses por vista: estudo de 12 poses, não animação completa. Quatro casos na Unity confirmaram os sprites novos, contato e acerto de 20. O estudo inicial ainda usava curvatura simples dos dedos.

Após a crítica de que o arco parecia colado, `procedural_hand_contact_r7.py` passou a derivar o socket do centro real dos dedos, em vez de uma fração arbitrária do osso da mão. CCD ajusta dedos sobre cilindro e pinça polegar/indicador na corda. Braços mantêm comprimento; não há escala para alcançar a arma. Isso melhora a pegada, mas não prova capacidade artística universal para qualquer arma.

O usuário relatou que a empunhadura pareceu funcionar e que a puxada estava bugada. A revisão V3 preserva essa pegada, orienta o plano de tiro para o ombro direito e usa polos anatômicos separados para os cotovelos. A posição da pinça vem dos vértices centrais da corda já deformada em cada quadro; não há um relógio independente para a mão.

Arco: **Animated Longbow**, djonvincent, [OpenGameArt](https://opengameart.org/content/animated-longbow), CC0. Original intacto em `ArtSource/Labs/Humanoid2026/R7/Sources/Bow/`, licença e hash juntos. Estudo derivado separado. Fonte possui 37 quadros a 24 fps; a revisão avalia todos em Sul/Leste. Corpo inferior é idle congelado: não é animação corporal completa de arqueiro, sistema de projéteis ou combate à distância.

A prévia V3 usa composição 3D para preservar a oclusão dos dedos sobre madeira/corda; sprites compostos são exclusivos do diagnóstico. A versão de equipamento em runtime ainda exige camadas frente/trás por quadro antes de integração definitiva. Corpo e arma separados também são renderizados para inspeção. Não substituir a espada do jogador por essa composição como implementação oficial.

Scripts de autoria recusam sobrescrita; PNGs finais passam pelo Aseprite local. As primeiras versões rejeitadas não são referência aprovada. Revisão artística da nova puxada permanece com o usuário.

## Evidências e reprodução

Scripts em `AgentScripts/*Humanoid*R7.cs`; análise em `Tools/ArtPipeline/{review_humanoid_r7,verify_humanoid_sword_r7,measure_humanoid_sword_r7}.py`. Dados em `Docs/Validation/HumanoidSwordR7/`. Fontes em `ArtSource/Labs/Humanoid2026/R7/`.

Prévia: `previews/bow-draw-v3.gif`; geometria/cápsulas: `previews/f7-actual-sweep.png`; combate: `previews/basic-eight-unity.gif`, `heavy-eight-unity.gif`. Aprovação técnica e artística são registros distintos.

### Correção da soltura

A trajetória original foi inspecionada quadro a quadro: o máximo de puxada é o quadro 30; os quadros 31–37 contêm retorno e rebote da corda. A mão acompanha a corda somente até 30. Após isso, o alvo da mão faz retorno suave independente e a pinça abre; manter contato durante o rebote era o erro principal da soltura. A validação geométrica distingue contato obrigatório antes da soltura de separação intencional depois dela. Não se exige erro mão/corda zero nessa segunda fase.

### Resultado da revisão V3 e prova na Unity

74 poses (37 Sul + 37 Leste) geradas e acabadas no Aseprite. Erro máximo do socket do braço: 0,00000025 m; dedos: 0,000418 m; variação máxima de comprimento dos dedos: 0,000000081 m. A corda avança até 0,2553 m entre quadros no rebote; o retorno da mão é separado, com passo máximo 0,1059 m. Antes da soltura há contato obrigatório; após ela há separação intencional. Esses números medem geometria, não aprovação artística.

`InspectBowDrawStudyR7.Inspect` exibiu as 74 poses no jogador real, em Play, com captura após WaitForEndOfFrame e frames avançando; restaura corpo, espada e posição ao terminar. Capturas podem prolongar a exposição de um quadro; a prévia fonte usa 24 fps. Console corrente: zero erros/avisos. `bow-draw-unity.json`, `bow-draw-v3.json` e `console-bow-final-play.json` registram a execução. `previews/bow-draw-unity.png` mostra o arco no mundo; `bow-draw-unity-keyframes.gif` é amostragem de seis poses por vista, não gravação contínua. `bow-draw-v3.gif` contém a sequência inteira. A fonte Blender preserva os 37 quadros dos braços editáveis, além da animação original do arco, no mesmo relógio.
