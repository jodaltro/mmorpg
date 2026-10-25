"""Browser smoke test, isolated local Nakama QA stack only. No published endpoints."""
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:8198'
OUT = Path('D:/unity/hospedeiro-web-qa/nakama')
OUT.mkdir(parents=True,exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge',args=['--use-gl=angle','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
    context = browser.new_context(viewport={'width':844,'height':390},has_touch=True,is_mobile=True,device_scale_factor=1)
    page = context.new_page()
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.goto(BASE+'/?probe=1&touch=1&stride=4')
    field=page.get_by_role('textbox',name='Nome da célula')
    field.wait_for(timeout=30000)
    field.fill('Célula QA móvel')
    page.screenshot(path=str(OUT/'entry.png'))
    page.get_by_role('button',name='Entrar no corpo').click()
    deadline=time.monotonic()+120
    data=None
    while time.monotonic()<deadline:
        page.wait_for_timeout(250)
        data=page.evaluate('window.__probe || null')
        if data and data.get('network',{}).get('ready') and page.locator('#loader').count()==0: break
    assert data and data['network']['ready'],data
    assert data['online'] and data['network']['players']>=1,data
    print('PASS name-only entry waits for shared world and private view',flush=True)
    assert data['id'].startswith('nk-')
    page.screenshot(path=str(OUT/'shared-world.png'))
    page.keyboard.down('d');page.wait_for_timeout(1200);page.keyboard.up('d');page.wait_for_timeout(1000)
    after=page.evaluate('window.__probe')
    assert abs(after['x']-data['x'])>10,(data['x'],after['x'])
    print('PASS browser controls move the authoritative cell over proxied WebSocket',flush=True)
    uid=data['id']
    page.reload()
    page.get_by_role('button',name='Entrar no corpo').click(timeout=30000)
    page.wait_for_function("window.__probe && window.__probe.network.ready && !document.getElementById('loader')",timeout=120000)
    assert page.evaluate('window.__probe.id')==uid
    print('PASS page reload preserves the guest character without a password',flush=True)
    assert not errors,errors[:8]
    print('PASS no browser or GDScript errors',flush=True)
    browser.close()
