"""Local Aseprite entry point. Requires the ArtPipeline's existing Pillow dependency."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tempfile
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def executable():
    candidates = [os.environ.get('ASEPRITE_EXE'), shutil.which('aseprite'), shutil.which('Aseprite.exe')]
    for base in [os.environ.get('ProgramFiles'), os.environ.get('ProgramFiles(x86)'), os.environ.get('LOCALAPPDATA')]:
        if base:
            candidates += [str(Path(base)/'Aseprite/Aseprite.exe'), str(Path(base)/'Programs/Aseprite/Aseprite.exe'), str(Path(base)/'Steam/steamapps/common/Aseprite/Aseprite.exe')]
    candidates += [r'D:\Aseprite\Aseprite.exe', r'D:\SteamLibrary\steamapps\common\Aseprite\Aseprite.exe']
    # Steam libraries registered on this machine, without copying account data.
    for vdf in [Path(r'C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf')]:
        if vdf.exists():
            import re
            for base in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(errors='replace')):
                candidates.append(str(Path(base.replace('\\\\','\\'))/'steamapps/common/Aseprite/Aseprite.exe'))
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            probe = subprocess.run([candidate, '--version'], capture_output=True, text=True, timeout=20)
            if probe.returncode == 0 and 'Aseprite' in probe.stdout:
                return str(Path(candidate).resolve())
    raise SystemExit('Aseprite unavailable. Set ASEPRITE_EXE to the installed executable; do not install automatically.')

def run(*args):
    result = subprocess.run([executable(), *map(str,args)], capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()

def export(source, output):
    source = Path(source).resolve()
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    run('-b', source, '--save-as', output/'frame_{frame000}.png')
    run('-b', '--list-layers', '--list-tags', source, '--sheet-type', 'horizontal', '--sheet', output/'sheet.png', '--format', 'json-array', '--data', output/'frames.json')
    run('-b', source, '--save-as', output/'preview.gif')
    return verify(output)

def verify(output):
    output = Path(output)
    data = json.loads((output/'frames.json').read_text())
    frames = sorted(output.glob('frame_*.png'))
    assert frames and len(frames) == len(data['frames'])
    hashes = []
    for path, meta in zip(frames, data['frames']):
        with Image.open(path) as im:
            assert im.mode == 'RGBA' and im.size == (96,96), (path, im.mode, im.size)
            assert im.getextrema()[3] == (0,255), path
            assert meta['duration'] > 0
            hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
    with Image.open(output/'sheet.png') as sheet:
        assert sheet.size == (96*len(frames),96)
    with Image.open(output/'preview.gif') as gif:
        assert gif.n_frames == len(frames)
    report = dict(frames=len(frames), unique=len(set(hashes)), canvas=[96,96], rgba=True, transparent=True, hashes=hashes)
    (output/'qa.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

def validate():
    source = ROOT/'ArtSource/Characters/Hero/idle/south/frame_000.png'
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='mmorpg-aseprite-') as tmp:
        tmp = Path(tmp)
        run('-b', source, '--save-as', tmp/'copy.png')
        with Image.open(source) as original, Image.open(tmp/'copy.png') as copy:
            assert original.convert('RGBA').tobytes() == copy.convert('RGBA').tobytes()
        run('-b', source, '--sheet', tmp/'sheet.png', '--format', 'json-array', '--data', tmp/'sheet.json')
        assert len(json.loads((tmp/'sheet.json').read_text())['frames']) == 1
        run('-b', '--script-param', f'output={tmp / "walk.aseprite"}', '--script', HERE/'walk_lab.lua')
        inspection = run('-b', tmp/'walk.aseprite', '--script', HERE/'inspect.lua')
        qa = export(tmp/'walk.aseprite', tmp/'export')
        assert qa['unique'] == 4
        assert hashlib.sha256(source.read_bytes()).hexdigest() == before
        return dict(executable=executable(),version=run('--version'),help=bool(run('--help')),png_roundtrip=True,original_unchanged=True,lua=inspection,qa=qa)

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('operation', choices=['locate','validate','lab','export','verify'])
    p.add_argument('--source', type=Path)
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    if a.operation == 'locate': print(executable())
    elif a.operation == 'validate': print(json.dumps(validate(),indent=2))
    elif a.operation == 'lab':
        if not a.output: p.error('--output required')
        a.output = a.output.resolve()
        if a.output.exists(): p.error('Refusing to overwrite existing document')
        a.output.parent.mkdir(parents=True,exist_ok=True)
        print(run('-b','--script-param',f'output={a.output}','--script',HERE/'walk_lab.lua'))
    elif a.operation == 'export':
        if not a.source or not a.output: p.error('--source and --output required')
        print(json.dumps(export(a.source,a.output),indent=2))
    else:
        if not a.output: p.error('--output required')
        print(json.dumps(verify(a.output),indent=2))
