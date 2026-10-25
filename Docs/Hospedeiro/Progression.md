# Progressão por transformações — 25/10/2026

O ciclo passa a ser: explorar e combater → conquistar um gene ou uma nova habilidade → entender a mudança antes de expressar → montar uma combinação e experimentar no combate. Sem níveis nem XP. A classe continua sendo uma identidade permanente, e genes permanecem como escolhas de build; o objetivo é que recompensas mudem ações, alcance de atuação, defesa ou suporte, além dos atributos.

## Ritmo inicial

| Marco | Antes | Agora |
|---|---:|---:|
| Pressão por oferta de mutação | 30 | 120 |
| Maturidade da primeira diferenciação | 42 | 168 |
| Maturidade da classe final | 120 | 480 |

São quatro vezes os requisitos anteriores, sem multiplicar as recompensas de pressão para anulá-los. Os acessos a masmorras acompanham a escala. Não é uma promessa de duração em minutos: combate, exploração e missões podem produzir ritmos diferentes. Esse é um primeiro ajuste para avaliar em sessões de jogadores, não uma medição de retenção ou economia de longo prazo.

As dez provas de classe contam os feitos **depois da diferenciação**. Feitos da fase anterior não concluem a prova antecipadamente nem fazem sua oferta deixar de ser elegível antes de alcançar a classe. Isso é importante especialmente para as provas baseadas em 120 abates.

## Recompensas concretas

Treze missões, incluindo a primeira travessia e as dez provas de classe, concedem genes permanentes, além das recompensas existentes. Nas cinco masmorras, cada expedição gera até três genes elegíveis ainda não conquistados: vencer permite escolher um deles. A entrada e a sala segura mostram os mesmos prêmios, seus efeitos e como ativá-los. Quando o conjunto se esgota, a interface informa que restam apenas os recursos. Ver [Masmorras e recompensas](DungeonRewards.md).

A recompensa entra na **biblioteca**. Não substitui automaticamente um gene expresso e não abre uma escolha que interrompa o combate. O aviso **Gene conquistado** leva diretamente a Corpo → Genes. Expressar, trocar ou silenciar continua sendo uma intenção validada pelo motor, respeitando os bloqueios de reconfiguração.

## Dezoito genes com mecânicas adicionais

Os três genes de abertura ilustram escolhas diferentes: **Flagelo Calejado** acrescenta uma onda circular ao chicote; **Vesícula Tóxica** acrescenta dois projéteis em leque; **Núcleo Reativo** acrescenta um escudo ao impulso, com intervalo próprio.

Todas as dez classes têm um gene de transformação associado à sua prova. Entre as mudanças estão a poça ácida de Engolir, a aura tóxica da Rede de DNA, a descarga em cadeia dos Dendritos em Chicote, os anticorpos adicionais do Anticorpo Y, a ruptura retardada da Perforina e os pulsos reparadores das classes de suporte. Cinco outros genes genéricos acrescentam espinhos em cadeia, onda ao impulso, reparo, poça digestiva e escudo ao usar habilidades de classe.

Os efeitos preservam os custos e desvantagens dos genes. Efeitos ligados a disparos e explosões usam uma fração do dano da habilidade; habilidades sem dano direto usam a referência mínima declarada no adaptador de combate. Poças aplicam pulsos a cada 0,5 s. Escudos e efeitos genéricos têm intervalos próprios para impedir renovação sem limite. Curas respeitam o máximo de membrana e não curam inimigos. Não foi feito um novo balanceamento estatístico completo das combinações: os testes antigos de atributos não medem o valor dessas novas mecânicas.

## Escolher entendendo o resultado

As ofertas compactas abrem **Ver mudança**. A inspeção mostra a descrição inteira, custos, comparação **agora → depois** e só então **Expressar este gene**. Comparar não consome a oferta. A comparação de troca/build também informa o efeito que será ganho ou perdido. A inspeção de habilidades apresenta seus valores modificados e os efeitos dos genes ativos.

## Autoridade e manutenção

`data/gene_transformations.json` é a tabela de conteúdo. `tools/gen_mutations.py` gera o catálogo e as descrições do universo da mesma fonte, preservando os atributos calibrados em `data/balance.json`. `tools/tune_pacing.py` define o ritmo; `tools/tune_rewards.py` configura recompensas e contadores de provas, de forma idempotente.

O efeito genérico `acquire-gene`, em `engine/core`, recebe um ID validado pelo compilador e registra a aquisição privada na biblioteca. É idempotente e determinístico; o replay inclui a conquista. Conteúdo, classes e valores de combate permanecem fora do núcleo.

No jogo online, o Godot de autoridade aplica os efeitos depois de validar e pagar o ataque. O cliente desenha a antecipação visual sem causar dano, curar ou conceder recompensas. Ecos gratuitos não disparam outra rodada dos efeitos de genes. Uma ruptura pendente é cancelada se o jogador morrer, sair da cena ou trocar de instância. Poças e projéteis usam o mesmo mundo físico do autor; o estilo das poças é replicado aos demais jogadores.

Alterar o universo muda seu fingerprint. O mundo salvo não pode ser reproduzido com essas regras e alegar o mesmo Digest. Em 25/10/2026, o usuário autorizou ativar esta progressão e descartar o progresso anterior. O supervisor agora usa o universo do repositório e `D:/unity/hospedeiro-run/worldsim-dungeon-rewards.exe`, com dados novos em `D:/unity/hospedeiro-data`. A chave de sessão foi preservada; os logs antigos foram retirados de uso em `D:/unity/hospedeiro-data-retired-20261025`, após bloqueio da remoção direta pela revisão automática. Não são carregados pelo servidor. O supervisor aceita `-UniversePath` e `-ReuseServer` e recusa alterações incompatíveis em vez de iniciar outro mundo automaticamente.
