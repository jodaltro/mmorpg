"""Build auditable PNG review copies. Original captures are always read-only.

Input JSON: {images:[{original, scene, state, comparison, camera, integral}]}.
Comparative groups receive the same integer nearest-neighbour reduction.
Optional bounded shared-palette reduction at half size is explicit. Never dither,
adjust colour/contrast or upsample. Quantized copies require visual inspection.
"""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
from PIL import Image

LIMIT = 750 * 1024
SCHEMA = 'valdoria-visual-review/v1'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def resolve(root, name):
    p = (root / name).resolve()
    if not p.is_relative_to(root.resolve()):
        raise ValueError('Path escapes evidence root: ' + name)
    return p


def png(image):
    buf = io.BytesIO()
    # Rebuild pixels to remove metadata; keep RGBA values intact.
    clean = Image.frombytes(image.mode, image.size, image.tobytes())
    if image.mode=='P':
        clean.putpalette(image.getpalette())
    if clean.mode=='RGBA' and clean.getchannel('A').getextrema()==(255,255):
        clean=clean.convert('RGB')  # Lossless removal of redundant opaque alpha.
    clean.save(buf, format='PNG', optimize=True, compress_level=9)
    return buf.getvalue()


def pixels(path):
    with Image.open(path) as im:
        if im.format != 'PNG':
            raise ValueError('Expected PNG: ' + str(path))
        im.load()
        return im.convert('RGBA')


def quantize_group(images):
    if any(im.getchannel('A').getextrema()!=(255,255) for im in images):
        return None
    import numpy as np
    board=Image.new('RGB',(sum(im.width for im in images),images[0].height));x=0
    for im in images:board.paste(im.convert('RGB'),(x,0));x+=im.width
    palette=board.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    result=[];errors=[]
    for im in images:
        q=im.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE)
        error=np.abs(np.array(im.convert('RGB')).astype(float)-np.array(q.convert('RGB')).astype(float))
        metrics={'meanAbsoluteChannelError':float(error.mean()),'percentile95ChannelError':float(np.quantile(error,.95))}
        if metrics['meanAbsoluteChannelError']>3 or metrics['percentile95ChannelError']>9:return None
        result.append(q);errors.append(metrics)
    return result,errors,hashlib.sha256(bytes(palette.getpalette())).hexdigest()


