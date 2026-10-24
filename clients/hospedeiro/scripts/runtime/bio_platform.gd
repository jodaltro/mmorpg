class_name BioPlatform
extends RefCounted
## Where the game is running: a browser (and then a phone or a desktop), or the native client. Everything that differs between them
## (touch controls, how big the interface is, where the engine lives) asks this.

## A test or a developer can force it: `?touch=1` in the page address, `-- --touch` on the command line.
static var forced_touch := -1  # -1 detect, 0 off, 1 on
static var _detected := -1


static func is_web() -> bool:
	return OS.has_feature("web")


static func _js(code: String) -> Variant:
	if not is_web():
		return null
	return JavaScriptBridge.eval(code, true)


static func query_param(key: String) -> String:
	var v: Variant = _js("new URLSearchParams(window.location.search).get(%s) || ''" % JSON.stringify(key))
	return str(v) if v != null else ""


## True on a phone or tablet: the first pointer is a finger.
static func is_touch() -> bool:
	if forced_touch >= 0:
		return forced_touch == 1
	if _detected < 0:
		if is_web():
			var q := query_param("touch")
			if q == "1" or q == "0":
				_detected = 1 if q == "1" else 0
			else:
				_detected = 1 if bool(_js("window.matchMedia('(pointer: coarse)').matches")) else 0
		else:
			_detected = 1 if OS.get_cmdline_user_args().has("--touch") else 0
	return _detected == 1


## The engine's address. In the browser the game and the engine are served from the same origin, so there is nothing to configure;
## `?engine=` overrides it and `?engine=off` plays offline.
static func engine_url(fallback: String) -> String:
	if not is_web():
		return fallback
	var q := query_param("engine")
	if q == "off":
		return ""
	if not q.is_empty():
		return q
	var origin: Variant = _js("window.location.origin")
	return str(origin) if origin != null and str(origin).begins_with("http") else fallback


## The size of the page in CSS pixels (what a person sees), not in device pixels.
static func css_size() -> Vector2:
	if is_web():
		var w: Variant = _js("window.innerWidth")
		var h: Variant = _js("window.innerHeight")
		if w != null and h != null:
			return Vector2(float(w), float(h))
	return Vector2(DisplayServer.window_get_size())


## iPhone Safari has no full screen for a page: the button would do nothing, so it is not shown there.
static func fullscreen_available() -> bool:
	if is_web():
		return bool(_js("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)"))
	return true


static func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## The test menu (Esc), the design panels and their keys let anyone become any class or turn invulnerable. They belong to the
## developer: the native client has them, a public web build only with `?debug=1`.
static func debug_enabled() -> bool:
	return not is_web() or query_param("debug") == "1"
