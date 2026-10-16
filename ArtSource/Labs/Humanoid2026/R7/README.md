# R7 — separação física/visual da espada

Fontes profissionais CC0, corpo/roupa e 264 sprites reutilizados por referência imutável do R6, sem redesenho. Proveniência original em R5/R6; hashes em reused-sources.json. CharacterSet R7 separado em Assets/Mmorpg/Art/Experimental/HumanoidSwordR7.

O perfil físico/visual registra a calibração zero e o contrato preservado. SwordSwing mantém LegacyGrip como padrão; só a cena R7 opta por PlanarSweepOrigin. Metadados de mão, holdAngle, depth e timings copiados do candidato R6; nenhuma coordenada de osso alimenta a colisão planar. Scripts repetíveis em AgentScripts/BuildHumanoidSwordR7.cs e InspectHumanoidSwordR7.cs; evidências e auditorias em Docs/Validation/HumanoidSwordR7. Roll/Death ficam para R8. Aprovação artística dos novos ataques/diagonais pendente.

## Arco e dedos — extensão posterior

O usuário pediu testar outra arma. Animated Longbow (djonvincent, CC0) está em Sources/Bow, original preservado com hash/licença. `BowGripStudyV3.blend` é o estudo derivado: pegada esquerda no centro real da mão, pinça direita, IK sem esticar ossos. A corda dirige a mão até a soltura; depois a mão se desacopla e retorna com SmoothStep, sem acompanhar o rebote da corda. 37 quadros fonte, 24 fps, duas vistas; composição diagnóstica no Aseprite em BowDrawStudy. Não é equipamento runtime definitivo nem combate de projéteis. A versão anterior foi rejeitada pelo usuário; não é referência artística aprovada.
