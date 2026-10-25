"""Local-only integration: real Lua RPC with an in-memory Nakama storage double,
real browser WASM, two WebRTC peers without external STUN. Needs lupa/playwright.
Run from repository root after tools/build_web.py. Never contacts a live server.
"""
import base64
import copy
import hashlib
import json
import threading
import time
import uuid
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from lupa import LuaRuntime
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[3]
lua = LuaRuntime(unpack_returned_tuples=True)
rows, callbacks = {}, {}
lock = threading.RLock()


def plain(value):
    if hasattr(value, 'items'):
        pairs = dict(value.items())
        if pairs and all(isinstance(k, int) for k in pairs):
            return [plain(pairs[k]) for k in sorted(pairs)]
        return {k: plain(v) for k, v in pairs.items()}
    return value


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


def storage_read(requests):
    result = []
    for q in plain(requests):
        key = (q['collection'], q['key'], q['user_id'])
        if key in rows:
            result.append(copy.deepcopy(rows[key]))
    return table(result)


def storage_write(requests):
    requests = plain(requests)
    for q in requests:
        old = rows.get((q['collection'], q['key'], q['user_id']))
        if q['version'] == '*' and old or q['version'] != '*' and (not old or old['version'] != q['version']):
            raise ValueError('version conflict')
    result = []
    for q in requests:
        key = (q['collection'], q['key'], q['user_id'])
        q = copy.deepcopy(q)
        q['version'] = str(uuid.uuid4())
        rows[key] = q
        result.append({'version': q['version'], 'collection': q['collection'], 'key': q['key']})
    return table(result)


nk = lua.table_from({
    'json_decode': lambda raw: table(json.loads(raw)),
    'json_encode': lambda value: json.dumps(plain(value), separators=(',', ':')),
    'storage_read': storage_read, 'storage_write': storage_write,
    'uuid_v4': lambda: str(uuid.uuid4()), 'time': lambda: int(time.time() * 1000),
    'sha256_hash': lambda raw: hashlib.sha256(raw.encode()).hexdigest(),
    'register_rpc': lambda fn, name: callbacks.update({name: fn}),
})
lua.globals().nk_test = nk
lua.execute("package.preload['nakama']=function() return nk_test end")
lua.execute((ROOT / 'services/nakama/modules/personal.lua').read_text(encoding='utf-8'))


def rpc(owner, body):
    with lock:
        return json.loads(callbacks['hosp_personal'](table({'user_id': owner}), json.dumps(body)))


def test_rpc():
    base = dict(op='save', base=0, version='*', request='one', commands=[{'version': 1}], definition=json.dumps({'id': 'test', 'emptyArray': [], 'emptyObject': {}}))
    saved = rpc('alice', base)
    assert saved['status'] == 200
    definition = rpc('alice', {'op':'load'})['definition']['json']
    assert json.loads(definition)['emptyArray'] == [] and json.loads(definition)['emptyObject'] == {}
    assert rpc('alice', base)['status'] == 200, 'lost response must be idempotent'
    assert rpc('alice', dict(base, commands=[{'version': 2}]))['status'] == 409
    assert rpc('bob', {'op': 'load'})['meta']['count'] == 0, 'save privacy'
    assert rpc('alice', dict(base, request='different'))['status'] == 409
    assert all(r['permission_read'] == 0 and r['permission_write'] == 0 for r in rows.values())
    room = rpc('alice', {'op': 'room-create'})['room']
    assert rpc('bob', {'op': 'room-poll', 'room': room})['status'] == 403
    assert rpc('bob', {'op': 'room-join', 'room': room})['status'] == 200
    assert rpc('third', {'op': 'room-join', 'room': room})['status'] == 403
    rpc('alice', {'op': 'room-send', 'room': room, 'message': {'type': 'description', 'sdp': 'test'}})
    assert len(rpc('bob', {'op': 'room-poll', 'room': room})['messages']) == 1
    assert not rpc('alice', {'op': 'room-poll', 'room': room})['messages']
    rpc('alice', {'op': 'room-close', 'room': room})
    assert rpc('bob', {'op': 'room-poll', 'room': room})['status'] == 410
    rows.clear()
    print('PASS Lua: private saves, CAS, idempotency, room admission, expiry', flush=True)


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        try:
            data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            if self.path.startswith('/nakama/v2/account/authenticate/device'):
                uid = hashlib.sha256(data['id'].encode()).hexdigest()[:24]
                claims = base64.urlsafe_b64encode(json.dumps({'uid': uid}).encode()).decode().rstrip('=')
                result = {'token': 'header.' + claims + '.test'}
            elif self.path == '/nakama/v2/rpc/hosp_personal':
                token = self.headers['Authorization'].split()[1]
                uid = json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '==='))['uid']
                result = {'payload': json.dumps(rpc(uid, json.loads(data)))}
            else:
                raise ValueError('Unexpected network call: ' + self.path)
            encoded = json.dumps(result).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except Exception as err:
            self.send_error(500, str(err))


