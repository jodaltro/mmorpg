# Humanoid States R8 — fonte e reprodução

Laboratório separado; aprovação artística de esquiva e morte **pendente**. Origem: humanoide e animações profissionais Quaternius CC0 já documentados em R5/R6, figurino R5 e fonte retarget R7. Nenhum arquivo original foi substituído. `ValdoriaStatesR8.blend` conserva meshes, materiais, texturas, armature e ações profissionais; as ações editáveis `R8_EvasiveStep` e `R8_Death01` têm fake user para sobreviver ao salvamento. Nenhuma geração externa de arte.

`spatial-audit.json` contém 944 amostras de todos os quadros Roll/Death01 nas oito vistas: bounds dos meshes deformados visíveis, extremidades anatômicas e deslocamento local da pelve. A transformação do rig permanece fixa. O movimento corporal da queda é conservado dentro do sprite; não é root motion físico.

`canvas-contract.json`: PPU Unity 32. Esquiva 128×160, pivô inferior (64,34). Morte 256×224, pivô inferior (128,66), padding (64,32,64,32). Densidade Blender 66,666667 pixels/metro da fonte. Com câmera ortográfica AUTO, usar `2.4 * max(width,height) / 160` (3,84 para morte). Usar apenas a altura produziria aumento involuntário de 14,2857%; essa tentativa intermediária foi recusada, antes da integração final.

Passo evasivo: oito poses do segmento Sprint_Loop 0..10, blend quaternion local com Idle por `0.75*sin(pi*t)`, oito durações de 0,0275 s. Preserva comprimentos dos ossos, sem comprimir o Roll completo. Morte: Death01 completo 0..72 a 30 fps, exportado em 25 poses 0,3,...72. Queda 2,4 s e cel terminal de 1/30 s, seguido de retenção indefinida em runtime.

Ferramentas em `Tools/ArtPipeline/`: `audit_humanoid_r8.py`, `audit_limbs_r8.py`, `verify_projection_r8.py`, `render_humanoid_r8.py`, `bake_humanoid_r8.py`, `verify_states_source_r8.py`, `export_humanoid_r8.py`. Consulte os argumentos nos scripts antes de executar. Eles usam Blender local e Aseprite local/Lua; recusam sobrescrever fontes finais. Renderizações e screenshots intermediários ficam em Temp, fora do Git. Não executar geradores sobre retoques manuais.

Pastas `dodge/` e `death/`: documentos Aseprite editáveis, sheets PNG RGBA, JSON e metadados de mãos/pivô/duração/alpha bounds. Exportação mantém a quantização/contorno aprovados de R6. `AgentScripts/BuildHumanoidStatesR8.cs` cria um novo CharacterSet e uma nova cena a partir de R7, recusando substituir existentes. A cena oficial continua MmorpgWorld.
