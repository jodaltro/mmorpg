"""Evidence only: original PixelLab PNGs, nearest previews; never writes production art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import json
import hashlib

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'ArtSource/References/PixelLab/Marco06B6'
PREVIEW = BASE / 'previews'
BG = (67, 70, 78)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    original = sorted((BASE / 'walk_south/original').rglob('*.png'))
    frames = [p for p in original if 'south' in str(p) and 'rotations' not in str(p)]
    if len(frames) != 8:
        raise ValueError(f'Expected eight south frames, found {frames}')
    old_paths = sorted((ROOT / 'ArtSource/Characters/Hero/walk/south').glob('frame_*.png'))
    old = [Image.open(p).convert('RGBA') for p in old_paths]
    new = [Image.open(p).convert('RGBA') for p in frames]
    # One fixed translation for the entire new clip: reference ground y76 -> y88.
    # No per-frame stabilization, scale, retouch or invented drawing.
    raw_new = new
    new = []
    for im in raw_new:
        aligned = Image.new('RGBA', im.size)
        aligned.paste(im, (0, 12))
        new.append(aligned)
    w = max(96, *(im.width for im in new))
    h = max(96, *(im.height for im in new))
    def tile(im, title):
        out = Image.new('RGB', (w * 4, h * 4 + 28), BG)
        enlarged = im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST)
        out.paste(enlarged, ((w-im.width)*2, 28+(h-im.height)*2), enlarged)
        ImageDraw.Draw(out).text((10, 9), title, fill='white')
        return out
    sheet = Image.new('RGB', (w*4*4, (h*4+28)*2), BG)
    for i, im in enumerate(new):
        sheet.paste(tile(im, f'PixelLab south - frame {i:03}'), ((i%4)*w*4, (i//4)*(h*4+28)))
    sheet.save(PREVIEW / 'walk-south-contact-sheet.png')
    # Exactly two cycles. Both cycles last 720 ms (8 x 90 vs 2 x 360 ms).
    walk = [tile(im, f'PixelLab - {i:03}') for i,im in enumerate(new)] * 2
    walk[0].save(PREVIEW/'walk-south-two-cycles.gif', save_all=True, append_images=walk[1:], duration=90, disposal=2)
    comparison = []
    for i in range(16):
        panel = Image.new('RGB', (w*8, h*4+28), BG)
        panel.paste(tile(old[(i//4)%len(old)], 'Anterior - 2 poses / ciclo 720 ms'), (0,0))
        panel.paste(tile(new[i%8], 'PixelLab - 8 frames / ciclo 720 ms'), (w*4,0))
        comparison.append(panel)
    comparison[0].save(PREVIEW/'old-vs-pixellab-two-cycles.gif', save_all=True, append_images=comparison[1:], duration=90, disposal=2)
    comparison[0].save(PREVIEW/'old-vs-pixellab.png')
    def metrics(path, im):
        return dict(file=str(path.relative_to(ROOT)).replace('\\','/'), canvas=list(im.size), mode=Image.open(path).mode, bounds=im.getbbox(), alphaRange=im.getchannel('A').getextrema(), sha256=sha(path), rgbaSha256=hashlib.sha256(im.tobytes()).hexdigest())
    reference = Image.open(ROOT/'ArtSource/Characters/Hero/idle/south/frame_000.png').convert('RGBA')
    south = Image.open(BASE/'character/original/Idle/rotations/south.png').convert('RGBA')
    report = dict(status='rejected artistically; not imported', frames=[metrics(p,im) for p,im in zip(frames,raw_new)], distinctRGBA=len({im.tobytes() for im in raw_new}), referencePixelsIdentical=reference.size==south.size and reference.tobytes()==south.tobytes(), previewScale=4, interpolation='nearest only; no synthesized frames', durationMs=90, comparisonCycleMs=720, cyclesEncoded=2, canvasAlignment='fixed translation (0,+12) of all new frames for ground comparison; no scale or per-frame correction', oldNativeFrameMs=125, oldComparisonFrameMs=360, notes='Old cycle slowed to match full cycle length for pose comparison; this is source-art evidence, not captured gameplay.')
    report['artisticReview'] = {
        'identity': 'Palette/outfit recognizable; temporal identity fails at frame 006 (face missing, back-of-head appearance).',
        'feet': 'Forward-foot reversal occurs around 004->005, but contact/absorption/passing/lift phases are not reliably distinct. No eight-phase approval.',
        'arms': 'No reliable continuous anatomical right-hand grip; light blade-like artifacts around right hand at 004 and right boot at 006.',
        'scale': 'Visible height 51-53 px vs original idle 50 px; no rescale needed. Original animation is translated upward in canvas.',
        'cape': 'Recognizable blue, but pose silhouettes repeat and cloth is stiff.',
        'loop': '007->000 visibly changes leading leg and silhouette; head/face discontinuity 005->006->007 is unacceptable.',
        'verdict': 'Not better enough to replace original; artistic defects cannot be solved by padding/pivots.'
    }
    (BASE/'qa-report.json').write_text(json.dumps(report,indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    main()
