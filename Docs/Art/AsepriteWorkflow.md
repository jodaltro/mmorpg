# Aseprite local — configuração e laboratório

Configuração validada em 15/10/2026. Executável encontrado: `D:\Aseprite\Aseprite.exe`, versão **1.3.18.6-x64**. ASEPRITE_EXE e PATH não estavam configurados. Nenhum executável, licença ou configuração privada foi copiado para o projeto. Sem geração externa ou chamadas pagas.

A skill do repositório está em `.agents/skills/aseprite-pixel-art/SKILL.md`, com frontmatter `name`/`description` e descoberta automática padrão. Em uma nova sessão aberta em `D:\unity\Mmorpg`, invoque `$aseprite-pixel-art` ou peça um trabalho de pixel art no Aseprite. AGENTS.md também aponta para o arquivo. A descoberta em uma nova sessão não pode ser exercitada dentro desta sessão já aberta.

## Comandos a partir da raiz

Python e Pillow são as dependências já utilizadas pelo ArtPipeline; não há servidor MCP.

```powershell
python Tools/ArtPipeline/Aseprite/aseprite.py locate
python Tools/ArtPipeline/Aseprite/aseprite.py validate
python Tools/ArtPipeline/Aseprite/aseprite.py lab --output ArtSource/Labs/Aseprite/novo-walk.aseprite
python Tools/ArtPipeline/Aseprite/aseprite.py export --source ArtSource/Labs/Aseprite/novo-walk.aseprite --output ArtSource/Labs/Aseprite/nova-exportacao
python Tools/ArtPipeline/Aseprite/aseprite.py verify --output ArtSource/Labs/Aseprite/nova-exportacao
& Tools/ArtPipeline/Aseprite/Invoke-Aseprite.ps1 -b ArtSource/Labs/Aseprite/walk-south.aseprite --script Tools/ArtPipeline/Aseprite/inspect.lua
```

O gerador recusa documento existente; o exportador exige diretório novo. A CLI direta do Aseprite pode sobrescrever saídas: use destinos novos. Para instalações em outro caminho, configure `$env:ASEPRITE_EXE` antes dos comandos. `validate` usa diretório temporário e não mantém cópias do protagonista.

Para abrir no editor gráfico:

```powershell
Start-Process -FilePath 'D:\Aseprite\Aseprite.exe' -ArgumentList '"D:\unity\Mmorpg\ArtSource\Labs\Aseprite\walk-south.aseprite"'
```

## Laboratório editável

[Documento](../../ArtSource/Labs/Aseprite/walk-south.aseprite), [sheet](../../ArtSource/Labs/Aseprite/export/sheet.png), [JSON](../../ArtSource/Labs/Aseprite/export/frames.json), [prévia](../../ArtSource/Labs/Aseprite/export/preview.gif). Os quatro PNGs individuais e `qa.json` estão na mesma pasta de exportação.

Documento RGBA 96×96, oito camadas e quatro quadros de 140 ms, tag `walk_south_blocking`. Ordem: contato esquerdo, passagem direita, contato direito, passagem esquerda. Esquerda anatômica fica à direita da imagem. É **blocking geométrico para edição**, não caminhada profissional nem novo protagonista aprovado.

Construção exata em `walk_lab.lua`: pernas são dois retângulos escuros a x41/x49 com botas marrons; o topo das botas alterna y84/80/78/82 e y78/82/84/80. Tronco é retângulo escuro 18×20 com interior cinza 14×15. Braços são mangas azuis 6 px, com comprimentos contrapostos e mãos de pele 6×4. Cabeça é bloco de cabelo 16×16, rosto 12×10 e dois olhos 2×2. Roupa são dois retângulos azuis sobre cintura/quadril. Tronco/cabeça/roupa recebem bob de 0/1/0/1 px; isso apenas demonstra edição, não valida distribuição de peso.

Camadas ocultas: contato (linha y88 e eixo x48), pivô amarelo (48,70), mãos (direita magenta, esquerda verde). Pontos acompanham as mãos esquemáticas. Na passagem, o contato do pé ainda exige correção manual; guias não certificam apoio. Não há espada desenhada. A paleta é explícita no Lua, sem dependência de paleta pessoal. Guia e marcadores podem ser ligados no editor, mas devem permanecer ocultos ao exportar. Edite cels, silhuetas e duração na timeline; salve trabalho manual com outro nome para preservar o exemplo reproduzível.

## Testes efetivamente executados

O relatório `ArtSource/Labs/Aseprite/environment-validation.json` registra versão, CLI, Lua e hashes. Foram executados `--version`, `--help`, abertura batch do PNG idle sul existente, roundtrip PNG pixel a pixel, sheet/JSON do original em temporários e verificação de que seu hash não mudou. Lua criou documento, que foi reaberto para leitura de quatro frames e oito camadas. Exportação produziu quatro PNGs RGBA 96×96 com alfa 0–255 e quatro conteúdos distintos, sheet 384×96, quatro entradas JSON com durações positivas e GIF com quatro quadros. O laboratório persistente foi reaberto pelo mesmo leitor Lua. Saídas temporárias são removidas automaticamente.

Não foi feita inspeção interativa do editor gráfico, nem aprovação artística. Nenhuma cena, backend, regra de combate ou asset final foi modificado. Unity, importação, testes de gameplay e suítes extensas não foram executados.

O launcher PowerShell foi executado sobre o laboratório e a leitura Lua foi também confirmada por captura de stdout no Python. A recusa de sobrescrita do gerador foi testada sobre o documento existente. A prancha exportada foi inspecionada: quatro bonecos geométricos legíveis, sem guias sobre a arte. `git diff --check` passou. O validador oficial de skills `quick_validate.py` foi tentado nos dois runtimes Python disponíveis, mas não executou por ausência de PyYAML; o frontmatter foi conferido diretamente (name/description, nome e diretório correspondentes, sem placeholders). Não declarar esse validador como aprovado.

## Preparação futura para Unity

Siga [contrato](ProductionAssetContract.md), [animação](HeroAnimation.md), [empunhadura](WeaponAttachment.md) e [pipeline](ProductionPipeline.md). Preserve 32 PPU, canvas completo, pivô (48,70) e chão de referência (48,88); meça mãos por frame sobre a luva desenhada, equipamento separado. O JSON Aseprite contém retângulos/durações/tags, mas não substitui o manifesto com pés, mãos, ângulo, profundidade, proveniência e hashes.

Após revisão artística e metadados completos, use `ProductionArt06B4.Import` para manter ProductionCharacterSet/ProductionSpriteAnimator e Point/uncompressed/mipmaps off. **Não executar a migração `production.py`**, que pode regenerar fontes. O laboratório de quatro quadros não cumpre o pacote final de oito desenhos por direção previsto no contrato. Desenho de anatomia, peso, perspectivas, roupa, oito fases e revisão da empunhadura permanecem trabalho artístico manual.

Referências consultadas: [CLI oficial](https://www.aseprite.org/docs/cli/), [scripting](https://www.aseprite.org/docs/scripting/) e [API Lua](https://www.aseprite.org/api/). Opções foram confirmadas também pelo `--help` da instalação local.
