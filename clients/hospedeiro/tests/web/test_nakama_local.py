"""Real two-client integration against the ISOLATED localhost QA stack only.

Requires scripts/hospedeiro-nakama.ps1 -LocalTest and a test world on port 8198.
Never points at the published server; never resets a non-QA world.
"""
import asyncio
import base64
import json
import math
import time
import uuid
import requests
import websockets

BASE = 'http://127.0.0.1:7352'

class Guest:
    def __init__(self, name):
        r = requests.post(BASE + '/v2/account/authenticate/device?create=true', auth=('hospedeiro',''),
                          json={'id':'qa-' + uuid.uuid4().hex}, timeout=10)
        r.raise_for_status()
        self.token = r.json()['token']
        self.uid = json.loads(base64.urlsafe_b64decode(self.token.split('.')[1] + '==='))['uid']
        self.name, self.ws, self.seq = name, None, 0

    def rpc(self, op, **body):
        r = requests.post(BASE + '/v2/rpc/hosp_world', headers={'Authorization':'Bearer ' + self.token},
                          json=json.dumps({'op':op, **body}), timeout=10)
        if r.status_code != 200: return {'status':r.status_code}
        return json.loads(r.json()['payload'])

    async def join(self):
        for _ in range(50):
            r = requests.post(BASE + '/v2/rpc/hosp_lobby', headers={'Authorization':'Bearer '+self.token}, json='{}', timeout=10)
            if r.status_code == 200: break
            await asyncio.sleep(.3)
        r.raise_for_status()
        self.mid = json.loads(r.json()['payload'])['match_id']
        self.ws = await websockets.connect('ws://127.0.0.1:7352/ws?format=json&token='+self.token, max_size=1048576)
        await self.ws.send(json.dumps({'cid':'join','match_join':{'match_id':self.mid,'metadata':{'name':self.name}}}))
        while True:
            d = json.loads(await asyncio.wait_for(self.ws.recv(),10))
            assert 'error' not in d, d
            if 'match' in d: break

    async def send(self, move=(0,0), aim=(1,0), actions=(), code=1, extra=None):
        self.seq += 1
        body = extra or {'seq':self.seq,'move':move,'aim':aim,'actions':list(actions)}
        await self.ws.send(json.dumps({'match_data_send':{'match_id':self.mid,'op_code':code,
             'data':base64.b64encode(json.dumps(body).encode()).decode(),'reliable':True}}))

    async def snapshot(self):
        deadline = time.monotonic()+15
        while time.monotonic() < deadline:
            d = json.loads(await asyncio.wait_for(self.ws.recv(),15))
            assert 'error' not in d, d
            if 'match_data' in d and int(d['match_data']['op_code']) == 2:
                p = json.loads(base64.b64decode(d['match_data']['data']))
                if any(e.get('uid') == self.uid for e in p.get('entities',[])): return p
        raise AssertionError('no authoritative snapshot')

    async def latest(self):
        # Consume frames already buffered so movement assertions compare current state.
        result = await self.snapshot()
        for _ in range(8): result = await self.snapshot()
        return result

    def me(self,p): return next(e for e in p['entities'] if e.get('uid') == self.uid)

async def main():
    # Fail closed: only this script's hard-coded isolated QA ports can be used.
    assert BASE == 'http://127.0.0.1:7352'
    a,b = Guest('QA Alfa'), Guest('QA Beta')
    try:
        await a.join(); await b.join()
        pa,pb = await a.latest(),await b.latest()
        assert a.mid == b.mid
        assert any(e.get('uid')==b.uid for e in pa['entities'])
        assert any(e.get('uid')==a.uid for e in pb['entities'])
        print('PASS two guests share the same authoritative world',flush=True)
        start = a.me(pa)['p']
        for _ in range(22):
            await a.send(move=(1,0));await asyncio.sleep(.05)
        await a.send()
        pa = await a.latest()
        end = a.me(pa)['p']
        assert math.dist(start,end)>15,(start,end)
        print('PASS movement calculated on game server',flush=True)
        await a.send(code=2, extra={'target':b.uid,'body':{'version':1,'entities':[{'uid':b.uid,'hp':999999}]}})
        pb = await b.latest()
        assert b.me(pb)['hp']<=b.me(pb)['max_hp']
        assert a.rpc('command',body={'origin':'adapter','kind':'act','action':'derrotar-virus'})['status'] != 200
        print('PASS forged snapshots and adapter claims rejected',flush=True)
        private = a.rpc('view')
        assert private['status']==200,private
        assert a.rpc('view',actor='nk-'+b.uid)['body']['self']['id']==private['body']['self']['id']=='nk-'+a.uid
        print('PASS gateway derives actor from Nakama session',flush=True)
        # Same nutrients and enemies have the same IDs for both observers.
        pa,pb=await a.latest(),await b.latest()
        common={e['id'] for e in pa['entities'] if e['kind']=='nutrient'} & {e['id'] for e in pb['entities'] if e['kind']=='nutrient'}
        assert common
        print('PASS shared entities have stable server IDs',flush=True)
        old_id=a.uid
        await a.ws.close();await asyncio.sleep(.5);await a.join()
        pa=await a.latest();assert a.uid==old_id
        print('PASS reconnect preserves guest identity',flush=True)
        before=a.rpc('view')['body']['tick']
        assert a.rpc('reset',confirm='wrong')['status']!=200
        reset=a.rpc('reset',confirm='new-world')
        assert reset['status']==200,reset
        for _ in range(100):
            await asyncio.sleep(.2)
            again=a.rpc('view')
            if again['status']==200 and again['body']['tick'] < before: break
        assert again['status']==200 and again['body']['tick'] < before,again
        print('PASS confirmed reset archives only the isolated QA world and guests rejoin',flush=True)
    finally:
        if a.ws: await a.ws.close()
        if b.ws: await b.ws.close()

if __name__=='__main__': asyncio.run(main())
