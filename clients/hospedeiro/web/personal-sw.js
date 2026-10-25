/* One complete export per cache: HTML, Godot and local core stay together.
 * A new build activates after existing game tabs close. APIs are never cached. */
const CACHE = 'hospedeiro-__BUILD__';
const ASSETS = __ASSETS__;
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS))));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const name of await caches.keys()) if (name.startsWith('hospedeiro-') && name !== CACHE) await caches.delete(name);
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  const key = url.pathname === '/' ? '/index.html' : url.pathname;
  if (!ASSETS.includes(key)) return;
  event.respondWith(caches.open(CACHE).then(async cache => await cache.match(key) || fetch(event.request)));
});
