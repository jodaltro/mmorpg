"""Loading contract: run against a local worldsim -public -web build/web server."""
import sys
from playwright.sync_api import sync_playwright

base = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8197").rstrip("/")
with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge", args=["--use-gl=angle", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    page = browser.new_page(viewport={"width": 844, "height": 390}, is_mobile=True, has_touch=True)
    page.goto(base + "/?probe=1&engine=off")
    page.wait_for_function("window.__probe && !document.getElementById('loader')", timeout=60000)
    assert not page.evaluate("window.__probe.online")
    print("PASS explicit offline opens without waiting for the server")
    page.close()
    page = browser.new_page(viewport={"width": 844, "height": 390}, is_mobile=True, has_touch=True)
    page.route("**/v1/**", lambda route: route.fulfill(status=503, content_type="application/json", body='{"error":"world_offline"}'))
    page.goto(base + "/?probe=1")
    page.wait_for_function("window.__probe", timeout=60000)
    assert page.locator("#loader").is_visible()
    print("PASS missing initial API keeps the loading screen visible")
    page.get_by_role("button", name="Jogar offline").wait_for(timeout=30000)
    assert page.locator("#loader").is_visible()
    print("PASS timeout offers an explicit choice rather than silently entering offline")
    page.get_by_role("button", name="Jogar offline").click()
    assert page.locator("#loader").count() == 0
    print("PASS choosing offline dismisses loading")
    page.reload()
    page.wait_for_function("window.__probe", timeout=60000)
    page.get_by_role("button", name="Jogar offline").wait_for(timeout=30000)
    page.unroute("**/v1/**")
    page.wait_for_function("window.__hospedeiroReady && !document.getElementById('loader')", timeout=45000)
    print("PASS a late initial API response dismisses loading after the timeout prompt")
    browser.close()
