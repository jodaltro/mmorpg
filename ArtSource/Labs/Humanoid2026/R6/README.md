# R6 — oito direções validadas; combate retido como estudo

Entrega parcial explícita. O jogador da cena `HumanoidCombat8Dir2026.unity` usa `Valdoria8Dir.asset`, com 104 sprites de locomoção. R5/cardinais aprovados intactos. Novas diagonais aguardam aprovação artística. Sem promoção oficial.

## Arquivos

- `ValdoriaSwordsman8Dir.blend`: cópia do .blend R5, mesmo corpo, roupa, rig, materiais e pesos. Texturas relativas apontam para R5 e fontes originais versionadas. Não é um personagem reconstruído.
- `views.json`: índices Unity e ângulos de câmera observados; os rótulos agora expressam a orientação no jogo.
- `Locomotion/Locomotion8Dir.aseprite`: 104 quadros e 16 tags; cels cardinais copiados do R5 e 52 quadros diagonais renderizados de verdade. Mesmas 5 camadas; referência e guias cardinais preservadas, metadados diagonais no sidecar.
- `Locomotion`: atlas, manifesto, mãos/juntas/pés, pranchas, comparação R5/R6 e GIFs. Não há PNG girado nem espelhamento.
- `animation-audit.json`: presença e duração reais de oito ações profissionais da biblioteca local. `combat-source-audit.json`: trajetória amostrada da pelve/mão das seis ações estudadas.
- `CombatCandidate`: 160 quadros / 32 clips de preparação/corte/recuperação/Hurt nas oito vistas. São estudos, sem aprovação e sem gate de gameplay. Pesado reaproveita os desenhos do básico, com relógio físico próprio; não é uma segunda animação profissional distinta.

A arma continua separada. O candidato mede a palma por hand_r + 45% do eixo até a ponta do osso, projeta no canvas, calcula hand/holdAngle e depth. Não copia âncoras antigas. O encaixe matemático ocorreu, mas o ataque na fixture de alvo próximo produziu zero acertos e zero dano em vez de 1/20: a mesma âncora alimenta o Sweep físico existente. O candidato foi retirado da cena principal. Nunca tratar igualdade matemática de âncora como integração de combate aprovada.

Roll e Death01 foram rejeitados no canvas atual: os probes in-place continuam cortando membros nas bordas. Rolamento de 1,467 s exigiria aceleração de 6,67× para a esquiva de 0,22 s, sem avaliação artística satisfatória. Não foram incorporados como Dodge/Death nem ocultados como clips concluídos.

## Produção local e reprodução

Blender 5.2.2, Aseprite 1.3.18.6, Python/Pillow para orquestração/medição/pranchas. Sem download novo, IA generativa ou compra. Licenças CC0 e proveniência são as mesmas do R5 e Sources anteriores.

`render_humanoid_r6.py --output <novo-diretorio>` (via Blender) abre R5 e renderiza só diagonais. `export_humanoid_r6.py --renders <diretorio>` monta o Aseprite/atlas, recusando Locomotion existente. Esses destinos são referências agora versionadas: para outra revisão, parametrizar novos destinos ou trabalhar em outro laboratório, sem apagar R5/R6.

`audit_humanoid_combat_r6.py` produz probes e dados em Temp/HumanoidR6/CombatAudit, recusando destino existente. `render_humanoid_combat_r6.py --output <novo-diretorio>` produz somente ataque/Hurt candidatos; `--quick` mostra probes in-place de Roll/Death. `export_humanoid_combat_r6.py` exporta o candidato para uma pasta nova; `review_humanoid_r6.py` monta evidências de capturas reais. Renders intermediários e screenshots brutos de estudo permanecem em Temp.

Autoria Unity: `FreezeHumanoidCombat8Dir2026.Record`, `BuildHumanoidCombat8Dir2026.Create`, `InspectHumanoidCombat8Dir2026.Prepare`, Play, Setup B11, Inspect, Stop/Cleanup B11 e Verify. Create recusa cena/atlas existentes. IntegrateCombatCandidate é ferramenta de estudo de primeira criação; o asset resultante não passou no gate e não está ativo. KeepValidatedLocomotion retorna a cena à referência válida. Todos os comandos usam `--caller plugin --skill unity-pipeline`.

Relatório: `Docs/Validation/HumanoidCombat8Dir2026.md`. Não usar os resultados de estudo como prova de combate completo.
