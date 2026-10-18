"""Review board only: real Blender studies and unchanged approved actor pixels."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]


def board(output):
    output = Path(output)
    if output.exists():
        raise FileExistsError('Refuse existing review board')
    source = ROOT / 'ArtSource/Labs/World2026/WorldStudio07R/VolumeStudies'
    studies = json.loads((source / 'studies.json').read_text())['studies']
    meta = json.loads((ROOT / 'Docs/Validation/ValdoriaWorldStudio07/Final/quaternius-scale.json').read_text())
    texture = Image.open(ROOT / meta['texture']).convert('RGBA')
    x, y, w, h = meta['rect']
    actor = texture.crop((x, texture.height-y-h, x+w, texture.height-y))
    actor = actor.crop(actor.getbbox())
    actor = actor.resize((round(actor.width*1.25), round(actor.height*1.25)), Image.Resampling.NEAREST)
    result = Image.new('RGB', (2280, 880), '#292c2a')
    draw = ImageDraw.Draw(result)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 22)
    small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)
    for i, study in enumerate(studies):
        clay = Image.open(source / (study['id']+'.png')).convert('RGBA')
        ratio = 154.8373 / (study['doorPixels'][0][1]-study['doorPixels'][1][1])
        bounds = clay.getbbox()
        clay = clay.crop(bounds)
        clay = clay.resize((round(clay.width*ratio), round(clay.height*ratio)), Image.Resampling.LANCZOS)
        ox = i*760+(760-clay.width)//2
        oy = 710-clay.height
        result.paste(clay, (ox, oy), clay)
        door_x = round(ox+(study['doorPixels'][0][0]-bounds[0])*ratio)
        door_y = round(oy+(study['doorPixels'][0][1]-bounds[1])*ratio)
        result.paste(actor, (door_x-actor.width-15, door_y-actor.height), actor)
        draw.text((i*760+25, 35), study['id']+(' / ESCOLHIDO' if i == 1 else ''), font=font, fill='#e3dbc4')
        draw.text((i*760+25, 760), f"Camera {study['cameraYaw']} graus | telhado +{study['roofRise']} m", font=small, fill='#e3dbc4')
        draw.text((i*760+25, 790), 'Blender: estudo de volume, nao Game View', font=small, fill='#b6bab3')
        draw.text((i*760+25, 820), 'Portas na mesma escala aparente; Quaternius original', font=small, fill='#b6bab3')
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    board(parser.parse_args().output)
