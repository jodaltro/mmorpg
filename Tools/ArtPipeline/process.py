"""Deterministic processing of curated rectangles; originals are read only.
python Tools/ArtPipeline/process.py
"""
import json, hashlib, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[2]
manifest=json.loads((ROOT/'Tools/ArtPipeline/frames.json').read_text())
OUT=ROOT/'Assets/Mmorpg/Art/Processed'
PREVIEW=ROOT/'Docs/Art/Previews'; PREVIEW.mkdir(parents=True,exist_ok=True)
sources={}
review_path=ROOT/'Tools/ArtPipeline/review.json'
review=json.loads(review_path.read_text()) if review_path.exists() else {}
for e in manifest['entries']:
    if e['source'] not in sources: sources[e['source']]=Image.open(ROOT/e['source']).convert('RGBA')
    x,y,w,h=e['rect']; im=sources[e['source']].crop((x,y,x+w,y+h))
    pixels=np.array(im); pixels[pixels[:,:,3]<=7]=0; im=Image.fromarray(pixels)
    if e.get('remove_polygons'):
        mask=Image.new('L',im.size,0);draw=ImageDraw.Draw(mask)
        for polygon in e['remove_polygons']: draw.polygon([(px-x,py-y) for px,py in polygon],fill=255)
        # 3px safety expansion removes the antialiased fringe along these hand cuts.
        mask=mask.filter(ImageFilter.MaxFilter(7))
        im.paste((0,0,0,0),(0,0),mask)
    size=(round(w*e['scale']),round(h*e['scale']))
    im=im.resize(size,Image.Resampling.NEAREST)
    canvas=Image.new('RGBA',e['canvas'])
    offset=(round(e['anchor'][0]-(e['source_anchor'][0]-x)*e['scale']),round(e['anchor'][1]-(e['source_anchor'][1]-y)*e['scale']))
    if offset[0]<0 or offset[1]<0 or offset[0]+size[0]>canvas.width or offset[1]+size[1]>canvas.height:
        raise ValueError('Canvas clips '+e['name'])
    canvas.alpha_composite(im,offset)
    dest=OUT/e['actor']/(e['name']+'.png');dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest)
    e['output']=str(dest.relative_to(ROOT)).replace('\\','/');e['output_sha256']=hashlib.sha256(dest.read_bytes()).hexdigest(); e['status']=review.get('actors',{}).get(e['actor'],'processed-awaiting-animation-review')
    e['bounds']=canvas.getbbox()
    e['clipped']=False
# Native scale contact sheets, enlarged with nearest for review.
for kind in ('Hero','Wolf','Spider','Golem','Bat','Healer','Hunter','Smith','Scholar','Environment','VFX','UI'):
    items=[e for e in manifest['entries'] if e['actor']==kind]
    if not items:continue
    cell=256 if kind=='Environment' else 144; sheet=Image.new('RGB',(cell*4,cell*math.ceil(len(items)/4)),(36,42,48));draw=ImageDraw.Draw(sheet)
    for i,e in enumerate(items):
        im=Image.open(ROOT/e['output']);px=(i%4)*cell+(cell-im.width)//2; py=(i//4)*cell+10
        sheet.paste(im,(px,py),im);draw.line((px,py+e['anchor'][1],px+im.width,py+e['anchor'][1]),fill=(67,87,88));draw.text(((i%4)*cell+3,(i//4)*cell+cell-19),e['name'],fill='white')
    sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(PREVIEW/(kind+'.png'))
    if kind in ('Hero','Wolf','Bat'):
        for action in ('walk','attack','dodge','flight'):
            seq=[e for e in items if e['animation']==action and e['direction']==('S' if kind=='Bat' else 'W')]
            if not seq:continue
            # Ping-pong return to rest explicitly; this is a preview, not extra authored poses.
            rest=next((e for e in items if e['animation']=='idle' and e['direction']=='W'),seq[0])
            seq=([rest]+seq+[rest]) if action not in ('walk','flight') else seq
            frames=[]
            for e in seq:
                im=Image.open(ROOT/e['output']);bg=Image.new('RGBA',im.size,(36,42,48,255));bg.alpha_composite(im);frames.append(bg.resize((im.width*4,im.height*4),Image.Resampling.NEAREST).convert('RGB'))
            frames[0].save(PREVIEW/(kind+'_'+action+'.gif'),save_all=True,append_images=frames[1:],duration=125,loop=0)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Processed',len(manifest['entries']),'frames. Original source SHA-256 preserved in inventory.')
