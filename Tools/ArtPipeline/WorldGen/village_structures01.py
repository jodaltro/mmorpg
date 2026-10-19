"""One-time source assembly and repeatable Aseprite-only module export.

ImageGen masters are retained; bootstrap refuses existing source. Pixel art
fit uses nearest and no dithering. Final pixels belong to the .aseprite file.
"""
from pathlib import Path
import argparse,json,shutil,subprocess
from PIL import Image,ImageDraw
import numpy as np
import playable_village01 as v

BASE=v.BASE/'StructuresV1'
MASTERS={
 'wall':'exec-826221f0-b443-4f2c-88f0-681f14e2d3b2.png',
 'wall-side-study':'exec-052d2095-0745-4de0-98d8-f91cda1d76b2.png',
 'bridge':'exec-0911273d-1dd0-4c22-8a53-f81f5ed9ab37.png'}
GENERATED=Path('C:/Users/Administrator/.codex/generated_images/01a14b5b-0ccf-7062-aba5-78b8e4e46efb')

def lua(code,path):
    path.write_text(code,encoding='utf-8');subprocess.run(['D:/Aseprite/Aseprite.exe','-b','--script',str(path)],check=True,capture_output=True)
def q(path):return json.dumps(str(path.resolve()).replace('\\','/'))
def author():
    if BASE.exists():raise FileExistsError('Refuse source overwrite')
    BASE.mkdir(parents=True);(BASE/'Masters').mkdir();layers=[]
    for name,file in MASTERS.items():shutil.copyfile(GENERATED/file,BASE/'Masters'/f'{name}.png')
    im=Image.open(BASE/'Masters/wall.png').convert('RGBA');im=im.crop(im.getbbox()).resize((384,128),Image.Resampling.NEAREST)
    layers.append(('wall-horizontal',im))
    # The diagonal side study is not rotated/stretched into a false world axis.
    # Author a straight longitudinal parapet using its approved-family stone
    # pigment and distinct side/top planes. Separate 12u ground span from height.
    side=Image.new('RGBA',(96,384));d=ImageDraw.Draw(side)
    material=im.crop((80,65,160,112)).convert('RGB')
    for y in range(0,384,47):side.paste(material.resize((45,47),Image.Resampling.NEAREST),(43,y))
    d.rectangle((14,0,42,383),fill=(178,166,126));d.line([(14,0),(14,383)],fill=(224,212,163),width=3);d.line([(86,0),(86,383)],fill=(76,79,61),width=4)
    for y in range(-8,384,48):
        d.polygon([(8,y+16),(8,y),(25,y-5),(42,y+2),(42,y+21)],fill=(207,194,146))
        d.polygon([(25,y+6),(42,y+2),(42,y+21),(25,y+28)],fill=(110,108,79));d.line([(9,y),(25,y-5),(41,y+2)],fill=(235,219,173),width=2)
        d.line([(43,y+28),(85,y+28)],fill=(103,101,75),width=2)
    layers.append(('wall-vertical',side))
    bridge=Image.open(BASE/'Masters/bridge.png').convert('RGBA');bridge=bridge.crop(bridge.getbbox()).resize((320,576),Image.Resampling.NEAREST)
    # Ownership layers, same pixels; no guessed interior is reconstructed.
    for name,x0,x1 in [('bridge-left',0,94),('bridge-deck',94,226),('bridge-right',226,320)]:
        image=Image.new('RGBA',bridge.size);image.paste(bridge.crop((x0,0,x1,576)),(x0,0));layers.append((name,image))
    code='local s=Sprite(512,640);s:deleteLayer(s.layers[1]);'
    for name,image in layers:
        p=BASE/(name+'-bootstrap.png');image.save(p)
        code+=f'local l=s:newLayer();l.name={json.dumps(name)};s:newCel(l,1,Image{{fromFile={q(p)}}},Point(0,0));'
    code+='s:saveAs('+q(BASE/'village-structures.aseprite')+');s:close();'
    lua(code,BASE/'initial-authoring.lua')
    v.write(BASE/'source.json',{'schema':'valdoria-structure-source/v1','source':'village-structures.aseprite','canvas':[512,640],'ppu':32,'nativeRects':{name:[0,0,*image.size] for name,image in layers},'masters':{name:{'file':f'Masters/{name}.png','sha256':v.sha(BASE/'Masters'/f'{name}.png')} for name in MASTERS},'provenance':'ImageGen built-in: new environment sprites referenced approved castle only. Nearest native fit, no dithering. Side master retained as rejected diagonal study; longitudinal wall authored as distinct planes. Bootstrap is provenance, never overwrite edited source. Sources approved only after explicit user review. No character pixels generated.'})
def export(out):
    if out.exists():raise FileExistsError('Refuse export overwrite')
    out.mkdir(parents=True);meta=v.read(BASE/'source.json');code='local s=app.open('+q(BASE/meta['source'])+');'
    for name,rect in meta['nativeRects'].items():
        code+='for _,l in ipairs(s.layers) do l.isVisible=(l.name=='+json.dumps(name)+') end;'
        code+='local im=Image(s.spec);im:drawSprite(s,1);local crop=Image(im,Rectangle('+','.join(str(t) for t in rect)+'));crop:saveAs('+q(out/(name+'.png'))+');'
    code+='s:close();';lua(code,out/'export.lua');v.write(out/'manifest.json',{'source':{'path':str((BASE/meta['source']).relative_to(v.ROOT)).replace('\\','/'),'sha256':v.sha(BASE/meta['source'])},'files':{p.name:v.sha(p) for p in out.glob('*.png')}})
def refine():
    final=BASE/'village-structures-v2.aseprite'
    if final.exists():raise FileExistsError('Refuse revised source overwrite')
    master=Image.open(BASE/'Masters/wall.png').convert('RGBA');a=master.getchannel('A');box=a.point(lambda value:255 if value>10 else 0).getbbox()
    master=master.crop(box).resize((384,192),Image.Resampling.NEAREST)
    # Discard almost-transparent image-generation fringe in the new module;
    # explicit source operation, never global tint or filtering of old art.
    arr=np.array(master);arr[:,:,3]=np.where(arr[:,:,3]>10,arr[:,:,3],0);master=Image.fromarray(arr)
    fit=BASE/'wall-horizontal-native-v2.png';master.save(fit)
    code='local s=app.open('+q(BASE/'village-structures.aseprite')+');for _,l in ipairs(s.layers) do if l.name=="wall-horizontal" then s:deleteCel(l,1);s:newCel(l,1,Image{fromFile='+q(fit)+'},Point(0,0)) end end;s:saveAs('+q(final)+');s:close();'
    lua(code,BASE/'refine-v2.lua');meta=v.read(BASE/'source.json');meta['source']=final.name;meta['nativeRects']['wall-horizontal']=[0,0,384,192];meta['revision']='V2: alpha>10 bounds remove empty tiling margins; wall reaches 6u; physics unchanged';v.write(BASE/'source.json',meta)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['author','refine','export']);p.add_argument('--output',type=Path);a=p.parse_args();author() if a.action=='author' else refine() if a.action=='refine' else export(a.output)
