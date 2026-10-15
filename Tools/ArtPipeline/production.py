"""Export reviewed B3 drawings into the B4 production contract. Never invent poses.
Run from repository root: python Tools/ArtPipeline/production.py
"""
import json, shutil, hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OLD = json.loads((ROOT/'Assets/Mmorpg/Art/Processed/manifest.json').read_text('utf-8'))
DIRS = dict(S='south', W='west', N='north', E='east')
HANDS = {
    'idle': [[37,70],[41,70],[61,70],[52,70]],
    'walk_0': [[36,69],[44,72],[61,68],[54,70]],
    'walk_1': [[38,71],[44,70],[60,71],[57,69]],
    'dodge': [[36,66],[40,82],[58,72],[67,73]],
}
def repair_glove(image, source):
    """Two small manually authored glove patches where B3 sword removal clipped the wrist.
    No whole-body deformation, procedural gait, or automatic color/background erasure.
    """
    patches={
        'Hero_walk_S_0': (33,64,['..dd.','.dom.','.omm.','.oml.','.ommo','..omo','..oo.']),
        'Hero_idle_W_0': (38,65,['..dd.','.dom.','.omm.','.oml.','.ommo','..omo','..oo.']),
    }
    if source not in patches: return False
    x,y,rows=patches[source];palette=dict(o=(27,20,22,250),d=(75,45,34,250),m=(121,79,49,250),l=(177,126,71,250))
    for dy,row in enumerate(rows):
        for dx,c in enumerate(row):
            if c!='.': image.putpixel((x+dx,y+dy),palette[c])
    return True
