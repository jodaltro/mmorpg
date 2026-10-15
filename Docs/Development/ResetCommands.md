# Comandos de sessão — 06B.4

`LocalSessionCommands` é o único dono de Esc e dos reinícios na cena B4. O menu oferece Continuar, Reiniciar sessão, Nova jornada (desenvolvimento), Configurações (volume geral) e Sair. Esc durante diálogo fecha o diálogo. Pausa usa tempo zero; painel de diagnóstico continua passivo. F5 e Ctrl+Shift+R só são lidos no Editor/Development, e Nova jornada é escondida nas builds finais.

A HUD precisa de GraphicRaycaster e a cena de um EventSystem com InputSystemUIInputModule/ações UI atribuídas. `ProductionArt06B4.RepairPauseInput` corrige esses componentes sem reconstruir o menu; a ferramenta Integrate também os configura. Os botões foram verificados por cliques de Mouse no Input System, inclusive durante a pausa com tempo zero.

## Perfil e proteção

A cena B4 usa `Application.persistentDataPath/DevelopmentJourneys/marco06b4/`, com identidade própria. Não importa/sobrescreve silenciosamente os saves B1/B2/B3 ou pessoais. Retomar B4 carrega o perfil B4 existente. As inspeções usam exclusivamente `Temp/Marco06B4/<GUID>` por override; esse caminho não faz parte da configuração serializada da cena.

Lista de propriedade: `journey.json`, suas variantes `.bak/.tmp`, `marco06b1-exploration.json`, suas variantes `.bak/.tmp`, `profile.json`, `decision-cache.json` (somente se existir). Não há PlayerPrefs.DeleteAll, remoção recursiva, varredura para apagar arquivos ou chamada remota de exclusão. O cache local de decisões existente está dentro do snapshot; o arquivo de cache separado é reservado, não inventado.

## F5 / Reiniciar sessão

Avança epoch, aborta requisições de decisões rastreadas, cancela corrotinas temporárias, captura o snapshot, aguarda o writer de persistência, salva exploração e suspende escritas dos componentes antigos. Recarrega a cena atual por SceneManager, preservando identidade, inventário, habilidades, fatos, oportunidades e estados salvos. Recria saúde/motores/visuais transitórios e usa a entrada regional segura já existente. Não depende de Application.Quit.

## Ctrl+Shift+R / Nova jornada

Abre confirmação com identidade resumida e lista de dados. Esc/Cancelar não limpam nada. Confirmar executa o mesmo encerramento de tarefas/saves, copia todos os arquivos da allowlist existentes para `Backups/<UTC-GUID>`, compara bytes de todos os backups e somente então remove os arquivos pertencentes ao perfil. Gera identidade nova e recarrega a cena. Falha de limpeza tenta restaurar os arquivos do backup; falha de backup impede qualquer remoção.

Se há `SupabaseSession.HasSession`, ambos os reinícios são bloqueados e o menu solicita sair explicitamente do online. O comando não efetua logout implícito, nem toca Supabase/Go/OpenRouter. Perfil inválido bloqueia a inicialização dos módulos locais, sem fallback para saves pessoais. Corrupção do save de jornada usa a recuperação checksum/backup preexistente; erro de persistência impede o reinício.

`SessionEpoch.Current` é monotônico no processo e muda em cada transição/abertura. Clientes verificam epoch antes de entregar respostas; coordenadores de Mira/mundo verificam também Engine/World e epoch antes de aplicar. `SessionEpoch.Track` mantém requisições ativas para Abort. Identidade de sessão local não substitui actorId/worldId de domínio. Ao encerrar Play/sair sem reload, os overrides estáticos anteriores são restaurados.

Não foram executadas migrações ou exclusões remotas. Não há serviço remoto novo nem limpeza de diretório genérico.
