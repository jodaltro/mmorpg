"""Layer professional LPC garments and apply deterministic material ramps through Aseprite.
No body geometry, motion, garment silhouettes, new poses or gameplay are generated.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
LIB=ROOT/'ArtSource/Labs/NpcResearch/Marco06B13R2'
OUT=LIB/'Wardrobe'
EVIDENCE=ROOT/'Docs/Validation/Marco06B13R2/Wardrobe'
TEMP=ROOT/'Temp/Marco06B13R2/Wardrobe'


def dump(path,data):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')


def rgb(s):return tuple(bytes.fromhex(s))


def ramp(path,colors,keep_outline=True):
    im=Image.open(path).convert('RGBA')
    values=sorted({p[:3] for p in im.get_flattened_data() if p[3] and (not keep_outline or sum(p[:3])>150)},key=lambda p:sum(p))
    assert values
    return {','.join(map(str,v)):rgb(colors[round(i*(len(colors)-1)/max(1,len(values)-1))]) for i,v in enumerate(values)}


def tinted(im,mapping):
    result=im.copy()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=im.getpixel((x,y));target=mapping.get(f'{r},{g},{b}')
            if target is not None:result.putpixel((x,y),(*target,a))
    assert result.getchannel('A').tobytes()==im.getchannel('A').tobytes()
    return result


def main():
    p=argparse.ArgumentParser();p.add_argument('--external',type=Path,required=True);p.add_argument('--aseprite',type=Path,required=True);p.add_argument('--resume',action='store_true');args=p.parse_args()
    assert args.resume or not OUT.exists(),'Preserve existing wardrobe edits; use new output revision'
    OUT.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True);TEMP.mkdir(parents=True,exist_ok=True)
    hashes={};originals={}
    def copy(path):
        relative=path.relative_to(args.external/'lpc');dest=OUT/'Sources'/relative;dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():assert dest.read_bytes()==path.read_bytes()
        else:shutil.copyfile(path,dest)
        hashes[str(dest.relative_to(ROOT)).replace('\\','/')]=hashlib.sha256(dest.read_bytes()).hexdigest();return dest
    for gender in ['Feminine, Thin','Masculine, Thin']:
        originals[gender]={}
        for action in ['Idle','Walk']:
            originals[gender][action]={slot:copy(args.external/f'lpc/Characters/Clothing/{gender}/{group}/{piece}/{action}.png') for slot,group,piece in [('Shirt','Torso','Shirt 01 - Longsleeve Shirt'),('Pants','Legs','Pants 03 - Pants'),('Boots','Feet','Shoes 02 - Boots')]}
            hair='Medium 04 - Bangs & Bun' if gender.startswith('Feminine') else 'Short 02 - Parted'
            originals[gender][action]['Hair']=copy(args.external/f'lpc/Characters/Hair/{hair}/{action}.png')
    for name in ['Clothing','Hair']:copy(args.external/f'lpc/Characters/{name}/Credits.txt')
    palettes={
      'MiraIvory':dict(base='LpcFeminine',gender='Feminine, Thin',shirt=['6b6258','948674','c5bea1','e4e1c7','f3f0dc'],pants=['263d32','3f5740','637c58','90a077','bcc6a0']),
      'MiraSage':dict(base='LpcFeminine',gender='Feminine, Thin',shirt=['354a3c','52694f','81966b','adc491','d3ddae'],pants=['3a302b','584a39','7d6b4d','a18a66','c7b58c']),
      'OrinForest':dict(base='LpcMasculine',gender='Masculine, Thin',shirt=['243b2c','365b3b','587b4d','7b9863','abc18b'],pants=['382a24','59422f','806242','a58960','c6b38a']),
      'OrinUmber':dict(base='LpcMasculine',gender='Masculine, Thin',shirt=['4b3428','6b4b33','967247','bb9666','ddc496'],pants=['22352b','394c35','586f49','7a9065','a2b78d'])}
    leather=['281d1b','493129','705039','99714e','c1976b'];hair=['2c1b16','492a1e','67402b','875a3a','ad7c50','d3a470'];report=[];all_variants=[]
    for name,recipe in palettes.items():
        base=json.loads((LIB/recipe['base']/'manifest.json').read_text());frames=[];expected=[];maps={}
        for slot,colors in [('Shirt',recipe['shirt']),('Pants',recipe['pants']),('Boots',leather),('Hair',hair)]:
            # Build a mapping over both author sheets so identical source colors stay identical across actions.
            colorset={}
            for action in ['Idle','Walk']:colorset.update(ramp(originals[recipe['gender']][action][slot],colors,slot!='Hair'))
            maps[slot]=colorset
        for clip in base['clips']:
            action=clip['name'].split('_')[0].title()
            for index in range(clip['first']-1,clip['last']):
                f=base['frames'][index];parts={part['layer']:dict(part,path=str((ROOT/part['path']).resolve())) for part in f['parts']};body=parts['Body'];head=parts['Head'];x,y=body['x'],body['y']
                for slot in ['Pants','Boots','Shirt','Hair']:parts[slot]=dict(path=str(originals[recipe['gender']][action][slot].resolve()),x=x,y=y,layer=slot,colorMap=maps[slot])
                ordered=[parts[k] for k in ['Body','Pants','Boots','Shirt','Head','Hair']];frames.append(dict(seconds=f['seconds'],parts=ordered));im=Image.new('RGBA',(64,64))
                for part in ordered:
                    piece=Image.open(part['path']).convert('RGBA').crop((x,y,x+64,y+64));piece=tinted(piece,part.get('colorMap',{}));im.alpha_composite(piece)
                expected.append(im)
        plan=dict(output=str((OUT/(name+'.aseprite')).resolve()),width=64,height=64,layers=['Body','Pants','Boots','Shirt','Head','Hair'],frames=frames,clips=base['clips']);planfile=TEMP/(name+'.json');dump(planfile,plan)
        if not Path(plan['output']).exists():subprocess.run([str(args.aseprite),'-b','--script-param','plan='+str(planfile),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/assemble_npc_research_b13r2.lua')],capture_output=True,text=True,check=True)
        sheet=TEMP/(name+'.png');meta=TEMP/(name+'-export.json');subprocess.run([str(args.aseprite),'-b',plan['output'],'--sheet',str(sheet),'--data',str(meta),'--format','json-array','--sheet-type','horizontal'],capture_output=True,check=True)
        data=json.loads(meta.read_text());image=Image.open(sheet).convert('RGBA');assert len(data['frames'])==len(expected)==44
        for f,reference in zip(data['frames'],expected):
            r=f['frame'];actual=image.crop((r['x'],r['y'],r['x']+64,r['y']+64));assert actual.getchannel('A').tobytes()==reference.getchannel('A').tobytes()
            for a,b in zip(memoryview(actual.tobytes()).cast('I'),memoryview(reference.tobytes()).cast('I')):assert a==b or (a>>24==0 and b>>24==0)
        # Exported cels and recipe can be independently edited; no body drawing or frame order changed.
        for frame in frames:
            for part in frame['parts']:part['path']=str(Path(part['path']).relative_to(ROOT)).replace('\\','/')
        dump(OUT/(name+'.json'),dict(recipe=recipe,colorMaps=maps,frames=frames,clips=base['clips'],canvas=[64,64],license='OGA-BY-3.0',status='Procedural garment assembly/color proof; artistic approval pending'))
        for clip in base['clips']:
            if not clip['name'].endswith('south'):continue
            ims=expected[clip['first']-1:clip['last']];preview=[]
            for im in ims*2:
                panel=Image.new('RGBA',(100,100),'#263137');panel.alpha_composite(im,(18,18));preview.append(panel.convert('RGB').resize((400,400),Image.Resampling.NEAREST))
            preview[0].save(EVIDENCE/(name+'-'+clip['name']+'.gif'),save_all=True,append_images=preview[1:],duration=125,disposal=2,optimize=False)
        if name in ['MiraIvory','OrinForest']:
            strip=Image.new('RGBA',(700,384),'#263137');draw=ImageDraw.Draw(strip)
            draw.text((4,4),name+' - original motion / layered clothes',fill='white')
            for row,d in enumerate(['north','west','south','east']):
                clip=next(c for c in base['clips'] if c['name']=='walk_'+d);draw.text((2,35+row*90),d,fill='white')
                for n,index in enumerate(range(clip['first']-1,clip['last'])):strip.alpha_composite(expected[index],(60+n*80,25+row*90))
            strip.convert('RGB').save(EVIDENCE/(name+'-walk-directions.png'))
        south=next(c for c in base['clips'] if c['name']=='idle_south');all_variants.append((name,expected[south['first']-1]));bounds=[im.getbbox() for im in expected]
        report.append(dict(name=name,frames=44,clips=8,layers=plan['layers'],sourceBodyAndHeadUnchanged=True,garmentAlphaAndGeometryUnchanged=True,exportMatchesExpectedVisiblePixelsAndAlpha=True,heightMin=min(b[3]-b[1] for b in bounds),heightMax=max(b[3]-b[1] for b in bounds),timing='125 ms inspection; inherited from research base',runtimeChanges=False))
    board=Image.new('RGBA',(len(all_variants)*120,100),'#263137');draw=ImageDraw.Draw(board)
    for i,(name,im) in enumerate(all_variants):board.alpha_composite(im,(i*120+28,8));draw.text((i*120+6,78),name,fill='white')
    board.resize((board.width*3,board.height*3),Image.Resampling.NEAREST).convert('RGB').save(EVIDENCE/'wardrobe-options.png')
    dump(OUT/'source-hashes.json',hashes);dump(EVIDENCE/'checks.json',report);print(json.dumps(report,indent=2))


if __name__=='__main__':main()
