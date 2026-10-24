"""Change the mobile UI with real touch input and verify reload persistence."""
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright
source=Path(__file__).with_name("e2e_online.py").read_text(encoding="utf-8")
exec(source[:source.index("with sync_playwright() as p:")])
with sync_playwright() as p:
    b,ctx,pg,logs=page(p,667,375,True,query="probe=1&engine=off")
    pg.wait_for_function("window.__probe && !document.getElementById('loader')",timeout=60000)
    t=Touch(ctx.new_cdp_session(pg))
    def menu():
        q=probe(pg);r=375/q['logical'][1]
        t.tap((q['logical'][0]-64)*r,36*r)
    def select(value):
        q=probe(pg);r=375/q['logical'][1]
        sx,sy,sw,sh=q['menus']['scaleSlider']
        x=sx+8+(value-75)/50*(sw-16)
        t.down(x*r,(sy+sh/2)*r)
        t.move(x*r,(sy+sh/2)*r)
        t.up()
        return wait_for(pg,lambda q:abs(q['moba']['scale']-value/100)<0.01,'scale '+str(value))
    menu()
    select(125)
    check(True,'touch slider enlarges the complete interface to 125%')
    shot(pg,'settings_125')
    q=probe(pg);r=375/q['logical'][1]
    t.tap((q['logical'][0]-78)*r,86*r)
    q=wait_for(pg,lambda q:q['body'],'body window at 125%')
    rect=q['bodyRect']
    check(rect[0]+rect[2]<=q['logical'][0]+1 and rect[1]+rect[3]<=q['logical'][1]+1,'body window fits the smallest phone at 125%')
    shot(pg,'body_125')
    for i,name in enumerate(['form','genes','abilities','builds']):
        q=probe(pg);r=375/q['logical'][1]
        x,y,w,h=q['menus']['tabs'][i]
        t.tap((x+w/2)*r,(y+h/2)*r)
        q=wait_for(pg,lambda q:q['menus']['bodyTab']==i,name)
        x,y,w,h=q['bodyRect']
        check(x+w<=q['logical'][0]+1 and y+h<=q['logical'][1]+1,name+' fits at 125%')
        shot(pg,name+'_125')
    q=probe(pg);r=375/q['logical'][1]
    x,y,w,h=q['bodyRect']
    t.tap((x+w-44)*r,(y+32)*r)
    wait_for(pg,lambda q:not q['body'],'body close')
    shot(pg,'play_125')
    pg.reload()
    pg.wait_for_function("window.__probe && !document.getElementById('loader')",timeout=60000)
    check(abs(probe(pg)['moba']['scale']-1.25)<0.01,'125% survives reloading the game')
    menu()
    select(75)
    check(True,'touch slider reduces the complete interface to 75%')
    menu()
    shot(pg,'play_75')
    menu()
    q=probe(pg);r=375/q['logical'][1]
    sx,sy,sw,sh=q['menus']['scaleReset']
    t.tap((sx+sw/2)*r,(sy+sh/2)*r)
    wait_for(pg,lambda q:abs(q['moba']['scale']-1)<0.01,'reset')
    check(True,'Restore 100% resets the interface')
    clean(logs,'interface settings')
    b.close()
print('%d checks passed'%len(passed))
