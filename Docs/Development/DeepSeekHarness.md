# DeepSeek Harness — uso no projeto Mmorpg

**Estado:** guia de preparação, não comprovação de instalação. Atualizado em 17/10/2026. O Harness, o plugin Unity e o acesso ao Editor local **precisam ser verificados na máquina** antes de qualquer tarefa grande.

## Objetivo

Permitir que um agente operando no workspace `D:\unity\Mmorpg` aproveite os pipelines **Unity 6000.6.5f1**, **Aseprite 1.3.18.6**, Blender e Python existentes, seguindo `AGENTS.md` e os relatórios mais recentes. O objetivo não é substituir os sistemas do projeto, instalar novas dependências sem autorização ou alterar a cena oficial apenas para provar conectividade.

## Referências e pré-requisitos

- Projeto Windows: `D:\unity\Mmorpg`; repositório `jodaltro/mmorpg`, **branch `main`**.
- Editor Unity instalado, licença válida, conexão CLI existente (`unity-pipeline`), projeto aberto.
- Aseprite historicamente em `D:\Aseprite\Aseprite.exe`; wrappers internos em `Tools/ArtPipeline/Aseprite/`.
- Git autenticado; Node.js/npm conforme a versão requerida pelo Harness escolhido.
- Configurar a API/modelo DeepSeek no **ambiente privado do aplicativo**, nunca no Git.
- Fontes públicas de projeto: `AGENTS.md`, `Docs/Art/AsepriteWorkflow.md`, `Docs/Art/HumanoidStandard.md`, `Docs/Validation/Marco06B13R10Consolidado.md`.

A distribuição, os nomes de pacotes, comandos e requisitos de plugins podem mudar. **Verificar a documentação/CLI da versão realmente instalada** antes de executar instruções vistas online. Não presumir que uma integração de nome semelhante funcione com outra versão do Harness.

## Preparação segura no PowerShell

```powershell
cd D:\unity\Mmorpg
git status --short
git branch --show-current
node --version
npm --version
python Tools/ArtPipeline/Aseprite/aseprite.py locate
python Tools/ArtPipeline/Aseprite/aseprite.py validate
```

Os dois últimos comandos usam ferramentas já presentes no repositório; `validate` deve operar com temporários, conforme o fluxo existente. Caso o Aseprite não seja localizado, conferir `D:\Aseprite\Aseprite.exe` ou configurar `ASEPRITE_EXE` **apenas no ambiente da sessão**, se necessário.

## Instalar e configurar o Harness

1. Identificar o **repositório e pacote oficiais** da distribuição de DeepSeek Harness adotada, ler seu README e confirmar compatibilidade com Windows/Node. Instalar segundo essas instruções; não executar comandos `npx` de pacotes não verificados.
2. Iniciar a interface ou CLI conforme a versão instalada; selecionar `D:\unity\Mmorpg` como workspace.
3. Conectar chave/modelo DeepSeek pelo armazenamento privado da ferramenta. Conferir que logs, arquivos `.env` e saídas do agente não serão comitados.
4. Ler `AGENTS.md` no início da sessão. Confirmar explicitamente o protagonista Quaternius R10 e não o Iron Knight histórico.
5. Para Unity, localizar o plugin compatível com essa distribuição e sua versão, inspecionar permissões e instalação. O candidato citado anteriormente é `opdsh/unity-plugin`, mas **não tratar o nome do repositório como prova de compatibilidade com a instalação atual**. Se o plugin não funcionar, usar Unity CLI diretamente pelo terminal do agente, desde que autenticação e Editor conectado sejam verificados.
6. Para Aseprite, preferir **CLI/Lua do programa instalado** e o wrapper do próprio projeto. O plugin comunitário `dsh-aseprite` (se disponível/compatível) pode ser avaliado como interface auxiliar, mas não substitui a verificação de exportação/roundtrip pelo Aseprite real.

### Unity CLI existente

O fluxo do projeto já pressupõe comandos Unity CLI sob o contexto `--caller plugin --skill unity-pipeline`. Confirmar os subcomandos efetivamente suportados pela instalação antes de executá-los:

```powershell
unity auth status
unity license status
```

No editor conectado, validar a conexão, usar `set_autotick`, `recompile`, acompanhar `recompile_status` e consultar Console. **Não entrar em Play automaticamente na cena oficial** e não executar scripts `Apply` R10 legados de recalibração: eles podem alterar a escala atual.

## Smoke test inicial — sem risco aos dados

**Gate A — ferramentas:** confirmar a identidade do projeto, branch, versão Unity e caminho executável do Aseprite. Se algo falhar, parar e registrar erro.

