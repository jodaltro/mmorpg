# Marco 06B.8 — rig 2D determinístico

2026-10-15. **Rig experimental criado; caminhada reprovada artisticamente. Não supera perceptivelmente o B7.** Sem expansão para outras direções ou integração na Unity. O objetivo principal de movimento natural permanece não atingido.

## Entrega

Diretório: `ArtSource/Labs/AnimationResearch/Marco06B8/`.

- [Documento Aseprite R2](../../ArtSource/Labs/AnimationResearch/Marco06B8/hero-rig-south-r2.aseprite), [rig/coordenadas/proveniência](../../ArtSource/Labs/AnimationResearch/Marco06B8/hero-rig-south-r2.aseprite.rig.json).
- [GIF R2 com dois ciclos](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/two-cycles.gif), [B7 × B8](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/b7-vs-b8.gif), [original × B8](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/original-vs-b8.gif).
- [Oito poses](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/poses.png), [articulações](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/joints.png), [articulações animadas](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/joints-two-cycles.gif).
- [Trajetória das solas](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/foot-trajectory.png), [CSV](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/foot-trajectory.csv), [QA/violações](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/qa-report.json), [mãos candidatas](../../ArtSource/Labs/AnimationResearch/Marco06B8/review-r2/manifest-candidate.json).
- [Reprodutor local](../../ArtSource/Labs/AnimationResearch/Marco06B8/review.html): servir `ArtSource/Labs` e abrir `/AnimationResearch/Marco06B8/review.html`.

`hero-rig-south.aseprite`, `frames`, `parts` e prévias na raiz conservam R1. Sufixo `-r2` identifica a extração corrigida. São oito poses por tentativa, não dezesseis fases de caminhada. Fontes editáveis fora de Assets; nenhuma arte final aprovada.

## Diagnóstico B7 e referência Rig

Lidos: B5, B6, B6-R1, B7, workflow Aseprite, contrato, HeroAnimation, ProductionPipeline, WeaponAttachment e GameVision. B7 R2 foi aberto pelo Aseprite Lua para leitura real dos cels e sua prancha inspecionada. Quatro poses, joelhos convergentes e quadril quase imóvel confundem cruzamento com flexão. A retração de aproximadamente 3 px não acompanha 53,76 px percorridos em 480 ms a 112 px/s.

