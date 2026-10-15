"""Reproducible authoring of versioned definitions; no DB, saves or Editor writes."""
import json
from pathlib import Path

root=Path(__file__).resolve().parent.parent
regions=[('valdoria','Valdoria',['gray-forest','kharum']),('gray-forest','Floresta Cinzenta',['valdoria','echo-marsh']),('kharum','Minas de Kharum',['valdoria','asterion']),('echo-marsh','Pântano dos Ecos',['gray-forest','asterion']),('asterion','Ruínas de Asterion',['kharum','echo-marsh'])]
abilities=[('weakness-reading','Leitura de Fraquezas','weakness',0),('counterattack','Contra-ataque','counter',2),('fracturing-strike','Golpe Fraturante','fracture',3),('silent-step','Passo Silencioso','stealth',3),('toxic-resistance','Resistência Tóxica','toxic',0),('extract-essence','Extrair Essência','extract',0),('seismic-impact','Impacto Sísmico','seismic',4),('hunter-mark','Marca do Caçador','mark',3),('alchemical-combustion','Combustão Alquímica','burn',3),('reinforced-guard','Guarda Reforçada','guard',2),('ancestral-sense','Sentido Ancestral','sense',0),('purification','Purificação','purify',4)]
materials=['corruption-sample','wolf-fang','gray-pelt','boar-tusk','spider-venom','bat-wing','stone-core','crawler-shell','echo-essence','mire-heart','guardian-fragment','iron-ore','copper-ore','quartz','sulfur','coal','silver-ore','basalt','salt','gray-herb','toxic-reed','echo-lotus','ember-seed','pure-water','ancient-moss']
items=[dict(id=x,name=x.replace('-',' ').title(),use='material',power=0) for x in materials]
for id,name,slot,power in [('iron-blade','Lâmina de Ferro','weapon',5),('reinforced-mail','Malha Reforçada','armor',5),('mining-pick','Picareta','tool',1),('alchemist-kit','Estojo Alquímico','tool',1),('silver-charm','Amuleto de Prata','charm',3),('hunter-cloak','Manto do Caçador','cloak',1)]:
    items.append(dict(id=id,name=name,use='equipment',slot=slot,power=power))
for id,name,use,power in [('healing-draught','Infusão Curativa','heal',35),('antidote','Antídoto','antidote',1),('fire-flask','Frasco Ígneo','burn',12),('purifier','Sal Purificador','purify',20)]:
    items.append(dict(id=id,name=name,use=use,power=power))
for x in ['asterion-glyph','miners-seal','historical-fragment']:items.append(dict(id=x,name=x.replace('-',' ').title(),use='evidence',power=0))
creatures=[]
for id,name,reg,pattern,hp,dmg,loot in [
 ('corrupted-wolf','Lobo Corrompido','gray-forest','pursuit',60,15,{'corruption-sample':1,'wolf-fang':2,'gray-pelt':2}),
 ('thorn-boar','Javali de Espinhos','gray-forest','charge',75,22,{'boar-tusk':2}),
 ('venom-spider','Aranha Tóxica','echo-marsh','venom',45,9,{'spider-venom':3}),
 ('cave-bat','Morcego de Cristal','kharum','flying',40,8,{'bat-wing':3}),
 ('stone-sentinel','Sentinela de Pedra','kharum','armored',90,16,{'stone-core':2}),
 ('burrow-crawler','Rastejante Escavador','kharum','burrow',55,12,{'crawler-shell':2}),
 ('echo-wisp','Eco Errante','echo-marsh','ethereal',50,11,{'echo-essence':2}),
 ('mire-hydra','Hidra do Lodo','echo-marsh','regenerate',85,16,{'mire-heart':2}),
 ('asterion-guardian','Guardião de Asterion','asterion','shield',100,18,{'guardian-fragment':2})]:
    creatures.append(dict(id=id,name=name,region=reg,pattern=pattern,hp=hp,damage=dmg,loot=loot,requires=[]))
npcs=[]
for id,name,reg,role,knowledge in [
 ('mira','Mira','gray-forest','pesquisa',['lore:corruption']),('orin','Orin','gray-forest','caça',['lore:weakness']),
 ('helena','Helena','valdoria','acolhimento',['lore:routes']),('brann','Brann','valdoria','forja',['lore:armor']),
 ('lia','Lia','valdoria','exploração',['lore:stealth']),('selka','Selka','valdoria','alquimia',['lore:fire']),
 ('dorin','Dorin','kharum','mineração',['lore:fracture']),('tessa','Tessa','kharum','arquivo',['lore:mines']),
 ('nera','Nera','echo-marsh','ervas',['lore:toxin']),('ivo','Ivo','echo-marsh','travessia',['lore:marsh']),
 ('soren','Soren','asterion','história',['lore:asterion']),('enya','Enya','asterion','ecos ancestrais',['lore:ancestors'])]:
    npcs.append(dict(id=id,name=name,region=reg,role=role,knowledge=knowledge))
