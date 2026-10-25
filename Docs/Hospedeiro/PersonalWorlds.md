# Mundos pessoais e visitas — 25/10/2026

Direção autorizada pelo usuário: jogar localmente, guardar progresso no servidor em segundo plano, convidar um amigo por QR Code e conexão direta. O visitante usa a própria build **e continua evoluindo**. PvP de teste no **mapa aberto inteiro, junto dos monstros**, sem arena obrigatória e sem recompensas por abater jogadores.

## Como jogar

No navegador, a entrada padrão é **Meu mundo · jogo local**. O seletor também conserva o **Mundo MMORPG compartilhado** (`?mode=shared`), com sua autoridade e seu save anteriores. O modo pessoal começa com um personagem separado; não importa dados nem confirmações para o mundo MMORPG.

**Mundo / amigos** abre convite por link/QR Code, entrada no mundo de um amigo, status da nuvem, backup e restauração. O link contém uma autorização aleatória no fragmento `#visit=`; o servidor de arquivos não recebe esse fragmento. São **dois participantes** nesta primeira versão: dono e visitante. O dono mantém o jogo aberto. Um convite expira após 15 minutos sem atividade de sinalização; fechar a visita invalida o convite do anfitrião. Quem lê o QR Code entra pelo navegador, escolhe o nome e confirma a visita no painel.

As células podem se atacar e combater invasores no mesmo mapa. Cada participante exibe nome e membrana; o dono confirma dano, morte e vencedor. Renascer usa o fluxo existente. Jogadores e auxiliares de jogadores não contam como monstros para missões, pressão ou recompensas. O abate de um monstro pelo visitante avança o registro do visitante, sem creditar o abate ao dono. A diferenciação, os genes e as habilidades do visitante continuam sendo decididos pelo seu motor pessoal; as escolhas de catálogo são reaplicadas pelo anfitrião ao corpo em combate.

## Simulação e persistência

O mesmo `engine/core`, com o mesmo universo, é compilado em Go/WASM. Um **Web Worker** executa `Step`, visões, affordances e ticks sem ocupar a thread de renderização. Movimento, IA de combate e efeitos continuam no Godot. Não existe espera pela nuvem no caminho de um ataque ou passo. Sem Jev conectado, os prazos usam os padrões determinísticos do universo; esta versão pessoal não chama o Jev ao vivo.

O journal de comandos aceitos é persistido em **IndexedDB**, em transações. Um save fixa sua definição do universo para não ser reinterpretado silenciosamente depois de uma alteração de conteúdo. A posição de retorno ao mundo, vida, ATP, tutorial, exploração e organização das builds acompanham o save. NPCs, missões, genes, história e recompensas de masmorras são reconstruídos pelo replay do motor. A população física transitória de monstros e recursos é recriada ao reabrir o jogo.

Checkpoints locais a cada 128 comandos aceleram a retomada: são apenas cache, com digest do estado, hash do prefixo do journal e fingerprint do universo. Cache incompatível ou corrompido é descartado e o log completo é reproduzido. Uma resposta HTTP perdida após salvar é recuperada comparando a continuação remota com o prefixo local, preservando comandos ainda pendentes. Web Locks evita dois escritores simultâneos no mesmo aparelho nos navegadores que oferecem essa API.

O RPC separado **`hosp_personal`** guarda lotes imutáveis de até 128 comandos e um cursor com controle de versão no storage do Nakama. As coleções `personal_{journal,meta,definition}_v1` têm leitura/escrita diretas desabilitadas; o RPC deriva o dono da sessão técnica, nunca de um campo de identidade enviado pelo cliente. Não há tabelas SQL novas nem migração do banco compartilhado.

A sincronização ocorre a cada 60 segundos, no máximo quatro lotes por passagem, e adia o início e os próximos lotes enquanto o jogador está em combate com a página visível. O journal continua sendo salvo localmente. `head` consulta apenas cursor/versão com uma leitura de storage; a definição completa e os segmentos só são baixados para restauração ou recuperação de um recibo perdido. O painel também permite **Sincronizar save agora**. Falha de rede mantém registros pendentes neste aparelho. Concorrência usa CAS e recibos idempotentes com hash do lote; versões divergentes interrompem o upload. O painel oferece restauração explícita da nuvem, com download prévio do backup local e validação do replay antes da substituição. A nuvem nunca rebobina uma sessão em andamento automaticamente. O backup inclui a identidade técnica e deve ser guardado como arquivo pessoal, fora do repositório.

