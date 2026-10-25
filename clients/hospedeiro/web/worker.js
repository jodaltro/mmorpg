// The public face of Hospedeiro on Cloudflare (free plan).
//   /v1/*  -> the game server running on the owner's machine, reached through a Cloudflare Tunnel (env.ORIGIN)
//   the rest -> the web build, kept in R2 (env.WEB), so the game opens even when the machine is off (then it plays offline)
// Bindings: WEB (R2 bucket), ORIGIN (tunnel address, plain text), EDGE_SECRET (secret text, shared with the server).

const SECURITY = {
	"X-Content-Type-Options": "nosniff",
	"Referrer-Policy": "no-referrer",
	"Permissions-Policy": "geolocation=(), microphone=(), camera=()",
};

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		if (url.pathname.startsWith("/v1/") || url.pathname.startsWith("/nakama/")) {
			return proxy(request, env, url);
		}
		return assets(request, env, url);
	},
};

function json(status, body) {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...SECURITY },
	});
}

async function proxy(request, env, url) {
	if (!env.ORIGIN) {
		return json(503, { version: 1, error: "world_offline" });
	}
	const headers = new Headers(request.headers);
	headers.set("X-Edge-Secret", env.EDGE_SECRET || "");
	headers.set("X-Client-IP", request.headers.get("CF-Connecting-IP") || "");
	headers.delete("Origin"); // the edge is the one browsers talk to; the server only trusts the edge
	headers.delete("Referer");
	headers.delete("X-Adapter-Key");
	const hasBody = request.method !== "GET" && request.method !== "HEAD";
	try {
		const res = await fetch(new URL(url.pathname + url.search, env.ORIGIN), {
			method: request.method,
			headers,
			body: hasBody ? request.body : undefined,
			redirect: "manual",
			signal: request.headers.get("Upgrade")?.toLowerCase() === "websocket" ? undefined : AbortSignal.timeout(9000),
		});
		if (res.status === 101) return res;
		const out = new Headers(res.headers);
		out.set("Cache-Control", "no-store");
		for (const [k, v] of Object.entries(SECURITY)) out.set(k, v);
		return new Response(res.body, { status: res.status, headers: out });
	} catch (err) {
		// The machine that hosts the world is off, asleep or its tunnel is down: the game keeps playing alone.
		return json(503, { version: 1, error: "world_offline" });
	}
}

function accepts(header, name) {
	return new RegExp("(^|[\\s,])" + name + "(\\s*;\\s*q=(?!0(\\.0*)?(,|$)))?\\s*(,|$)").test(header);
}

async function assets(request, env, url) {
	if (request.method !== "GET" && request.method !== "HEAD") {
		return new Response("method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
	}
	let key = decodeURIComponent(url.pathname).replace(/^\/+/, "");
	if (key === "") key = "index.html";
	if (key.split("/").includes("..") || key.length > 200) {
		return new Response("not found", { status: 404 });
	}
	const ae = request.headers.get("Accept-Encoding") || "";
	let encoding = "";
	let object = null;
	for (const [ext, name] of [[".br", "br"], [".gz", "gzip"]]) {
		if (accepts(ae, name)) {
			object = await env.WEB.get(key + ext, { onlyIf: request.headers });
			if (object) {
				encoding = name;
				break;
			}
		}
	}
	if (!object) {
		object = await env.WEB.get(key, { onlyIf: request.headers });
	}
	if (!object) {
		return new Response("not found", { status: 404, headers: SECURITY });
	}
	const headers = new Headers(SECURITY);
	object.writeHttpMetadata(headers);
	headers.set("ETag", object.httpEtag);
	headers.set("Cache-Control", "no-cache");
	headers.append("Vary", "Accept-Encoding");
	if (encoding) headers.set("Content-Encoding", encoding);
	if (!("body" in object)) {
		return new Response(null, { status: 304, headers }); // the browser already has this version
	}
	// The body is stored already compressed: "manual" tells the edge not to compress it again on top of what the header says.
	return new Response(request.method === "HEAD" ? null : object.body, { status: 200, headers, encodeBody: encoding ? "manual" : "automatic" });
}
