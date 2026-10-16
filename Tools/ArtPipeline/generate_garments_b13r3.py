"""Drive the Aseprite procedural surface authoring backend, export and inspect native frames.
Python measures source landmarks and builds previews; all new garment pixels are authored in Lua/Aseprite.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'ArtSource/Labs/NpcResearch/Marco06B13R2/Wardrobe'


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--recipe',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--aseprite',type=Path,default=Path('D:/Aseprite/Aseprite.exe'));args=parser.parse_args()
    output=args.output.resolve();assert not output.exists(),'Refusing to overwrite generated or manually edited work';output.mkdir(parents=True)
    recipe=json.loads(args.recipe.read_text(encoding='utf-8'));manifest=json.loads((SOURCE/'MiraIvory.json').read_text(encoding='utf-8'));source=SOURCE/'MiraIvory.aseprite';before=digest(source);poses=[]
    for clip in manifest['clips']:
        direction=clip['name'].split('_')[-1]
        for n in range(clip['first']-1,clip['last']):
            frame=manifest['frames'][n];parts={p['layer']:p for p in frame['parts']};bounds={}
            for name in ['Head','Body']:
                p=parts[name];image=Image.open(ROOT/p['path']).convert('RGBA').crop((p['x'],p['y'],p['x']+64,p['y']+64));bounds[name]=image.getbbox()
            head,body=bounds['Head'],bounds['Body'];cx=(head[0]+head[2])/2
            poses.append(dict(direction=direction,action=clip['name'].split('_')[0],sourceFrame=n,
                head=dict(x=cx,y=head[1]+5),shoulders=dict(x=cx,y=head[3]-1),waist=dict(x=cx,y=head[3]+11),
                headBounds=head,bodyBounds=body,feet=dict(x=32,y=62),groundPivot=dict(x=32,y=44)))
    temp=ROOT/'Temp/Marco06B13R3';temp.mkdir(parents=True,exist_ok=True)
    plan=dict(source=str(source),output=str(output/(recipe['name']+'.aseprite')),metadata=str(output/'geometry.json'),recipe=recipe,poses=poses)
    planfile=temp/(recipe['name']+'-'+output.name+'.json');planfile.write_text(json.dumps(plan),encoding='utf-8')
    script=ROOT/'Tools/ArtPipeline/Aseprite/generate_garments_b13r3.lua';geometry=ROOT/'Tools/ArtPipeline/Aseprite/garment_geometry.lua'
    result=subprocess.run([str(args.aseprite),'-b','--script-param','plan='+str(planfile),'--script-param','geometry='+str(geometry),'--script',str(script)],capture_output=True,text=True,check=True)
    assert Path(plan['output']).exists(),result.stdout+result.stderr
    subprocess.run([str(args.aseprite),'-b',plan['output'],'--sheet',str(output/'spritesheet.png'),'--data',str(output/'aseprite.json'),'--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
    doc=json.loads((output/'aseprite.json').read_text());sheet=Image.open(output/'spritesheet.png').convert('RGBA');frames=[]
    for f in doc['frames']:
        r=f['frame'];assert r['w']==64 and r['h']==64
        frames.append(sheet.crop((r['x'],r['y'],r['x']+64,r['y']+64)))
    assert len(frames)==len(poses)==44 and before==digest(source)
    metadata=json.loads((output/'geometry.json').read_text());assert metadata['originalLayersPreserved'];assert all(f['metrics']['clippedFragments']==0 for f in metadata['frames']),'Geometry outside native canvas'
    export=dict(schema='npc-procedural-garment-v1',character='Mira',ppu=32,canvas=[64,64],pivot=[32,44],feet=[32,62],recipe=recipe,source='ArtSource/Labs/NpcResearch/Marco06B13R2/Wardrobe/MiraIvory.aseprite',sourceSha256=before,
                license='Composite derivative OGA-BY-3.0; generated geometry by this project',clips=manifest['clips'],frames=[dict(index=i,rect=f['frame'],durationMs=f['duration'],sha256=hashlib.sha256(frames[i].tobytes()).hexdigest()) for i,f in enumerate(doc['frames'])],status='Experimental wardrobe; no production promotion')
    (output/'manifest.json').write_text(json.dumps(export,indent=2)+'\n',encoding='utf-8')
    for clip in manifest['clips']:
        ims=frames[clip['first']-1:clip['last']];render=[]
        for im in ims*2:
            panel=Image.new('RGBA',(84,84),'#263137');panel.alpha_composite(im,(10,10));render.append(panel.convert('RGB').resize((336,336),Image.Resampling.NEAREST))
        render[0].save(output/(clip['name']+'.gif'),save_all=True,append_images=render[1:],duration=125,disposal=2,optimize=False)
    board=Image.new('RGBA',(8*80+70,4*90+25),'#263137');draw=ImageDraw.Draw(board)
    draw.text((4,4),recipe['name']+' - generated geometry / original body poses',fill='white')
    for row,d in enumerate(['north','west','south','east']):
        clip=next(c for c in manifest['clips'] if c['name']=='walk_'+d);draw.text((4,40+row*90),d,fill='white')
        for n,i in enumerate(range(clip['first']-1,clip['last'])):board.alpha_composite(frames[i],(70+n*80,25+row*90))
    board.convert('RGB').save(output/'directions.png')
    native=Image.new('RGBA',(4*90,88),'#263137');draw=ImageDraw.Draw(native)
    for i,d in enumerate(['south','west','north','east']):
        clip=next(c for c in manifest['clips'] if c['name']=='idle_'+d);native.alpha_composite(frames[clip['first']-1],(i*90+13,0));draw.text((i*90+10,70),d,fill='white')
    native.resize((native.width*3,native.height*3),Image.Resampling.NEAREST).convert('RGB').save(output/'idle-directions-3x.png')
    report=dict(frames=44,clips=8,canvas=[64,64],sourceFileUnchanged=True,originalLayersPreserved=True,
                generatedTriangles=sum(f['metrics']['triangles'] for f in metadata['frames']),clippedFragments=0,
                minimumVisibleHeight=min(im.getbbox()[3]-im.getbbox()[1] for im in frames),maximumVisibleHeight=max(im.getbbox()[3]-im.getbbox()[1] for im in frames),secondaryClothAnimation=False)
    (output/'qa.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))


if __name__=='__main__':main()
