# Marco 06B.4 — entrega e validação

**Integração técnica implementada; aprovação artística definitiva pendente.** O herói continua com duas poses de caminhada por direção. Não foram obtidos os 32 desenhos de ciclo natural exigidos. Duas propostas do gerador integrado foram reprovadas por apoio repetido/continuidade inadequada e permaneceram fora do gameplay. Não se apresenta repetição, translação ou aumento de FPS como oito fases novas.

## Entrega

- Cena nova: `Assets/Mmorpg/Scenes/Marco06B4Polish.unity`. B3 e cenas anteriores preservadas; geração recusa sobrescrever destino existente. B4 foi acrescentada às cenas de build, sem trocar a cena inicial anterior.
- Corpo filho em VisualRoot, raiz física preservada, metadados de mão por quadro, espada separada única e fases visuais de preparação/corte/recuperação no Sweep existente. Retoques locais de luva em dois derivados; sem modificar PNGs fornecidos ou Processed B3.
- Fontes: `ArtSource/Characters`, `Creatures`, `Weapons/IronSword`, `VFX`, `Terrain`, `Environment`, `Interface`; referências rejeitadas em `ArtSource/References/Rejected`.
- 92 entradas de personagens/criaturas migradas e 11 PNGs auxiliares (espada + efeitos existentes); não são desenhos novos. 77 clips de personagem com contagens/status reais. Herói: 24 entradas, incluindo stances reutilizadas; 8 entradas walk = 2 poses por vista. NPCs: uma pose frontal cada. Expansão de monstros permanece preparada/provisória, com gameplay/visuais B3 preservados.
- Saídas importadas: `Assets/Mmorpg/Art/Production`, `Animations`, `Auxiliary`, `Prefabs/PlayerVisualB4.prefab`. Reimportação verificou **103 GUIDs/local IDs de sprites preservados** ([evidência](Marco06B4/reimport.json)).
- Ferramentas: `Tools/ArtPipeline/production.py`, `production_verify.py`, `gameplay_previews_b4.py`; `AgentScripts/ProductionArt06B4.cs`, `InspectPolish06B4.cs`, `InspectLayout06B4.cs`, `InspectSessionGuards06B4.cs`.
- Câmera adaptativa em escala inteira, grade 32 PPU e limite externo do Ground. Vida/slots/cooldowns/contexto/região existentes mantidos. Mensagens curtas expiram em 5 s; longas vão ao Diário.
- Esc com menu de sessão/configuração de volume; F5 preserva perfil; Ctrl+Shift+R exige confirmação e backup; F8 diagnóstico; Ctrl+F8 histórico; F7 mão/lâmina/Sweep. Desenvolvimento oculto nas builds finais por diretivas de compilação.

## Verificações executadas

Unity Editor **6000.6.5f1**, CLI conectado com `--caller plugin --skill unity-pipeline`, autotick 16 ms. Recompile e recompile_status concluídos sem erros; Console ground truth sem erros/warnings na inspeção registrada. Os contadores históricos do buffer Pipeline contêm mensagens anteriores e não equivalem a erros desta execução ([console](Marco06B4/console-status.json)). Não foram executadas suítes completas de EditMode, PlayMode, Go ou SQL, nem build de distribuição.

| Inspeção curta | Resultado observado |
|---|---|
| Execução/frames | Play real com avanço de milhares de frames e input sintético Input System; sem teleporte na caminhada |
| Walk quatro direções | Dois sprites distintos por direção, observados em múltiplos ciclos; oeste inclui idle após contato com obstáculo. Não oito poses |
| Mãos | Âncoras revisadas em prancha/execução; QA final exige alfa >150 no pixel da empunhadura de todos os frames do herói |
| Ataque quatro direções | Preparação, corte e recuperação capturados; corpo ainda usa poses adaptadas |
| Sweep | Ciano vem do loop físico real, amarelo da geometria mostrada, magenta da empunhadura; erro máximo de endpoints geométricos durante janela ativa ~1,43×10⁻⁶ unidade na amostra final. Isso não comprova qualidade anatômica do ataque |
| Lobo/dano | Combate real: lobo 60→0, jogador 100→70; recebeu dano e confirmou derrota. Esquiva e impacto existentes continuam ligados aos estados/acertos |
| Acontecimentos | CreatureDefeated, EvidenceCollected, NpcInteracted e EvidenceDelivered reais; decisão local Mira científica, alerta florestal, validação aceita, consequência, save e apresentação observáveis com correlação |
| F5 | Identidade preservada; descoberta de exploração persistida recuperada após reload |
| Nova jornada | Confirmação abriu; Esc cancelou sem mudar identidade; confirmar criou backup e identidade nova, limpando a descoberta do perfil temporário; arquivo sentinela alheio preservado |
| F8 | Mostrar/ocultar verificados nos dois sentidos; painel não pausa o jogo |
| Go indisponível | GET real do health terminou em timeout ~2 s. Supabase permaneceu não verificado |
| Jev não configurado | Modo determinístico local claramente identificado; nenhuma chamada OpenRouter |
| Bloqueio online | Guard exercitado com fixture em memória de sessão autenticada; sem login/rede real. Reset recusado. Não é evidência de Supabase conectado |
| Epoch e recuperação | Probe isolado rejeitou resposta tardia após avanço de epoch (zero decisões aplicadas); save Temp corrompido recuperou `.bak` verificado |
| Importação | RGBA, dimensões, pivôs, durações, arquivos, hashes, numeração e unicidade verificadas pelo Python; reimport preservou IDs |