O [projeto de referência](https://github.com/JatCool/AI-Sprite-Animation) documenta um modo Rig sem ComfyUI: máscaras, hierarquia, pixels originais, composição sem AA e exportação. Seu foco lateral exige adaptação para pernas frontais, oclusão sob a túnica e articulações projetadas. Alinhar o pixel inferior à linha do chão não constitui foot lock mundial. Não instalamos o package nem copiamos código. Criamos um Lua pequeno para este herói/vista. A composição 4× com voto majoritário da referência não foi implementada: nosso protótipo usa retarget inverso nearest em pixels inteiros.

## Rig e pixels

17 partes: cabeça, cabelo, tronco, quadril, roupa, dois braços superiores, antebraços, mãos, coxas, canelas e botas; mais uma camada oculta de articulações. Cada parte tem cels editáveis, pivô, hierarquia, profundidade, máscara alfa/faixa Y, origem e limite angular declarados. Canvas 96×96, 32 PPU, pivô (48,70). Coordenadas de ombros, cotovelos, mãos, quadril, joelhos e tornozelos por amostra no JSON.

R2 extrai perna direita/braço esquerdo do terceiro frame B7; demais partes do primeiro. Máscaras são alfa da camada de origem intersectado com faixas Y explícitas, com sobreposição nas juntas. A primeira tentativa extraía a canela direita de uma perna já encurtada em perspectiva. R2 usa a pose estendida e reposiciona joelhos relativamente aos tornozelos: violações caem de 24 para 20, mas anatomia permanece inadequada.

A hierarquia está declarada; as poses fornecem endpoints absolutos. Não há solver FK/IK que preserve comprimento anatômico. Retarget longitudinal comprime/estende pixels, preservando espessura perpendicular. **Limites são diagnósticos: as violações reprovam o candidato, não são resolvidas pelo renderer.** Este rig não satisfaz ainda o contrato de um rig anatômico final.

QA confirmou oito hashes RGBA distintos, alfa binário, cores exclusivamente da origem e recorte cabeça/rosto idêntico nos oito frames. Paleta visual RGBA preservada; não se certificou organização idêntica das amostras na tabela de paleta do documento. Não foram pintados oito personagens independentes. Pillow apenas monta prévias/QA; transformação e autoria do personagem são Aseprite Lua.

## Apoios e medidas

Fases: contato esquerdo, absorção esquerda, passagem direita, elevação direita, contato direito, absorção direita, passagem esquerda, elevação esquerda. Esquerda anatômica fica à direita da imagem. Quadril local X: 0,1,2,1,0,-1,-2,-1 px. Absorção vertical atua no quadril/pernas; cabeça fixa; braços contrabalançam. Tronco ainda transmite pouco peso.

Modelo retilíneo sul: 3,5 u/s × 32 = 112 px/s. dt=30 ms; ciclo=240 ms; deslocamento=26,88 px/ciclo; apoio=120 ms. Pé de apoio recua 3,36 px por amostra: sola alvo Y=89 / 85,64 / 82,28 / 78,92. O outro pé tem trajetória suspensa própria. Não se congelam ambos. Linha y88 é referência do idle, não correção global de altura dos frames.

**Medição em modelo de translação; não gameplay real.** Mundo projetado = sola local + 112×tempo. Sola = linha inferior opaca da camada de bota; centro horizontal dessa linha fica constante durante apoio. R2 renderiza Y=89 / 86 / 82 / 79. A diferença maior–menor posição mundial nos quatro instantes amostrados é **0,64 px por apoio** (0,02 u).

Isso não elimina deslizamento: durante a sustentação de cada PNG, a raiz anda **3,36 px**. Erro relativo ao contato inicial tende a **3,72 px** antes da troca; intervalo pico a pico ao longo do apoio tende a **4,00 px**, incluindo quantização. Trocas saltam 3–4 px para compensar. CSV contém os instantes iniciais, não toda a deriva entre frames. Não há foot lock contínuo. Não foram medidos aceleração, colisão, diagonal ou transições no jogo.

O orçamento inicial de retração de 13,44 px por apoio levou a 240 ms/ciclo: 4,17 ciclos/s ou 500 passos/min, excessivo para caminhada legível. Esta cadência foi calculada e **reprovada**, não aprovada como calibração final. Desacelerar sem ampliar/reprojetar a passada aumenta deslizamento. Nenhuma velocidade física, root motion ou bobbing foi alterado para mascarar isso.

## Revisão temporal e decisão artística

Pranchas R1/R2 abertas. Reprodutor local executado no navegador com B7/R2 lado a lado e pixels nativos: estados avançaram de 149 ms/frame 4 para 4704 ms/frame 4/19 ciclos e 11594 ms/frame 2/48 ciclos; capturas mostraram poses renderizadas. Reprodução limitada a dois ciclos acionada e término observado parado no frame 7/tempo amostrado 479 ms (intervalo solicitado 480 ms). Isso confirma execução temporal no navegador, sem alegar observação humana contínua de cada instante ou playback no Aseprite GUI.

GIF R2: 16 frames, 480 ms, dois ciclos, sem extensão de loop infinito; ampliação 4× nearest. Comparações preservam B7=120 ms/pose e original=125 ms/pose, sem desacelerá-los para favorecer B8. A comparação tem dois ciclos B8, um B7 e 1,92 ciclos originais, identificados pelos clocks.

O resultado continua marcha rápida: botas lateralmente rígidas, canelas achatadas e quadril numericamente deslocado sem resposta legível da massa do tronco. Passagens 002/006 aproximam botas e comprimem canelas; 003/007 recuperam comprimento abruptamente. Retorno 007→000 muda pé elevado para contato sem rolagem convincente da sola. **Loop e transferência de peso reprovados; não é uma melhora perceptível sobre B7.**

Ainda requer desenho localizado nas máscaras de junta e conexões quadril/coxa (x38–57/y68–78), joelho/canela/bota (x38–58/y72–88), cotovelos/punhos (x28–39 e x57–67/y61–77), ponta/calcanhar e resposta de torso/ombros. Não basta acrescentar quadros. Preservação de cores não garante contorno, proporção ou peso.

Mãos direita/esquerda medidas por frame, arredondadas ao pixel, verificadas sobre alfa opaco da própria camada de luva. Manifesto candidato fornece conversão para `ProductionFrame.hand`, com status reprovado/não importável. **Espada não conectada nem validada.** Continuidade dos punhos ainda precisa de acabamento. Espada segue separada; SwordSwing e geometria dos ataques não foram modificados.

Gate da etapa 9 não satisfeito: sem cena nova, importação, Unity CLI, recompile, Play/input, Console ou testes de espada. Não declarar essas verificações aprovadas. Nenhuma suíte extensa executada. Produção, gameplay e cenas preservados.

## DirectML: diagnóstico sem instalação

CIM confirmou Windows 10 Home 10.0.19045/build 19045, Radeon RX 5700 XT e driver 32.0.12019.1028. Python padrão 3.14.7. Os 8 GB são informação de hardware fornecida pelo usuário; não se usou AdapterRAM truncado como medição. Sem instalação de drivers, CUDA, ROCm, ComfyUI, modelos ou runtimes ML. Zero chamadas pagas.

[Microsoft Learn](https://learn.microsoft.com/en-us/windows/ai/directml/pytorch-windows) descreve PyTorch/DirectML em preview para GPUs DirectX 12 desde Windows 10 1709: SO atende. [README Microsoft](https://github.com/microsoft/DirectML/blob/master/PyTorch/README.md) indica Python 3.8–3.12; [PyPI](https://pypi.org/project/torch-directml/) oferece 0.2.5.dev240914, com wheels Windows até CPython 3.12, sem wheel 3.14. Futuro experimento deve usar ambiente isolado 3.10/3.11, resolver e pinar torch/torchvision/torch-directml e começar pela soma de tensores no dispositivo real. O repositório [DirectML](https://github.com/microsoft/DirectML) anuncia manutenção: risco de atraso em relação às APIs atuais.

**RX 5700 XT é candidata plausível via DirectML; funcionamento/desempenho nesta máquina não foram demonstrados.** Não se presume ROCm ou ComfyUI/AnimateDiff funcionais. Nós com `.cuda()`, extensões CUDA, Triton/xformers e operadores específicos podem exigir substituição. Suporte genérico a PyTorch não garante todos os operadores/tipos.

Alternativa: [ONNX Runtime DirectML](https://onnxruntime.ai/docs/execution-providers/DirectML-ExecutionProvider.html) para inferência; documenta opset até 20 com exceções, execução sequencial e memory pattern desabilitado. Inspecionar grafo/provider real, sem atribuir fallback CPU à GPU.

Pose futura: detector leve com keypoints exportado para ONNX, ou Keypoint R-CNN como teste de compatibilidade — não há garantia de operadores nem reconhecimento de sprites. [Código oficial Torchvision](https://github.com/pytorch/vision/blob/main/torchvision/models/detection/keypoint_rcnn.py): 59.137.258 parâmetros, aproximadamente 226 MiB apenas em pesos FP32. Ativações, cópias e workspace dependem da resolução. Reserva preliminar de engenharia de 1–3 GiB para detector batch=1 é estimativa a medir, não benchmark nem orçamento de AnimateDiff. Unity/desktop também consomem os 8 GB. Pose humana de fotos não resolve automaticamente a projeção estilizada deste herói.

Recomendação futura: prova mínima isolada com tensor e depois pequeno grafo/modelo autorizado, medindo dispositivo e memória, sem difusão nesta etapa. O gargalo demonstrado aqui é anatomia projetada e acabamento dos pixels.

## Respostas da entrega

| Pergunta | Resultado |
|---|---|
| 1. Rig criado? | Sim, protótipo de 17 partes; restrições ainda não resolvidas. |
| 2. Articulações? | Quadril, ombros, cotovelos, mãos, joelhos e tornozelos; cabeça fixa. |
| 3. Rosto/paleta preservados? | Sim, verificados por hash e conjunto RGBA. |
| 4. Melhor que B7? | Não. |
| 5. Apoios alternam? | Sim no modelo L→R; sem comprovação em jogo. |
| 6. Peso legível? | Insuficiente. |
| 7. Erro dos pés? | 0,64 px entre amostras; até 3,72 px relativo ao contato entre trocas, no modelo. |
| 8. Loop natural? | Não. |
| 9. Quadros? | Oito R2 distintos; oito R1 arquivados separadamente. |
| 10. Espada validada? | Não; somente âncoras de luva candidatas. |
| 11. Teste Unity? | Não, gate artístico reprovado. |
| 12. Trabalho artístico? | Joelho/canela, quadril, sola, punhos, torso e cadência. |
| 13. DirectML futuro? | Plausível; exige ambiente compatível e teste real. |
| 14. Limitações? | Retarget estica/comprime membros, limites diagnósticos, deriva entre frames, projeção frontal e cadência excessiva. |

## Reprodução e verificação

Lua: `Tools/ArtPipeline/Aseprite/hero_b8_rig.lua`, executado no Aseprite local 1.3.18.6 com `-b --script-param output=<novo.aseprite> --script <caminho-do-lua>`. Recusa documento existente. Versão atual reproduz R2 a partir de B7. Usar caminhos absolutos e aguardar o arquivo finalizar antes de encadear exportação. Não executar migração B3/production.py.

Exportar pelo helper `aseprite.py export` para pasta nova, ou CLI direta com `--save-as frame_{frame000}.png`, sheet horizontal e JSON. A primeira execução do helper encontrou JSON vazio em ambas as tentativas; exportações diretas subsequentes produziram arquivos válidos e `verify` passou nos dois conjuntos. Não se reporta a execução falha como aprovação.

`inspect_b8.lua` reabre oito frames/18 camadas, verifica durações e exporta botas/luvas para pasta nova via `--script-param dir=...`. `hero_b8_review.py -r2` gera revisão R2; sem argumento processa R1. Recria somente derivados de revisão: não usar sobre retoques manuais. Pillow emitiu avisos de depreciação getdata, sem falha de QA.

Lua final executado novamente em Temp: oito PNGs reproduzidos RGBA idênticos aos oito R2 entregues. Recusa de sobrescrita observada. GIFs R2 verificados: 16 frames, 480 ms, sem extensão infinita. `py_compile` do script executado. QA confirma canvas, transparência, unicidade, cores da origem, cabeça estável, luvas opacas e trajetória por camada. `git diff --cached --check` exigido antes do commit.

Arquivos PixelLab B6-R1/B6-R2 e scripts locais preexistentes permanecem fora do commit. Nenhum checkpoint/cache/executável/licença adicionado. Commit/push somente da tarefa B8; resultado da publicação informado na resposta final.
