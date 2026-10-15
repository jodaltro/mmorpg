"""Quick source contract QA; does not run Unity/Go/SQL suites."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
reports=[]
for file in sorted((ROOT/'ArtSource').rglob('manifest.json')):
    m=json.loads(file.read_text('utf-8'))
    for clip in m.get('clips',[]):
        assert clip['frameCount']==len(clip['frames'])>0
        hashes=[]
        for i,f in enumerate(clip['frames']):
            p=ROOT/f['png'];assert p.name==f'frame_{i:03}.png'
            im=Image.open(p);assert im.mode=='RGBA' and list(im.size)==f['canvas']
            assert im.getextrema()[3][0]==0 and f['duration']>0
            assert 0<=f['pivot'][0]<=im.width and 0<=f['pivot'][1]<=im.height
            if m['id']=='Hero': assert im.getpixel(tuple(f['rightHand']))[3]>150,('Hand outside visible glove',f['source'],f['rightHand'])
            digest=hashlib.sha256(p.read_bytes()).hexdigest();assert digest==f['sha256'];hashes.append(digest)
        reports.append(dict(id=m['id'],animation=clip['animation'],direction=clip['direction'],frames=len(hashes),unique=len(set(hashes)),status=clip['status']))
out=ROOT/'Docs/Art/PreviewsB4';out.mkdir(parents=True,exist_ok=True)
(out/'source-qa.json').write_text(json.dumps(reports,indent=2)+'\n','utf-8')
hero=json.loads((ROOT/'ArtSource/Characters/Hero/manifest.json').read_text('utf-8'))
sheet=Image.new('RGB',(96*6*3,112*4*3),'#20292d');draw=ImageDraw.Draw(sheet)
for row,d in enumerate(['south','west','north','east']):
    frames=[f for c in hero['clips'] if c['direction']==d for f in c['frames']]
    for col,f in enumerate(frames):
        im=Image.open(ROOT/f['png']);drawim=ImageDraw.Draw(im)
        x,y=f['rightHand'];drawim.ellipse((x-1,y-1,x+1,y+1),outline='#ff00ff')
        y=f['feet'][1];drawim.line((0,y,95,y),fill='#00bbbb',width=1)
        tile=im.resize((288,288),Image.Resampling.NEAREST);sheet.paste(tile,(col*288,row*336),tile)
        draw.text((col*288+8,row*336+290),f['source'],fill='white')
sheet.save(out/'hero-attachments.png')
print(f'{len(reports)} clip contracts checked. Hero walk: '+str([(r['direction'],r['frames'],r['unique']) for r in reports if r['id']=='Hero' and r['animation']=='walk']))
