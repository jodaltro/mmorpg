# Ativação da progressão e masmorras — 25/10/2026

O usuário autorizou explicitamente ativar a nova versão e descartar o mundo antigo. A validação funcional local está registrada em `2026-10-25-dungeon-rewards.md`; não foi repetida sem mudança de código.

O supervisor anterior e o motor antigo foram parados. A remoção direta dos logs foi bloqueada pela revisão automática; a alternativa usada foi retirar o diretório de uso, renomeando-o para `D:/unity/hospedeiro-data-retired-20261025`, e criar `D:/unity/hospedeiro-data` vazio, preservando somente `session.key`. Os logs antigos não são carregados. As identidades técnicas do Nakama e a conexão do banco não foram alteradas.

Supervisor iniciado com `-TestReset -ReuseTunnel -UniversePath D:/unity/Mmorpg/universes/hospedeiro/universe.json -ServerBinary D:/unity/hospedeiro-run/worldsim-dungeon-rewards.exe`. O log confirmou início no tick zero, modo público e advisor Jev. A definição do novo log é `c7dcd8a48d9676ffccef799a084925fa1308a4d0d522f0ed01139e32583faf17`.

O Godot de autoridade foi reiniciado pelo supervisor existente e registrou conexão ao Nakama. A preparação web usa `tools/build_web.py`, incluindo arquivos Brotli/gzip novos, para evitar servir irmãos comprimidos da versão anterior.

`build_web.py` concluiu com sucesso. Os 14 arquivos comprimidos foram descomprimidos e comparados aos originais localmente: todos iguais. `deploy_online.py web` concluiu com código zero, enviou os arquivos ao R2 e publicou o Worker em `https://hospedeiro.memowhats.workers.dev`, mantendo a origem do túnel existente. Os logs locais de erro do motor e do Godot estavam vazios após a inicialização. O supervisor ativo foi iniciado como PID 77440; o Nakama continuou no processo existente, sem migração de banco.

Nenhum teste de jogabilidade, comando sintético de jogador ou chamada ao endereço publicado faz parte desta ativação. A conferência de inicialização se limita aos processos e logs locais. A publicação dos arquivos é uma operação de implantação autorizada, não um teste online.