nodes=[]
def node(id,name,reg,items=None,ability='',requires=None,fact=None):
    nodes.append(dict(id=id,name=name,region=reg,fact=fact or 'discovery:'+id,items=items or {},ability=ability,requires=requires or []))
node('forest-tracks','Rastros entre raízes','gray-forest',fact='tracking-confirmed')
node('forest-herbs','Ervas da clareira','gray-forest',{'gray-herb':6,'ember-seed':4})
node('hidden-grove','Bosque silencioso','gray-forest',{'ancient-moss':3},'silent-step',fact='lore:grove')
node('forest-spring','Fonte da floresta','gray-forest',{'pure-water':6})
node('iron-vein','Veio de ferro','kharum',{'iron-ore':6,'coal':6},requires=['done:mining-tools'])
node('copper-vein','Veio de cobre','kharum',{'copper-ore':4,'sulfur':4},requires=['done:mining-tools'])
node('crystal-seam','Fratura cristalina','kharum',{'quartz':6,'basalt':4},'fracturing-strike')
node('silver-seam','Veio de prata','kharum',{'silver-ore':4},'seismic-impact')
node('miners-record','Registro soterrado','kharum',{'miners-seal':2},fact='lore:miners-seal')
node('marsh-reeds','Juncos tóxicos','echo-marsh',{'toxic-reed':6,'salt':4})
node('echo-lotus','Lótus dos ecos','echo-marsh',{'echo-lotus':4},'toxic-resistance',fact='lore:lotus')
node('marsh-memory','Memória do pântano','echo-marsh',{'historical-fragment':2},fact='lore:marsh-memory')
node('ancestral-glyph','Glifo de Asterion','asterion',{'asterion-glyph':2},'ancestral-sense',fact='lore:glyph')
node('ruins-inscription','Inscrição das ruínas','asterion',fact='lore:inscription')
node('echo-extraction','Essência estabilizada','echo-marsh',{'echo-essence':2},'extract-essence',requires=['defeat:echo-wisp'])
opps=[]
def opp(id,name,theme,reg,req=None,cost=None,reward=None,ability='',npc='',fact=None,excludes=None,shared=False,after=0):
    opps.append(dict(id=id,name=name,theme=theme,region=reg,npc=npc,requires=(req or [])+(['talk:'+npc] if npc else []),excludes=excludes or [],costs=cost or {},rewards=reward or {},ability=ability,fact=fact or 'consequence:'+id,shared=shared,after=after))
