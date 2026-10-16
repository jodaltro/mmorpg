-- Assemble supplied drawings without redrawing, recoloring, trimming or inventing motion.
local f=assert(io.open(assert(app.params.plan),'r'));local plan=json.decode(f:read('*a'));f:close()
assert(not app.fs.isFile(plan.output),'Refusing to overwrite an editable document')
local s=Sprite(plan.width,plan.height,ColorMode.RGB)
for i=2,#plan.frames do s:newEmptyFrame() end
local layers={}
for i,name in ipairs(plan.layers) do layers[name]=(i==1 and s.layers[1] or s:newLayer());layers[name].name=name end
local cache={}
for i,frame in ipairs(plan.frames) do
  s.frames[i].duration=frame.seconds
  for _,item in ipairs(frame.parts) do
    if not cache[item.path] then
      local im=Image{fromFile=item.path}
      if im.colorMode~=ColorMode.RGB then
        local opened=app.open(item.path)
        app.command.ChangePixelFormat{format='rgb'}
        im=Image(opened.cels[1].image);opened:close();app.activeSprite=s
      end
      cache[item.path]=im
    end
    local im=Image(plan.width,plan.height,ColorMode.RGB)
    -- Direct RGBA copy avoids changing semitransparent source RGB while compositing onto an empty image.
    for y=0,plan.height-1 do for x=0,plan.width-1 do
      local value=cache[item.path]:getPixel(x+item.x,y+item.y)
      if item.colorMap then
        local pc=app.pixelColor
        local key=pc.rgbaR(value)..','..pc.rgbaG(value)..','..pc.rgbaB(value)
        local target=item.colorMap[key]
        if target then value=pc.rgba(target[1],target[2],target[3],pc.rgbaA(value)) end
      end
      im:drawPixel(x,y,value)
    end end
    s:newCel(layers[item.layer],i,im,Point(0,0))
  end
end
for _,clip in ipairs(plan.clips) do local tag=s:newTag(clip.first,clip.last);tag.name=clip.name end
s:saveAs(plan.output)
print('Assembled '..#plan.frames..' supplied drawings; original geometry preserved')
