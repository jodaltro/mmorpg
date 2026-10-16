"""Read-only B13 comparison. No downloads, authoring, Unity imports or rescaling of characters.

Screen Smith CC0 crops may go into evidence; Laphkal/Hormelz review stays outside repo.
GegX is deliberately never opened: its license prohibits AI evaluation.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'Docs/Validation/Marco06B13'


def measure(im):
    alpha = im.getchannel('A')
    bounds = alpha.getbbox()
    solid = alpha.point(lambda a: 255 if a >= 128 else 0).getbbox()
    return dict(canvas=list(im.size), rgbaBounds=bounds,
                visibleHeight=bounds[3]-bounds[1], solidBounds=solid,
                solidHeight=solid[3]-solid[1], rgbaColors=len(im.getcolors(1000000)),
                sha256=hashlib.sha256(im.tobytes()).hexdigest())


def original(name):
    manifest = json.loads((REPO/f'ArtSource/Characters/{name}/manifest.json').read_text(encoding='utf-8-sig'))
    frame = manifest['clips'][0]['frames'][0]
    return Image.open(REPO/frame['png']).convert('RGBA'), frame


def board(entries, title, path):
    # Each strip uses native pixels. The second strip magnifies the WHOLE layout 3x nearest.
    native = Image.new('RGBA', (len(entries)*112, 145), '#263137')
    draw = ImageDraw.Draw(native)
    draw.text((5, 4), title, fill='white')
    draw.line((0, 112, native.width, 112), fill='#76987f')
    for i, (label, im) in enumerate(entries):
        bounds = im.getbbox()
        crop = im.crop(bounds)
        native.alpha_composite(crop, (i*112+(112-crop.width)//2, 112-crop.height))
        draw.text((i*112+4, 120), label, fill='white')
    native.convert('RGB').save(path)
    native.resize((native.width*3,native.height*3), Image.Resampling.NEAREST).convert('RGB').save(path.with_name(path.stem+'-3x.png'))


def cycle(frames, path, duration):
    output=[]
    for n in range(2):
        for im in frames:
            panel=Image.new('RGBA',(96,96),'#263137')
            panel.alpha_composite(im,((96-im.width)//2,90-im.height))
            output.append(panel.convert('RGB').resize((288,288),Image.Resampling.NEAREST))
    # Deliberately finite two cycles. Source frame order retained, no synthesized drawings.
    output[0].save(path,save_all=True,append_images=output[1:],duration=duration,disposal=2,optimize=False)


def directions(rows, path, title):
    panel=Image.new('RGBA',(340,330),'#263137');draw=ImageDraw.Draw(panel)
    draw.text((5,4),title,fill='white')
    for row,(direction,frames) in enumerate(rows.items()):
        draw.text((4,row*76+28),direction,fill='white')
        for n,im in enumerate(frames):
            b=im.getbbox();crop=im.crop(b)
            panel.alpha_composite(crop,(74+n*65+(64-crop.width)//2,row*76+74-crop.height))
    panel.convert('RGB').save(path)


def composite(entries, path, title):
    # Real baseline capture + explicit comparison overlay; never presented as Unity integration.
    bg=Image.open(OUT/'baseline/Orin-current.png').convert('RGBA')
    draw=ImageDraw.Draw(bg)
    draw.rectangle((0,285,bg.width,310),fill='#162228')
    draw.text((8,292),title+' | COMPOSITE ONLY - native 32 PPU, whole image x2',fill='white')
    for i,(label,im) in enumerate(entries):
        bounds=im.getbbox()
        crop=im.crop(bounds).resize(((bounds[2]-bounds[0])*2,(bounds[3]-bounds[1])*2),Image.Resampling.NEAREST)
        x=140+i*180
        bg.alpha_composite(crop,(x-crop.width//2,420-crop.height))
        draw.text((x-65,432),label,fill='white')
    bg.convert('RGB').save(path)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--external',type=Path,required=True)
    args=parser.parse_args();external=args.external.resolve()
    if external.is_relative_to(REPO):raise SystemExit('Restricted previews must remain outside repository')
    local=external/'review';local.mkdir(exist_ok=True);OUT.mkdir(exist_ok=True)
    baseline=[];metrics={}
    for name,label in [('IronKnight','Iron Knight'),('Healer','Mira current'),('Hunter','Orin current')]:
        im,frame=original(name);baseline.append((label,im));metrics[name]=dict(**measure(im),pivot=frame['pivot'],feet=frame['feet'])
    board(baseline,'CURRENT - 1 px = 1 px, 32 PPU',OUT/'current-scale.png')
    sheet=Image.open(external/'screensmith/TownsPeople2_Animations.png').convert('RGBA')
    candidates=[]
    for role,index in [('Mira',5),('Orin',6)]:
        # Observed 12 columns x 16 rows: each character has 3 frames x 4 rows.
        x=(index%4)*54;y=(index//4)*104
        rows={d:[sheet.crop((x+n*18,y+r*26,x+(n+1)*18,y+(r+1)*26)) for n in range(3)] for r,d in enumerate(['south','west','east','north'])}
        metrics['ScreenSmith-'+role]={d:[measure(im) for im in frames] for d,frames in rows.items()}
        directions(rows,OUT/f'screensmith-{role}-directions.png','Screen Smith CC0 | AI generated | native pixels')
        for d,frames in rows.items():cycle(frames,OUT/f'screensmith-{role}-walk-{d}.gif',100)
        candidates.append(('Screen '+role,rows['south'][0]))
    board(baseline+candidates,'CC0 REVIEW - native pixels / 32 PPU',OUT/'screensmith-scale.png')
    composite(baseline+candidates,OUT/'screensmith-valdoria-composite.png','Screen Smith CC0 - AI generated')
    restricted=[]
    for role,name in [('Mira','cleric'),('Orin','archer')]:
        rows={d:[Image.open(p).convert('RGBA') for p in sorted((external/'laphkal'/name).glob(f'{name}_{d}_*.png'))] for d in ['down','left','right','up']}
        assert all(len(frames)==4 for frames in rows.values())
        metrics['Laphkal-'+role]={d:[measure(im) for im in frames] for d,frames in rows.items()}
        directions(rows,local/f'laphkal-{role}-directions.png','LOCAL REVIEW ONLY - not licensed for public raw redistribution')
        for d,frames in rows.items():cycle(frames,local/f'laphkal-{role}-walk-{d}.gif',125)
        restricted.append(('Laphkal '+role,rows['down'][0]))
    board(baseline+restricted,'LOCAL ONLY - native pixels / 32 PPU',local/'laphkal-scale.png')
    composite(baseline+restricted,local/'laphkal-valdoria-composite.png','Laphkal LOCAL ONLY')
    # Preserve source rectangles and durations. Never infer a production pivot from bounding boxes.
    for action in ['anim_walkwHD','iddle_001']:
        for direction in [2,4,6,8]:
            p=next((external/'hormelz-girl/StylOo_Redo'/action).glob(f'*dir{direction}.json'))
            doc=json.loads(p.read_text(encoding='utf-8'));im=Image.open(p.with_suffix('.png')).convert('RGBA');frames=[]
            for f in doc['frames']:
                r=f['frame'];x,y,w,h=[int(r[k]) for k in ['x','y','w','h']];frames.append(im.crop((x,y,x+w,y+h)))
            metrics[f'HormelzGirl-{action}-{direction}']=dict(frames=len(frames),durationsSeconds=[f['duration'] for f in doc['frames']],first=measure(frames[0]),minHeight=min(measure(f)['visibleHeight'] for f in frames),maxHeight=max(measure(f)['visibleHeight'] for f in frames))
            if direction==8 and action=='iddle_001':board(baseline+[('Girl idle',frames[0])],'LOCAL only - native pixels',local/'hormelz-girl-scale.png')
    adaptation=local/'adaptation'
    if (adaptation/'cleric.json').exists() and (adaptation/'archer.json').exists():
        adapted=[];adaptation_checks={}
        for role,name in [('Mira','cleric'),('Orin','archer')]:
            doc=json.loads((adaptation/(name+'.json')).read_text(encoding='utf-8'))
            sheet=Image.open(adaptation/(name+'.png')).convert('RGBA');rows={};checks=[]
            for d,direction in enumerate(['down','left','right','up']):
                frames=[]
                for n in range(4):
                    record=doc['frames'][d*4+n];rect=record['frame'];x,y,w,h=[rect[k] for k in ['x','y','w','h']]
                    im=sheet.crop((x,y,x+w,y+h));original_im=Image.open(external/f'laphkal/{name}/{name}_{direction}_0{n+1}.png').convert('RGBA')
                    assert im.size==original_im.size and im.getchannel('A').tobytes()==original_im.getchannel('A').tobytes()
                    assert record['duration']==125
                    frames.append(im);checks.append(dict(direction=direction,frame=n+1,alphaIdentical=True,durationMs=125,changedPixels=sum(a!=b for a,b in zip(memoryview(im.tobytes()).cast('I'),memoryview(original_im.tobytes()).cast('I')))))
                rows[direction]=frames;cycle(frames,adaptation/f'{role}-walk-{direction}.gif',125)
            directions(rows,adaptation/f'{role}-directions.png','LOCAL PALETTE STUDY - Aseprite - original motion')
            adapted.append(('Adapted '+role,rows['down'][0]));adaptation_checks[role]=checks
        board(baseline+adapted,'LOCAL ASEPRITE STUDY - native 32 PPU',adaptation/'adapted-scale.png')
        board([baseline[0]]+restricted+adapted,'LOCAL - source and palette variant / same native size',adaptation/'before-after.png')
        composite(baseline+adapted,adaptation/'adapted-valdoria.png','Local Aseprite palette study')
        (OUT/'adaptation-checks.json').write_text(json.dumps(adaptation_checks,indent=2)+'\n',encoding='utf-8')
    (OUT/'pixel-measurements.json').write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf-8')
    print('Published only existing project artwork and Screen Smith CC0 crops. Restricted previews: '+str(local))


if __name__=='__main__':main()