Um service worker guarda uma exportação completa para reabrir sem rede depois do primeiro carregamento e da conclusão do cache. Uma versão nova espera as abas anteriores fecharem: HTML, Godot e WASM não são misturados entre versões. A API não entra no cache.

## Visitas e rede

WebRTC DataChannels conectam os navegadores. SDP e candidatos ICE passam pelo RPC; **inputs, snapshots, efeitos e acontecimentos de combate passam pelos canais entre jogadores**. O canal de controle é confiável; inputs redundantes e snapshots usam canal sem retransmissão, preservando predição, reconciliação e interpolação existentes. Mensagens grandes têm fragmentação limitada e expiração. O RTT entre os participantes aparece também no mobile.

O anfitrião executa os dois corpos e os monstros. O visitante envia intenções e escolhas de catálogo; não declara dano ou HP. A autoridade é o dispositivo do dono: este modo é privado e não competitivo, e seus journals nunca são importados para o MMORPG.

O caminho pessoal recebe pacotes antes da física, envia cada intenção no próprio tick de 60 Hz e publica snapshots após a simulação a 30 Hz. A apresentação remota usa uma margem adaptativa de 33–100 ms, em vez do mínimo de 60 ms do modo compartilhado. Movimento e efeitos previstos continuam imediatos no visitante; dano e resultado são confirmados pelo anfitrião. A margem de interpolação e os ticks ainda existem: conexão direta não significa apresentação remota instantânea.

O indicador **P2P ms** usa o RTT do par ICE selecionado quando o navegador fornece `currentRoundTripTime`, com fallback para ping do canal. Ambos os aparelhos exibem a mesma categoria de medida; antes o visitante mostrava confirmação de input e o anfitrião mostrava ping do canal. O painel separa **rede** e **resposta do jogo** (ping de aplicação, sujeito à agenda da thread gráfica). A confirmação de input continua no diagnóstico do probe. O painel identifica pares host/host como **P2P local**, outros pares diretos como **P2P direto**, e candidatos relay como **Relay**; isso descreve o transporte selecionado, sem provar a topologia física do Wi-Fi. Medição conforme [RTCIceCandidatePairStats / MDN](https://developer.mozilla.org/en-US/docs/Web/API/RTCIceCandidatePairStats/currentRoundTripTime).

Uma vitória abre uma mensagem central independente dos banners de missão e morte, nos dois aparelhos, durante seis segundos. O resultado tem sequência e deduplicação por vida, sem recompensas; renascer permite novo confronto. Contra-ataques e compartilhamento de dano conservam a autoria para esse resultado.

STUN padrão: `stun:stun.cloudflare.com:3478`. LAN pode conectar diretamente, sem internet no caminho dos pacotes de jogo. Redes diferentes dependem de NAT/firewall; STUN não garante conexão direta. Existe suporte a `window.HOSPEDEIRO_ICE_SERVERS` para configuração de TURN pelo hospedeiro, mas **nenhum relay pago foi provisionado**. Sem rota possível, o painel explica a falha. Não há promessa de ping abaixo de 100 ms para toda rede.

Referências: [Godot/WebRTC](https://docs.godotengine.org/en/4.7/tutorials/networking/webrtc.html), [ICE/MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Connectivity), [Cloudflare STUN/TURN](https://developers.cloudflare.com/realtime/turn/), [storage e controle de versão do Nakama](https://heroiclabs.com/docs/nakama/concepts/storage/collections/).

## Limites desta entrega

- O novo modo e as visitas são do **cliente web/mobile**. O executável Godot nativo conserva o modo anterior; WebRTC nativo exige a extensão correspondente.
- Masmorras individuais continuam no mundo pessoal quando jogando sozinho. Durante uma visita, a entrada explica que é preciso fechar a visita para iniciar uma masmorra. Coop de masmorras não foi implementado.
- O reset global de teste permanece exclusivo do MMORPG anterior; o modo pessoal não expõe esse reset.
- Navegadores podem suspender uma aba em segundo plano ou um telefone bloqueado. O mundo visitado exige o anfitrião ativo; não há migração de anfitrião ou servidor de combate de contingência.
- A identidade técnica continua por dispositivo, sem senha/cadastro. O nome não permite abrir o save de outro dispositivo. Reconexão da nuvem é automática; uma visita encerrada exige novo convite/entrada.

QR Code gerado localmente pela biblioteca MIT de [Kazuhiko Arase](https://github.com/kazuhikoarase/qrcode-generator), redistribuída com licença. Nenhum serviço externo recebe o link para gerar o QR.
