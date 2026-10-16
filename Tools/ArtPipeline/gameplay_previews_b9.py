"""Only crop/assemble real Unity end-of-frame captures, never synthesize gameplay."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'Docs/Validation/Marco06B9'
def capture_file(name):
    filename=name+'.png'
    live=BASE/filename
    return live if live.exists() else ROOT/'Temp/Marco06B9/Captures'/filename

metadata={m['name']:m for m in map(json.loads,(BASE/'capture-metadata.jsonl').read_text('utf-8-sig').splitlines())}
def preview(names,output):
    frames=[]; durations=[]
    for i,name in enumerate(names):
        m=metadata[name];src=Image.open(capture_file(name)).convert('RGB');x,y=m['playerScreen'];y=src.height-y
        tile=src.crop((round(x)-115,round(y)-115,round(x)+115,round(y)+90)).resize((460,410),Image.Resampling.NEAREST)
        frame=Image.new('RGB',(460,460),'#142023');frame.paste(tile,(0,0));draw=ImageDraw.Draw(frame)
        draw.text((8,415),'REAL UNITY / '+('0.35x CAPTURE' if m.get('timeScale',1)<1 else '1x / B9 EXPERIMENTAL'),fill='#e6d9ac')
        draw.text((8,430),m['source']+' / '+m['phase'],fill='white')
        draw.text((8,445),'body '+m['visual']+' aim '+m['aim'],fill='white');frames.append(frame)
        delta=(metadata[names[i+1]].get('realTime',metadata[names[i+1]]['time'])-m.get('realTime',m['time'])) if i+1<len(names) else .15
        durations.append(max(40,min(300,round(delta*1000))))
    frames[0].save(BASE/output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False)
    return {'file':output,'captures':names,'durationsMs':durations,'method':'real end-of-frame Unity ScreenCapture, player-follow review crop, nearest enlargement, actual sample times (capped at segment boundaries), no pose interpolation'}
reports=[]
reports.append(preview(['walk-'+str(d)+'-'+str(i).zfill(2) for d in range(4) for i in range(8)],'walk.gif'))
reports.append(preview(['walk-0-'+str(i).zfill(2) for i in range(8)],'walk-opposite-aim.gif'))
reports.append(preview(['attack-0-'+str(i).zfill(2) for i in range(13)],'attack-f7.gif'))
reports.append(preview(['attack-4-'+str(i).zfill(2) for i in range(24)],'heavy-diagonal-f7.gif'))
(BASE/'previews.json').write_text(json.dumps(reports,indent=2)+'\n','utf-8')
# Compact review contact sheet, never substituted for the temporal evidence.
thumbs=[]
for name in ['idle','walk-0-03','walk-1-03','walk-2-03','walk-3-03','attack-0-01','attack-0-03','attack-0-05','attack-0-07','attack-4-05','attack-4-11','attack-4-15']:
    m=metadata[name];src=Image.open(capture_file(name)).convert('RGB');x,y=m['playerScreen'];y=src.height-y
    tile=src.crop((round(x)-65,round(y)-90,round(x)+65,round(y)+65)).resize((260,310),Image.Resampling.NEAREST)
    draw=ImageDraw.Draw(tile);draw.text((3,3),name,fill='white');draw.text((3,18),m['phase'],fill='white');thumbs.append(tile)
sheet=Image.new('RGB',(260*4,310*3))
for i,tile in enumerate(thumbs):sheet.paste(tile,((i%4)*260,(i//4)*310))
sheet.save(BASE/'contact-sheet.png')
summary={'samples':len(metadata),'maximumGripError':max(m['gripError'] for m in metadata.values()),'minimumBladeLength':min(m['bladeLength'] for m in metadata.values()),'maximumBladeLength':max(m['bladeLength'] for m in metadata.values()),'scales':sorted(set(m['scale'] for m in metadata.values()))}
(BASE/'metrics.json').write_text(json.dumps(summary,indent=2)+'\n','utf-8');print(summary)
