"""Real touch navigation, modal dismissal and scroll-vs-tap regression checks."""
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright
source=Path(__file__).with_name("e2e_online.py").read_text(encoding="utf-8")
exec(source[:source.index("with sync_playwright() as p:")])
with sync_playwright() as p:
    b,ctx,pg,logs=page(p,667,375,True)
    t=Touch(ctx.new_cdp_session(pg))
    q=wait_for(pg,lambda q:q['online'],'online')
    pg.wait_for_function("window.__hospedeiroReady && !document.getElementById('loader')",timeout=60000)
    pg.evaluate("window.__cmd='god'")
    time.sleep(.5)
    pg.evaluate("window.__cmd='become:macrofago'")
    wait_for(pg,lambda q:all(q['abilities']),'abilities')
    def tap(x,y):
        q=probe(pg);r=375/q['logical'][1]
        t.tap(x*r,y*r)
    def navigate(index):
        q=probe(pg)
        tap(q['logical'][0]-64,36)
        wait_for(pg,lambda q:q['menus']['navigation'],'navigation')
        tap(probe(pg)['logical'][0]-78,86+50*index)
        time.sleep(.5)
    def outside():
        t.tap(3,180)
    def drag_rect(key):
        q=probe(pg);r=375/q['logical'][1]
        x,y,w,h=q['menus'][key]
        sx=(x+w*.55)*r;sy=(y+h*.8)*r
        t.down(sx,sy)
        for i in range(1,13):
            t.move(sx,sy-h*.6*r*i/12)
            time.sleep(.06)
        t.up()
        time.sleep(.6)
    navigate(0)
    q=wait_for(pg,lambda q:q['body'],'body')
    check(not q['menus']['navigation'],'choosing a destination closes navigation')
    rect=q['menus']['tabs'][2]
    tap(rect[0]+rect[2]/2,rect[1]+rect[3]/2)
    wait_for(pg,lambda q:q['menus']['bodyTab']==2,'ability tab')
    shot(pg,'abilities_before_scroll')
    drag_rect('bodyViewport')
    q=probe(pg)
    check(q['menus']['bodyScroll']>25,'dragging inside an ability card scrolls the body window')
    check(q['menus']['abilityPick']==-1,'scrolling does not select or swap a skill')
    shot(pg,'abilities_scrolled')
    outside()
    wait_for(pg,lambda q:not q['body'],'outside closes body')
    check(True,'outside tap closes a window')
    navigate(1)
    wait_for(pg,lambda q:q['codex'],'codex')
    drag_rect('codexViewport')
    check(probe(pg)['menus']['codexScroll']>25,'codex scrolls with a finger')
    shot(pg,'codex_scrolled')
    outside()
    wait_for(pg,lambda q:not q['codex'],'codex dismissed')
    navigate(3)
    wait_for(pg,lambda q:q['menus']['vitals'],'vitals')
    drag_rect('vitalsViewport')
    check(probe(pg)['menus']['vitalsScroll']>25,'all vital signs remain reachable by scrolling')
    shot(pg,'vitals_scrolled')
    outside()
    wait_for(pg,lambda q:not q['menus']['vitals'],'vitals dismissed')
    navigate(2)
    wait_for(pg,lambda q:q['menus']['atlas'],'atlas')
    shot(pg,'atlas')
    outside()
    wait_for(pg,lambda q:not q['menus']['atlas'],'atlas dismissed')
    check(True,'atlas also dismisses on outside tap')
    q=probe(pg);tap(q['logical'][0]-64,36)
    wait_for(pg,lambda q:q['menus']['navigation'],'navigation again')
    outside()
    wait_for(pg,lambda q:not q['menus']['navigation'],'navigation dismissed')
    check(True,'outside tap closes navigation')
    clean(logs,'mobile menus')
    b.close()
print('%d checks passed'%len(passed))
