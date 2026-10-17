# Contato procedural da espada e esquiva revisada

Quaternius CC0 e figurino R5/R6 existentes. A espada é a mesma arte separada B3/R7; não houve novo asset externo nem redesenho da arma. Morte e Hurt aprovados não pertencem a este atlas e continuam reutilizados do conjunto anterior.

`SwordContact.aseprite`: 272 poses de corpo finalizadas no Aseprite local. `Fingers.aseprite`/`fingers.png`: pixels exatos do corpo dentro dos polígonos da luva à frente do cabo, em sheet com a mesma grade e pivôs. `manifest.json` associa sprite, estado, vista, mão/palma, orientação, profundidade, duração, bounds e métricas. `qa.json` guarda gates geométricos/exportação. Fonte editável `../SwordContactR8.blend`, com 48 ações novas retidas por fake user e texturas relativas.

Reprodução em novos caminhos (recusa sobrescrever documentos existentes):

1. Blender local: `--background --python Tools/ArtPipeline/refine_sword_dodge_r8.py -- --output <pasta-nova>`; acrescentar `--quick` apenas para estudo frontal/lateral, ou `--no-render` para auditoria geométrica.
2. `python Tools/ArtPipeline/export_sword_feedback_r8.py --renders <pasta-render> --output <pasta-fonte-nova>` usa Aseprite CLI/Lua e exporta corpo + contato.
3. Blender: `--background --python Tools/ArtPipeline/verify_sword_source_r8.py -- --renders <pasta-render> --source <novo.blend> --report <novo.json>` reabre e verifica o bake e retemporiza as ações editáveis conforme o manifesto.
4. Na Unity conectada, importar com `BuildBowDrawStudyR7.CreateSwordContactR8`, depois `BuildSwordContactR8.Create` sobre a cena R8 limpa e parada. Os destinos publicados são fixos e devem estar livres; para uma nova revisão, preparar outros destinos explicitamente. Não reexecutar sobre retoques manuais.

Os solvers são os mesmos módulos do arco V4, com perfil de contato cilíndrico da espada. A posição da arma é limitada ao alcance anatômico antes do IK; dedos/polegar usam CCD. O eixo visual das fases é amostrado no plano da câmera, mantendo o relógio/Sweep do combate. É autoria procedural de sprites com anatomia e contato mensuráveis, não IK 3D contínuo em runtime nem garantia de compatibilidade automática com qualquer formato de arma.

Relatório: `Docs/Validation/HumanoidStatesR8Feedback.md`. Esquiva e espada: aprovação artística pendente do usuário.
