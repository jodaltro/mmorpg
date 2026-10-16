local dir=assert(app.params.dir)
local s=assert(app.activeSprite)
assert(#s.frames==8 and #s.layers==18)
for f=1,8 do
 assert(math.abs(s.frames[f].duration-.03)<.001)
 for _,idx in ipairs({3,6,11,14}) do
  local l=s.layers[idx];local c=assert(l:cel(f));local im=Image(96,96,ColorMode.RGB);im:drawImage(c.image,c.position)
  im:saveAs(dir..'/'..l.name:gsub(' ','-')..'-'..(f-1)..'.png')
 end
end
print('Reopened: 8 frames, 17 body layers, hidden guide='..tostring(not s.layers[18].isVisible))