def browser_test(base):
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='msedge', headless=True, args=['--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding'])
        contexts = [browser.new_context(viewport={'width': 960, 'height': 540}, has_touch=True) for _ in range(2)]
        pages = [c.new_page() for c in contexts]
        lost_ack = [False]
        for i, page in enumerate(pages):
            page.on('pageerror', lambda err: errors.append(str(err)))
            page.on('console', lambda msg: errors.append(msg.text) if 'SCRIPT ERROR' in msg.text or msg.text.startswith('ERROR:') else None)
            # Do not permit even STUN, analytics or an accidental published-server call.
            page.route('**/*', lambda route: route.continue_() if route.request.url.startswith(base) else route.abort())
            if i == 1:
                def lose_one_save_response(route):
                    body = json.loads(json.loads(route.request.post_data))
                    if body.get('op') == 'save' and not lost_ack[0]:
                        route.fetch()  # commit on the local server, lose only its reply
                        lost_ack[0] = True
                        route.abort()
                    else:
                        route.fallback()
                page.route('**/nakama/v2/rpc/hosp_personal', lose_one_save_response)
            page.goto(base + '/?mode=personal&probe=1&debug=1&touch=1&localIce=1')
            page.get_by_role('textbox', name='Nome da célula').fill('Teste ' + str(i))
            page.get_by_role('button', name='Entrar no corpo', exact=True).click()
            page.wait_for_function('window.__probe?.online && window.HospPersonal.ready', timeout=90000)
            page.evaluate("window.__cmd='tutorial:pause'")
        host, guest = pages
        host.evaluate('window.HospPersonal.partyOpen()')
        host.get_by_role('button', name='Mostrar convite e QR Code', exact=True).click()
        host.wait_for_selector('section svg', timeout=15000)
        host.screenshot(path=str(ROOT / 'build/personal-menu.png'))
        invite = host.get_by_placeholder('Cole o link do amigo').input_value()
        host.get_by_role('button', name='Voltar ao jogo', exact=True).click()
        guest.evaluate('(url)=>window.HospPersonal.partyJoin(url)', invite)
        guest.wait_for_function('window.__probe?.network.ready && window.__probe.network.players===2', timeout=60000)
        host.wait_for_function('window.HospPersonal.peer?.role === "host"', timeout=10000)
        print('PASS Browser: two full game clients, direct WebRTC, both players replicated', flush=True)
        guest.screenshot(path=str(ROOT / 'build/personal-pvp.png'))
        assert guest.evaluate('window.__probe.linkURL') == 'local://personal'
        host.evaluate("window.__cmd='party-monster'")
        guest.wait_for_function('window.__probe.personalProgress.abates===1', timeout=15000)
        assert host.evaluate('window.__probe.personalProgress.abates') == 0, 'visitor kills advanced the owner'
        host.evaluate("window.__cmd='party-pvp'")
        host.wait_for_function('!window.__probe.alive', timeout=10000)
        guest.wait_for_timeout(1200)
        assert guest.evaluate('window.__probe.personalProgress.abates') == 1, 'PvP advanced monster progression'
        guest.wait_for_function('window.HospPersonal.getCloudCount()>0', timeout=20000)
        assert lost_ack[0], 'lost save receipt was not exercised'
        print('PASS Browser: visitor progresses independently; player defeats give no progression; real Lua cloud save', flush=True)
        # Cloud and signalling can disappear after connection; local movement and WebRTC survive.
        for page in pages:
            page.route('**/nakama/**', lambda route: route.abort())
        start = guest.evaluate('window.__probe.x')
        guest.locator('#canvas').focus()
        guest.keyboard.down('d')
        guest.wait_for_timeout(1400)
        guest.keyboard.up('d')
        assert abs(guest.evaluate('window.__probe.x') - start) > 1, 'movement stopped without cloud'
        assert guest.evaluate('window.__probe.network.ready'), 'WebRTC depends on signalling after connecting'
        print('PASS Browser: movement and P2P survive unavailable cloud/signalling', flush=True)
        # A complete cached export opens without any network, and replays its durable journal.
        guest.evaluate('window.HospPersonal.partyClose()')
        guest.wait_for_function('window.__probe?.online && !window.__probe.network.ready', timeout=30000)
        guest.wait_for_function('!!navigator.serviceWorker.controller', timeout=30000)
        contexts[1].set_offline(True)
        guest.reload()
        guest.get_by_role('textbox', name='Nome da célula').fill('Teste 1')
        guest.get_by_role('button', name='Entrar no corpo', exact=True).click()
        guest.wait_for_function('window.__probe?.online && window.__probe.personalProgress.abates===1', timeout=90000)
        print('PASS Browser: fully offline reload preserves visitor progression and local journal', flush=True)
        contexts[1].set_offline(False)
        guest.unroute('**/nakama/**')
        guest.wait_for_function("""async () => {
          let offset=0, first=await window.HospPersonal.rpc({op:'load',offset:0});
          while(offset<first.meta.count){
            const part=offset===0?first:await window.HospPersonal.rpc({op:'load',offset});
            if(part.segment.commands.some(c=>c.action==='derrotar-virus'))return true;
            offset+=part.segment.commands.length;
          }return false;
        }""", timeout=30000, polling=2000)
        guest.on('dialog', lambda dialog: dialog.accept())
        guest.evaluate('window.HospPersonal.partyOpen()')
        with guest.expect_navigation(wait_until='domcontentloaded', timeout=30000):
            guest.get_by_role('button', name='Restaurar meu save da nuvem', exact=True).click()
        guest.wait_for_function('window.__probe?.online && window.__probe.personalProgress.abates===1', timeout=90000)
        print('PASS Browser: cloud journal restores through validated replay and resumes the game', flush=True)
        assert not errors, '\n'.join(errors[:20])
        browser.close()


if __name__ == '__main__':
    test_rpc()
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'build/web')))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        browser_test('http://127.0.0.1:' + str(server.server_port))
    finally:
        server.shutdown()
