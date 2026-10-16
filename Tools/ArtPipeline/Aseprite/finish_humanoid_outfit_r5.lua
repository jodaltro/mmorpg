-- R5 finishing of Blender renders. Native body reference stays separate and hidden.
local f=assert(io.open(assert(app.params.plan),'r'));local plan=json.decode(f:read('*a'));f:close()
assert(not app.fs.isFile(plan.output),'Refusing existing editable overwrite')
local s=Sprite(128,160,ColorMode.RGB);s.layers[1].name='Dressed render - body and weighted costume'
local outline=s:newLayer();outline.name='Silhouette outline';outline.stackIndex=1
local reference=s:newLayer();reference.name='Approved body reference - comparison only';reference.isVisible=false
local corrections=s:newLayer();corrections.name='Local pixel corrections - reserved'
local guides=s:newLayer();guides.name='Pivot ground and anatomical right hand';guides.isVisible=false
local pc=app.pixelColor
local function finish(path)
 local input=Image{fromFile=path};local result=Image(128,160,ColorMode.RGB)
 for y=0,159 do for x=0,127 do local p=input:getPixel(x,y);if pc.rgbaA(p)>=160 then
  local function q(n)return math.min(255,math.floor(n/16+.5)*16)end
  result:drawPixel(x,y,pc.rgba(q(pc.rgbaR(p)),q(pc.rgbaG(p)),q(pc.rgbaB(p)),255))
 end end end;return result
end
for i,frame in ipairs(plan.frames) do
 if i>1 then s:newEmptyFrame()end
 local pixels=finish(frame.path);local border=Image(128,160,ColorMode.RGB)
 for y=1,158 do for x=1,126 do if pc.rgbaA(pixels:getPixel(x,y))==0 then
  if pc.rgbaA(pixels:getPixel(x-1,y))>0 or pc.rgbaA(pixels:getPixel(x+1,y))>0 or pc.rgbaA(pixels:getPixel(x,y-1))>0 or pc.rgbaA(pixels:getPixel(x,y+1))>0 then border:drawPixel(x,y,pc.rgba(48,40,36,255))end
 end end end
 s:newCel(s.layers[1],i,border,Point(0,0))
 -- Layer indices can change when stacking; identify them by their semantic names.
 local function named(name)for _,l in ipairs(s.layers)do if l.name==name then return l end end end
 local render=named('Dressed render - body and weighted costume')
 -- The outline is bottommost; create its cel and the opaque render independently.
 if s.layers[1]~=outline then error('Outline stacking changed')end
 s:newCel(render,i,pixels,Point(0,0));s:newCel(reference,i,finish(frame.reference),Point(0,0))
 local marks=Image(128,160,ColorMode.RGB)
 local function dot(x,y,color)x=math.floor(x+.5);y=math.floor(y+.5);if x>=0 and x<128 and y>=0 and y<160 then marks:drawPixel(x,y,color)end end
 dot(64,126,pc.rgba(255,255,0,255));dot(64,144,pc.rgba(0,255,255,255));dot(frame.hand[1],frame.hand[2],pc.rgba(255,0,255,255));s:newCel(guides,i,marks,Point(0,0));s.frames[i].duration=frame.duration
end
for _,clip in ipairs(plan.clips)do local t=s:newTag(clip.first,clip.last);t.name=clip.name end
s:saveAs(plan.output);print('R5 editable: 52 poses, layered finishing and hidden reference/guides')