opp('forest-sample','Amostra para Mira','forest','gray-forest',cost={'corruption-sample':1},ability='weakness-reading',npc='mira',fact='investigation-confirmed')
opp('forest-observation','Observar a caçada','forest','gray-forest',['tracking-confirmed','defeat:corrupted-wolf'],ability='weakness-reading',npc='orin')
opp('hunter-mark-training','Leitura do rastro','forest','gray-forest',['tracking-confirmed'],ability='hunter-mark',npc='orin')
opp('silent-grove-route','Contornar as raízes','forest','valdoria',['visited:gray-forest'],ability='silent-step',npc='lia')
opp('silent-marsh-route','Travessia dos juncos','swamp','echo-marsh',['lore:marsh-memory'],ability='silent-step',npc='ivo')
opp('counter-training','Resposta ao preparo','forest','valdoria',['practice:dodge'],ability='counterattack',npc='brann')
opp('guard-training','Defender o impacto','mines','valdoria',['practice:guard'],ability='reinforced-guard',npc='brann')
opp('mining-tools','Ferramentas de Kharum','mines','kharum',reward={'mining-pick':1},npc='dorin')
opp('fracture-training','Fraturar sem esmagar','mines','kharum',['done:mining-tools'],cost={'iron-ore':1},ability='fracturing-strike',npc='dorin')
opp('seismic-training','Vibração das camadas','mines','kharum',['discovery:crystal-seam'],cost={'basalt':1},ability='seismic-impact',npc='dorin')
opp('seismic-combat-route','Aprender com a sentinela','mines','kharum',['defeat:stone-sentinel'],ability='seismic-impact',npc='tessa')
opp('toxin-study','Estudar o veneno','swamp','echo-marsh',cost={'toxic-reed':2},ability='toxic-resistance',npc='nera')
opp('toxin-combat-route','Sobreviver à aranha','swamp','echo-marsh',['defeat:venom-spider'],ability='toxic-resistance',npc='nera')
opp('essence-research','Estabilizar a corrupção','forest','gray-forest',['investigation-confirmed'],cost={'gray-herb':1},ability='extract-essence',npc='mira')
opp('essence-marsh-route','Ouvir a matéria','swamp','echo-marsh',['defeat:echo-wisp'],cost={'echo-lotus':1},ability='extract-essence',npc='ivo')
opp('combustion-training','Combustão controlada','forest','valdoria',cost={'sulfur':1,'ember-seed':1},reward={'alchemist-kit':1},ability='alchemical-combustion',npc='selka')
opp('ancestral-study','Reconhecer os ecos','asterion','asterion',['lore:inscription','lore:marsh-memory'],ability='ancestral-sense',npc='enya')
opp('ancestral-mines-route','Comparar os registros','asterion','asterion',['lore:miners-seal'],cost={'miners-seal':1},ability='ancestral-sense',npc='soren')
opp('purification-training','Purificar as águas','swamp','echo-marsh',['lore:corruption','lore:lotus'],cost={'salt':1,'pure-water':1},ability='purification',npc='nera')
opp('forge-blade','Forjar lâmina','mines','valdoria',cost={'iron-ore':2,'wolf-fang':1,'coal':1},reward={'iron-blade':1},npc='brann')
opp('forge-mail','Forjar malha','mines','valdoria',cost={'copper-ore':2,'crawler-shell':1,'coal':1},reward={'reinforced-mail':1},npc='brann')
opp('weave-cloak','Costurar manto','forest','valdoria',cost={'gray-pelt':1,'boar-tusk':1,'bat-wing':1},reward={'hunter-cloak':1},npc='lia')
opp('silver-ward','Amuleto ressonante','asterion','asterion',cost={'silver-ore':1,'quartz':1,'stone-core':1},reward={'silver-charm':1},npc='enya')
opp('brew-healing','Preparar infusões','forest','valdoria',cost={'gray-herb':2,'pure-water':1},reward={'healing-draught':3},npc='helena')
opp('brew-antidote','Preparar antídotos','swamp','echo-marsh',cost={'spider-venom':1,'toxic-reed':1,'pure-water':1},reward={'antidote':3},npc='nera')
opp('brew-fire','Preparar frascos ígneos','forest','valdoria',cost={'sulfur':1,'ember-seed':1,'bat-wing':1},reward={'fire-flask':3},npc='selka')
opp('brew-purifier','Preparar sais','swamp','echo-marsh',cost={'echo-lotus':1,'salt':1,'echo-essence':1},reward={'purifier':3},npc='nera')
opp('forest-restoration','Memória contra corrupção','forest','gray-forest',['lore:marsh-memory'],cost={'purifier':1,'ancient-moss':1},npc='mira',fact='region:forest-restored',shared=True)
opp('mines-awakening','Despertar a ressonância','mines','kharum',['defeat:stone-sentinel'],cost={'stone-core':1,'mire-heart':1},npc='tessa',fact='region:mines-awakened',shared=True,after=2)
opp('asterion-beacon','Acender o farol de Asterion','asterion','asterion',['lore:glyph','lore:marsh-memory'],cost={'asterion-glyph':1,'historical-fragment':1,'guardian-fragment':1,'echo-essence':1},npc='soren',fact='world:asterion-beacon',shared=True)
opp('beacon-attunement','Ouvir o farol compartilhado','asterion','asterion',['world:asterion-beacon'],ability='ancestral-sense',npc='enya')
c=dict(version=1,regions=[dict(id=x,name=n,connections=con) for x,n,con in regions],abilities=[dict(id=x,name=n,effect=e,cooldown=cd) for x,n,e,cd in abilities],items=items,creatures=creatures,npcs=npcs,nodes=nodes,opportunities=opps)
target=root/'Backend/authority/journey/content.json'
target.parent.mkdir(parents=True,exist_ok=True)
target.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
seed=root/'supabase/seed.sql'
existing=seed.read_text(encoding='utf-8').split('-- BEGIN EXPANDED CONTENT')[0].rstrip()+'\n'
sql=['-- BEGIN EXPANDED CONTENT: generated by AgentScripts/GenerateWorldContent.py',"insert into game.worlds(id,name,is_test,ruleset) values('marco05-expanded','Marco 05 — mundo expandido de teste',true,'expanded-v1') on conflict do nothing;"]
quote=lambda x:"'"+x.replace("'","''")+"'"
for r in c['regions']:
    sql.append("insert into game.world_regions(world_id,id,name) values('marco05-expanded',"+quote(r['id'])+','+quote(r['name'])+") on conflict do nothing;")
for plural,kind in [('regions','region'),('abilities','ability'),('items','item'),('creatures','creature'),('npcs','npc'),('nodes','node'),('opportunities','opportunity')]:
    for d in c[plural]:
        sql.append('insert into game.content_definitions(kind,id,version,definition) values('+quote(kind)+','+quote(d['id'])+',1,'+quote(json.dumps(d,ensure_ascii=False))+') on conflict do nothing;')
for o in opps:
    if o['shared']:
        sql.append("insert into game.content_definitions(kind,id,version,definition) values('event',"+quote(o['id'])+',1,'+quote(json.dumps(o,ensure_ascii=False))+') on conflict do nothing;')
seed.write_text(existing+'\n'.join(sql)+'\n',encoding='utf-8')
print(json.dumps({k:len(v) for k,v in c.items() if isinstance(v,list)}))
