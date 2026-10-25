"""Real delayed WebSocket + two browsers against the isolated loopback QA world.

Requires 8198/7352 QA services and a Web export. Never uses published endpoints.
Python dependencies: aiohttp, playwright. Evidence stays outside the repository.
"""
import asyncio
import json
import threading
import time
from pathlib import Path

from aiohttp import ClientSession, WSMsgType, web
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:18110'
UPSTREAM = 'http://127.0.0.1:8198'
OUT = Path('D:/unity/hospedeiro-web-qa/prediction')
OUT.mkdir(parents=True, exist_ok=True)
hold_until = 0.0


async def relay(source, destination):
    queue = asyncio.Queue(maxsize=1024)

    async def read():
        previous = 0.0
        count = 0
        async for message in source:
            if message.type not in (WSMsgType.TEXT, WSMsgType.BINARY): continue
            count += 1
            # Ordered reliable delivery, 180 ms one way plus deterministic jitter.
            previous = max(previous, time.monotonic() + .180 + (count % 5) * .004)
            await queue.put((previous, message))

    async def write():
        while True:
            due, message = await queue.get()
            while time.monotonic() < max(due, hold_until):
                await asyncio.sleep(min(.03, max(due, hold_until) - time.monotonic()))
            try:
                if message.type == WSMsgType.TEXT: await destination.send_str(message.data)
                else: await destination.send_bytes(message.data)
            except ConnectionError:
                return

    tasks = [asyncio.create_task(read()), asyncio.create_task(write())]
    await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    for task in tasks: task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)


async def proxy(request):
    session = request.app['session']
    url = UPSTREAM + request.rel_url.path_qs
    if request.headers.get('Upgrade', '').lower() == 'websocket':
        downstream = web.WebSocketResponse(autoping=False)
        await downstream.prepare(request)
        async with session.ws_connect(url, autoping=False, max_msg_size=1048576) as upstream:
            tasks = [asyncio.create_task(relay(downstream, upstream)), asyncio.create_task(relay(upstream, downstream))]
            await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in tasks: task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
        return downstream
    headers = {k: v for k, v in request.headers.items() if k.lower() not in ('host', 'connection', 'content-length')}
    headers['Accept-Encoding'] = 'identity'  # exercise the fresh export, never an older compressed sibling
    # The QA relay is the browser's same origin; preserve that relation upstream.
    if headers.get('Origin') == BASE: headers['Origin'] = UPSTREAM
    async with session.request(request.method, url, data=await request.read(), headers=headers) as response:
        body = await response.read()
        headers = {k: v for k, v in response.headers.items() if k.lower() not in ('transfer-encoding', 'content-encoding', 'content-length', 'connection')}
        return web.Response(status=response.status, body=body, headers=headers)


def serve(ready):
    async def run():
        app = web.Application()
        app['session'] = ClientSession()
        app.router.add_route('*', '/{path:.*}', proxy)
        runner = web.AppRunner(app, access_log=None)
        await runner.setup()
        await web.TCPSite(runner, '127.0.0.1', 18110).start()
        ready.set()
        await asyncio.Event().wait()
    asyncio.run(run())


