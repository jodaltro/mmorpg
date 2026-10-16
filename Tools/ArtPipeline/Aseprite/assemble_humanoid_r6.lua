local f=assert(io.open(assert(app.params.plan),'r'));local plan=json.decode(f:read('*a'));f:close()
assert(not app.fs.isFile(plan.output),'Refusing overwrite')
local old=app.open(plan.reference);local s=Sprite(128,160,ColorMode.RGB)
s.layers[1].name=old.layers[1].name
for i=2,#old.layers do s:newLayer().name=old.layers[i].name end
for i,l in ipairs(old.layers)do s.layers[i].isVisible=l.isVisible end
local pc=app.pixelColor
for i,frame in ipairs(plan.frames)do
 if i>1 then s:newEmptyFrame()end
 if frame.referenceFrame then
  for k,l in ipairs(old.layers)do local cel=l:cel(frame.referenceFrame);if cel then s:newCel(s.layers[k],i,cel.image,cel.position)end end
 else
  local input=Image{fromFile=frame.path};local pixels=Image(128,160,ColorMode.RGB);local border=Image(128,160,ColorMode.RGB)
  for y=0,159 do for x=0,127 do local p=input:getPixel(x,y);if pc.rgbaA(p)>=160 then local function q(n)return math.min(255,math.floor(n/16+.5)*16)end;pixels:drawPixel(x,y,pc.rgba(q(pc.rgbaR(p)),q(pc.rgbaG(p)),q(pc.rgbaB(p)),255))end end end
  for y=1,158 do for x=1,126 do if pc.rgbaA(pixels:getPixel(x,y))==0 and (pc.rgbaA(pixels:getPixel(x-1,y))>0 or pc.rgbaA(pixels:getPixel(x+1,y))>0 or pc.rgbaA(pixels:getPixel(x,y-1))>0 or pc.rgbaA(pixels:getPixel(x,y+1))>0)then border:drawPixel(x,y,pc.rgba(48,40,36,255))end end end
  s:newCel(s.layers[1],i,border,Point(0,0));s:newCel(s.layers[2],i,pixels,Point(0,0))
 end
 s.frames[i].duration=frame.duration
end
for _,c in ipairs(plan.clips)do local t=s:newTag(c.first,c.last);t.name=c.name end
s:saveAs(plan.output);old:close();print('R6 104 real locomotion frames, cardinal cels copied from R5')
