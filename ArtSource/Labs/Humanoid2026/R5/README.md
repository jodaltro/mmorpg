# R5 — Espadachim aventureiro de Valdoria

Figurino aprovado pelo usuário em 16/10/2026, após teste da apresentação experimental. Caminhada Quaternius aprovada anteriormente e preservada. Não promovido ao mundo oficial; combate e âncoras de espada pendentes.

## Editáveis e configuração

- `ValdoriaSwordsman.blend`: corpo e rig originais completos, fontes profissionais ajustadas por pesos, coleções Body/Clothing/Armor/Accessories/Hair/Rig/Rendering. Texturas usam caminhos relativos para Sources desta pasta e ../Sources/BaseModels; mantenha a estrutura do repositório. Não há cópias embutidas desnecessárias das texturas.
- `appearance.json`: identidade, paleta, lista de peças e método de skinning. `parts-audit.json`: geometria/pesos das peças importadas.
- `render-contract.json`: câmera/luz, amostragem congelada, direções e pivôs.
- `Results/ValdoriaSwordsman.aseprite`: cinco camadas, 52 quadros e oito tags. Render vestido composto, contorno separado, referência corporal oculta, guia oculto e camada reservada para correções. A camada de correções não recebeu pixels manuais; não confundir acabamento automatizado com desenho manual de 52 poses.
- `Results`: atlas, manifests, QA, mãos/pés/juntas por frame, GIFs e pranchas nearest. GIFs usam 110 ms pela resolução temporal do formato; o asset Unity preserva 111 ms.

## Fontes profissionais

Quaternius, CC0-1.0. `Sources/Outfits/License_Standard.txt` é o aviso original do kit gratuito. Cinco malhas modulares masculinas Ranger (tronco com dois cintos, braços, pernas, botas e ombreira) e cabelo SimpleParted foram obtidos como dados glTF/BIN, com texturas necessárias. As malhas não substituem nem removem braços do corpo aprovado. Apenas a pele duplicada incluída no arquivo de braços do kit foi excluída da peça importada.

Páginas oficiais: https://quaternius.itch.io/modular-character-outfits-fantasy e https://quaternius.itch.io/universal-base-characters . O catálogo completo de 12 outfits/62 partes não foi atribuído ao subconjunto gratuito. O mirror Standard auditado contém 20 arquivos de peças e quatro outfits completos (Peasant/Ranger, masculino/feminino); só as peças escolhidas foram baixadas, sem compra Source.

Transporte: mirror `agentkaerf/FreeModels` fixado em `db3df04d1e4714298a09510b26fb6de6645138a2` para roupas; mirror de corpos previamente auditado `NafisRayan/Animate-Rigged-Humanoid-No-Blender` em `5821923af517ac5fdc82505faa92a0d575fc1b1a` para cabelo. `outfit-provenance.json`, `hair-provenance.json` e `dependency-provenance.json` registram caminhos, blobs Git e SHA-256. Os downloads foram comparados aos blobs Git; não foi obtido um ZIP oficial para declarar equivalência byte a byte. Nenhum código de terceiros foi executado.

As texturas e materiais originais são editáveis. A nova paleta índigo modifica o material de tecido por máscara de cor, preservando a textura de couro/costuras; aço é material próprio na ombreira. Forro, mangas e luvas são superfícies derivadas da topologia/pesos do próprio corpo, sem primitivos grosseiros ou alteração da anatomia. Sem capa, vento ou simulação.

## Reprodução e segurança

`Tools/ArtPipeline/build_humanoid_outfit_r5.py --output <pasta-nova>` executado pelo Blender local cria as renderizações e o .blend de trabalho. Reutiliza a rotina original de pose/câmera por hooks explícitos; não altera `inspect_humanoid_study.py`. Destino de render novo obrigatório. A fonte de trabalho R5 é regenerável; não executar sobre edições manuais sem antes preservar outra versão.

`python Tools/ArtPipeline/export_humanoid_outfit_r5.py --renders <pasta-render>` exige `Results` ausente, usa Aseprite local/Lua e gera o editável. `python Tools/ArtPipeline/verify_humanoid_outfit_r5.py` verifica fontes congeladas, blobs, metadados e roundtrip. Não apague o Results aprovado para experimentar: crie outro laboratório/configure novos destinos.

Cena: `Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity`. Autoria por `BuildHumanoidOutfit2026.Create`, sem sobrescrever cena/atlas existentes. Comparação original continua acessível em `HumanoidScale2026.unity`. Relatório: `Docs/Validation/HumanoidOutfit2026.md`.