ready = threading.Event()
threading.Thread(target=serve, args=(ready,), daemon=True).start()
assert ready.wait(10)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True, args=['--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding'])
    pages = []
    errors = []
    for name in ('Previsão QA A', 'Previsão QA B'):
        context = browser.new_context(viewport={'width':844, 'height':390}, has_touch=True, device_scale_factor=1)
        context.route('**/*', lambda route: route.continue_() if route.request.url.startswith((BASE+'/', 'data:', 'blob:')) else route.abort())
        page = context.new_page()
        page.on('pageerror', lambda error: (errors.append(str(error)), print('PAGE ERROR', str(error), flush=True)))
        page.on('console', lambda msg: (errors.append(msg.text), print('CONSOLE ERROR', msg.text, flush=True)) if msg.type == 'error' else None)
        page.goto(BASE + '/?probe=1&touch=1&debug=1&stride=4')
        print('Page loaded', name, flush=True)
        page.get_by_role('textbox', name='Nome da célula').fill(name)
        page.get_by_role('button', name='Entrar no corpo').click()
        try:
            page.wait_for_function('window.__probe?.network.ready && !document.querySelector("#loader")', timeout=90000)
        except Exception:
            page.screenshot(path=str(OUT/'connection-failure.png'))
            print('Connection failed', page.evaluate('({probe:window.__probe, text:document.body.innerText})'), errors, flush=True)
            raise
        page.evaluate('window.__cmd="tutorial:pause"')
        page.wait_for_function('!window.__probe.tutorial.active', timeout=10000)
        pages.append(page)
    page = pages[0]
    page.bring_to_front()
    page.wait_for_function('window.__probe.network.players>=2 && window.__probe.network.ping>300', timeout=20000)
    print('PASS two guests share the isolated world through a delayed WebSocket', flush=True)

    def facts(): return page.evaluate('window.__probe')
    def center(rect):
        viewport = facts()['viewport']
        return ((rect[0]+rect[2]/2)*844/viewport[0], (rect[1]+rect[3]/2)*390/viewport[1])

    before = facts()
    baseline_ping = before['network']['ping']
    start = time.monotonic()
    page.touchscreen.tap(*center(before['tutorial']['toxin']))
    page.wait_for_function('(n)=>window.__probe.network.predictedCasts>n && window.__probe.network.pendingCasts>0', arg=before['network']['predictedCasts'], timeout=5000)
    cast_ms = round((time.monotonic()-start)*1000)
    assert facts()['network']['pendingCasts'] > 0
    print(f'PASS projectile appears before server confirmation (probe observed in {cast_ms} ms)', flush=True)
    page.screenshot(path=str(OUT/'immediate-shot.png'))
    page.wait_for_function('window.__probe.network.pendingCasts===0', timeout=10000)

    before = facts()
    page.keyboard.down('d')
    page.wait_for_function('(s)=>window.__probe.x>s+5', arg=before['x'], timeout=1500)
    immediate = facts()
    assert abs(immediate['network']['authorityX'] - before['network']['authorityX']) < 4, (before, immediate)
    print('PASS own movement responds while authority is still at the previous position', flush=True)
    samples = []
    for _ in range(8):
        page.wait_for_timeout(100)
        samples.append(facts())
    page.keyboard.up('d')
    page.wait_for_timeout(1200)
    max_correction = max(s['network']['correctionPx'] for s in samples)
    assert max_correction < 96, max_correction
    print(f'PASS movement reconciliation remains bounded ({max_correction:.2f} px peak visual correction)', flush=True)

    hold_until = time.monotonic() + .8
    before = facts()
    page.keyboard.down('a')
    page.wait_for_function('(s)=>window.__probe.x<s-5', arg=before['x'], timeout=1200)
    page.wait_for_timeout(250)
    page.keyboard.up('a')
    page.wait_for_timeout(4000)
    after = facts()
    print('Recovery diagnostic', {k: after['network'][k] for k in ('inputSeq','inputAck','missingInputs','predictionFrames','bufferedInputs','ping')}, flush=True)
    assert after['network']['ready'] and after['alive'], after
    assert after['network']['bufferedInputs'] < 12, after['network']
    assert after['network']['predictionFrames'] < 90, after['network']
    print('PASS an 800 ms delivery stall leaves local controls responsive and input retransmission recovers', flush=True)
    assert not errors, errors[:8]
    result = {'checks':6, 'configuredOneWayMs':180, 'jitterMs':[0,16], 'baselinePingMs':baseline_ping, 'observedPingMs':after['network']['ping'], 'probeObservedCastMs':cast_ms, 'maximumVisualCorrectionPx':max_correction, 'scriptErrors':errors, 'after':after['network'], 'endpoints':'loopback QA only, no resets'}
    (OUT/'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    page.screenshot(path=str(OUT/'recovered.png'))
    print(json.dumps(result, ensure_ascii=False), flush=True)
    browser.close()
