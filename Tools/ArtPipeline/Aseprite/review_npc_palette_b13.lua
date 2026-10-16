-- LOCAL study only: adapt supplied drawings, never generate motion or missing frames.
local source=assert(app.params.source)
local output=assert(app.params.output)
local role=assert(app.params.role)
assert(role=='cleric' or role=='archer')
assert(not app.fs.isFile(output),'Refusing to overwrite editable study')
local s=Sprite(64,64,ColorMode.RGB)
for i=2,16 do s:newEmptyFrame() end
for _,f in ipairs(s.frames) do f.duration=0.125 end -- publisher README recommends ~8 FPS
local original=s.layers[1];original.name='Original - unchanged - local restricted source'
local variant=s:newLayer();variant.name='Palette study - same drawing and alpha'
local pc=app.pixelColor
local function clamp(v)return math.min(255,math.max(0,math.floor(v+0.5)))end
local function adapt(value)
  local r,g,b,a=pc.rgbaR(value),pc.rgbaG(value),pc.rgbaB(value),pc.rgbaA(value)
  if a==0 then return value end
  if role=='cleric' then
    -- Neutral robe fabric to sage/ivory. Gold trim, skin and silhouette retained.
    if math.max(r,g,b)-math.min(r,g,b)<22 and r>72 then
      return pc.rgba(clamp(r*0.79),clamp(g*0.87),clamp(b*0.72),a)
    end
  else
    -- Saturated green hood/cloak to muted forest green, preserving tonal order.
    if g>r*1.12 and g>b*1.12 and g>40 then
      return pc.rgba(clamp(r*0.72+g*0.20),clamp(g*0.76),clamp(b*0.85+g*0.06),a)
    end
  end
  return value
end
local dirs={'down','left','right','up'}
for d,dir in ipairs(dirs) do
  local tag=s:newTag((d-1)*4+1,d*4);tag.name='walk_'..dir
  for f=1,4 do
    local path=app.fs.joinPath(source,role..'_'..dir..'_0'..f..'.png')
    local im=Image{fromFile=path};assert(im.width==64 and im.height==64)
    local changed=Image(im)
    for px in changed:pixels() do px(adapt(px())) end
    local frame=(d-1)*4+f
    s:newCel(original,frame,im,Point(0,0));s:newCel(variant,frame,changed,Point(0,0))
  end
end
original.isVisible=false
s:saveAs(output)
print('Local editable palette study: 16 original drawings retained; 4 walk tags; no invented idle; no resampling')
