"""Local rendered combat QA. Reuses the in-memory RPC fixture; no external requests."""
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
        page.get_by_role('textbox', name='Nome da célula').fill('Visual local')
        page.get_by_role('button', name='Entrar no corpo', exact=True).click()
        page.wait_for_function('window.__probe?.online && window.HospPersonal.ready', timeout=90000)
        assert not errors, '\n'.join(errors[:20])
        page.evaluate("window.__cmd='tutorial:pause'")
        page.wait_for_timeout(300)
        page.evaluate("window.__cmd='combat-showcase'")
        page.wait_for_function('window.__probe.enemyWear.length===3', timeout=10000)
        page.screenshot(path=str(ROOT / 'build/combat-healthy.png'))
        page.evaluate("window.__cmd='combat-damage'")
        page.wait_for_function('window.__probe.enemyWear[2].integrity<0.17', timeout=10000)
        facts = page.evaluate('window.__probe.enemyWear')
        assert [enemy['health'] for enemy in facts] == [100, 55, 15]
        assert facts[0]['size'] > facts[1]['size'] > facts[2]['size']
        page.screenshot(path=str(ROOT / 'build/combat-wounded.png'))
        page.evaluate("window.__cmd='combat-lash'")
        page.wait_for_function('window.__probe.lashTargets.length===3 && window.__probe.lashTargets.every(w=>w.extension>0.45)', timeout=10000, polling=20)
        targets = page.evaluate('window.__probe.lashTargets')
        assert all(whip['aimed'] for whip in targets)
        assert len({tuple(whip['target']) for whip in targets}) == 2, str(targets)
        page.screenshot(path=str(ROOT / 'build/combat-targeted-lash.png'))
        assert not errors, '\n'.join(errors[:20])
        print('PASS Browser: real health drives enemy wear; three whips aim at two contacts; no script errors', flush=True)
        browser.close()


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'build/web')))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        run('http://127.0.0.1:' + str(server.server_port))
    finally:
        server.shutdown()
