"""Drive Aseprite inspection conversion and build comparison boards from existing pixels."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'ArtSource/Labs/Humanoid2026'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--renders',type=Path,required=True)
    parser.add_argument('--aseprite',default='D:/Aseprite/Aseprite.exe');args=parser.parse_args()
    inspection=json.loads((args.renders/'inspection.json').read_text())
    dest=LAB/'Preview';dest.mkdir(exist_ok=False)
    out_frames={};report={}
    for sex,data in inspection.items():
        folder=dest/sex;folder.mkdir();clips=[];frames=[]
        for record in data['frames']:
            name=record['clip'];duration=.125 if name.startswith('idle') else (data['walkFrames'][1]-data['walkFrames'][0])/30/12
            if not clips or clips[-1]['name']!=name:clips.append(dict(name=name,first=len(frames)+1,last=len(frames)+1))
            else:clips[-1]['last']+=1
            frames.append(dict(path=str((args.renders/record['file']).resolve()),duration=duration))
        plan=dict(frames=frames,clips=clips,output=str((folder/(sex+'.aseprite')).resolve()))
        plan_path=ROOT/'Temp/HumanoidResearch'/('aseprite-'+sex+'.json');plan_path.write_text(json.dumps(plan))
        subprocess.run([args.aseprite,'-b','--script-param','plan='+str(plan_path),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/build_humanoid_study.lua')],check=True,capture_output=True)
        subprocess.run([args.aseprite,'-b',plan['output'],'--sheet',str(folder/'spritesheet.png'),'--list-tags','--data',str(folder/'aseprite.json'),'--format','json-array','--sheet-type','rows','--sheet-columns','8'],check=True,capture_output=True)
        sheet=Image.open(folder/'spritesheet.png').convert('RGBA');doc=json.loads((folder/'aseprite.json').read_text());images=[]
        for f in doc['frames']:
            r=f['frame'];im=sheet.crop((r['x'],r['y'],r['x']+128,r['y']+160));b=im.getbbox();assert b and b[0]>0 and b[1]>0 and b[2]<128 and b[3]<160,'Body clipped'
            assert set(im.getchannel('A').get_flattened_data())<={0,255};images.append(im)
        out_frames[sex]=(images,clips)
        for clip in clips:
            selected=images[clip['first']-1:clip['last']];gif=[]
            for im in selected*2:
                panel=Image.new('RGBA',(128,160),'#263137');panel.alpha_composite(im);gif.append(panel.convert('RGB').resize((384,480),Image.Resampling.NEAREST))
            gif[0].save(folder/(clip['name']+'.gif'),save_all=True,append_images=gif[1:],duration=round(frames[clip['first']-1]['duration']*1000),disposal=2,optimize=False)
        report[sex]=dict(frames=len(images),clips=len(clips),nativeCanvas=[128,160],
            visibleHeightRange=[min(im.getbbox()[3]-im.getbbox()[1] for im in images),max(im.getbbox()[3]-im.getbbox()[1] for im in images)],
            visibleFootBottomRange=[min(im.getbbox()[3] for im in images),max(im.getbbox()[3] for im in images)],
            frameHashes=[hashlib.sha256(im.tobytes()).hexdigest() for im in images],
            pixelPass='Aseprite Lua: threshold alpha 160, channel quantization 16, separate 1px outline',
            sourceAnimation='Professional UAL1 Idle_Loop/Walk_Loop, experimental retarget; not artistic approval')
        (folder/'manifest.json').write_text(json.dumps(dict(character=sex,clips=clips,frames=data['frames'],qa=report[sex]),indent=2)+'\n')
    # Native pixel comparison: no rescaling to conceal differences in anatomy.
    board=Image.new('RGBA',(600,190),'#263137');draw=ImageDraw.Draw(board)
    draw.text((8,6),'Native pixel comparison / candidate study - not in-game capture',fill='white')
    entries=[]
    for name in ['MiraHealer','OrinTracker']:
        path=ROOT/f'ArtSource/Labs/NpcResearch/Marco06B13R4/Results/{name}'
        m=json.loads((path/'aseprite.json').read_text());sheet=Image.open(path/'spritesheet.png').convert('RGBA');r=m['frames'][6]['frame']
        entries.append((name,sheet.crop((r['x'],r['y'],r['x']+64,r['y']+64)),[32,62]))
    for sex,(images,clips) in out_frames.items():
        clip=next(c for c in clips if c['name']=='idle_south');entries.append((sex+' candidate',images[clip['first']-1],[64,144]))
    for i,(name,im,foot) in enumerate(entries):
        x=70+i*145;board.alpha_composite(im,(x-foot[0],160-foot[1]));draw.text((i*145+10,172),name,fill='white')
    board.convert('RGB').save(dest/'native-comparison.png')
    board.resize((1200,380),Image.Resampling.NEAREST).convert('RGB').save(dest/'native-comparison-2x.png')
    views=Image.new('RGBA',(8*105,190),'#263137');draw=ImageDraw.Draw(views)
    for col,(sex,direction) in enumerate((s,d) for s in ['Male','Female'] for d in ['south','west','north','east']):
        images,clips=out_frames[sex];clip=next(c for c in clips if c['name']=='idle_'+direction)
        views.alpha_composite(images[clip['first']-1],(col*105-12,0));draw.text((col*105+3,166),sex,fill='white');draw.text((col*105+3,178),direction,fill='white')
    views.convert('RGB').save(dest/'directions.png')
    (dest/'qa.json').write_text(json.dumps(report,indent=2)+'\n')
    (dest/'inspection.json').write_text(json.dumps(inspection,indent=2)+'\n')
    print(json.dumps({s:{k:v for k,v in r.items() if k!='frameHashes'} for s,r in report.items()},indent=2))


if __name__=='__main__':main()
