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
        x=48+(value-75)/50*234
        t.down(x*r,(q['logical'][1]-60)*r)
        t.move(x*r,(q['logical'][1]-60)*r)
        t.up()
        return wait_for(pg,lambda q:abs(q['moba']['scale']-value/100)<0.01,'scale '+str(value))
    menu()
    select(125)
    check(True,'touch slider enlarges the complete interface to 125%')
    shot(pg,'settings_125')
    q=probe(pg);r=375/q['logical'][1]
    t.tap((q['logical'][0]-78)*r,86*r)
    menu()
    q=wait_for(pg,lambda q:q['body'],'body window at 125%')
    rect=q['bodyRect']
    check(rect[0]+rect[2]<=q['logical'][0]+1 and rect[1]+rect[3]<=q['logical'][1]+1,'body window fits the smallest phone at 125%')
    shot(pg,'body_125')
    pg.keyboard.press('g')
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
    t.tap(375*r,(q['logical'][1]-60)*r)
    wait_for(pg,lambda q:abs(q['moba']['scale']-1)<0.01,'reset')
    check(True,'Restore 100% resets the interface')
    clean(logs,'interface settings')
    b.close()
print('%d checks passed'%len(passed))