Todas as inspeções de persistência B4 usaram `Temp/Marco06B4/<GUID>`. Os backups/evidências registram o caminho efetivo. Não foi apagado save pessoal, diretório genérico ou dado remoto. Os probes de guard/recuperação são fixtures locais explicitamente identificadas; as capturas de caminhada/combate são gameplay real do Editor.

## Evidências

- [Cena/escala final](Marco06B4/final-village.png), [monitor](Marco06B4/monitor.png), [histórico de acontecimentos](Marco06B4/events-history.png), [menu Esc](Marco06B4/pause.png).
- [Caminhada provisória em GIF](Marco06B4/walk-provisional.gif) e [ataque com empunhadura/Sweep em GIF](Marco06B4/attack-grip-sweep.gif).
- [Confirmação](Marco06B4/reset-confirmation.png), [após F5](Marco06B4/after-f5.png), [nova jornada](Marco06B4/after-new-journey.png).
- [Combate](Marco06B4/fight-01.png), [resultado do lobo](Marco06B4/wolf-result.png), [relato de combate e correlações](Marco06B4/combat-inspection.txt).
- [Relato de reinícios](Marco06B4/reset-inspection.txt), [F8 e guard online](Marco06B4/guard-inspection.txt), [epoch/backup](Marco06B4/session-guard-probes.txt), [walk observado](Marco06B4/visual-inspection.txt).
- [Recuperação de uma cópia da jornada real e revisão final do monitor](Marco06B4/recovered-monitor.txt), [compilação final](Marco06B4/compile.json). O histórico expandido foi revisto com IDs resumidos e quatro registros visíveis.
- [Manifesto das prévias](Marco06B4/previews.json), [metadados das capturas](Marco06B4/capture-metadata.jsonl), [prancha de attachments](../Art/PreviewsB4/hero-attachments.png), [QA dos clips](../Art/PreviewsB4/source-qa.json).

GIFs montam capturas reais sequenciais com recorte que acompanha o jogador somente na prévia e ampliação nearest. São amostras de cadência, não vídeo de FPS constante, e não interpolam poses. Capturas `walk-*` e `attack-*` finais foram refeitas após os últimos ajustes de mão. O combate e os reinícios foram inspecionados antes do último retoque localizado de luva; as regras/código de sessão e combate permaneceram iguais.

## Limitações e próximos desenhos

Não aprovar artisticamente como polimento definitivo. Faltam 32 desenhos de walk com alternância real, ataques corporais próprios por direção, dodge completo, hurt e death. A reconstrução de duas luvas melhora o contato, mas não substitui animação profissional. Lobo ainda precisa corrida frontal/traseira, ataques completos e morte desenhada; NPCs não têm walk; expansão aranha/golem/morcego permanece limitada conforme B3. O retângulo geral de câmera reduz bordas externas, mas corredores entre regiões ainda podem mostrar áreas não compostas. Backend online/Supabase/OpenRouter real e builds finais não foram exercitados.

Não houve alteração de backend, esquema/serviços remotos, regras de dano/cooldown/habilidades, modelo de missões/propostas ou pacotes. Nenhuma chamada paga ou commit automático.

Documentação: [contrato](../Art/ProductionAssetContract.md), [herói](../Art/HeroAnimation.md), [arma](../Art/WeaponAttachment.md), [pipeline](../Art/ProductionPipeline.md), [diagnóstico](../Development/DebugOverlay.md), [reinícios](../Development/ResetCommands.md).

## Correção dos cliques no menu Esc

A cena estava sem GraphicRaycaster na HUD e sem EventSystem. Os atalhos funcionavam, mas os botões não recebiam cliques. A inspeção inicial acionava a confirmação por `onClick.Invoke` e não detectou a falta do caminho de entrada; esse resultado não comprovava funcionamento por mouse.

`ProductionArt06B4.RepairPauseInput` adiciona somente o raycaster e um EventSystem com InputSystemUIInputModule e ações UI padrão, preservando a hierarquia. `Integrate` também garante esses componentes em gerações futuras.

A nova inspeção `InspectPolish06B4.PauseButtons` usa eventos reais de posição/press/release de Mouse via Input System, sem Invoke nos botões. Verificou Continuar, Configurações, slider de volume (0,25), Voltar, Reiniciar sessão com recuperação, Nova jornada/Cancelar, Confirmar com backup em Temp e Sair encerrando Play. Volume e configurações de inspeção são restaurados. [Resultados](Marco06B4/pause-mouse-validation.txt), [captura do menu](Marco06B4/pause-mouse-fixed.png).
