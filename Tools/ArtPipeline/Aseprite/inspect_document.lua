-- Read-only metadata inspection for any existing Aseprite document.
-- Does not modify frames, layers, tags, or save the document.
local s = app.activeSprite
assert(s, "Open a source .aseprite or .ase document before running inspection")
local mode = tostring(s.colorMode)
print("ASEPRITE_INSPECT_BEGIN")
print(string.format("canvas=%dx%d", s.width, s.height))
print("colorMode=" .. mode)
print("frames=" .. tostring(#s.frames))
print("layers=" .. tostring(#s.layers))
print("tags=" .. tostring(#s.tags))
local elapsed = 0
for i, frame in ipairs(s.frames) do
  assert(frame.duration > 0, "Frame " .. i .. " has nonpositive duration")
  elapsed = elapsed + frame.duration
end
print(string.format("totalDurationSeconds=%.6f", elapsed))
for i, layer in ipairs(s.layers) do
  print(string.format("layer[%d]=%q visible=%s", i, layer.name, tostring(layer.isVisible)))
end
for i, tag in ipairs(s.tags) do
  print(string.format("tag[%d]=%q", i, tag.name))
end
print("ASEPRITE_INSPECT_END")
