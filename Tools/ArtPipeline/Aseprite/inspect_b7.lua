local s=assert(app.activeSprite)
assert(s.width==96 and s.height==96 and s.colorMode==ColorMode.RGB)
assert(#s.layers==12)
assert(#s.frames==tonumber(app.params.frames))
for i,l in ipairs(s.layers) do
  assert(#l.cels==#s.frames,l.name)
  assert(l.isVisible==(i<10),'Guide visibility: '..l.name)
  print(l.name..': '..#l.cels..' cels')
end
for _,f in ipairs(s.frames) do assert(math.abs(f.duration-0.12)<0.001) end
print('B7 document reopened: valid RGBA canvas, layers, cels, durations and hidden guides')
