"""Local-only offline UI checks: compact genes, mission access and reset cancellation."""
import sys,time
from pathlib import Path
from playwright.sync_api import sync_playwright
source=Path(__file__).with_name("e2e_online.py").read_text(encoding="utf-8")
exec(source[:source.index("with sync_playwright() as p:")])
if not BASE.startswith(('http://127.0.0.1:', 'http://localhost:')):
    raise SystemExit('Local test server required')
with sync_playwright() as p:
    b,ctx,pg,logs=page(p,667,375,True,query='probe=1&debug=1&engine=off')
    pg.wait_for_function("window.__probe && !document.getElementById('loader')",timeout=60000)
    t=Touch(ctx.new_cdp_session(pg))
    def at(x,y):
        r=375/probe(pg)['viewport'][1];t.tap(x*r,y*r)
    def rect(values):
        x,y,w,h=values;at(x+w/2,y+h/2)
    def menu():
        q=probe(pg);at(q['viewport'][0]-64,36)
        wait_for(pg,lambda q:q['menus']['navigation'],'navigation')
    menu();rect(probe(pg)['menus']['missionsButton'])
    q=wait_for(pg,lambda q:q['menus']['missions'],'missions window')
    check(not q['menus']['navigation'],'missions open directly from navigation and close its backdrop')
    shot(pg,'missions')
    t.tap(3,180);wait_for(pg,lambda q:not q['menus']['missions'],'missions closed')
    menu();rect(probe(pg)['menus']['restartButton'])
    wait_for(pg,lambda q:q['menus']['resetDialog'],'reset confirmation')
    check(True,'reset opens an explicit confirmation, never an immediate wipe')
    shot(pg,'reset_confirmation')
    t.tap(3,180);wait_for(pg,lambda q:not q['menus']['resetDialog'],'reset cancelled')
    check(True,'outside tap cancels reset confirmation')
    menu();q=probe(pg);at(q['viewport'][0]-78,86)
    wait_for(pg,lambda q:q['body'],'body')
    rect(probe(pg)['menus']['tabs'][1])
    q=wait_for(pg,lambda q:q['menus']['bodyTab']==1,'genes')
    check('espaço livre' not in q['menus']['bodyContent'] and len(q['menus']['bodyContent'])<500,'empty genes use a concise summary instead of six large cards')
    check('RESULTADO DA TROCA' not in q['menus']['bodyContent'],'comparison appears only after a selection')
    shot(pg,'genes')
    clean(logs,'genes and missions')
    b.close()
print('%d checks passed'%len(passed))
