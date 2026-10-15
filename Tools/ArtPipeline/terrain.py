"""Small periodic 32px terrain library. Deterministic, local, no external art.
Original atlas palette guides these tiles; source framed squares are rejected.
"""
from pathlib import Path
import random,json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'Assets/Mmorpg/Art/Tilesets';OUT.mkdir(parents=True,exist_ok=True)
palettes={'Grass':[(77,100,49),(69,91,45),(83,108,53),(88,112,56),(63,85,44)],'Forest':[(49,69,47),(44,62,43),(55,76,50),(60,81,52),(39,58,41)],'Dirt':[(129,104,71),(122,97,66),(136,110,77),(142,116,80),(113,93,64)],'Mine':[(65,64,65),(58,57,60),(73,69,68),(80,74,70),(53,54,58)],'Marsh':[(43,67,59),(38,61,56),(49,74,63),(58,79,63),(33,55,51)],'Ruin':[(91,98,90),(79,88,83),(103,108,97),(112,117,103),(72,83,78)]}
def tile(kind,variant):
    rng=random.Random(kind+str(variant));colors=palettes[kind];im=Image.new('RGBA',(32,32),colors[0]+(255,));d=ImageDraw.Draw(im)
    for _ in range(185):
        x=rng.randrange(32);y=rng.randrange(32);color=colors[rng.randrange(len(colors))]+(255,)
        for dx,dy in [(0,0),(1,0),(1,1)] if rng.random()<.25 else [(0,0)]:d.point(((x+dx)%32,(y+dy)%32),fill=color)
    if kind in ('Grass','Forest'):
        for _ in range(8):
            x=rng.randrange(32);y=rng.randrange(32)
            for dx,dy in [(0,0),(-1,-1),(1,-2)]:d.point(((x+dx)%32,(y+dy)%32),fill=colors[2]+(255,))
    return im
for kind in palettes:
    for v in range(4):tile(kind,v).save(OUT/f'{kind}_{v}.png')
# Dirt boundary masks: bit 1 west, 2 east, 4 south, 8 north marks grass neighbour.
# Shapes vary along a periodic edge; adjacent dirt cells share an open boundary.
for mask in range(16):
    im=tile('Dirt',0);grass=tile('Grass',0)
    for y in range(32):
        for x in range(32):
            width=2+((x*7+y*11)%3)
            edge=(mask&1 and x<width) or (mask&2 and x>=32-width) or (mask&4 and y>=32-width) or (mask&8 and y<width)
            if edge:im.putpixel((x,y),grass.getpixel((x,y)))
    im.save(OUT/f'Path_{mask}.png')
sheet=Image.new('RGB',(32*8,32*5));tiles=list(OUT.glob('*.png'))
for i,p in enumerate(tiles):sheet.paste(Image.open(p),((i%8)*32,(i//8)*32))
sheet.resize((768,480),Image.Resampling.NEAREST).save(ROOT/'Docs/Art/Previews/Terrain.png')
(OUT/'provenance.json').write_text(json.dumps({'generator':'Tools/ArtPipeline/terrain.py','seed':'kind + variant','size':[32,32],'ppu':32,'license':'Created locally for this project; no downloads.','tiles':len(tiles)},indent=2))
ui=ROOT/'Assets/Mmorpg/Art/Processed/UI';ui.mkdir(parents=True,exist_ok=True)
frame=Image.new('RGBA',(24,24),(23,30,33,247));d=ImageDraw.Draw(frame);d.rectangle((0,0,23,23),outline=(44,35,29,255));d.rectangle((1,1,22,22),outline=(131,105,66,255));d.rectangle((3,3,20,20),outline=(58,64,58,255));d.point((2,2),fill=(211,183,119,255));d.point((21,21),fill=(211,183,119,255));frame.save(ui/'Panel.png')
shadow=Image.new('RGBA',(32,16));d=ImageDraw.Draw(shadow);d.ellipse((3,5,28,12),fill=(10,20,21,48));d.ellipse((7,6,24,11),fill=(10,20,21,68));shadow.save(ROOT/'Assets/Mmorpg/Art/Processed/VFX/GroundShadow.png')
dummy=Image.new('RGBA',(48,64));d=ImageDraw.Draw(dummy)
d.rectangle((21,32,26,60),fill='#302820');d.rectangle((22,35,24,59),fill='#755536');d.rectangle((6,23,41,28),fill='#302820');d.rectangle((7,24,40,26),fill='#9a7848')
d.polygon([(16,24),(31,24),(34,43),(29,48),(17,47),(13,42)],fill='#342f25');d.polygon([(17,25),(29,25),(32,42),(28,46),(18,45),(15,40)],fill='#947448');d.rectangle((17,28,22,41),fill='#b29761');d.rectangle((15,35,32,37),fill='#514236');d.rectangle((19,38,28,39),fill='#65513b')
d.ellipse((15,5,32,24),fill='#362f25');d.ellipse((16,6,30,22),fill='#aa915c');d.rectangle((18,8,23,11),fill='#c6af77');d.rectangle((26,9,29,18),fill='#80663e');d.point((20,15),fill='#392e25');d.point((26,15),fill='#392e25');d.line((21,19,25,19),fill='#675134')
for x,y in [(17,8),(28,8),(14,13),(31,15),(18,23),(29,22),(14,35),(32,40)]:d.line((x,y,x-2,y+2),fill='#b69b60')
dummy.save(ROOT/'Assets/Mmorpg/Art/Processed/Environment/TrainingDummy.png')
print(len(tiles),'terrain sprites')
