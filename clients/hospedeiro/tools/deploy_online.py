"""Publishes Hospedeiro on Cloudflare (free plan) with the keys in engine/.env.

    python tools/deploy_online.py web            # upload build/web to R2 and (re)deploy the Worker
    python tools/deploy_online.py origin <url>   # point the Worker at the tunnel that reaches the game server

Needs `pip install requests boto3`. What it creates in the account (nothing else is touched): the R2 bucket `hospedeiro-web`,
the Worker `hospedeiro` (at <name>.<account subdomain>.workers.dev), and HOSPEDEIRO_EDGE_SECRET in engine/.env.
The Worker serves the build from R2 and sends /v1/* to the origin, carrying the edge secret that only it and the server know."""
import json
import mimetypes
import secrets
import sys
from pathlib import Path

import boto3
import requests

ROOT = Path(__file__).resolve().parents[3]
ENV = ROOT / "engine" / ".env"
BUILD = ROOT / "build" / "web"
WORKER_JS = Path(__file__).resolve().parents[1] / "web" / "worker.js"
BUCKET = "hospedeiro-web"
WORKER = "hospedeiro"
API = "https://api.cloudflare.com/client/v4"

TYPES = {".wasm": "application/wasm", ".js": "text/javascript; charset=utf-8", ".html": "text/html; charset=utf-8", ".pck": "application/octet-stream",
         ".png": "image/png", ".webmanifest": "application/manifest+json", ".json": "application/json"}


def read_env() -> dict:
    out = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def edge_secret(env: dict) -> str:
    if env.get("HOSPEDEIRO_EDGE_SECRET"):
        return env["HOSPEDEIRO_EDGE_SECRET"]
    value = secrets.token_urlsafe(32)
    with ENV.open("a", encoding="utf-8") as f:
        f.write(f"\n# Segredo entre o Worker e o servidor do jogo. Nao versionar.\nHOSPEDEIRO_EDGE_SECRET={value}\n")
    return value


def call(env, method, path, missing_ok=False, **kw):
    res = requests.request(method, f"{API}/accounts/{env['CLOUDFLARE_ACCOUNT_ID']}{path}", headers={"Authorization": "Bearer " + env["CLOUDFLARE_API_TOKEN"]}, timeout=120, **kw)
    if missing_ok and res.status_code == 404:
        return {}
    body = res.json() if res.content else {}
    if not body.get("success", res.ok):
        sys.exit(f"{method} {path} failed: {res.status_code} {body.get('errors')}")
    return body.get("result")


def ensure_bucket(env):
    names = [b["name"] for b in call(env, "GET", "/r2/buckets")["buckets"]]
    if BUCKET not in names:
        call(env, "POST", "/r2/buckets", json={"name": BUCKET})
        print("created R2 bucket", BUCKET)


def content_type(name: str) -> str:
    base = name[:-3] if name.endswith(".br") else name[:-3] if name.endswith(".gz") else name
    ext = Path(base).suffix
    return TYPES.get(ext) or mimetypes.guess_type(base)[0] or "application/octet-stream"


def upload_web(env):
    s3 = boto3.client("s3", endpoint_url=env["CLOUDFLARE_S3_ENDPOINT"], aws_access_key_id=env["CLOUDFLARE_ACCESS_KEY_ID"],
                      aws_secret_access_key=env["CLOUDFLARE_SECRET_ACCESS_KEY"], region_name="auto")
    local = {f.name: f for f in BUILD.iterdir() if f.is_file()}
    if "index.html" not in local or "index.wasm" not in local:
        sys.exit("build/web is empty: run python tools/build_web.py first")
    for name, f in sorted(local.items()):
        s3.upload_file(str(f), BUCKET, name, ExtraArgs={"ContentType": content_type(name)})
        print("uploaded %-28s %8.2f MB" % (name, f.stat().st_size / 1e6))
    remote = [o["Key"] for o in s3.list_objects_v2(Bucket=BUCKET).get("Contents", [])]
    for key in remote:
        if key not in local:
            s3.delete_object(Bucket=BUCKET, Key=key)
            print("removed stale", key)


def deploy_worker(env, origin=None):
    # Publishing assets must not disconnect an already running world.
    if origin is None:
        settings = call(env, "GET", f"/workers/scripts/{WORKER}/settings", missing_ok=True)
        origin = next((b.get("text", "") for b in settings.get("bindings", []) if b.get("name") == "ORIGIN"), "")
    meta = {
        "main_module": "worker.js",
        "compatibility_date": "2025-09-01",
        "bindings": [
            {"type": "r2_bucket", "name": "WEB", "bucket_name": BUCKET},
            {"type": "plain_text", "name": "ORIGIN", "text": origin},
            {"type": "secret_text", "name": "EDGE_SECRET", "text": edge_secret(env)},
        ],
    }
    files = {"metadata": (None, json.dumps(meta), "application/json"), "worker.js": ("worker.js", WORKER_JS.read_bytes(), "application/javascript+module")}
    call(env, "PUT", f"/workers/scripts/{WORKER}", files=files)
    call(env, "POST", f"/workers/scripts/{WORKER}/subdomain", json={"enabled": True, "previews_enabled": False})
    sub = call(env, "GET", "/workers/subdomain")["subdomain"]
    print(f"worker ready: https://{WORKER}.{sub}.workers.dev   (origin: {origin or 'none'})")


def main():
    env = read_env()
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "web":
        ensure_bucket(env)
        upload_web(env)
        deploy_worker(env, sys.argv[2] if len(sys.argv) > 2 else None)
    elif cmd == "origin" and len(sys.argv) > 2:
        deploy_worker(env, sys.argv[2].rstrip("/"))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
