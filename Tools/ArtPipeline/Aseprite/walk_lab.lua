-- Schematic blocking, not a finished hero animation. Coordinates: top-left pixels.
local output = assert(app.params.output, 'Pass --script-param output=...')
assert(not app.fs.isFile(output), 'Refusing to overwrite existing document')
local s = Sprite(96,96,ColorMode.RGB)
for i=2,4 do s:newEmptyFrame() end
for _,f in ipairs(s.frames) do f.duration=0.14 end
local tag=s:newTag(1,4); tag.name='walk_south_blocking'
local names={'Pernas','Tronco','Bracos','Cabeca','Roupa','Guias contato','Pivo','Maos'}
local colors={outline=Color(30,34,43),boot=Color(71,51,42),blue=Color(49,81,129),steel=Color(126,141,151),skin=Color(216,170,126),hair=Color(87,56,39)}
local function rect(im,x,y,w,h,c)
  for py=y,y+h-1 do for px=x,x+w-1 do im:drawPixel(px,py,c) end end
end
for li,name in ipairs(names) do
  local l
  if li==1 then l=s.layers[1] else l=s:newLayer() end
  l.name=name
  if li>=6 then l.isVisible=false end
  for f=1,4 do
    local im=Image(96,96,ColorMode.RGB)
    local bob=({0,1,0,1})[f]
    -- Anatomical left is image-right in a south-facing view.
    local leftY=({84,80,78,82})[f]
    local rightY=({78,82,84,80})[f]
    if li==1 then
      rect(im,41,71,6,leftY-70,colors.outline); rect(im,49,71,6,rightY-70,colors.outline)
      rect(im,40,leftY,8,4,colors.boot); rect(im,49,rightY,8,4,colors.boot)
    elseif li==2 then
      rect(im,39,54+bob,18,20,colors.outline); rect(im,41,56+bob,14,15,colors.steel)
    elseif li==3 then
      local a=({0,2,3,1})[f]
      rect(im,34,58+bob,6,13+a,colors.blue); rect(im,56,58+bob,6,16-a,colors.blue)
      rect(im,34,71+bob+a,6,4,colors.skin); rect(im,56,74+bob-a,6,4,colors.skin)
    elseif li==4 then
      rect(im,40,38+bob,16,16,colors.hair); rect(im,42,44+bob,12,10,colors.skin)
      rect(im,43,46+bob,2,2,colors.outline); rect(im,51,46+bob,2,2,colors.outline)
    elseif li==5 then
      rect(im,41,65+bob,14,6,colors.blue); rect(im,40,70+bob,16,5,colors.blue)
    elseif li==6 then
      rect(im,30,88,36,1,Color(0,220,220)); rect(im,48,32,1,57,Color(0,100,100))
    elseif li==7 then
      rect(im,46,70,5,1,Color(255,255,0)); rect(im,48,68,1,5,Color(255,255,0))
    else
      local a=({0,2,3,1})[f]
      rect(im,36,73+bob+a,1,1,Color(255,0,255)); rect(im,58,76+bob-a,1,1,Color(0,255,0))
    end
    s:newCel(l,f,im,Point(0,0))
  end
end
s:saveAs(output)
print('Created editable south walk blocking; manual refinement required')
