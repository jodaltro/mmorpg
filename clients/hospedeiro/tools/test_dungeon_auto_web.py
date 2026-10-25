"""Automatic portal/start with real local WASM rules, no published services."""
import threading
from functools import partial
from test_personal_web import Handler, ROOT, ThreadingHTTPServer, sync_playwright


def run(base):
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel='msedge', headless=True, args=['--enable-unsafe-swiftshader'])
        page = browser.new_page(viewport={'width': 960, 'height': 540}, has_touch=True)
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if 'SCRIPT ERROR' in message.text or message.text.startswith('ERROR:') else None)
        page.route('**/*', lambda route: route.continue_() if route.request.url.startswith(base) else route.abort())
        page.goto(base + '/?mode=personal&probe=1&debug=1&touch=1&localIce=1')
        page.get_by_role('textbox', name='Nome da célula').fill('Portal local')
        page.get_by_role('button', name='Entrar no corpo', exact=True).click()
        page.wait_for_function('window.__probe?.online && window.HospPersonal.ready', timeout=90000)
        # Legitimate adapter deeds in an isolated local journal unlock the portal.
        page.evaluate('''async () => {
          const P=window.HospPersonal, actor=window.__probe.id;
          const command=body=>new Promise((resolve,reject)=>{
            const ticket=P.begin('/v1/commands',{version:1,requestId:crypto.randomUUID(),actor,...body});
            const timer=setInterval(()=>{const value=P.take(ticket);if(value){clearInterval(timer);const r=JSON.parse(value);r.status===200?resolve(r):reject(Error(JSON.stringify(r)));}},5);
          });
          for(let i=0;i<168;i++)await command({origin:'adapter',kind:'act',action:'absorver-nutriente'});
          await command({origin:'adapter',kind:'move',region:'sangue'});
        }''')
        page.evaluate("window.__cmd='goto-gate:granuloma'")
        # No E, Agir, entry confirmation or start-combat clicks.
        page.wait_for_function('window.__probe.dungeon.active && !window.__probe.dungeon.briefing && window.__probe.dungeon.state==="active"', timeout=90000)
        assert not page.evaluate('window.__probe.dungeon.menu')
        page.screenshot(path=str(ROOT / 'build/dungeon-auto-entry.png'))
        assert not errors, '\n'.join(errors[:20])
        print('PASS Browser: reaching an unlocked portal enters and starts real WASM dungeon without confirmation', flush=True)
        browser.close()


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'build/web')))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        run('http://127.0.0.1:' + str(server.server_port))
    finally:
        server.shutdown()
