"""Generate reference tables from the canonical Go catalog, without implementing rules in C#."""
import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
c=json.loads((root/'Backend/authority/journey/content.json').read_text(encoding='utf-8'))
def write(name,lines):(root/'Docs'/name).write_text('\n'.join(lines)+'\n',encoding='utf-8')
def names(cat):return {x['id']:x['name'] for x in c[cat]}
regions,npcs,items,abilities=map(names,['regions','npcs','items','abilities'])
effects={
 'weakness':'Passiva: +10 em ataque durante exposição.',
 'counter':'Ativa no preparo: 25 de dano, interrupção e exposição; impede o golpe inimigo.',
 'fracture':'Ativa em alcance próximo: 18 de dano; remove proteção de armadura/escavação.',
 'stealth':'Ativa: aproxima, abre exposição e evita resposta naquele turno; também permite extrair musgo do bosque.',
 'toxic':'Passiva: dano periódico do veneno cai de 6 para 2.',
 'extract':'Capacidade de extrair essência estabilizada após derrota verificada do eco.',
 'seismic':'Ativa: 22 de dano, aproxima/aterrissa, fratura e interrompe o preparo.',
 'mark':'Ativa: aterra/aproxima; ataques seguintes +5 naquele encontro.',
 'burn':'Ativa com estojo equipado: 8 de impacto e três aplicações de 10 de queimadura; impede regeneração.',
 'guard':'Ativa no preparo: bloqueia o golpe, registra defesa validada.',
 'sense':'Capacidade de revelar/obter glifo nas ruínas; sem bônus bruto de combate.',
 'purify':'Ativa: remove veneno, cura 5, fratura; 12 de dano, ou 30 contra eco etéreo.'}
lines=['# Habilidades do Marco 05','', 'As 12 técnicas abaixo têm regras e efeitos na autoridade Go do protótipo por turnos. A cena `Marco05World.unity` envia as intenções e apresenta seus resultados; não são 12 habilidades do combate físico de `OfflineClearing.unity`, que permanece com Leitura de Fraquezas. [Validação](Validation/Marco05.md).','', 'Cooldown usa turnos/ações confirmados do personagem, nunca movimento ou relógio informado pelo cliente. Ativas exigem personagem vivo, encontro ativo, desbloqueio e cooldown vencido; validação específica está na tabela. Passivas não aceitam ativação manual. Não há níveis ou XP.','', '| ID / habilidade | Efeito e condição | Cooldown | Rotas de descoberta |','|---|---|---|---|']
for a in c['abilities']:
    routes=', '.join(o['id'] for o in c['opportunities'] if o['ability']==a['id'])
    lines.append(f"| `{a['id']}` — {a['name']} | {effects[a['effect']]} | {a['cooldown']} turnos | {routes} |")
lines+=['','As rotas incluem investigação/entrega, observação de combate, rastreamento, treinamento por defesa/esquiva, mineração, estudo alquímico, comparação de inscrições e consequência histórica compartilhada. Ignorar uma oportunidade não bloqueia uma rota alternativa. Equipar o amuleto reduz veneno; armadura e manto reduzem dano. Nenhuma técnica concede recompensa por um `CreatureDefeated` enviado pelo cliente.']
write('Abilities.md',lines)
lines=['# Itens do Marco 05','','38 definições versionadas no catálogo Go. Quantidades positivas, obtenção única por fonte, consumo e equipamento são confirmados no servidor e persistidos em registros normalizados. Inspeção na interface mostra tipo/quantidade; oportunidades mostram os materiais consumidos.','', '| ID / item | Função real | Fontes |','|---|---|---|']
for i in c['items']:
    use=', '.join(o['id'] for o in c['opportunities'] if i['id'] in o['costs'])
    if i['use']=='equipment':use=f"Equipar em {i['slot']}: "+{'weapon':'+5 de dano','armor':'−5 de dano recebido','charm':'−3 de veneno','cloak':'−1 de dano recebido','tool':'picareta verifica extração de veios; estojo permite Combustão'}[i['slot']]
    elif i['use'] in ['heal','antidote','burn','purify']:use={'heal':'Consumir: cura 35, máximo 100; recusa vida cheia','antidote':'Consumir: remove veneno; recusa ausência de veneno','burn':'Consumir em encontro: três aplicações de queimadura','purify':'Consumir: cura 20, remove veneno e expõe resistência'}[i['use']]
    sources=[x['id'] for x in c['creatures'] if i['id'] in x['loot']]+[x['id'] for x in c['nodes'] if i['id'] in x['items']]+[x['id'] for x in c['opportunities'] if i['id'] in x['rewards']]
    lines.append(f"| `{i['id']}` — {i['name']} | {use} | {', '.join(sources)} |")
