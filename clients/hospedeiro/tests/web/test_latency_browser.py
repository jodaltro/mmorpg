"""Mobile latency regression on isolated localhost QA only. Adds 180ms each way to WebSocket traffic."""
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE='http://127.0.0.1:8198'
OUT=Path('D:/unity/hospedeiro-web-qa/latency');OUT.mkdir(parents=True,exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='msedge',args=['--use-gl=angle','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
    context=browser.new_context(viewport={'width':844,'height':390},has_touch=True,is_mobile=True,device_scale_factor=1)
    context.add_init_script('''(() => {
      const Native=window.WebSocket, lag=180;
      window.WebSocket=class extends Native {
        send(data) { setTimeout(() => {if(this.readyState===Native.OPEN) super.send(data)},lag); }
        set onmessage(fn) { super.onmessage=fn ? (event)=>setTimeout(()=>fn.call(this,event),lag) : null; }
        get onmessage() { return super.onmessage; }
        addEventListener(type,fn,options) {
          if(type==='message') super.addEventListener(type,(event)=>setTimeout(()=>fn.call(this,event),lag),options);
          else super.addEventListener(type,fn,options);
        }
      };
    })();''')
    page=context.new_page();errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.goto(BASE+'/?probe=1&touch=1&stride=4')
    page.get_by_role('textbox',name='Nome da célula').fill('QA latência')
    page.get_by_role('button',name='Entrar no corpo').click()
    page.wait_for_function('window.__probe && window.__probe.network.ready && window.__probe.network.ping>=300 && !document.getElementById("loader")',timeout=120000)
    page.wait_for_timeout(800)
    before=page.evaluate('window.__probe')
    page.keyboard.down('d')
    try:
        page.wait_for_function('(x)=>window.__probe.x>x+2',arg=before['x'],timeout=330)
        early=page.evaluate('window.__probe')
        assert abs(early['network']['authorityX']-before['network']['authorityX'])<3,early['network']
        print('PASS predicted movement appears before the 360ms server round trip',flush=True)
    finally: page.keyboard.up('d')
    page.wait_for_timeout(2000)
    after=page.evaluate('window.__probe')
    assert 300<=after['network']['ping']<2000,after['network']
    assert after['network']['pingLabel'].endswith(' ms'),after['network']
    print('PASS mobile shows measured gameplay ms under injected latency: '+after['network']['pingLabel'],flush=True)
    assert abs(after['x']-after['network']['authorityX'])<48,(after['x'],after['network'])
    print('PASS movement converges back to the authoritative position',flush=True)
    page.screenshot(path=str(OUT/'mobile-ping.png'))
    assert not errors,errors[:8]
    print('PASS no browser or script errors',flush=True)
    browser.close()
