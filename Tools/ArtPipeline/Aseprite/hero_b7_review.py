"""B7 review artifacts from local Aseprite exports only. No generation services."""
from pathlib import Path
import hashlib,json,sys
from PIL import Image,ImageDraw
from aseprite import run,ROOT

LAB=ROOT/'ArtSource/Labs/Aseprite/HeroB7'
REVISION=sys.argv[1] if len(sys.argv)>1 else ''
WALK='walk'+REVISION
BG=(32,39,48,255)
def present(im,scale=4):
    back=Image.new('RGBA',im.size,BG);back.alpha_composite(im)
    return back.convert('RGB').resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
def sheet(images,labels,path):
    result=Image.new('RGB',(384*len(images),410),BG[:3]);d=ImageDraw.Draw(result)
    for i,(im,label) in enumerate(zip(images,labels)):
        result.paste(present(im),(384*i,20));d.text((384*i+12,5),label,fill='white')
    result.save(path)
def gif(images,path,durations):
    # Exactly two cycles, no infinite loop extension, no interpolation.
    images=images*2;durations=durations*2
    images[0].save(path,save_all=True,append_images=images[1:],duration=durations,disposal=2,optimize=False)
    with Image.open(path) as check:
        assert check.n_frames==len(images)
        assert sum(check.seek(i) or check.info['duration'] for i in range(check.n_frames))==sum(durations)

def main():
    review=LAB/('review'+REVISION);review.mkdir(exist_ok=False)
    idle=Image.open(LAB/'idle.png').convert('RGBA')
    old=Image.open(ROOT/'ArtSource/Characters/Hero/idle/south/frame_000.png').convert('RGBA')
    run('-b','--all-layers',LAB/'hero-master-south.aseprite','--save-as',review/'idle-guides.png')
    guides=Image.open(review/'idle-guides.png').convert('RGBA')
    sheet([old,idle,guides],['Anterior / mesma escala','B7 / idle sul candidato','B7 / guias'],review/'idle-comparison.png')
    if not (LAB/WALK).exists(): return
    frames=[Image.open(p).convert('RGBA') for p in sorted((LAB/WALK).glob('frame_*.png'))]
    anchors=json.loads((LAB/('hero-walk-south'+REVISION+'.aseprite.anchors.json')).read_text())
    assert len(frames)==len(anchors['frames'])==4
    sheet(frames,['000 contato esquerdo','001 passagem direita','002 contato direito','003 passagem esquerda'],review/'walk-poses.png')
    overlays=[];silhouettes=[];qa=[]
    support=[([53,88],[42,83]),([51,88],[47,82]),([42,88],[53,83]),([44,88],[48,82])]
    if REVISION:
        support[1]=([51,85],[47,82]);support[3]=([44,85],[48,82])
    for i,(im,m) in enumerate(zip(frames,anchors['frames'])):
        assert im.size==(96,96) and im.getextrema()[3]==(0,255)
        for hand in ['rightHand','leftHand']:
            assert im.getpixel(tuple(m[hand]))[3]==255,(i,hand,m[hand])
        over=im.copy();d=ImageDraw.Draw(over)
        d.line((28,88,68,88),fill='#447777')
        for point,color in [(m['pivot'],'#ffff00'),(m['rightHand'],'#ff00ff'),(m['leftHand'],'#00ff00'),(support[i][0],'#00ffff'),(support[i][1],'#ff8800')]:
            x,y=point;d.line((x-2,y,x+2,y),fill=color);d.line((x,y-2,x,y+2),fill=color)
        overlays.append(over)
        silhouette=Image.new('RGBA',(96,96),(220,225,231,0));silhouette.putalpha(im.getchannel('A'));silhouettes.append(silhouette)
        qa.append(dict(frame=i,rgbaSha256=hashlib.sha256(im.tobytes()).hexdigest(),bounds=im.getbbox(),colors=len(im.getcolors()),rightHand=m['rightHand'],leftHand=m['leftHand'],supportIntended=support[i][0],swingFootIntended=support[i][1],durationMs=120))
    assert len({r['rgbaSha256'] for r in qa})==4
    # Reject duplicates even after arbitrary integer translation of the complete drawing.
    assert len({hashlib.sha256(im.crop(im.getbbox()).tobytes()).hexdigest() for im in frames})==4
    sheet(overlays,['000 apoio ciano / aereo laranja','001 maos M/G / pivo amarelo','002 apoio ciano / aereo laranja','003 intencao de apoio'],review/'walk-anchors.png')
    sheet(silhouettes,['000','001','002','003'],review/'walk-silhouettes.png')
    gif([present(im,1) for im in frames],review/'walk-native-two-cycles.gif',[120]*4)
    gif([present(im) for im in frames],review/'walk-4x-two-cycles.gif',[120]*4)
    oldwalk=[Image.open(ROOT/f'ArtSource/Characters/Hero/walk/south/frame_{i:03}.png').convert('RGBA') for i in range(2)]
    # Common 10ms sampling over 960ms: old native 125ms rounds to GIF 120/130ms,
    # exact old frame transitions sampled at 0/125/250/375ms, candidate 120ms.
    comparison=[]
    for t in range(0,960,10):
        frame=Image.new('RGB',(768,410),BG[:3]);draw=ImageDraw.Draw(frame)
        frame.paste(present(oldwalk[(t//125)%2]),(0,20));frame.paste(present(frames[(t//120)%4]),(384,20))
        draw.text((12,5),'Anterior: 2 poses, ciclo 250ms',fill='white');draw.text((396,5),'B7: 4 poses, ciclo 480ms',fill='white')
        comparison.append(frame)
    comparison[0].save(review/'old-vs-b7.gif',save_all=True,append_images=comparison[1:],duration=10,disposal=2,optimize=False)
    with Image.open(review/'old-vs-b7.gif') as check:
        assert sum(check.seek(i) or check.info['duration'] for i in range(check.n_frames))==960
    report=dict(status='experimental-unapproved',unityTested=False,ppu=32,canvas=[96,96],pivot=[48,70],ground=[48,88],frames=qa,distinct=4,translatedDuplicates=False,candidateCycleMs=480,distanceAtReferenceSpeedPixels=53.76,comparison='960ms: two B7 cycles; old native 250ms clock, continuous 10ms sampling; no equal-cadence claim')
    (review/'qa.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__': main()
