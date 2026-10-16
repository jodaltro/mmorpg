"""Prepare a licensed, editable research library. No networking, Unity import or new drawings."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

REPO=Path(__file__).resolve().parents[2]
BASE=REPO/'ArtSource/Labs/NpcResearch/Marco06B13R2'
EVIDENCE=REPO/'Docs/Validation/Marco06B13R2'


def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')


def main():
    p=argparse.ArgumentParser();p.add_argument('--external',type=Path,required=True);p.add_argument('--girl',type=Path,required=True);p.add_argument('--aseprite',type=Path,required=True);p.add_argument('--resume',action='store_true');args=p.parse_args()
    assert args.resume or not BASE.exists(),'Refuse overwriting research sources/editables; use a new revision'
    BASE.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    source_records={};candidates=[];checks=[]

    def source(path,group):
        dest=BASE/group/'Originals'/path.name
        if dest.exists():assert dest.read_bytes()==path.read_bytes()
        else:dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)
        source_records[str(dest.relative_to(REPO)).replace('\\','/')]=hashlib.sha256(dest.read_bytes()).hexdigest()
        return dest

    def assemble(name,width,height,clips,layers,timing):
        folder=BASE/name;folder.mkdir(parents=True,exist_ok=True);frames=[];tags=[];previews={};bounds=[]
        for clip,entries in clips.items():
            first=len(frames)+1;preview=[]
            for seconds,parts in entries:
                frames.append(dict(seconds=seconds,parts=[dict(path=str(path.resolve()),x=x,y=y,layer=layer) for path,x,y,layer in parts]))
                im=Image.new('RGBA',(width,height))
                for path,x,y,layer in parts:im.alpha_composite(Image.open(path).convert('RGBA').crop((x,y,x+width,y+height)))
                if im.getbbox():bounds.append(im.getbbox())
                else:assert name=='MagicEffects','Unexpected blank character frame'
                preview.append(im)
            tags.append(dict(name=clip,first=first,last=len(frames)));previews[clip]=preview
        plan=dict(output=str((folder/(name+'.aseprite')).resolve()),width=width,height=height,layers=layers,frames=frames,clips=tags)
        # Absolute local paths are transient; portable metadata stores repo-relative source paths.
        temp=REPO/'Temp/Marco06B13R2';temp.mkdir(parents=True,exist_ok=True);plan_file=temp/(name+'.json');write(plan_file,plan)
        if not Path(plan['output']).exists():
            result=subprocess.run([str(args.aseprite),'-b','--script-param','plan='+str(plan_file),'--script',str(REPO/'Tools/ArtPipeline/Aseprite/assemble_npc_research_b13r2.lua')],capture_output=True,text=True,check=True)
            assert Path(plan['output']).exists(),result.stderr
        for f in frames:
            for part in f['parts']:part['path']=str(Path(part['path']).relative_to(REPO)).replace('\\','/')
        write(folder/'manifest.json',dict(name=name,canvas=[width,height],layers=layers,clips=tags,frames=frames,timing=timing,status='Editable source candidate; no NPC identity or production approval'))
        # Export through Aseprite, then compare every exported pixel to the supplied drawing composite.
        export=temp/name;export.mkdir(exist_ok=True)
        subprocess.run([str(args.aseprite),'-b',str(folder/(name+'.aseprite')),'--sheet',str(export/'sheet.png'),'--data',str(export/'sheet.json'),'--format','json-array','--sheet-type','horizontal'],capture_output=True,check=True)
        data=json.loads((export/'sheet.json').read_text());sheet=Image.open(export/'sheet.png').convert('RGBA');expected=[im for ims in previews.values() for im in ims]
        assert len(data['frames'])==len(expected)
        for frame,im in zip(data['frames'],expected):
            r=frame['frame'];actual=sheet.crop((r['x'],r['y'],r['x']+width,r['y']+height))
            assert actual.getchannel('A').tobytes()==im.getchannel('A').tobytes(),'Alpha change: '+name
            # Aseprite may retain hidden RGB in fully transparent pixels; those RGB values are not artwork.
            for a,b in zip(memoryview(actual.tobytes()).cast('I'),memoryview(im.tobytes()).cast('I')):
                assert a==b or (a>>24==0 and b>>24==0),'Visible pixel change: '+name
        for clip,ims in previews.items():
            if not (clip.endswith('south') or name=='MagicEffects'):continue
            clip_index=next(t for t in tags if t['name']==clip);duration=[max(10,round(frames[i]['seconds']*100)*10) for i in range(clip_index['first']-1,clip_index['last'])]
            nonempty=[im.getbbox() for im in ims if im.getbbox()]
            union=(min(b[0] for b in nonempty),min(b[1] for b in nonempty),max(b[2] for b in nonempty),max(b[3] for b in nonempty))
            output=[]
            for im in ims*2:
                canvas=Image.new('RGBA',(160,150),'#263137')
                crop=im.crop(union);canvas.alpha_composite(crop,((160-crop.width)//2,130-crop.height))
                output.append(canvas.convert('RGB').resize((320,300),Image.Resampling.NEAREST))
            output[0].save(EVIDENCE/(name+'-'+clip+'.gif'),save_all=True,append_images=output[1:],duration=duration*2,disposal=2,optimize=False)
        first=previews.get('idle_south',next(iter(previews.values())))[0];candidates.append((name,first))
        if name!='MagicEffects':
            strip=Image.new('RGBA',(8*120+70,4*125+25),'#263137');draw=ImageDraw.Draw(strip)
            draw.text((4,4),name+' | 8 sampled original walk frames/direction | native pixels',fill='white')
            for row,d in enumerate(['north','west','south','east']):
                ims=previews['walk_'+d];boxes=[im.getbbox() for im in ims];u=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
                draw.text((4,35+row*125),d,fill='white')
                for n in range(8):
                    crop=ims[round(n*(len(ims)-1)/7)].crop(u);strip.alpha_composite(crop,(70+n*120+(120-crop.width)//2,145+row*125-crop.height))
            strip.convert('RGB').save(EVIDENCE/(name+'-walk-directions.png'))
        checks.append(dict(name=name,frames=len(frames),clips=len(tags),canvas=[width,height],heightMin=min(b[3]-b[1] for b in bounds),heightMax=max(b[3]-b[1] for b in bounds),allExportedVisiblePixelsAndAlphaIdentical=True,transparentRgbIgnored=True,timing=timing,layers=layers))

    for name,root,animations,canvas in [
        ('HormelzGirl',args.girl/'StylOo_Redo',{'idle':'iddle_001','walk':'anim_walkwHD'},(256,256)),
        ('HormelzMelee',args.external/'melee/MeleeCharacter',{'idle':'Idle1','walk':'WalkFoward'},(126,132))]:
        clips={}
        for action,sub in animations.items():
            for direction,number in [('south',8),('west',2),('north',4),('east',6)]:
                path=next((root/sub).glob(f'*dir{number}.png'));local=source(path,name);entries=[]
                if name=='HormelzGirl':
                    meta=next((root/sub).glob(f'*dir{number}.json'));source(meta,name);doc=json.loads(meta.read_text(encoding='utf-8-sig'))
                    for f in doc['frames']:r=f['frame'];entries.append((f['duration'],[(local,int(r['x']),int(r['y']),'Original drawing')]))
                else:
                    # Publisher JSONs are empty. Inspect nonempty cells and use the matching author GIF timing as reference.
                    gif=next((root/sub).glob('*dir2.gif'));source(gif,name);g=Image.open(gif);assert all(g.seek(i) is None and g.info['duration']==40 for i in range(g.n_frames))
                    im=Image.open(path).convert('RGBA');w,h=canvas
                    for y in range(0,im.height,h):
                        for x in range(0,im.width,w):
                            if im.crop((x,y,x+w,y+h)).getbbox():entries.append((.04,[(local,x,y,'Original drawing')]))
                    assert len(entries)==g.n_frames
                clips[action+'_'+direction]=entries
        timing='Original JSON seconds retained in manifest; Aseprite rounds to integer milliseconds' if name=='HormelzGirl' else '40 ms reference from original dir2 GIF; other cardinal timings inferred; original JSONs empty'
        assemble(name,*canvas,clips,['Original drawing'],timing)

    for name,body,head in [('LpcFeminine','Body 01 - Feminine, Thin','Head 01 - Feminine'),('LpcMasculine','Body 02 - Masculine, Thin','Head 02 - Masculine')]:
        clips={}
        for action,count in [('Idle',3),('Walk',8)]:
            bp=source(args.external/f'lpc/Characters/Body/{body}/{action}.png',name+'Body')
            hp=source(args.external/f'lpc/Characters/Head/{head}/{action}.png',name+'Head')
            for row,direction in enumerate(['north','west','south','east']):clips[action.lower()+'_'+direction]=[(.125,[(bp,n*64,row*64,'Body'),(hp,n*64,row*64,'Head')]) for n in range(count)]
        # Keep body/head as separately editable layers; no tracing or synthesized pose.
        assemble(name,64,64,clips,['Body','Head'],'125 ms inspection timing only; source sheets have no per-frame timing')

    root=args.external/'foozle/Foozle_2DE0001_Pixel_Magic_Effects';clips={}
    for directory in sorted(root.iterdir()):
        if directory.is_dir() and directory.name!='Icons':clips[directory.name]=[(.1,[(source(path,'MagicEffects/'+directory.name),0,0,'Original effect')]) for path in sorted(directory.glob('*.png'))]
    assemble('MagicEffects',64,64,clips,['Original effect'],'100 ms inspection timing only; no source timeline provided; downloaded individual frames are 64x64')
    write(BASE/'original-hashes.json',source_records);write(EVIDENCE/'checks.json',checks)
    hero_meta=json.loads((REPO/'ArtSource/Characters/IronKnight/manifest.json').read_text(encoding='utf-8-sig'));hero=Image.open(REPO/hero_meta['clips'][0]['frames'][0]['png']).convert('RGBA')
    items=[('Official hero',hero)]+[item for item in candidates if item[0]!='MagicEffects'];board=Image.new('RGBA',(len(items)*150,170),'#263137');draw=ImageDraw.Draw(board)
    draw.text((6,5),'Native pixels: bases for editing, not final NPC designs',fill='white');draw.line((0,140,board.width,140),fill='#76987f')
    for i,(name,im) in enumerate(items):
        b=im.getbbox();crop=im.crop(b);board.alpha_composite(crop,(i*150+(150-crop.width)//2,140-crop.height));draw.text((i*150+5,150),name,fill='white')
    board.resize((board.width*2,board.height*2),Image.Resampling.NEAREST).convert('RGB').save(EVIDENCE/'base-comparison.png')
    print(json.dumps(checks,indent=2))


if __name__=='__main__':main()
