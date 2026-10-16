# Armas procedurais e validação no jogo

## O que existe neste checkpoint

O jogador da cena experimental `Assets/Mmorpg/Scenes/HumanoidSwordR7.unity` pode abrir **Esc → Validar armas** e escolher **Espada**, **Arco frontal** ou **Arco lateral**. A seleção não é um item de inventário, desbloqueio ou alteração do perfil; vale somente durante a sessão. F5 retorna à espada. A entrada oficial do jogo permanece `MmorpgWorld.unity`.

| Opção | Controles e comportamento |
|---|---|
| Espada | Continuar e testar; WASD para andar, clique/J para básico e botão direito para pesado. Combate e autoridade existentes. |
| Arco frontal/lateral | Continuar e testar; clique/J reproduz puxada/soltura/retorno; V muda a vista; Esc permite escolher outra arma. |
| Prévia do arco | Teste estacionário da pose aprovada; sem locomoção de arqueiro, flecha, projétil ou dano à distância. |

Esc pausa também a sequência do arco. A câmera usa um alvo temporário mais alto para enquadrar a arma inteira; retorna ao alvo original com a espada. Durante o estudo estacionário, entrada de combate/movimento e HUD de ações ficam suspensos e são restaurados ao sair. O menu de sessão continua disponível. Um golpe/esquiva em andamento impede entrar na prévia do arco; dano recebido encerra a prévia e devolve a apresentação normal. A seleção não altera vida, cooldowns, colisores, alcance ou saves.

## Capacidade procedural demonstrada

1. **Arma dirige as mãos:** o transform da arma fornece o alvo; os braços resolvem IK de dois ossos sem alongamento. Alvos inalcançáveis são rejeitados. Não há dependência circular mão→arma→mão.
2. **Socket da mão real:** centro do conjunto de dedos para empunhadura cilíndrica; pinça entre polegar/indicador para corda. A referência arbitrária a uma fração do osso da mão foi insuficiente e substituída no estudo do arco.
3. **Contato dos dedos:** CCD local adapta os dedos ao cilindro/raio do cabo ou à pinça. Comprimentos preservados. O método parte da mão profissional existente; não comprova qualquer anatomia ou empunhadura universal.
4. **Arco deformado:** os alvos vêm da malha avaliada no mesmo quadro. A mão direita acompanha a corda até o máximo de puxada, quadro 30; depois abre e retorna independente do rebote. A esquerda mantém a empunhadura.
5. **Adaptação anatômica V4:** perfil explícito ajusta posição/plano do arco, profundidade da deformação e polos dos cotovelos. A translação da animação da corda usa 72% da original neste corpo, sem reduzir o tamanho do arco ou esticar braços.
6. **Rejeição de poses inválidas:** amostragem da luva contra a superfície da cabeça, limite de flexão e continuidade do cotovelo. O teste é localizado, para este corpo; não é colisão universal de todo o personagem/equipamento.
7. **Fontes editáveis:** Blender com ossos e animação; Aseprite com camadas, tags e timings; atlases Unity Point/32 PPU, 128×160 e pivô (64,34). Fontes e atlas V3 rejeitados preservados como histórico.

## Aprovação e cobertura

O usuário aprovou a correção V4 após ver prancha, animação e captura na Unity: **“ficou bom”**. Isso cobre a puxada, mão e braço/cotovelo nas vistas frontal/lateral mostradas. Registro com hashes em `Docs/Validation/HumanoidSwordR7/bow-v4-artistic-approval.json`.

O estudo de espada demonstra dois perfis e três poses em duas vistas, com lâmina separada e integração de acerto. O arco demonstra 37 quadros por vista, com fonte de arma separada no Blender e **composição diagnóstica de corpo+arma nos sprites** para preservar a oclusão. Essa composição permite revisar a pose no mundo; não é a arquitetura definitiva de equipamento trocável em oito direções. Locomoção de arco, outras vistas, arco separado em camadas runtime, projéteis e combate à distância continuam pendentes.

## Fontes e ferramentas

- Humanoide/roupa: referência profissional CC0 e proveniência em `ArtSource/Labs/Humanoid2026/R5` e `R6`, preservadas.
- Arco: Animated Longbow, djonvincent, CC0; original, licença e hash em `ArtSource/Labs/Humanoid2026/R7/Sources/Bow/`.
- Referência atual: `BowGripStudyV4.blend`, `bow-anatomical-profile-v4.json`, `BowAnatomyStudy/BowDraw.aseprite` no R7.
- Autoria: `procedural_grip_r7.py`, `procedural_hand_contact_r7.py`, `procedural_bow_grip_r7.py`; QA: `bow_pose_constraints_r7.py`, `verify_bow_anatomy_r7.py`; acabamento local: `export_bow_draw_r7.py --revision v4`.
- Importação: `BuildBowDrawStudyR7.CreateAnatomical`; menu: `BuildWeaponValidationMenuR7.Create`. Ambos recusam sobrescrever o trabalho existente.
- Runtime: `WeaponValidationPreview`, `WeaponValidationMenu`; extensão opcional de `SessionMenuView`, configurada somente no R7.

Relatórios: `Docs/Validation/BowAnatomyR7.md`, `WeaponValidationMenuR7.md` e `HumanoidSwordR7.md`. Não há dependência de geração externa, serviço pago ou backend para o menu/prévia.
