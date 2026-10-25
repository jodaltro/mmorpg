# Mundos pessoais, visitas e PvP aberto — 25/10/2026

Validação exclusivamente local. Nenhum teste foi executado contra o servidor publicado, o Supabase ou jogadores reais. O comportamento entregue e seus limites estão em [PersonalWorlds.md](../Hospedeiro/PersonalWorlds.md).

## Motor Go

- `go vet ./...` e `go test ./...` em `engine/`: aprovados. O novo pacote `personal` verifica replay determinístico, isolamento de mundos, rejeição sem alterar o journal, journal inválido, uso de checkpoint e descarte de cache corrompido com fallback ao log.
- `gofmt -l engine`: os dez arquivos anteriores fora desta alteração continuam listados (`advisor/jev.go` e nove cenários). Os arquivos Go novos estão formatados. Não foi feita reformatação incidental desses arquivos antigos.
- Build Go/WASM do mesmo core, sem dependências Go novas. Exportação web Godot concluída, sem `SCRIPT ERROR`/`ERROR` no export. WASM do motor local: aproximadamente 1,23 MB em Brotli, além do runtime gráfico existente.

## Godot

- Runner completo: **370 testes, zero falhas**. Uma primeira execução registrou recursos retidos no encerramento; a repetição diagnóstica com `--verbose` terminou com os mesmos 370 testes e sem `SCRIPT ERROR`/`ERROR`, inclusive no encerramento.
- Suíte `personal_world`, após os ajustes de visitas: **3 testes, zero falhas**, sem erros de script ou recursos no encerramento. Cobre anfitrião sem espera por input de rede, dois corpos no mesmo mundo físico, host/visitante versus monstros, snapshots com ambos os jogadores, feitos destinados ao visitante, ausência de progressão por PvP/esquiva de PvP, build limitada ao catálogo e nichos/adaptações do visitante.

## Navegador, Lua e persistência

Executado `clients/hospedeiro/tools/test_personal_web.py`, com Edge headless, dois contextos separados, tela de 960 × 540 com toque e servidor HTTP em loopback. O teste usa o **código Lua real do RPC**, executado por Lupa, com **doubles locais** para autenticação e storage do Nakama; não usa o banco real. Tráfego fora do loopback é bloqueado, e `localIce=1` desativa STUN externo.

Resultados aprovados:

1. Isolamento de saves por sessão, permissões zero para acesso direto, CAS, recibos idempotentes, rejeição de payload diferente com o mesmo recibo, autorização do convite, limite de dois participantes e expiração.
2. Dois clientes completos do jogo conectados por WebRTC, incluindo inputs, predição e snapshots de ambos os jogadores. QR Code renderizado localmente; o link gerado por ele foi usado para conectar o visitante.
3. Monstro derrotado pelo visitante: `abates` do visitante passa a 1, o do anfitrião permanece 0. Abater o anfitrião não incrementa esse contador.
4. Uma resposta de upload é intencionalmente descartada **depois** da escrita no storage double. A sincronização recupera o cursor sem duplicar comandos nem perder a continuação local.
5. Nuvem/sinalização ficam indisponíveis depois da conexão: movimento e sessão P2P continuam.
6. Sair da visita e reabrir totalmente sem rede: journal e progressão do visitante continuam disponíveis pelo cache local/service worker.
7. Restaurar a nuvem pelo menu: backup local baixado, replay validado, troca atômica do save e retomada do jogo com o abate preservado.
8. Saída dos navegadores sem erros JavaScript ou `SCRIPT ERROR`/`ERROR` do Godot. Capturas do menu/QR e do jogo/PvP inspecionadas visualmente; ficam em `build/`, ignorado pelo Git.

Não foi medida latência entre casas, operadoras ou redes móveis. A captura local mostrou 53 ms em um instante; isso não representa um resultado de internet ou garantia de 100 ms. Não houve provisionamento de TURN, teste em dispositivo físico, teste do novo modo no executável nativo ou chamada ao Jev ao vivo.

Logs locais da execução ficam em `D:/unity/hospedeiro-run/personal-*.log`, fora do repositório. Dependências de QA (`lupa`, `playwright`) ficam no D:, fora do projeto.

## Publicação

O build foi enviado ao R2 e o Worker atualizado, preservando o endereço do túnel. Os logs locais do Nakama registraram o RPC `hosp_personal` e `Startup done`; o supervisor reiniciou Nakama/Godot sem reset ou migração do mundo compartilhado. O limite HTTP do Nakama foi explicitado em 1 MiB para o envelope dos lotes (o RPC limita o conteúdo a 512 KiB), e o script PowerShell passou pelo parser local. Nenhum endpoint publicado foi usado para testes após a publicação.
