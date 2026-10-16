local s = app.activeSprite
assert(s and s.width == 96 and s.height == 96)
assert(#s.frames == 4 and #s.layers == 8)
for _, f in ipairs(s.frames) do assert(f.duration > 0) end
for _, l in ipairs(s.layers) do print(l.name .. ': ' .. #l.cels .. ' cels') end
print('Validated 96x96 RGBA document: 4 frames, 8 layers')
