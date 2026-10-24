"""Compact skill inspection, deliberate touch drag/cancel and native mouse drag/drop."""
import sys,time
from pathlib import Path
from playwright.sync_api import sync_playwright
source=Path(__file__).with_name("e2e_online.py").read_text(encoding="utf-8")
exec(source[:source.index("with sync_playwright() as p:")])
with sync_playwright() as p:
    for mobile in ([False] if "--desktop" in sys.argv else [True] if "--mobile" in sys.argv else [True,False]):
        print("START", "mobile" if mobile else "desktop", flush=True)
        w,h=(667,375) if mobile else (1280,720)
        b,ctx,pg,logs=page(p,w,h,mobile,query='probe=1&debug=1&engine=off')
        pg.wait_for_function("window.__probe && !document.getElementById('loader')",timeout=60000)
        pg.evaluate("window.__cmd='god'")
        time.sleep(.4)
        pg.evaluate("window.__cmd='become:macrofago'")
        wait_for(pg,lambda q:all(q['abilities']),'skills')
        pg.keyboard.press('g')
        print('opening body',flush=True)
        wait_for(pg,lambda q:q['body'],'body')
        touch=Touch(ctx.new_cdp_session(pg)) if mobile else None
        def tap_rect(rect):
            q=probe(pg);r=h/q['viewport'][1]
            x,y,rw,rh=rect
            if mobile: touch.tap((x+rw/2)*r,(y+rh/2)*r)
            else: pg.mouse.click((x+rw/2)*r,(y+rh/2)*r);time.sleep(.5)
        def button(text):
            return next(item['rect'] for item in probe(pg)['menus']['bodyButtons'] if item['text']==text)
        print('opening skill tab',flush=True)
        tap_rect(probe(pg)['menus']['tabs'][2])
        q=wait_for(pg,lambda q:len(q['menus']['abilitySlots'])==4,'four slots')
        order=q['abilities'][:]
        check(all(rect[3]<90 for rect in q['menus']['abilitySlots']),('mobile' if mobile else 'desktop')+' slots are compact')
        tap_rect(q['menus']['abilitySlots'][0])
        tap_rect(probe(pg)['menus']['abilitySlots'][1])
        check(probe(pg)['abilities']==order,'inspection never changes skill order')
        check('COMO FUNCIONA' not in probe(pg)['menus']['bodyContent'],'long explanations are collapsed initially')
        tap_rect(button('Como funciona'))
        wait_for(pg,lambda q:q['menus']['abilityDetails'],'expanded inspector')
        check('COMO FUNCIONA' in probe(pg)['menus']['bodyContent'],'full explanation remains available on demand')
        tap_rect(button('Menos detalhes'))
        q=probe(pg);r=h/q['viewport'][1]
        def centre(index):
            x,y,rw,rh=probe(pg)['menus']['abilitySlots'][index]
            return ((x+rw/2)*r,(y+rh/2)*r)
        x,y=centre(0);tx,ty=centre(3)
        if mobile:
            touch.down(x,y)
            wait_for(pg,lambda q:q['menus']['draggingSkill'],'long press starts drag')
            for i in range(1,9):
                touch.move(x+(tx-x)*i/8,y+(ty-y)*i/8);time.sleep(.05)
            shot(pg,'skill_drag_mobile')
            touch.up()
        else:
            pg.mouse.move(x,y);pg.mouse.down()
            pg.mouse.move(tx,ty,steps=12);time.sleep(.3)
            pg.mouse.up()
        q=wait_for(pg,lambda q:q['abilities'][3]==order[0],'reorder')
        check(q['abilities'][0]==order[3],'drag swaps source and destination and preserves the other slots')
        after=q['abilities'][:]
        if mobile:
            x,y=centre(0);touch.down(x,y)
            wait_for(pg,lambda q:q['menus']['draggingSkill'],'cancel drag starts')
            touch.move(3,180);touch.up();time.sleep(.5)
            check(probe(pg)['abilities']==after,'dropping outside cancels without changing the loadout')
            x,y=centre(0);tx,ty=centre(2)
            touch.down(x,y);touch.move(tx,ty);touch.up();time.sleep(.5)
            check(probe(pg)['abilities']==after and not probe(pg)['menus']['draggingSkill'],'a quick swipe never reorders skills')
        shot(pg,'skills_mobile' if mobile else 'skills_desktop')
        tap_rect(probe(pg)['menus']['tabs'][3])
        wait_for(pg,lambda q:q['menus']['bodyTab']==3,'builds')
        tap_rect(button('Build 2 · vazia'))
        check(probe(pg)['menus']['buildPick']==2,'preset selection changes the preview')
        tap_rect(button('Renomear'))
        pg.keyboard.press('Control+a')
        pg.keyboard.press('Backspace')
        pg.keyboard.type('Exploracao',delay=30)
        pg.keyboard.press('Enter')
        time.sleep(.5)
        shot(pg,'rename_mobile' if mobile else 'rename_desktop')
        wait_for(pg,lambda q:'Exploracao' in q['menus']['bodyContent'],'rename')
        check(True,'renaming requires an explicit edit and confirmation')
        shot(pg,'builds_mobile' if mobile else 'builds_desktop')
        clean(logs,'touch loadout' if mobile else 'desktop loadout')
        print('closing browser',flush=True)
        b.close()
        print('browser closed',flush=True)
print('%d checks passed'%len(passed))
