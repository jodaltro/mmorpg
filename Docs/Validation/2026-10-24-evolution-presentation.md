# Evolução de classe: escolha e transformação

## Comportamento

- Oferta de linhagem aparece no centro da tela quando o jogador está vivo, conectado, fora da masmorra, sem outra janela aberta e fora de combate. Combate considera golpes/dano nos últimos cinco segundos e inimigos ativos a menos de cinco unidades. A escolha central fecha se começar combate ou cair a conexão. Fechar adia a oferta sem recusá-la; ela continua no menu Corpo, inclusive durante combate.
- Escolher uma classe mostra o início da evolução, fecha o menu e solicita `diferenciar` com `design: refresh`. Toques repetidos não enviam várias escolhas. O corpo pisca brevemente, fica branco com órbitas/partículas e aguarda a conclusão real do visual.
- Linhagem, atributos e combate continuam autoritativos e entram em efeito normalmente. Só a aparência local é retida durante a preparação. O personagem continua controlável e vulnerável; não há pausa do mundo nem troca de mapa.
- O visual completo é revelado com partículas, anéis de luz e expansão da membrana quando a solicitação foi aceita, a classe foi confirmada e todas as decisões do desenho terminaram. A introdução visual tem um mínimo de 2,3 segundos, mas tempo sozinho não confirma conclusão. O padrão determinístico no prazo também conclui o visual.
- Recusa, desconexão, morte ou espera acima de 90 segundos liberam a apresentação. Reset limpa a revisão e o adiamento da oferta anterior, sem deixar corpo branco ou bloquear nova evolução. Nenhum reset real foi feito durante validação.

## Contrato

O argumento opcional `design: refresh` cria novas decisões validadas dos traços de aparência, com contexto da linhagem escolhida, substituindo decisões antigas de desenho daquele jogador. Jev permanece assíncrono, fora do `Step`/lock. A chamada só acontece após a validação normal da escolha de linhagem; não existe endpoint livre para disparar redesenhos.

`look.designPending` e `look.designRevision` são campos adicionais em `/v1`; não removem nem alteram campos existentes. Funcionam inclusive antes de existir um visual. Não dependem de os novos traços serem diferentes dos antigos para reconhecer conclusão. Comandos históricos sem o argumento mantêm o comportamento anterior. Nenhum conteúdo do universo foi alterado.

## Validações executadas localmente

- Godot import e export Web: concluídos sem erros de script. Export final inclui a apresentação.
- `run_tests.gd -- evolution_presentation`: 7 testes, 0 falhas; oferta fora de combate, fechamento/adiamento, menu em combate, solicitação única, espera real, retenção visual, falhas/callback atrasado, desconexão, reset e largura mobile. A revisão gráfica revelou títulos sem altura e largura mínima excessiva; ambos corrigidos antes da execução final.
- `run_tests.gd -- body_panel`: 19 testes, 0 falhas; escolhas e menus existentes.
- `run_tests.gd -- network_server`: 6 testes, 0 falhas; combate autoritativo e serialização. Saídas Godot verificadas também por `SCRIPT ERROR`/`ERROR`, não só pela contagem.
- Dois cenários Go novos sobre Hospedeiro: solicitação de todos os 19 traços, rejeição de resposta antiga, conclusão somente após todos os traços, prazo determinístico e replay com o mesmo Digest.
- `go vet ./...` e `go test ./...`: aprovados. Jev ao vivo não habilitado nos testes. `gofmt -l .` executado: os arquivos Go alterados estão formatados; listou dez arquivos preexistentes fora do escopo.
- Reprodução local de uma cópia do log atual: 1.519 comandos aceitos, revisão 1.519. Nenhuma chamada de IA nem escrita no mundo real nessa reprodução.
- Prévia gráfica nativa local com toque, 844×390: escolha, corpo branco e revelação renderizados e inspecionados. Capturas externas ao Git: `D:/unity/hospedeiro-web-qa/evolution-choice-mobile.png`, `evolution-white-mobile.png` e `evolution-reveal-mobile.png`. A prévia usa resposta local simulada; não se declara validação ao vivo do Jev.

## Aplicação

Motor recompilado e aplicado ao executável operacional `D:/unity/hospedeiro-run/worldsim-nakama-v2.exe` (cópia idêntica ao build `worldsim-evolution-v3.exe`). Supervisor reiniciado com o mesmo mundo, Jev, reset temporário e túnel reutilizado. Startup local confirmou o mundo no tick 1173, sem reset. Nakama, PostgreSQL e Godot headless foram mantidos. Nove arquivos do cliente publicados no R2 existente. Nenhum teste contra o endpoint publicado ou banco remoto.
