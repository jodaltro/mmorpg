# Visitas locais: latência e resultado PvP — 25/10/2026

## Diagnóstico e alterações

- O combate pessoal já usava WebRTC direto; o banco não confirmava ataques. Havia filas adicionais: envio de input a 30 Hz no render, snapshots a 20 Hz e interpolação mínima de 60 ms. O anfitrião exibia ping de aplicação e o visitante confirmação de input, medidas diferentes.
- Transporte pessoal agora drena antes da física, envia input a 60 Hz no próprio tick e publica snapshots após simulação a 30 Hz. Interpolação pessoal: 33–100 ms conforme jitter. Predição e revalidação de ações permanecem; o MMORPG mantém seus parâmetros anteriores.
- Save na nuvem: intervalo de 10 para 60 s, com adiamento durante combate visível e consulta leve `head` (um cursor, sem definição/segmento). Persistência local e recuperação de recibos perdidos permanecem. Sincronização manual no painel.
- Indicador P2P usa RTT do transporte ICE, com fallback de aplicação. Painel distingue rota, rede e ping da aplicação. A confirmação de input continua no probe.
- Resultado PvP separado dos banners de missão/morte, deduplicado por vida, transmitido pelo canal confiável. Crédito de dano refletido/complementar/compartilhado preservado.

## Executado localmente

- Godot headless `--import`: sem erros de script.
- `run_tests.gd -- personal_world`: **6 testes, 0 falhas**, incluindo vitória dos dois lados, nova vida, deduplicação e snapshots a 30 Hz sem render.
- `run_tests.gd -- net_`: **21 testes, 0 falhas**, antes do acréscimo do teste de envio imediato.
- `run_tests.gd -- net_responsiveness`: **19 testes, 0 falhas**, incluindo envio de cada input no próprio tick sem render, predição, perda seletiva e reconciliação com latência/jitter simulados.
- `run_tests.gd -- network_server`: **11 testes, 0 falhas**.
- Saídas acima inspecionadas também por `SCRIPT ERROR`/`ERROR`, sem ocorrências.
- `go -C engine vet ./...` e `go -C engine test ./...`: aprovados (resultados de teste em cache). `gofmt -l engine` executado: continuam os dez arquivos preexistentes fora de formato em advisor/scenarios, não alterados nesta entrega.
- Exportação web completa por `build_web.py`: concluída.
- `test_personal_web.py`: Lua real com storage Nakama em memória; dois navegadores Edge com touch, WASM real e WebRTC sem STUN externo. Aprovados: cursor leve, isolamento/CAS/idempotência; rota host/host; vitória de visitante e anfitrião visível após morte; save adiado em combate; recuperação de resposta HTTP perdida; progressão independente; movimento/P2P com nuvem e sinalização bloqueadas; recarga totalmente offline; restauração por replay validado.
- Após ajustar o cartão para não sobrepor as instruções de renascimento, nova exportação e `test_personal_web.py --victory-only`: aprovado nos dois sentidos; captura `build/personal-host-victory.png` inspecionada visualmente, cartão legível e separado do texto de morte. A captura fica fora do versionamento.

No segundo ensaio completo, a amostra registrada foi rede **0/1 ms**, ping da aplicação **16/30 ms** e confirmação de input do visitante **29 ms**. São dois clientes no mesmo computador, sem medição anterior comparável: isso **não comprova** a latência de dois celulares físicos no mesmo Wi-Fi. A frequência de ticks, o roteador, a carga gráfica e o navegador continuam afetando a experiência.

Nenhum teste contra servidor publicado, banco real ou Jev ao vivo. Nenhum reset de mundo.