lines+=['','Picareta precisa estar equipada para extrair ferro/cobre. Glifo exige Sentido Ancestral; lótus exige Resistência Tóxica; essência estabilizada exige Extrair Essência e derrota real do eco. Alvo de treino não concede materiais. Nada é sincronizado implicitamente com os saves locais.']
write('Items.md',lines)
lines=['# Mundo e conteúdo do Marco 05','','Catálogo canônico em `Backend/authority/journey/content.json`, produzido por `AgentScripts/GenerateWorldContent.py`. Go valida IDs, referências, recompensas, condições contraditórias, regiões desconectadas e ilhas de dependências sem entrada. A Unity usa `/v1/content` para apresentação; não replica o motor de consequências.','', 'Contagens da expansão: **5 regiões, 9 criaturas, 12 NPCs, 12 habilidades, 38 itens, 31 oportunidades e 15 pontos de interação**. Arte placeholder reutiliza sprites originais. A cena offline, Mira/Orin, Leitura, amostra, rotas e acontecimentos dos Marcos 01–04 continuam preservados; o mundo expandido é `marco05-expanded`, separado da demonstração `marco05-dev`.','', '## Criaturas','', '| ID / criatura | Região | Mecânica | Extração |','|---|---|---|']
patterns={'pursuit':'Persegue de perto; golpe telegrafado permite esquiva/exposição.','charge':'Carga forte; após resolver impacto recua distância e exige aproximação.','venom':'Golpes não bloqueados aplicam veneno por três turnos.','flying':'Inicia a distância 2; ataques próximos falham; aproximação/Marca/Impacto aterrissam.','armored':'Reduz ataque físico em 14 até ser fraturada.','burrow':'Oculta-se após agir; ataque não acerta até exposição ou fratura.','ethereal':'Recebe apenas um terço de dano físico até purificação/fratura.','regenerate':'Regenera 6 por turno; queimadura ou fratura interrompem.','shield':'Proteção frontal recebe um quarto de dano; exposição/fratura abre defesa.'}
for x in c['creatures']:lines.append(f"| `{x['id']}` — {x['name']} | {regions[x['region']]} | {patterns[x['pattern']]} | {', '.join(items[k]+' × '+str(v) for k,v in x['loot'].items())} |")
lines+=['','Derrota, distância abstrata, vida, turnos e loot pertencem ao Go. Não há comprovação de colisão/movimento real, projéteis físicos ou perseguição espacial no mundo expandido. Essas mecânicas são encontros discretos, distintos da simulação física offline do lobo.','', '## NPCs','', '| ID / identidade | Local | Função | Conhecimento inicial (fonte: conversa local) |','|---|---|---|']
for n in c['npcs']:lines.append(f"| `{n['id']}` — {n['name']} | {regions[n['region']]} | {n['role']} | {', '.join(n['knowledge'])} |")
lines+=['','Conversas exigem a região correta. Conhecimento inicial é transmitido somente ao personagem que conversa; relação e fonte são privadas. Descobertas oferecidas a um NPC ficam vinculadas a fatos daquele personagem. Não há onisciência automática.','', '## Oportunidades combináveis','', '| ID / oportunidade | Linha / região | Condições | Consumo | Efeito |','|---|---|---|---|']
for o in c['opportunities']:
    effect=abilities.get(o['ability'],'') or ', '.join(items[k]+' × '+str(v) for k,v in o['rewards'].items()) or o['fact']
    if o['shared']:effect+=' (compartilhado, autoria única)'
    if o['after']:effect+=f"; agenda em {o['after']} ações confirmadas"
    lines.append(f"| `{o['id']}` — {o['name']} | {o['theme']} / {regions[o['region']]} | {', '.join(o['requires']) or 'materiais/local'} | {', '.join(items[k]+' × '+str(v) for k,v in o['costs'].items()) or '—'} | {effect} |")
lines+=['','A interface exibe no máximo três oportunidades disponíveis por região. A elegibilidade é reavaliada: custos, conhecimento, estado mundial e ignorar/completar podem retirar ou abrir possibilidades. Nem todo ponto/conversa abre oportunidade. As quatro linhas não são campanhas obrigatórias.','', 'O farol `asterion-beacon` exige glifo, memória do pântano e materiais de encontros distintos; transação, lock mundial e UNIQUE garantem uma única ativação/autoria por mundo. Outros personagens ganham uma rota alternativa de Sentido Ancestral, sem copiar inventário ou fatos privados. Para repetir o experimento, criar/seedar outro mundo is_test ou resetar explicitamente o banco de desenvolvimento autorizado; nunca tentar remover só um evento de um mundo confiável.']
write('WorldContent.md',lines)
write('WorldMap.md',['# Mapa jogável — Marco 05','','`Marco05World.unity` apresenta cinco áreas e transições confirmadas pelo backend. WASD movimenta a representação local; a intenção `travel` valida conexão e ausência de encontro ativo. Só após confirmação a área e o ponto de entrada mudam. `OfflineClearing.unity` continua disponível e é preservada.','','```mermaid','graph LR',' V[Valdoria] --- F[Floresta Cinzenta]',' V --- K[Minas de Kharum]',' F --- P[Pântano dos Ecos]',' K --- A[Ruínas de Asterion]',' P --- A','```','','| Área | Gameplay próprio |','|---|---|','| Valdoria | Treino de defesa/esquiva, forja, alquimia, consumíveis, descanso |','| Floresta Cinzenta | Rastros, caça, pesquisa de corrupção, bosque silencioso, recuperação regional |','| Minas de Kharum | Picareta, fratura de veios, voo/armadura/escavação, ressonância agendada |','| Pântano dos Ecos | Veneno, lótus condicionado, ecos etéreos, regeneração, memória histórica |','| Ruínas de Asterion | Inscrições/glifos, comparação de registros, guardião e farol único compartilhado |','','Memórias do pântano abrem estudo nas ruínas e recuperação da floresta; mineração produz materiais usados na forja e em Asterion. As áreas são salas placeholder dentro da mesma cena, sem necessidade de recarregar sessão/saves; não são cinco cópias da cena offline.'])
print('Content documentation updated from canonical definitions')
