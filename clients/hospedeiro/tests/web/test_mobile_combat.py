"""Browser checks for the mobile combat HUD, including real multi-touch drag/cancel."""
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

# Reuse test helpers without running the full integration suite.
source = Path(__file__).with_name("e2e_online.py").read_text(encoding="utf-8")
exec(source[:source.index("with sync_playwright() as p:")])
with sync_playwright() as p:
    b, ctx, pg, logs = page(p, 844, 390, True)
    t = Touch(ctx.new_cdp_session(pg))
    q = wait_for(pg, lambda q: q["online"], "mobile online")
    pg.wait_for_function("window.__hospedeiroReady && !document.getElementById('loader')")
    pg.evaluate("window.__cmd='god'")
    time.sleep(0.5)
    pg.evaluate("window.__cmd='become:macrofago'")
    q = wait_for(pg, lambda q: len([a for a in q['abilities'] if a]) == 4, "class abilities")
    ratio = 390 / q["logical"][1]
    button = q["moba"]["buttons"][3]
    x,y = button["x"]*ratio,button["y"]*ratio
    previous = q["lastCast"]
    t.down(x,y)
    time.sleep(0.3)
    check(probe(pg)["lastCast"] == previous, "holding a skill does not cast it")
    t.move(q["moba"]["cancel"][0]*ratio,q["moba"]["cancel"][1]*ratio)
    wait_for(pg, lambda q: q["moba"]["buttons"][3]["cancelled"], "cancel zone")
    shot(pg,"cancel_skill")
    t.up()
    time.sleep(0.4)
    check(probe(pg)["lastCast"] == previous, "releasing over cancel does not cast")
    t.down(x,y)
    t.move(x,y-35)
    time.sleep(0.3)
    shot(pg,"aim_skill")
    t.up()
    wait_for(pg, lambda q: q["lastCast"] == q["abilities"][3], "release casts")
    check(True,"release casts the chosen class skill")
    check(len({v['glyph'] for v in probe(pg)['moba']['buttons']}) == 4,"the four macrophage skills have distinct icons")
    shot(pg,"combat_phone")
    clean(logs,"mobile combat")
    b.close()
    for w,h,name in [(667,375,"small_phone"),(1024,768,"tablet")]:
        b,ctx,pg,logs = page(p,w,h,True,query="probe=1&debug=1&engine=off")
        pg.wait_for_function("window.__probe && !document.getElementById('loader')",timeout=60000)
        pg.evaluate("window.__cmd='become:macrofago'")
        q=wait_for(pg,lambda q:len([a for a in q['abilities'] if a])==4,name+" abilities")
        check(q['touch'],name+": touch layout selected")
        shot(pg,name)
        clean(logs,name)
        b.close()
print("%d checks passed" % len(passed))
