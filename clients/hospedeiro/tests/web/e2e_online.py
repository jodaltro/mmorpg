"""Browser tests of the online build, against a running server that serves it (worldsim serve -public -web build/web ...).

    python tests/web/e2e_online.py http://127.0.0.1:8197 [shots_dir]

Needs `pip install playwright requests` and an installed Edge or Chrome (no browser download). The tests add ?probe=1 themselves.
Exits non-zero on the first failure and prints what it checked."""
import json
import sys
import time
import requests
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8197").rstrip("/")
SHOTS = Path(sys.argv[2]) if len(sys.argv) > 2 else None
GL = ["--use-gl=angle", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"]
passed = []


def check(ok, what):
    print(("PASS  " if ok else "FAIL  ") + what)
    if not ok:
        sys.exit(1)
    passed.append(what)


def probe(pg):
    return pg.evaluate("window.__probe || null")


def wait_for(pg, cond, what, timeout=120):
    t0 = time.time()
    while time.time() - t0 < timeout:
        p = probe(pg)
        if p and cond(p):
            return p
        time.sleep(0.25)
    check(False, "timeout waiting for " + what + " last=" + json.dumps(probe(pg)))


def shot(pg, name):
    if SHOTS:
        SHOTS.mkdir(parents=True, exist_ok=True)
        pg.screenshot(path=str(SHOTS / f"{name}.png"))


class Touch:
    """Fingers for the Chrome DevTools protocol: each event names only the finger that changed."""

    def __init__(self, cdp):
        self.cdp = cdp
        self.points = {}

    def _send(self, kind, i):
        x, y = self.points[i]
        self.cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": [{"x": x, "y": y, "id": i}]})

    def down(self, x, y, i=1):
        self.points[i] = (x, y)
        self._send("touchStart", i)

    def move(self, x, y, i=1):
        self.points[i] = (x, y)
        self._send("touchMove", i)

    def up(self, i=None):
        for k in ([i] if i is not None else list(self.points)):
            if k in self.points:
                self._send("touchEnd", k)
                del self.points[k]

    def tap(self, x, y, i=1, hold=0.12):
        self.down(x, y, i)
        time.sleep(hold)
        self.up(i)
        time.sleep(0.5)


def page(p, w, h, touch, dpr=2, query="probe=1&debug=1"):
    b = p.chromium.launch(channel="msedge", args=GL)
    ctx = b.new_context(viewport={"width": w, "height": h}, device_scale_factor=dpr, is_mobile=touch, has_touch=touch)
    pg = ctx.new_page()
    logs = []
    pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
    pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
    pg.goto(f"{BASE}/?{query}")
    return b, ctx, pg, logs


def clean(logs, what):
    bad = [l for l in logs if l.startswith("[pageerror]") or (l.startswith("[error]") and "favicon" not in l)]
    check(not bad, what + " (no console errors)" + (": " + bad[0] if bad else ""))


def api(path, token=None, method="GET", body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    response = requests.request(method, BASE + path, headers=headers, json=body, timeout=20)
    try:
        data = response.json()
    except ValueError:
        data = {"error": response.text[:200]}
    return response.status_code, data


def window_button_x(logical_w, ratio, index):
    """Centre of the index-th window button (Corpo, Codice, Mapa, Sinais) in CSS pixels."""
    x = logical_w - 12 - 96 - 8
    centres = []
    for _ in range(4):
        centres.append(x - 37)
        x -= 74 + 8
    return centres[::-1][index] * ratio


with sync_playwright() as p:
    # ---- phone, landscape: detected as touch, online, sticks and buttons work
    b, ctx, pg, logs = page(p, 844, 390, True)
    t = Touch(ctx.new_cdp_session(pg))
    p0 = wait_for(pg, lambda q: q["online"], "phone online")
    pg.wait_for_function("window.__hospedeiroReady && !document.getElementById('loader')", timeout=45000)
    check(True, "phone: initial world view applied before loader is dismissed")
    check(p0["touch"], "phone: touch detected without any flag")
    check(p0["id"].startswith("cel-") and len(p0["id"]) == 14, "phone: the engine gave this cell an id (%s)" % p0["id"])
    check(p0["logical"][1] == 420, "phone: interface sized for a thumb (logical %s)" % p0["logical"])
    check(p0["resetAllowed"] is False, "phone: a public engine hides the world reset")
    check(not p0["debugMenu"], "phone: the test menu is closed")
    ratio = 390 / p0["logical"][1]
    x0 = p0["x"]
    t.down(70, 320, 1)
    for k in range(1, 9):
        t.move(70 + 8 * k, 320, 1)
        time.sleep(0.08)
    time.sleep(1.2)
    p1 = probe(pg)
    check(p1["x"] - x0 > 30, "phone: the move stick walks the cell (+%.0f)" % (p1["x"] - x0))
    ax, ay = (p0["logical"][0] - 92) * ratio, (p0["logical"][1] - 92) * ratio
    t.down(ax, ay, 2)  # the other thumb, while the first is still walking
    time.sleep(0.6)
    p2 = probe(pg)
    check(p2["lash"], "phone: holding the attack button presses the lash while the other thumb walks (state %s)" % json.dumps({k: p2[k] for k in ("alive", "membrane", "attackHeld", "moveHeld", "region")}))
    check(p2["x"] - p1["x"] > 20, "phone: the cell kept walking during the attack (+%.0f)" % (p2["x"] - p1["x"]))
    t.up(2)
    time.sleep(0.3)
    check(not probe(pg)["lash"], "phone: letting go of the attack releases it")
    t.up(1)
    time.sleep(0.2)
    mx = (p0["logical"][0] - 64) * ratio
    t.tap(mx, 36 * ratio)
    bx = (p0["logical"][0] - 78) * ratio
    t.tap(bx, 86 * ratio)
    time.sleep(0.6)
    check(probe(pg)["body"], "phone: menu opens the body window")
    shot(pg, "phone_body")
    t.tap(3, 195)
    check(not probe(pg)["body"], "phone: tapping outside closes the body window")
    pg.evaluate("window.__cmd='become:macrofago'")
    time.sleep(2.0)
    check(len([a for a in probe(pg)["abilities"] if a]) == 4, "phone: the class abilities show up as buttons")
    shot(pg, "phone_play")
    sess_id = p0["id"]
    clean(logs, "phone")
    b.close()

    # ---- phone, portrait: asked to turn
    b, ctx, pg, logs = page(p, 390, 844, True)
    time.sleep(3)
    shown = pg.evaluate("getComputedStyle(document.getElementById('rotate')).display")
    check(shown == "flex", "portrait phone: asked to turn the device")
    shot(pg, "phone_portrait")
    b.close()

    # ---- tablet
    b, ctx, pg, logs = page(p, 1024, 768, True, dpr=2)
    q = wait_for(pg, lambda q: q["online"], "tablet online")
    check(q["touch"] and q["logical"][1] == 768, "tablet: touch controls, one interface unit is one CSS pixel (logical %s)" % q["logical"])
    shot(pg, "tablet_play")
    clean(logs, "tablet")
    b.close()

    # ---- desktop, keyboard and mouse
    b, ctx, pg, logs = page(p, 1280, 720, False, dpr=1, query="probe=1")
    q = wait_for(pg, lambda q: q["online"], "desktop online")
    check(not q["touch"], "desktop: no touch controls")
    x0 = q["x"]
    pg.keyboard.down("d")
    time.sleep(1.2)
    pg.keyboard.up("d")
    check(probe(pg)["x"] - x0 > 20, "desktop: D walks the cell")
    pg.mouse.move(900, 300)
    pg.mouse.down()
    time.sleep(0.3)
    check(probe(pg)["lash"], "desktop: the mouse button attacks")
    pg.mouse.up()
    pg.keyboard.press("g")
    time.sleep(0.6)
    check(probe(pg)["body"], "desktop: G opens the body window")
    pg.keyboard.press("g")
    pg.keyboard.press("Escape")
    time.sleep(0.5)
    check(not probe(pg)["debugMenu"], "desktop: Esc does not open the developer test menu on a public page")
    shot(pg, "desktop_play")
    clean(logs, "desktop")
    b.close()

    # ---- the developer flag brings the test menu back
    b, ctx, pg, logs = page(p, 1280, 720, False, dpr=1, query="probe=1&debug=1")
    wait_for(pg, lambda q: q["online"], "debug online")
    pg.keyboard.press("Escape")
    time.sleep(0.6)
    check(probe(pg)["debugMenu"], "debug=1: Esc opens the test menu")
    b.close()

# ---- the API in public mode
code, _ = api("/v1/commands", method="POST", body={"version": 1, "requestId": "x", "origin": "adapter", "kind": "join", "actor": sess_id, "name": "intruso", "region": "medula"})
check(code == 401, "api: a command with no token is refused (%s)" % code)
code, s1 = api("/v1/session", method="POST", body={"version": 1})
check(code == 200 and s1["public"] is True and s1["capabilities"]["reset"] is False, "api: a new session is issued")
code, s2 = api("/v1/session", method="POST", body={"version": 1, "id": s1["id"], "token": s1["token"]})
check(code == 200 and s2["id"] == s1["id"] and s2["token"] == s1["token"], "api: the same cell gets the same token back")
code, _ = api("/v1/session", method="POST", body={"version": 1, "id": s1["id"], "token": "forged"})
check(code == 401, "api: a forged token is refused")
code, _ = api("/v1/views/" + s1["id"])
check(code == 401, "api: a view with no token is refused")
code, _ = api("/v1/world/reset", method="POST", body={"version": 1, "confirm": "new-world"})
check(code == 403, "api: nobody can wipe the shared world")
code, pl = api("/v1/players")
check(code == 200 and len(pl["players"]) >= 3, "api: the shared body has several cells now (%d)" % len(pl["players"]))
print("\n%d checks passed" % len(passed))