**Gate B — Aseprite:** executar `locate` e `validate` do wrapper; usar arquivos temporários/novo laboratório e comparar os hashes do material de entrada. Não exportar sobre sprite de produção.

**Gate C — Unity:** abrir uma cena experimental já existente (por exemplo `Assets/Mmorpg/Scenes/HumanoidStatesR8.unity`) **fora de Play**, sem salvar alterações, confirmar scripts/Console e capturar estado. Se quiser testar Play, antes configurar perfil isolado e seguir rotinas de restauração do projeto.

**Gate D — limpeza:** encerrar Play, reverter apenas mudanças temporárias desse teste, restaurar dispositivos de input, `timeScale`, overrides e opções do Editor; conferir `git status`. Não commitar dados gerados apenas para testes de conectividade, salvo se o usuário pedir documentação específica.

Uma conexão acessível não comprova integração correta: registrar comandos executados, respostas, erros e evidências. Não alegar teste no Editor quando apenas uma consulta de código ocorreu.

## Regras específicas ao estado R10

- `MmorpgWorld.unity` usa Quaternius R8 em produção, 64 clips/528 frames, oito direções. Iron Knight está preservado **como histórico**.
- Grupo visual atual 1.25, mapa 1.74, câmera ortográfica 7.03125: **proporção ainda sem aprovação final**. NPCs temporariamente ocultos, interações correspondentes indisponíveis.
- Backdrop R10 detalhado é **imagem única**, sem colisão/oclusão semântica própria. Próximas tarefas devem usar área-piloto com footprints, sorting, navegação, quadro de referência pelo poço e QA real.
- Combate da cena oficial requer regressão por usar `LegacyGrip` acoplado à mão visual com escala 1.25; `PlanarSweepOrigin` passou no laboratório R7, não foi automaticamente promovido.
- Caminhada, figurino, esquiva expressiva, Hurt e morte do personagem têm aprovações específicas; espada ainda demanda revisão artística, com guarda ligeiramente avançada.

## Fluxo de trabalho para tarefas posteriores

1. Ler `AGENTS.md` e os relatórios relevantes; verificar worktree e preservar alterações alheias.
2. Propor um escopo pequeno e **cena experimental nova**; autor de cena deve recusar sobrescrita.
3. Criar assets editáveis, receitas/proveniência, scripts de autoria reexecutáveis e validações automatizadas proporcionais à mudança.
4. Rodar importação pelo Aseprite real quando aplicável; integrar no Editor Unity real com recompile/Console/Play e Input System sob perfil isolado.
5. Produzir capturas reais e separar claramente arte aprovada, candidato artístico e teste técnico. Não promover arte experimental automaticamente.
6. Fazer `git diff --check`, revisar segredos/saves, commit e push **apenas do conteúdo autorizado em `main`**, registrando SHA. Não alterar o default branch do remoto como atalho.

## Troubleshooting

- **Harness não encontra Unity:** conferir plugin instalado **na mesma instância/perfil**, path/versão da CLI, autenticação/licença e Editor aberto com o projeto correto. Testar CLI direta antes de culpar o jogo.
- **Aseprite não encontrado:** executar `python Tools/ArtPipeline/Aseprite/aseprite.py locate`; conferir instalação real em `D:\Aseprite\Aseprite.exe` e variável `ASEPRITE_EXE`.
- **Plugin Aseprite não consegue exportar:** reproduzir pelo wrapper local com destino temporário; confirmar versão, Lua e limites de overwrite.
- **Unity abre diálogo de mudança externa da cena:** resolver no Editor, não forçar regeneração nem salvar cena inesperadamente.
- **Teste altera saves:** interromper, restaurar o override e consultar `LocalJourneyProfile` antes de executar novo Play; nunca resetar perfis pessoais.
- **Os comandos mostrados por tutoriais não existem:** consultar `--help` e documentação da versão instalada; não inferir nomes de métodos ou APIs.

## Referências

- Código e documentos próprios: `AGENTS.md`, `Docs/Art/AsepriteWorkflow.md`, `Docs/Art/ProductionPipeline.md`.
- Documentação oficial Unity e pacote Unity CLI utilizados pelo projeto.
- [Aseprite CLI](https://www.aseprite.org/docs/cli/) e [scripting](https://www.aseprite.org/docs/scripting/).
- Repositórios de integração citados para avaliação de compatibilidade: [opdsh/unity-plugin](https://github.com/opdsh/unity-plugin) e [Ratevoid/dsh-aseprite](https://github.com/Ratevoid/dsh-aseprite). Nenhuma instalação desses conectores foi realizada por esta atualização documental.
