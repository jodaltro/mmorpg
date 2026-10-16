# R7 â€” separaÃ§Ã£o fÃ­sica/visual da espada

Fontes profissionais CC0, corpo/roupa e 264 sprites reutilizados por referÃªncia imutÃ¡vel do R6, sem redesenho. ProveniÃªncia original em R5/R6; hashes em reused-sources.json. CharacterSet R7 separado em Assets/Mmorpg/Art/Experimental/HumanoidSwordR7.

O perfil fÃ­sico/visual registra a calibraÃ§Ã£o zero e o contrato preservado. SwordSwing mantÃ©m LegacyGrip como padrÃ£o; sÃ³ a cena R7 opta por PlanarSweepOrigin. Metadados de mÃ£o, holdAngle, depth e timings copiados do candidato R6; nenhuma coordenada de osso alimenta a colisÃ£o planar. Scripts repetÃ­veis em AgentScripts/BuildHumanoidSwordR7.cs e InspectHumanoidSwordR7.cs; evidÃªncias e auditorias em Docs/Validation/HumanoidSwordR7. Roll/Death ficam para R8. AprovaÃ§Ã£o artÃ­stica dos novos ataques/diagonais pendente.

## Arco e dedos â€” extensÃ£o posterior

O usuÃ¡rio pediu testar outra arma. Animated Longbow (djonvincent, CC0) estÃ¡ em Sources/Bow, original preservado com hash/licenÃ§a. `BowGripStudyV3.blend` Ã© o estudo derivado: pegada esquerda no centro real da mÃ£o, pinÃ§a direita, IK sem esticar ossos. A corda dirige a mÃ£o atÃ© a soltura; depois a mÃ£o se desacopla e retorna com SmoothStep, sem acompanhar o rebote da corda. 37 quadros fonte, 24 fps, duas vistas; composiÃ§Ã£o diagnÃ³stica no Aseprite em BowDrawStudy. NÃ£o Ã© equipamento runtime definitivo nem combate de projÃ©teis. A versÃ£o anterior foi rejeitada pelo usuÃ¡rio; nÃ£o Ã© referÃªncia artÃ­stica aprovada.

V4: perfil `bow-anatomical-profile-v4.json`, fonte `BowGripStudyV4.blend`, diagnÃ³stico Aseprite `BowAnatomyStudy/`. O usuÃ¡rio rejeitou V3 por interseÃ§Ã£o com cabeÃ§a e dobra do cotovelo. V4 verifica a superfÃ­cie da cabeÃ§a/luva real, reduz a profundidade da deformaÃ§Ã£o da corda e muda o polo do cotovelo sem esticar braÃ§os. Prancha V4 considerada melhor; sequÃªncia final ainda em revisÃ£o. Ver Docs/Validation/BowAnatomyR7.md.
