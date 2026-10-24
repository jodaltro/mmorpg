# Hospedeiro web e mobile

Estado conferido em 24/10/2026. Endereço público: https://hospedeiro.memowhats.workers.dev

## Onde estava

O Worker e o bucket R2 já existiam e o mundo respondia pelo túnel da Cloudflare. A implementação web, sessões e controles por toque estavam no worktree, sem commit. Faltava registrar e validar esse conjunto, corrigir a compilação do probe web e revisar a interface no celular.

## Operação

O Worker serve os arquivos de `build/web` do bucket `hospedeiro-web` e encaminha `/v1/` ao servidor na porta 8096. O servidor continua em loopback, com Jev e dados em `D:/unity/hospedeiro-data`. As credenciais ficam em `engine/.env`; nunca vão ao bundle web.

O processo `scripts/hospedeiro-online.ps1` mantém servidor e túnel e atualiza o destino do Worker após reconexão. Iniciar com PowerShell, oculto ao executar em segundo plano. Não usar `-Fresh` para atualizações normais: essa opção arquiva o mundo atual e inicia outro. Logs ficam em `D:/unity/hospedeiro-run`.

Dependências Python: requests, boto3 e brotli para publicar; playwright para os testes de navegador. Neste computador estão em `D:/tools/hospedeiro-python`; definir `PYTHONPATH` para essa pasta. O supervisor aceita `-PythonDependencies` para outro caminho.

Exportar com `python clients/hospedeiro/tools/build_web.py`. São necessários Godot 4.7.2 e seus templates Web. Publicar com `python clients/hospedeiro/tools/deploy_online.py web`; a publicação preserva a origem existente do mundo. Para trocar o túnel explicitamente: `deploy_online.py origin <url>`.

## Carregamento inicial

A tela de carregamento aguarda a sessão e a primeira visão do motor, aplicada aos NPCs, missões e estado do corpo. Só então libera o jogo. Depois disso, consultas e reconexões ocorrem em segundo plano. Após 20 segundos sem a visão inicial, oferece tentar novamente ou jogar offline; não libera silenciosamente um mundo incompleto. `?engine=off` entra offline explicitamente.

## Mobile

Jogar na horizontal. Movimento com o polegar esquerdo. Segurar Atacar usa mira automática; arrastar o dedo a partir do contato assume a direção manual. A mira mantém o alvo enquanto outro não estiver claramente mais próximo. Toxina, impulso e as quatro habilidades conhecidas ficam junto ao ataque, em arco à direita. As habilidades têm ícones por função: tocar e soltar usa a mira assistida; segurar e arrastar mostra a direção, soltar usa e arrastar para X cancela. O minimapa no topo esquerdo abre o atlas. Referências e decisões em `MobileUX.md`.

Menu reúne Corpo, Códice, Mapa, Sinais e tela cheia quando o navegador permitir. Em **Tamanho da interface**, arraste a barra de 75% a 125% e solte para aplicar. A preferência fica salva no navegador/dispositivo; **Restaurar 100%** retorna ao padrão. A escala muda controles, textos e painéis, mantendo o campo de visão do mundo. Histórico e indicadores secundários ficam recolhidos durante o combate. Abrir menu ou janela solta os controles mantidos. O botão Agir e a tipografia dos controles/painéis foram reduzidos para liberar espaço. Vida e ATP ficam no topo esquerdo, sem sobreposição com conexão e região.

## O que ainda falta

- Servidor em infraestrutura permanente: hoje desligar ou suspender este computador interrompe o mundo compartilhado. O túnel é temporário; o supervisor precisa permanecer ativo.
- Testes em aparelhos físicos, especialmente Safari/iPhone, teclado virtual, recortes de tela e desempenho térmico. Emulação de navegador não substitui hardware real.
- Combate autoritativo e cooperativo: o protótipo ainda informa acontecimentos pelo cliente; o token protege a identidade, mas não impede um jogador de falsificar seus próprios feitos. Não há sincronização de combate entre jogadores.
- Instalação e cache integral offline de PWA: há manifesto, mas não service worker. O modo de jogo offline funciona quando os arquivos carregam e o motor fica indisponível; não promete abrir sem internet.

Resultados realmente executados ficam em `Docs/Validation/2026-10-24-web-mobile.md`.
