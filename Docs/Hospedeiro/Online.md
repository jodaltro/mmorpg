# Hospedeiro web e mobile

> **POLÍTICA VIGENTE — 28/10/2026:** o usuário autoriza limpeza destrutiva, descarte de saves, mundos, journals e progressão, recriação do banco de dados e reset total do Hospedeiro quando necessários ao desenvolvimento. Migração sem perda, compatibilidade com dados antigos, backup e restauração do estado anterior são opcionais e não bloqueiam implementação, gates ou release. Registrar a estratégia escolhida (migração ou reset/recriação) e validar o estado resultante. A autorização não exige reset em toda mudança. Persistência, replay/digest e idempotência continuam obrigatórios dentro da versão vigente. Testes continuam locais/isolados; este ajuste documental não executa limpeza, reset, migração, deploy ou acesso ao banco.

Estado conferido em 24/10/2026. Endereço público: https://hospedeiro.memowhats.workers.dev

## Onde estava

O Worker e o bucket R2 já existiam e o mundo respondia pelo túnel da Cloudflare. A implementação web, sessões e controles por toque estavam no worktree, sem commit. Faltava registrar e validar esse conjunto, corrigir a compilação do probe web e revisar a interface no celular.

## Operação

O Worker serve os arquivos de `build/web` do bucket `hospedeiro-web` e encaminha `/v1/` e `/nakama/` ao servidor na porta 8096, incluindo upgrade WebSocket. O Go encaminha `/nakama/` à porta 7350. O servidor continua em loopback, com Jev e dados em `D:/unity/hospedeiro-data`. As credenciais do motor ficam em `engine/.env`; as novas chaves de serviço em `D:/unity/hospedeiro-nakama/keys.json`. Nunca vão ao bundle web. Ver [Nakama.md](Nakama.md).

O processo `scripts/hospedeiro-online.ps1` mantém servidor e túnel e atualiza o destino do Worker após reconexão. Iniciar com PowerShell, oculto ao executar em segundo plano. Não usar `-Fresh` para atualizações normais: essa opção arquiva o mundo atual e inicia outro. Logs ficam em `D:/unity/hospedeiro-run`.

Dependências Python: requests, boto3 e brotli para publicar; playwright para os testes de navegador. Neste computador estão em `D:/tools/hospedeiro-python`; definir `PYTHONPATH` para essa pasta. O supervisor aceita `-PythonDependencies` para outro caminho.

Exportar com `python clients/hospedeiro/tools/build_web.py`. São necessários Godot 4.7.2 e seus templates Web. Publicar com `python clients/hospedeiro/tools/deploy_online.py web`; a publicação preserva a origem existente do mundo. Para trocar o túnel explicitamente: `deploy_online.py origin <url>`.

## Carregamento inicial

A entrada pede somente o nome da célula. A tela de carregamento aguarda a sessão Nakama, o primeiro estado compartilhado do Godot e a primeira visão privada do motor, aplicada aos NPCs, missões e estado do corpo. Só então libera o jogo. Depois disso, consultas ocorrem em segundo plano; uma desconexão pausa os controles e tenta reconectar. Após 20 segundos sem a visão inicial, oferece tentar novamente ou abrir uma sessão offline separada. `?engine=off` entra offline explicitamente.

## Mobile

Jogar na horizontal. Movimento com o polegar esquerdo. Segurar Atacar usa mira automática; arrastar o dedo a partir do contato assume a direção manual. A mira mantém o alvo enquanto outro não estiver claramente mais próximo. Toxina, impulso e as quatro habilidades conhecidas ficam junto ao ataque, em arco à direita. As habilidades têm ícones por função: tocar e soltar usa a mira assistida; segurar e arrastar mostra a direção, soltar usa e arrastar para X cancela. O minimapa no topo esquerdo abre o atlas. Referências e decisões em `MobileUX.md`.

Menu reúne Corpo, Códice, Mapa, Sinais e tela cheia quando o navegador permitir. Em **Tamanho da interface**, arraste a barra de 75% a 125% e solte para aplicar. A preferência fica salva no navegador/dispositivo; **Restaurar 100%** retorna ao padrão. A escala muda controles, textos e painéis, mantendo o campo de visão do mundo. Histórico e indicadores secundários ficam recolhidos durante o combate. Abrir menu ou janela solta os controles mantidos. O botão Agir e a tipografia dos controles/painéis foram reduzidos para liberar espaço. Vida e ATP ficam no topo esquerdo, sem sobreposição com conexão e região.

## O que ainda falta

- Servidor em infraestrutura permanente: hoje desligar ou suspender este computador interrompe o mundo compartilhado. O túnel é temporário; o supervisor precisa permanecer ativo.
- Testes em aparelhos físicos, especialmente Safari/iPhone, teclado virtual, recortes de tela e desempenho térmico. Emulação de navegador não substitui hardware real.
- Grupos e masmorras cooperativas: o mundo aberto já compartilha jogadores, inimigos e coleta com combate autoritativo, mas as masmorras desta entrega são pessoais. Ainda faltam grupos, persistência de posição/vitais entre reconexões e partição por órgão. O limite inicial de 64 convidados por sala não foi validado por teste de carga.
- Instalação e cache integral offline de PWA: há manifesto, mas não service worker. O modo de jogo offline funciona quando os arquivos carregam e o motor fica indisponível; não promete abrir sem internet.

Resultados realmente executados ficam em `Docs/Validation/2026-10-24-web-mobile.md`.


## Reset temporário de teste — 24/10/2026

O menu mobile inclui Reiniciar mundo · teste quando a sessão recebe capabilities.reset=true. A confirmação avisa que o mundo compartilhado, os genes, as missões e a evolução reiniciam para todos. O log anterior fica arquivado pelo motor. Esta opção foi habilitada a pedido do usuário para a fase de testes.

O servidor usa a opção explícita serve -test-reset. A API exige sessão válida, player da sessão e confirm=new-world. Sem a opção, o modo público continua retornando reset_disabled. O contrato v1 recebe apenas o campo opcional player no pedido de reset; o comportamento padrão permanece igual.

Supervisor: scripts/hospedeiro-online.ps1 -TestReset -ReuseTunnel. ReuseTunnel conserva a origem existente; sem TestReset o reset público volta a ser bloqueado. ServerBinary permite escolher o executável; por padrão prefere D:/unity/hospedeiro-run/worldsim-nakama-v2.exe, depois worldsim-current.exe e engine/worldsim.exe. Uma compilação com suporte a -nakama é necessária para esta implantação. A supervisão verifica a porta e o processo do túnel localmente, sem sondagens do endereço publicado.

O fluxo atual de atualização mantém D:/unity/hospedeiro-data e o túnel por padrão; isso não impõe preservação em mudanças de desenvolvimento. Limpeza de dados e reset/recriação estão autorizados quando necessários. A confirmação no jogo pertence ao botão de reset do produto. Testes de publicação continuam locais e não executam reset real.
