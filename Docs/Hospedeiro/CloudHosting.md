# Hospedagem e latência — 24/10/2026

Meta solicitada: até 100 ms de ida e volta do jogo para jogadores no Brasil. É uma meta, ainda sem medição em dispositivos/redes reais. Todos os testes desta mudança foram locais. Previsão de movimento reduz a espera visual, não a distância da rede.

## Situação

Cliente já publicado no Worker/R2. Nakama, Godot autoritativo e motor Go ainda executam no PC, acessados pelo túnel. Publicar arquivos na borda não move esses processos para o Brasil.

A conta Cloudflare já tem Workers Paid, R2 e acesso a Containers. Nenhum recurso de outro projeto foi modificado. Workers comuns não executam os binários Go/Godot/Nakama; precisam de um container ou servidor de origem.

O Supabase arquivado foi retomado pelo usuário. A região `us-east-1` foi inferida pelo DNS e pelas faixas oficiais de IP da AWS, depois confirmada no painel do projeto `mmorpg`. A preparação oficial do Nakama foi aplicada ao schema privado desse projeto, mas **o jogo não foi apontado para esse banco dos EUA**. Para a meta brasileira, usar um novo projeto em São Paulo (`sa-east-1`). O projeto antigo foi pausado para liberar uma das duas vagas gratuitas; o painel confirmou a pausa. O formulário `hospedeiro-brasil` ficou preparado em São Paulo, com Data API desligada, aguardando o usuário definir a senha e concluir a criação. Não alterar outros projetos da organização.

## Opção de menor custo previsível

Uma VPS em São Paulo, com Go, Godot e Nakama juntos, mantém os saltos internos em loopback e o log Go em disco persistente. Usar Supabase em São Paulo para as identidades Nakama. Referência de orçamento: Vultr Cloud Compute, 1 vCPU/2 GB por US$10/mês, região `sao` disponível na consulta pública de planos em 24/10. A opção de 1 GB custa US$5, mas a capacidade conjunta dos três processos não foi validada nessa memória. Não foi contratado servidor nem assumida uma nova mensalidade.

O Supabase existente evita contratar outro banco. O plano gratuito e seus limites/pausas continuam aplicáveis; não prometer disponibilidade permanente gratuita.

## Alternativa Cloudflare Containers

Restringir o placement a `SAM` (América do Sul), sem fallback para EUA. Isso não é garantia de uma cidade brasileira específica. Manter os três processos na mesma instância e reservar apenas uma autoridade por mundo. O console Nakama não deve ser publicado.

Estimativa adicional para uma instância `basic` de 1 GiB/0,25 vCPU/4 GB sempre ligada, mês de 720 horas: cerca de US$6,26 de memória + US$0,68 de disco, mais CPU ativa (até cerca de US$12,51 se saturada continuamente), tráfego e impostos. As franquias são compartilhadas com outros recursos da conta; a memória necessária ainda precisa ser dimensionada. O Workers Paid base já existe. Assim, Containers não é automaticamente a opção mais barata para um mundo ativo 24h.

Antes do corte faltam:

- Banco em `sa-east-1` e credenciais de execução privadas.
- Persistência durável do log de comandos Go: o `FileLog` atual não pode ficar no disco efêmero de Containers. Snapshots de filesystem/R2 não substituem a confirmação durável de cada comando.
- Imagem Linux versionada com Go, Godot e Nakama; supervisor, encerramento ordenado e recuperação da autoridade. Este ambiente ainda não tem Docker/WSL Linux pronto para construir/validar essa imagem.
- Publicação da origem e corte do Worker, conservando chaves e a autoridade única. Não foi feita migração do servidor de jogo para cloud nesta mudança.

## Preparação PostgreSQL reproduzível

`scripts/prepare-hospedeiro-postgres.py` lê uma conexão administrativa de um `.env` ignorado e exige TLS com verificação completa fora de loopback. `--ca` substitui o caminho antigo do certificado. A saída deve ficar fora do checkout.

`--reset` apaga os schemas de aplicação `game` e `nakama`; não apaga schemas internos do Supabase. O banco observado antes da preparação tinha `public` sem tabelas/views e nenhum `game`. Não executar esse reset como verificação do mundo publicado.

A preparação usa as migrações oficiais do Nakama 3.41.0, `pg_trgm` em `extensions`, schema privado `nakama`, role de migração dona do schema e role de execução com DML/uso de sequências, sem CREATE no schema. Revoga acesso de `PUBLIC`, `anon` e `authenticated`. Não expor o schema pela Data API. Os clientes usam Nakama, sem receber URL PostgreSQL ou senha.

O supervisor aceita `-DatabaseEnv <arquivo>` com `HOSPEDEIRO_NAKAMA_DATABASE_URL` e `HOSPEDEIRO_NAKAMA_MIGRATION_URL`. Sem essa opção, conserva o PostgreSQL local. Usar conexão direta; pooler exige revisão do nome de usuário e modo de sessão. Não usar transaction pooler por suposição.

## Referências oficiais

- [Supabase: regiões](https://supabase.com/docs/guides/platform/regions), [conexão PostgreSQL](https://supabase.com/docs/guides/database/connecting-to-postgres).
- [Cloudflare: placement](https://developers.cloudflare.com/containers/concepts/placement/), [preços](https://developers.cloudflare.com/containers/platform/pricing/), [limites](https://developers.cloudflare.com/containers/platform/limits/), [filesystem e ciclo de vida](https://developers.cloudflare.com/containers/faq/).
- [Vultr: API pública de planos](https://api.vultr.com/v2/plans).
- [Nakama: configuração](https://heroiclabs.com/docs/nakama/getting-started/configuration/), [comandos de migração](https://heroiclabs.com/docs/nakama/getting-started/commands/).
