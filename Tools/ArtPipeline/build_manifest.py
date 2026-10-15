"""Curated source rectangles in top-left pixels. Run after audit.py.
All ranges below were inspected on annotated sheets; never infer a cell grid.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
inventory=json.loads((ROOT/'Docs/Art/Audit/inventory.json').read_text())
regions={Path(r['file']).stem:r['candidate_components'] for r in inventory}
entries=[]
def entry(name,source,rect,actor,action,direction='S',frame=0,anchor=None,canvas=(96,96),scale=1/3,**extra):
    x,y,w,h=rect
    item=dict(name=name,source='assets_para_usar/'+source+'.png',rect=rect,actor=actor,animation=action,direction=direction,frame=frame,canvas=list(canvas),source_anchor=anchor or [x+w/2,y+h],anchor=[canvas[0]//2,canvas[1]-8],scale=scale,pivot=[.5,8/canvas[1]],duration=.125,status='source-review-only')
    if actor in ('VFX','UI'): item.update(anchor=[canvas[0]//2,canvas[1]//2],pivot=[.5,.5])
    item.update(extra); entries.append(item)
def component(source,index): return regions[source][index]['rect']
# Four native directions; no mirrored sword or invented diagonal pose.
# Sword blades are removed ONLY from these explicit, hand-reviewed polygons.
# Each body is then paired with the existing physical SwordHand renderer.
dirs=['S','W','N','E']; cols=[0,2,4,6]
hero_indices=[[0,2,4,6],[8,10,12,14],[16,18,20,22],[24,28,26,31],[35,36,37,34],[40,42,43,45]]
anchors=[[(106,163),(460,159),(817,162),(1165,157)],[(101,328),(460,323),(817,334),(1165,323)],[(103,492),(458,483),(817,496),(1163,487)],[(109,681),(454,676),(817,688),(1165,664)],[(110,844),(454,839),(817,855),(1165,836)],[(102,1004),(455,972),(814,1013),(1111,986)]]
# Polygon vertices are SOURCE pixels, not generated based on color.
cuts={
 (0,0):[[(7,151),(57,101),(70,98),(65,113),(20,159)]],
 (0,1):[[(366,140),(426,101),(439,98),(435,111),(378,149)]],
 (0,3):[[(1192,96),(1261,135),(1256,148),(1186,111)]],
 (1,0):[[(4,310),(56,260),(67,264),(18,320)]],
 (1,1):[[(363,304),(427,269),(439,268),(433,280),(375,314)]],
 (1,3):[[(1195,271),(1261,301),(1257,316),(1189,283)]],
 (2,0):[[(13,497),(58,435),(69,436),(28,505)]],
 (2,1):[[(365,463),(430,433),(439,433),(435,445),(373,474)]],
 (2,3):[[(1196,435),(1273,460),(1268,474),(1190,449)]],
 (3,0):[[(52,543),(115,503),(124,511),(71,554)],[(141,628),(194,680),(183,691),(135,645)]],
 (3,1):[[(370,510),(432,510),(432,573),(447,589),(436,603),(370,566)]],
 (3,2):[[(773,532),(818,499),(841,519),(820,541),(805,534),(787,551)]],
 (3,3):[[(1210,574),(1279,505),(1287,528),(1223,591)],[(1250,638),(1280,638),(1280,670),(1250,670)]],
 (4,0):[[(29,687),(44,684),(63,749),(55,767),(44,754)],[(145,794),(168,845),(157,852),(138,808)]],
 (4,1):[[(370,669),(402,670),(436,747),(423,766),(370,706)]],
 (4,2):[[(778,728),(827,684),(838,691),(790,739)]],
 (4,3):[[(1217,742),(1250,658),(1279,658),(1256,736),(1231,750)]],
 (5,0):[[(10,984),(59,942),(70,943),(23,994)]],
 (5,1):[],
 (5,3):[[(1165,947),(1222,970),(1222,990),(1190,984),(1161,961)]]}
for row,indices in enumerate(hero_indices):
    action='idle' if row==0 else 'walk' if row<3 else 'attack' if row<5 else 'dodge'
    frame=0 if row in (0,1,3,5) else 1
    for d,index in enumerate(indices):
        rect=component('personagem',index); x,y,w,h=rect
        # one shared 96px canvas, body stays native 1:3 scale; padding includes weapon paths
        entry(f'Hero_{action}_{dirs[d]}_{frame}','personagem',[max(0,x-2),max(0,y-2),w+4,h+4],'Hero',action,dirs[d],frame,anchors[row][d],remove_polygons=cuts.get((row,d),[]),duration=.125 if action=='walk' else .1)
# Reject the dual-blade south attacks and overhead north arms, which cannot match
# the established waist-height physical grip. Use compatible native body stances.
for d in ('S','W','N','E'):
    for f in (0,1):
        target=next(e for e in entries if e['name']==f'Hero_attack_{d}_{f}')
        source=next(e for e in entries if e['name']==f'Hero_'+('dodge' if d=='S' else 'walk')+f'_{d}_{0 if d in ("S","N") else f}')
        for key in ('rect','source_anchor','remove_polygons'): target[key]=source.get(key,[])
        target['limitation']='Compatible body stance substitution: original attack arms do not match the existing physical grip. SwordSwing owns the continuous swing; not a newly drawn full-body attack pose.'
# Wolf sheet has ten headings in idle but only eight moving frames. Select four
# matching body orientations; do not label adjacent headings as temporal frames.
wolf_sets={'idle':[0,3,5,7],'walk':[0,13,14,16],'attack':[19,22,23,27],'hurt':[28,30,31,34]}
for action,indices in wolf_sets.items():
    for d,i in enumerate(indices):
        rect=component('monstros',i)
        entry(f'Wolf_{action}_{dirs[d]}_0','monstros',rect,'Wolf',action,dirs[d],anchor=[rect[0]+rect[2]/2,rect[1]+rect[3]-3],canvas=(80,80))
for action in ('attack','hurt'):
    target=next(e for e in entries if e['name']==f'Wolf_{action}_N_0')
    source=next(e for e in entries if e['name']=='Wolf_idle_N_0')
    target['rect']=source['rect'];target['source_anchor']=source['source_anchor'];target['limitation']='No coherent north attack/reaction pose: use north body instead of showing a right-facing strike.'
# Prepare all other creatures as reviewed source poses. No unsupported full cycles.
for kind,source,sets in [('Spider','monstros',{'idle':[37,39,41,43],'walk':[46,48,50,52],'attack':[55,57,59,62],'hurt':[64,66,68,71],'death':[76,77,78,79,80,81]}),('Golem','monstros_2',{'idle':[0,2,4,6],'walk':[8,10,12,14],'attack':[16,18,20,22],'hurt':[26,28,30,32],'death':[34,35,36,37,38,39,40,41]})]:
    for action,indices in sets.items():
        for j,i in enumerate(indices):
            r=component(source,i)
            entry(f'{kind}_{action}_{dirs[j%4]}_{j//4}',source,r,kind,action,dirs[j%4],j//4,canvas=(112,112) if kind=='Golem' else (80,80),scale=.46 if kind=='Golem' else 1/3)
# NPC cuts must avoid merged neighbouring figures.
for kind,rect in [('Healer',[9,48,108,180]),('Hunter',[397,51,107,174]),('Smith',[726,47,137,183]),('Scholar',[1093,57,108,171])]:
    entry(kind+'_idle_S_0','npcs',rect,kind,'idle',canvas=(80,80),anchor=[rect[0]+rect[2]/2,rect[1]+rect[3]-4],scale=.3)
props={'House':[883,17,154,208],'Tree':[1039,2,116,157],'Pine':[1006,235,99,157],'Rock':[1067,525,59,47],'Bush':[1184,143,80,67],'Pillar':[597,860,70,139]}
for name,r in props.items():
    entry(name,'cenarios',r,'Environment','prop',canvas=(224,224),anchor=[r[0]+r[2]/2,r[1]+r[3]-6],scale=.85 if name in ('House','Tree','Pine') else .6)
    # Remove neighbour fragments crossing otherwise valid rectangular cuts.
    if name=='Tree': entries[-1]['remove_polygons']=[[(1115,130),(1159,130),(1159,164),(1115,164)]]
    if name=='Pine': entries[-1]['rect']=[1008,237,95,153]
for name,r in {'Flowers':[1043,162,66,61],'Stump':[573,389,67,58],'Barrel':[557,76,48,60],'Sign':[473,75,65,63],'Crystal':[973,627,69,57],'Herb':[473,404,40,40]}.items():
    entry(name,'cenarios',r,'Environment','prop',canvas=(80,80),scale=.5)
# One native front-facing flap pair only; no unsupported north orientation claims.
for f,i in enumerate((42,50)):
    r=component('monstros_2',i)
    entry(f'Bat_flight_S_{f}','monstros_2',r,'Bat','flight','S',f,anchor=[100,712 if f==0 else 802],canvas=(80,80),scale=.4)
    entries[-1]['anchor']=[40,40];entries[-1]['pivot']=[.5,.5]
for i,r in enumerate([[24,59,74,65],[129,43,118,84]]):
    entry('Sword' if i==0 else 'Slash','efeitos_habilidades_e_icones',r,'VFX','equipment' if i==0 else 'slash',canvas=(80,80),anchor=[r[0]+r[2]/2,r[1]+r[3]/2],scale=.5)
    if i==0:entries[-1]['pivot']=[31/80,35/80]
for i,r in enumerate([[48,150,115,103],[170,143,136,110],[303,152,118,91],[443,140,126,107]]):
    entry(f'Impact_{i}','efeitos_habilidades_e_icones',r,'VFX','impact',frame=i,canvas=(80,80),anchor=[r[0]+r[2]/2,r[1]+r[3]/2],scale=.4,duration_override=.045)
for i,r in enumerate([[32,253,104,67],[172,253,137,71],[316,253,154,75]]):
    entry(f'Dust_{i}','efeitos_habilidades_e_icones',r,'VFX','dodge-dust',frame=i,canvas=(80,80),anchor=[r[0]+r[2]/2,r[1]+r[3]-8],scale=.35)
for name,r in {'WeaknessReticle':[38,333,98,99],'HunterMark':[36,435,104,83],'Corruption':[28,927,115,60]}.items():
    entry(name,'efeitos_habilidades_e_icones',r,'VFX','marker',canvas=(80,80),scale=.35)
for i in range(12):
    entry(f'Icon_{i}','efeitos_habilidades_e_icones',[12+i*118,985,108,100],'UI','icon',frame=i,canvas=(40,40),anchor=[66+i*118,1035],scale=1/3)
manifest={'version':1,'coordinate_system':'source: top-left xywh; source_anchor: top-left pixel; output pivot: normalized bottom-left','ppu':32,'alpha_cleanup':'Only alpha <=7 is discarded. No RGB/keying, component deletion, or opaque threshold. Core alpha retained.','entries':entries}
for e in entries:
    # Keep physics root at existing torso centre. Stable feet are 18 logical px
    # below it for humanoids and 10px for quadrupeds. No collider repositioning.
    if e['actor']=='Hero': e['pivot'][1]=26/e['canvas'][1]
    elif e['actor'] in ('Healer','Hunter','Smith','Scholar'): e['pivot'][1]=26/e['canvas'][1]
    elif e['actor'] in ('Wolf','Spider','Golem'): e['pivot'][1]=18/e['canvas'][1]
(ROOT/'Tools/ArtPipeline/frames.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(len(entries),'explicit entries')
