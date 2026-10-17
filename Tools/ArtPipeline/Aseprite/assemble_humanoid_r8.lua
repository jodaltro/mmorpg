local f=assert(io.open(assert(app.params.plan),'r'));local plan=json.decode(f:read('*a'));f:close()
assert(not app.fs.isFile(plan.output),'Refusing overwrite')
local old=app.open(plan.reference);local w,h=plan.canvas[1],plan.canvas[2];local s=Sprite(w,h,ColorMode.RGB)
s.layers[1].name=old.layers[1].name
for i=2,#old.layers do s:newLayer().name=old.layers[i].name end
for i,l in ipairs(old.layers)do s.layers[i].isVisible=l.isVisible end
local pc=app.pixelColor
for i,frame in ipairs(plan.frames)do
 if i>1 then s:newEmptyFrame()end
 local input=Image{fromFile=frame.path};assert(input.width==w and input.height==h,'Canvas mismatch');local pixels=Image(w,h,ColorMode.RGB);local border=Image(w,h,ColorMode.RGB)
 for y=0,h-1 do for x=0,w-1 do local p=input:getPixel(x,y);if pc.rgbaA(p)>=160 then local function q(n)return math.min(255,math.floor(n/16+.5)*16)end;pixels:drawPixel(x,y,pc.rgba(q(pc.rgbaR(p)),q(pc.rgbaG(p)),q(pc.rgbaB(p)),255))end end end
 for y=1,h-2 do for x=1,w-2 do if pc.rgbaA(pixels:getPixel(x,y))==0 and (pc.rgbaA(pixels:getPixel(x-1,y))>0 or pc.rgbaA(pixels:getPixel(x+1,y))>0 or pc.rgbaA(pixels:getPixel(x,y-1))>0 or pc.rgbaA(pixels:getPixel(x,y+1))>0)then border:drawPixel(x,y,pc.rgba(48,40,36,255))end end end
 s:newCel(s.layers[1],i,border,Point(0,0));s:newCel(s.layers[2],i,pixels,Point(0,0));s.frames[i].duration=frame.duration
end
for _,c in ipairs(plan.clips)do local t=s:newTag(c.first,c.last);t.name=c.name end
s:saveAs(plan.output);old:close();print('R8 action canvas '..w..'x'..h..', '..#plan.frames..' frames')