def build(root, index, output='ReviewLite', manifest='QA/image-manifest.json', allow_quantization=False):
    root = Path(root).resolve()
    items = json.loads(Path(index).read_text(encoding='utf-8'))['images']
    dest = resolve(root, output)
    target = resolve(root, manifest)
    if dest.exists() or target.exists():
        raise FileExistsError('Refuse existing review/manifest destination')
    originals = {}
    groups = {}
    for entry in items:
        for key in ('original', 'scene', 'state', 'comparison', 'camera', 'integral'):
            if key not in entry:
                raise ValueError('Missing metadata: ' + key)
        path = resolve(root, entry['original'])
        if path in originals:
            raise ValueError('Duplicate original: ' + str(path))
        originals[path] = sha(path)
        groups.setdefault(entry['comparison'], []).append(entry)
    planned = []
    for group in groups.values():
        images = [pixels(resolve(root, e['original'])) for e in group]
        if len({im.size for im in images}) != 1:
            raise ValueError('Comparison dimensions differ')
        if len({json.dumps(e['camera'], sort_keys=True) for e in group}) != 1:
            raise ValueError('Comparison cameras differ')
        w, h = images[0].size
        accepted = None
        # Exact integer divisors preserve aspect and document pixel decimation.
        for factor in (1, 2, 3, 4):
            if w % factor or h % factor:
                continue
            transformed = [im if factor == 1 else im.resize((w//factor, h//factor), Image.Resampling.NEAREST) for im in images]
            encoded = [png(im) for im in transformed]
            if all(len(data) <= LIMIT for data in encoded):
                accepted = factor, transformed, encoded, False, None, None
                break
            if factor==2 and allow_quantization:
                reduced=quantize_group(transformed)
                if reduced:
                    quantized,errors,paletteHash=reduced
                    encoded=[png(im) for im in quantized]
                    if all(len(v)<=LIMIT for v in encoded):
                        accepted=factor,quantized,encoded,True,errors,paletteHash
                        break
        if accepted is None:
            raise ValueError('Review exceeds 750 KiB; supply labelled detail crops, never silently degrade further')
        factor, transformed, encoded, quantized, errors, paletteHash = accepted
        for ordinal,(entry, im, data) in enumerate(zip(group, transformed, encoded)):
            name = Path(entry['original']).name
            relative = (Path(output) / name).as_posix()
            if any(row[0]['review'] == relative for row in planned):
                raise ValueError('Review filename collision')
            record = dict(entry, review=relative, originalDimensions=[w,h], reviewDimensions=list(im.size),
                          originalBytes=resolve(root, entry['original']).stat().st_size, reviewBytes=len(data),
                          originalSHA256=originals[resolve(root, entry['original'])], reviewSHA256=hashlib.sha256(data).hexdigest(),
                          method='lossless PNG recompression; metadata removed' + (f'; nearest integer reduction 1/{factor}' if factor > 1 else '') + ('; shared median-cut 256 colours, no dithering' if quantized else ''),
                          scaleDivisor=factor, crop=entry.get('crop'), quantized=quantized,
                          colourReduction={'paletteSHA256':paletteHash,'colours':256,'dither':'none','error':errors[ordinal]} if quantized else None,
                          integrity={'decodable': True, 'originalUnchanged': True, 'pixelsMatchDeclaredTransform': True},
                          visualFidelityReview='pending' if factor > 1 else 'pixel-identical',
                          github={'published':False,'base64RecoveryTested':False,'visualInspectionViaConnector':False})
            planned.append((record,data))
    dest.mkdir(parents=True)
    for record,data in planned:
        resolve(root,record['review']).write_bytes(data)
    if any(sha(p) != expected for p,expected in originals.items()):
        raise ValueError('Original modified during build')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps({'schema':SCHEMA,'maxReviewBytes':LIMIT,'images':[r for r,_ in planned]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    return verify(root,target)


def verify(root, manifest, report=None):
    root=Path(root).resolve()
    data=json.loads(Path(manifest).read_text(encoding='utf-8'))
    if data['schema'] != SCHEMA or data['maxReviewBytes'] != LIMIT or not data['images']:
        raise ValueError('Invalid image manifest')
    groups={}
    for e in data['images']:
        original=resolve(root,e['original']);review=resolve(root,e['review'])
        if original==review:raise ValueError('Original overwritten')
        a,b=pixels(original),pixels(review);factor=e['scaleDivisor']
        expected=a if factor==1 else a.resize((a.width//factor,a.height//factor),Image.Resampling.NEAREST)
        if factor not in (1,2,3,4) or a.width%factor or a.height%factor:raise ValueError('Invalid integer scale')
        if list(a.size)!=e['originalDimensions'] or list(b.size)!=e['reviewDimensions']:raise ValueError('Dimensions mismatch')
        if a.width*b.height!=a.height*b.width:raise ValueError('Aspect distorted')
        if expected.size!=b.size:raise ValueError('Transform dimensions')
        if not e['quantized'] and expected.tobytes()!=b.tobytes():raise ValueError('Pixels differ from declared transform')
        if e['quantized']:
            import numpy as np
            with Image.open(review) as pal:
                if pal.mode!='P' or hashlib.sha256(bytes(pal.getpalette())).hexdigest()!=e['colourReduction']['paletteSHA256']:raise ValueError('Palette mismatch')
            if expected.getchannel('A').tobytes()!=b.getchannel('A').tobytes():raise ValueError('Alpha changed')
            err=np.abs(np.array(expected.convert('RGB')).astype(float)-np.array(b.convert('RGB')).astype(float))
            metrics={'meanAbsoluteChannelError':float(err.mean()),'percentile95ChannelError':float(np.quantile(err,.95))}
            if metrics!=e['colourReduction']['error'] or metrics['meanAbsoluteChannelError']>3 or metrics['percentile95ChannelError']>9:raise ValueError('Quantization fidelity bounds')
        for p,prefix in ((original,'original'),(review,'review')):
            if sha(p)!=e[prefix+'SHA256'] or p.stat().st_size!=e[prefix+'Bytes']:raise ValueError('Hash/byte mismatch')
        if review.stat().st_size>LIMIT:raise ValueError('Review exceeds limit')
        if not e['scene'] or not e['camera'] or not e['state']:raise ValueError('Incomplete capture metadata')
        if bool(e['integral'])==bool(e.get('crop')):raise ValueError('Integral/crop metadata inconsistent')
        if e.get('crop'):
            source=pixels(resolve(root,e['crop']['source']));bounds=e['crop']['boundsLTRB']
            if len(bounds)!=4 or not (0<=bounds[0]<bounds[2]<=source.width and 0<=bounds[1]<bounds[3]<=source.height):raise ValueError('Invalid crop bounds')
            if source.crop(bounds).tobytes()!=a.tobytes():raise ValueError('Crop differs from authoritative original')
        signature=(tuple(a.size),tuple(b.size),factor,e['quantized'],e.get('colourReduction',{}).get('paletteSHA256') if e.get('colourReduction') else None,json.dumps(e['camera'],sort_keys=True))
        if e['comparison'] in groups and groups[e['comparison']]!=signature:raise ValueError('Pair transforms/cameras differ')
        groups[e['comparison']]=signature
    if report:
        report=Path(report)
        for link in re.findall(r'!\[[^\]]*\]\(([^)]+)\)',report.read_text(encoding='utf-8')):
            if '://' not in link and not (report.parent/link).exists():raise FileNotFoundError('Report image: '+link)
    return {'passed':True,'images':len(data['images']),'groups':len(groups),'maxReviewBytes':max(e['reviewBytes'] for e in data['images']),'originalsUnchanged':True}


def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','verify']);p.add_argument('--root',type=Path,required=True);p.add_argument('--index',type=Path);p.add_argument('--manifest',type=Path);p.add_argument('--report',type=Path);p.add_argument('--allow-quantization',action='store_true');a=p.parse_args()
    if a.action=='build':result=build(a.root,a.index,allow_quantization=a.allow_quantization)
    else:result=verify(a.root,a.manifest,a.report)
    print(json.dumps(result))


if __name__=='__main__':main()
