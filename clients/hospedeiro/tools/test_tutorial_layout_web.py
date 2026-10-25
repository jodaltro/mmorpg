"""Local mobile regression: waiting tutorial, orientation, UI scale and return GPS."""
import threading
from functools import partial
from test_personal_web import Handler, ROOT, ThreadingHTTPServer, sync_playwright


def run(base):
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel='msedge', headless=True, args=['--enable-unsafe-swiftshader'])
        page = browser.new_page(viewport={'width': 1280, 'height': 576}, has_touch=True)
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if 'SCRIPT ERROR' in message.text or message.text.startswith('ERROR:') else None)
        page.route('**/*', lambda route: route.continue_() if route.request.url.startswith(base) else route.abort())
        page.goto(base + '/?mode=personal&probe=1&debug=1&touch=1&localIce=1')
        page.get_by_role('textbox', name='Nome da célula').fill('Tutorial local')
        page.get_by_role('button', name='Entrar no corpo', exact=True).click()
        page.wait_for_function('window.__probe?.online && window.HospPersonal.ready', timeout=90000)
        page.evaluate("window.__cmd='tutorial-outside'")
        page.wait_for_function('window.__probe.tutorial.waiting && window.__probe.tutorial.step===1', timeout=10000)
        for width, height, scale in [(1280,576,1), (640,360,1.25), (360,780,1.25), (780,360,0.75), (1280,576,1)]:
            page.set_viewport_size({'width':width, 'height':height})
            page.evaluate('(scale)=>window.__cmd="ui-scale:"+scale', scale)
            page.wait_for_timeout(500)
            page.wait_for_function('''() => {
              const p=window.__probe,t=p.tutorial,c=t.card,b=t.next,v=p.viewport;
              return t.waiting && c[3]<=v[1]*0.58+2 && c[0]>=0 && c[0]+c[2]<=v[0]+1 && c[1]+c[3]<=v[1]-4
                && b[1]>=c[1] && b[1]+b[3]<=c[1]+c[3]+1;
            }''', timeout=10000)
        page.screenshot(path=str(ROOT / 'build/tutorial-waiting-fit.png'))
        point=page.evaluate('''() => {const p=__probe,b=p.tutorial.next,v=p.viewport;return [(b[0]+b[2]/2)*1280/v[0],(b[1]+b[3]/2)*576/v[1]];}''')
        page.touchscreen.tap(*point)
        page.wait_for_function('!window.__probe.tutorial.active && window.__probe.tutorial.pausedRoute', timeout=10000)
        assert page.evaluate('window.__probe.tutorial.step') == 1
        page.screenshot(path=str(ROOT / 'build/tutorial-return-gps.png'))
        assert not errors, '\n'.join(errors[:20])
        print('PASS Browser: tutorial bounded through 5 viewport/scale changes; touch footer starts return GPS and preserves lesson', flush=True)
        browser.close()


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'build/web')))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        run('http://127.0.0.1:' + str(server.server_port))
    finally:
        server.shutdown()