def export():
    for actor in ['Hero','Wolf','Healer','Hunter','Smith','Scholar','Spider','Golem','Bat']:
        dest = ROOT/'ArtSource'/('Characters' if actor in ['Hero','Healer','Hunter','Smith','Scholar'] else 'Creatures')/actor
        entries = [e for e in OLD['entries'] if e['actor']==actor]
        if not entries: continue
        clips = []
        groups = {}
        for e in entries: groups.setdefault((e['animation'],e['direction']),[]).append(e)
        for (action,d), frames in groups.items():
            output=[]
            for i,e in enumerate(sorted(frames,key=lambda e:e['frame'])):
                folder=dest/action/DIRS.get(d,d.lower()); folder.mkdir(parents=True,exist_ok=True)
                target=folder/f'frame_{i:03}.png'; source=ROOT/e['output']
                image=Image.open(source).convert('RGBA');retouched=repair_glove(image,e['name'])
                if retouched: image.save(target)
                elif not target.exists() or target.read_bytes()!=source.read_bytes(): shutil.copyfile(source,target)
                canvas=list(image.size)
                pivot=[round(e['pivot'][0]*canvas[0],4),round((1-e['pivot'][1])*canvas[1],4)]
                direction=list(DIRS).index(d) if d in DIRS else 0
                hand=None
                if actor=='Hero':
                    key=f'walk_{i}' if action=='walk' else action
                    if action=='attack': key='dodge' if d=='S' else 'walk_0' if d=='N' else f'walk_{min(i,1)}'
                    hand=HANDS.get(key,HANDS['idle'])[direction]
                output.append(dict(png=target.relative_to(ROOT).as_posix(),duration=e['duration'],
                    canvas=canvas,pivot=pivot,feet=e.get('anchor'),rightHand=hand,leftHand=None,
                    equipmentAngle=[-135,-155,90,-25][direction],equipmentDepth=-1 if d=='N' else 1,
                    events=[],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),inputSha256=hashlib.sha256(source.read_bytes()).hexdigest(),source=e['name'],retouch='localized manually drawn glove' if retouched else None))
            clips.append(dict(animation=action,direction=DIRS.get(d,d.lower()),frameCount=len(output),
                loop=action in ['idle','walk','flight'],status='provisional-native-poses',frames=output))
        data=dict(schema=1,id=actor,ppu=32,coordinates='pixels, top-left origin; +x right, +y down; pivot/feet/hands in canvas coordinates',
            status='provisional; not production animation approval',clips=clips,
            missing=['walk: eight distinct weight-transfer drawings per cardinal direction','native hurt/death','full body attack'] if actor=='Hero' else ['complete directional locomotion and action sequences'],
            groundContact='feet in each frame; Bat uses suspended body anchor and separate ground shadow',
            collider='existing physical root; never derived from changing frame bounds')
        dest.mkdir(parents=True,exist_ok=True); (dest/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n','utf-8')
    weapon=ROOT/'ArtSource/Weapons/IronSword';weapon.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'Assets/Mmorpg/Art/Processed/VFX/Sword.png',weapon/'frame_000.png')
    (weapon/'manifest.json').write_text(json.dumps(dict(schema=1,id='iron-sword',type='sword',png='ArtSource/Weapons/IronSword/frame_000.png',canvas=[80,80],ppu=32,pivot=[31,45],tip=[57,24],orientationDegrees=38.79655,visualLength=1,compatibility=['Hero'],status='existing isolated B3 sword; attachment calibrated in Unity'),indent=2)+'\n','utf-8')
    def group(folder, entries, **properties):
        directory=ROOT/'ArtSource'/folder;directory.mkdir(parents=True,exist_ok=True)
        frames=[]
        for i,e in enumerate(entries):
            target=directory/f'frame_{i:03}.png';shutil.copyfile(ROOT/e['output'],target)
            frames.append(dict(png=target.relative_to(ROOT).as_posix(),canvas=e['canvas'],pivot=[e['pivot'][0]*e['canvas'][0],(1-e['pivot'][1])*e['canvas'][1]],duration=e['duration'],source=e['name']))
        (directory/'manifest.json').write_text(json.dumps(dict(schema=1,id=directory.name,ppu=32,frames=frames,**properties),ensure_ascii=False,indent=2)+'\n','utf-8')
    definitions=[('SwordCut',['Slash'],'SwordSwing.Active','end of active window',False,2),
                 ('Impact',[f'Impact_{i}' for i in range(4)],'OfflineAuthority.HitConfirmed','four frames at 24 FPS',False,4),
                 ('Dodge',[f'Dust_{i}' for i in range(3)],'ActorState.IsDodging rising edge','three frames at 18 FPS',False,-2),
                 ('WeaknessReading',['WeaknessReticle'],'confirmed weakness mark','mark consumed or expired',False,3),
                 ('HuntersMark',['HunterMark'],'confirmed hunter mark','mark consumed or expired',False,3)]
    for name,names,start,end,loop,order in definitions:
        entries=[next(e for e in OLD['entries'] if e['name']==n) for n in names]
        entries=[dict(e,duration=1/24 if name=='Impact' else 1/18 if name=='Dodge' else e['duration']) for e in entries]
        group('VFX/'+name,entries,startEvent=start,endEvent=end,loop=loop,sortingOffset=order,status='existing B3 effect; no new drawn sequence')
    group('Interface/Icons',[e for e in OLD['entries'] if e['actor']=='UI'],status='existing icons; no automatic HUD replacement')
    group('Environment/Props',[e for e in OLD['entries'] if e['actor']=='Environment'],status='existing reviewed props; collision stays at authored root, not sprite bounds')
    terrain=ROOT/'ArtSource/Terrain';terrain.mkdir(parents=True,exist_ok=True);tiles=[]
    for p in sorted((ROOT/'Assets/Mmorpg/Art/Tilesets').glob('*.png')):
        if Image.open(p).size!=(32,32): raise ValueError('Non-floor tile in terrain: '+str(p))
        shutil.copyfile(p,terrain/p.name);tiles.append(dict(png=(terrain/p.name).relative_to(ROOT).as_posix(),canvas=[32,32],category='transition' if p.stem.startswith('Path_') else 'floor',collision=False))
    (terrain/'manifest.json').write_text(json.dumps(dict(schema=1,id='terrain',ppu=32,tiles=tiles,status='B3 regular floors; props are separate'),indent=2)+'\n','utf-8')
    print('Exported existing drawings, weapons, VFX, props, icons and regular tiles. Zero new walk drawings accepted.')
if __name__=='__main__': export()
