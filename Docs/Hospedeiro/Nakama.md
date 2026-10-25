# Nakama no Hospedeiro

Decisão e primeira integração: 24/10/2026. A instrução atual do usuário substitui o adiamento antigo de publicação: usar Nakama e entrar só pelo nome, sem senha ou cadastro.

## O que está implementado

- Convidado informa 2–24 caracteres. Um identificador aleatório fica no navegador/dispositivo; Nakama emite a sessão automaticamente. O nome é de exibição e pode se repetir. Reabrir no mesmo navegador conserva o personagem; outro dispositivo cria outro convidado. Não há recuperação de conta nem vínculo por nome.
- Uma sala Nakama autoritativa admite até 64 convidados e uma presença de servidor protegida por chave. O runtime Lua vincula entrada à sessão real, limita mensagens e só aceita snapshots da presença do Godot autorizado. A sala vazia mantém o host vivo.
- Godot headless roda as regras já existentes de movimento, colisão, ataques, habilidades, custos e recargas. Clientes enviam vetores e intenções, nunca posição, vida, dano ou recompensa. Vetores não finitos, sequências repetidas e listas arbitrárias são rejeitados.
- Mundo aberto compartilhado: jogadores visíveis por nome e corpo, criaturas que escolhem a célula próxima, nutrientes/coletas únicos, projéteis, minas, redes e assinaturas procedurais replicadas. Atualizações de estado a 20 Hz, suavizadas no cliente, com seleção por proximidade.
- O motor Go continua responsável por missões, genes, linhagens, conhecimento, história e Jev. Somente o Godot confirma feitos. O gateway Lua deriva o ator de `ctx.user_id`, permite apenas intenções de jogador e obtém a visão privada correspondente. A chave de adapter fica no servidor.
- Masmorras pessoais usam um `World2D` próprio por convidado no servidor. A apresentação desenha a sala sem executar combate ou decidir quando foi limpa. Concluir/falhar continua passando pelo motor. Grupos de masmorra ainda não estão implementados.
- Conexão inicial só libera os controles após snapshot próprio e visão privada. Perda de conexão interrompe os controles e reconecta; entradas paradas por mais de 500 ms deixam de mover no servidor. Recarregar a página preserva a identidade. O modo offline permanece explícito e independente.
- Reset temporário exige confirmação, passa pelo gateway e depende de `-test-reset` do motor. A instância real nunca é resetada durante testes. Identidades Nakama sobrevivem ao reset, personagens renascem e o motor arquiva o mundo anterior.

## Serviços deste computador

| Componente | Localização / porta |
|---|---|
| Mundo Go + proxy Nakama | loopback 8096; dados `D:/unity/hospedeiro-data` |
| Nakama 3.41.0 | loopback HTTP/WS 7350, gRPC 7349 |
| Console Nakama | somente loopback HTTP 7370, gRPC 7367 |
| PostgreSQL 17.6 | somente loopback 55432; `D:/unity/hospedeiro-nakama-db` |
| Configuração/chaves/logs Nakama | `D:/unity/hospedeiro-nakama` |
| Binários portáteis | `D:/tools/hospedeiro-online` |
| Cliente web | Cloudflare Worker/R2; `/nakama/` aceita WebSocket |

Instalação reproduzível dos binários oficiais, sem mudar PATH nem instalar serviço Windows:

```powershell
python scripts/install-hospedeiro-nakama.py
```

O supervisor principal inicia o mundo, o supervisor Nakama/Godot e o túnel. Atualização normal conserva dados e túnel:

```powershell
powershell -NoProfile -File scripts/hospedeiro-online.ps1 -TestReset -ReuseTunnel -ServerBinary D:/unity/hospedeiro-run/worldsim-nakama-v2.exe
```

`scripts/hospedeiro-nakama.ps1` gera chaves locais na primeira execução, prepara o banco com as migrações oficiais do Nakama e reinicia os processos de Nakama e Godot se terminarem. PostgreSQL fica separado e não é encerrado ao parar o supervisor. O console e o banco não são expostos pelo Worker. A chave pública `hospedeiro` serve apenas para abrir sessões de convidado; não é credencial de autoridade.

## Validação local isolada

`scripts/hospedeiro-nakama.ps1 -LocalTest` usa HTTP/WS 7352 (gRPC 7351), console 7372/7369, banco `hospedeiro_qa` e configuração em `D:/unity/hospedeiro-nakama-qa`. Preparar motor de teste na porta 8198 com dados `D:/unity/hospedeiro-nakama-qa/world`, advisor determinístico, `-public -test-reset -nakama http://127.0.0.1:7352`, usando a chave adapter do arquivo QA. Nunca usar os dados reais nessa configuração.

Scripts de teste em `clients/hospedeiro/tests/web/test_nakama_local.py` e `test_nakama_browser.py` fixam os endereços QA de loopback. O primeiro testa duas conexões reais, bloqueios de autoridade, privacidade, reconexão e reset do mundo QA; o segundo testa entrada mobile, carregamento, movimento pelo proxy e identidade após recarregar. Testes Godot cobrem contrato de entrada, combate do servidor, crédito de dano tardio, coleta exclusiva, serialização visual e isolamento de masmorras.

## Limites atuais

O mundo continua hospedado neste PC, portanto suspensão/desligamento interrompe as partidas. A sala é única, sem distribuição por órgãos; 64 é um limite de admissão inicial, não capacidade medida. Posição e vitais de combate recomeçam na medula ao reconectar, enquanto progressão e missões permanecem no motor. Não há grupos, recuperação de convidado nem migração automática dos antigos IDs `cel-*` para os novos `nk-*`; os dados antigos são conservados. Movimento local tem previsão e reconciliação contra os snapshots; dano, vitais e recompensas continuam autoritativos. A previsão não reduz o RTT físico da conexão. Ainda falta testar dispositivos físicos e carga.

Referências oficiais: [Godot/Nakama](https://heroiclabs.com/docs/nakama/client-libraries/godot/), [partidas autoritativas](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/), [match handlers Lua](https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/), [instalação Windows](https://heroiclabs.com/docs/nakama/getting-started/install/windows/).

## Latência e hospedagem

Entradas a até 30 Hz, relay Lua a 60 Hz e snapshots a 20 Hz. Metadados visuais só são repetidos quando mudam, na primeira aparição e em uma atualização completa por segundo; vitais e posições permanecem em cada estado. O cliente descarta snapshots intermediários na mesma leitura, conservando metadados e eventos. A autoridade vazia envia heartbeat a 1 Hz. Clientes antigos continuam recebendo estado completo.

O mobile mostra RTT medido até a confirmação da entrada, com fallback para ping do socket. Leituras antigas expiram e reconexão não inventa 0 ms. Veja o plano e os limites em [CloudHosting.md](CloudHosting.md).
