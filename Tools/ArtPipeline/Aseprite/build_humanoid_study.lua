-- Pixel inspection pass for licensed 3D model renders; original model/animation data stays intact.
local file=assert(io.open(assert(app.params.plan),'r'));local plan=json.decode(file:read('*a'));file:close()
assert(not app.fs.isFile(plan.output),'Refusing existing editable overwrite')
local s=Sprite(128,160,ColorMode.RGB)
s.layers[1].name='Native inspection pixels'
local outline=s:newLayer();outline.name='Inspection silhouette outline';outline.stackIndex=1
local pc=app.pixelColor
for i,frame in ipairs(plan.frames) do
  if i>1 then s:newEmptyFrame()end
  local source=Image{fromFile=frame.path};assert(source.width==128 and source.height==160)
  local pixels=Image(128,160,ColorMode.RGB);local border=Image(128,160,ColorMode.RGB)
  for y=0,159 do for x=0,127 do
    local p=source:getPixel(x,y)
    if pc.rgbaA(p)>=160 then
      local function q(n)return math.min(255,math.floor(n/16+.5)*16)end
      pixels:drawPixel(x,y,pc.rgba(q(pc.rgbaR(p)),q(pc.rgbaG(p)),q(pc.rgbaB(p)),255))
    end
  end end
  for y=1,158 do for x=1,126 do
    if pc.rgbaA(pixels:getPixel(x,y))==0 then
      if pc.rgbaA(pixels:getPixel(x-1,y))>0 or pc.rgbaA(pixels:getPixel(x+1,y))>0 or pc.rgbaA(pixels:getPixel(x,y-1))>0 or pc.rgbaA(pixels:getPixel(x,y+1))>0 then
        border:drawPixel(x,y,pc.rgba(48,40,36,255))
      end
    end
  end end
  s:newCel(s.layers[2],i,pixels,Point(0,0));s:newCel(outline,i,border,Point(0,0))
  s.frames[i].duration=frame.duration
end
for _,clip in ipairs(plan.clips) do local tag=s:newTag(clip.first,clip.last);tag.name=clip.name end
s:saveAs(plan.output)
print('Native RGBA inspection document: '..#plan.frames..' frames, no rescaling or generated body motion')
