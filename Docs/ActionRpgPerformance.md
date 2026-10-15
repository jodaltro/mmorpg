# Medições do recorte action

Editor Unity 6000.6.5f1, Ryzen 7 1700X, Radeon RX 5700 XT, 24.512 MB de RAM. Game view reportada: **1101 × 510**; PNGs de evidência capturados em 1280 × 720. Física: passo de **0,02 s** (50 Hz), Rigidbody2D/Collider2D. Dados de hardware em [m06a-reference-hardware.json](Validation/m06a-reference-hardware.json).

| Ensaio executado no Editor | Frames amostrados | Média de frame | P95 | Maior tempo de melee | Rede / erros |
|---|---:|---:|---:|---:|---:|
| Lobo, coleta, caminhada e entrega | 9.636 | 3,521 ms | 4,413 ms | 0,278 ms | 0 / 0 |
| Aranha e habilidades | 6.694 | 3,971 ms | 5,044 ms | 0,052 ms | 0 / 0 |
| Golem, esquiva real e Contra-ataque | 5.159 | 3,950 ms | 5,473 ms | 0,041 ms | 0 / 0 |
| Retorno e quadro/diário | 20.110 | 3,893 ms | 5,120 ms | 0,041 ms | 0 / 0 |

Cada linha pertence à sessão indicada, e inclui os frames anteriores daquela sessão; não são amostras independentes para somar. Os dados brutos são strings produzidas por ActionMetrics, nos JSONs `m06a-gameplay-*-final`, `m06a-gameplay-spider` e `m06a-gameplay-journal` em Validation. Contadores de frames do último ensaio avançaram de **5.159 → 20.110 → 33.747**; jogo ativo, sem freeze no frame 1.

A amostra observada no Editor possui folga em relação ao orçamento de 16,67 ms de 60 FPS. Isso não é garantia de frame máximo, GPU, desempenho da build ou de outros computadores. O pico observado ao **recarregar a cena foi 257,489 ms**, numa leitura com apenas um frame amostrado; recarga não é aprovada como transição sem hitch. Consulte [reload](Validation/m06a-gameplay-reload.json).

No primeiro ensaio de melee foi observado pico de **31,027 ms**, incluindo o callback que gravava o fato síncrono em disco. Após introduzir gravação serial em segundo plano para o arquivo isolado action, o percurso seguinte registrou máximo de **0,278 ms**. São ensaios distintos; não se atribui toda a diferença exclusivamente a disco/JIT. Troca de cena e encerramento esperam a fila; leitura deliberada conserva a validação/replay anterior. O teste de recarga imediata usa storage artificialmente lento para proteger o último fato confirmado.

O marcador de ataque observado em LateUpdate apareceu no mesmo frame da ação aceita (**0 frames intermediários** nos ensaios). A preparação visual pesada é imediata e a resolução aguarda sua janela configurada de 0,38 s. Esses dados não medem latência física do dispositivo/monitor nem apresentação na GPU. A suíte Input System verifica feedback, compromisso, direção e orientação da esquiva com mouse/tecla no mesmo frame.

Instrumentação: ActionMetrics mede tempos unscaled de frame, percentil, maior duração de resolução melee, frames até marcador, HTTP iniciado pelos clientes narrativos existentes e erros/exceções durante a sessão. Timers de melee incluem callbacks; não são um perfil individual do custo de IA, veneno, área ou GPU. A coleta é limitada a 36.000 frames por sessão. Não há operação de rede síncrona no gameplay: modo determinístico não envia HTTP, e modo consultivo usa UnityWebRequest/corrotina com revalidação.

Não houve teste de carga MMO, múltiplos jogadores, mobile ou avaliação humana de equilíbrio. O próximo trabalho de performance seria medir a build com profiler e uma sessão longa de gameplay real, incluindo máximos e percentis mais altos, após feedback sobre este recorte.
