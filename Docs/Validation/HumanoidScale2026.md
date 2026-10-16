# Corpos maiores dentro de Valdoria — 2026-10-16

Pedido: visualizar a família Quaternius dentro do jogo antes de escolher a direção artística.

Cena: `Assets/Mmorpg/Scenes/HumanoidScale2026.unity`, cópia experimental do mundo oficial. Female representa Mira; Male representa Orin. Iron Knight permanece como comparação. As bases ainda estão sem roupas finais. Nenhum desenho foi refeito nesta integração.

![Captura real em Play](HumanoidScale2026/gameplay/overview.png)

## Importação e limites visuais

Dois atlas originais copiados para `Assets/Mmorpg/Art/Experimental/HumanoidScale2026/`: 52 sprites por corpo, oito clips demonstrados (idle/walk nas quatro direções), canvas 128×160, 32 PPU, Point, FullRect, sem compressão/mipmaps, pivô Unity (64,34). Fonte CC0 e hashes em `ArtSource/Labs/Humanoid2026/provenance.json`. A resolução nativa maior está preservada.

O mundo não foi ampliado nesta comparação: corpos ficam visivelmente maiores que os NPCs anteriores e portas/etiquetas ainda usam a escala antiga. Pivô único é uma calibração inicial, não certificação de contato de pés durante toda a animação. Protagonista, combate e roupas complexas ainda não foram migrados. A apresentação não constitui aprovação artística.

## Verificação executada

Unity 6000.6.5f1 conectada via CLI Pipeline; autotick habilitado; recompilação up_to_date sem erros. Play real avançou de 9321 a 17690 frames na execução completa. Capturas são Game View real, sem composição.

- Mira e Orin: quatro idles e 12 frames de caminhada por direção, dois ciclos demonstrados em cada direção, trocando sprites somente durante inspeção em Play. Os NPCs continuam estáticos na cena salva.
- Input real de teclado: diálogos E de ambos, contato frontal caminhando, contato traseiro e oclusão frente/costas equivalentes ao mundo oficial. Posicionamento de inspeção usa Rigidbody; não foi validada navegação ao redor dos NPCs. A primeira tentativa dessa rota encontrou obstáculo e foi substituída por posicionamento explícito para o teste de oclusão.
- HUD e zoom da câmera mantidos; F5 recarregou a cena experimental, preservando identidade e fatos do perfil isolado. Herói vivo após recarga.
- Console final: zero erros e zero avisos. Input e opções do Editor restaurados ao sair de Play; override de perfil removido.
- 232 arquivos protegidos inalterados, cinco arquivos pessoais de save inalterados, colliders/identidades/interações dos dois NPCs preservados. Entrada oficial continua no índice zero; apenas esta cena foi acrescentada ao build.

Evidências: [QA](HumanoidScale2026/gameplay/qa.json), [preservação](HumanoidScale2026/preservation.json), capturas de cada direção/diálogo/oclusão na pasta `HumanoidScale2026/gameplay/`. O registro captures.jsonl inclui as duas tentativas.

## Reprodução

Criação única: abrir mundo oficial limpo, executar `BuildHumanoidScale2026.Preflight`, depois `ImportAndCreate` via run_script. Recusa sobrescrever cena/atlas existentes.

Inspeção: abrir cena experimental limpa; `InspectHumanoidScale2026.Prepare`, editor_play, `InspectIronKnight06B11.Setup`, `InspectHumanoidScale2026.Inspect`, opcional `Present`, editor_stop, `InspectIronKnight06B11.Cleanup`, `BuildHumanoidScale2026.Verify`. Todos os comandos usam `--caller plugin --skill unity-pipeline`. A cena ficou aberta e parada, pronta para revisão no Editor.
