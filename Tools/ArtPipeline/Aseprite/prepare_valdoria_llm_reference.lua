-- Clean the generated concept sheet in Aseprite: remove the fake checkerboard,
-- snap color to a restrained 16-step RGB palette, retain native pixel detail,
-- and create an editable source with a separate cleanup layer.
local input=assert(app.params.input,'Pass --script-param input=...')
local output=assert(app.params.output,'Pass --script-param output=...')
assert(not app.fs.isFile(output),'Refusing to overwrite source')
local raw=Image{fromFile=input}
local w,h=raw.width,raw.height
local pc=app.pixelColor
local function channels(x,y)
  local p=raw:getPixel(x,y)
  return pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p),pc.rgbaA(p)
end
local function isBackdrop(x,y)
  local r,g,b,a=channels(x,y)
  local hi=math.max(r,g,b); local lo=math.min(r,g,b)
  return a>0 and hi>=184 and (hi-lo)<=18
end
local visited={}; local queue={}; local head=1
local function push(x,y)
  if x<0 or y<0 or x>=w or y>=h then return end
  local id=y*w+x
  if visited[id] then return end
  if isBackdrop(x,y) then visited[id]=true; queue[#queue+1]=id end
end
for x=0,w-1 do push(x,0);push(x,h-1) end
for y=1,h-2 do push(0,y);push(w-1,y) end
while head<=#queue do
  local id=queue[head];head=head+1
  local y=math.floor(id/w); local x=id-y*w
  push(x-1,y);push(x+1,y);push(x,y-1);push(x,y+1)
end
local cleaned=Image(w,h,ColorMode.RGB)
local kept=0; local removed=0
for y=0,h-1 do for x=0,w-1 do
  local r,g,b,a=channels(x,y); local id=y*w+x
  if visited[id] or a==0 then removed=removed+1
  else
    local function q(v) return math.min(255,math.floor(v/8+.5)*8) end
    cleaned:drawPixel(x,y,pc.rgba(q(r),q(g),q(b),255));kept=kept+1
  end
end end
local s=Sprite(w,h,ColorMode.RGB)
s.layers[1].name='LLM concept — cleaned RGB pixels'
s:newCel(s.layers[1],1,cleaned,Point(0,0))
local cleanup=s:newLayer();cleanup.name='Aseprite manual pixel cleanup';cleanup.isVisible=true
local guide=s:newLayer();guide.name='Guides (hidden)';guide.isVisible=false
s:saveAs(output)
raw=nil
print('Aseprite cleaned '..w..'x'..h..' concept atlas; kept='..kept..' transparent='..removed..'; separate editable cleanup layer added')
