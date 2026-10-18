-- Technical correction of isolated opaque white source-border artifact.
-- Exterior stone paint is preserved. Execute only as an explicit source edit.
local p='D:/unity/Mmorpg/ArtSource/Labs/World2026/Nature10/SourceV2/fieldstone.aseprite'
local s=app.open(p)
app.transaction(function()
 for _,cel in ipairs(s.cels) do
  local im=cel.image
  local x=231-cel.position.x
  if x>=0 and x<im.width then
   for y=0,im.height-1 do im:drawPixel(x,y,0) end
  end
 end
end)
s:saveAs(p)
s:close()
