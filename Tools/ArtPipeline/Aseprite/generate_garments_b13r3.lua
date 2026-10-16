local function read(path)local f=assert(io.open(path,'r'));local value=json.decode(f:read('*a'));f:close();return value end
local plan=read(assert(app.params.plan));local geometry=dofile(assert(app.params.geometry))
assert(not app.fs.isFile(plan.output),'Refusing to overwrite an existing garment document')
local canvas=plan.canvas or {64,64}
local s=app.open(plan.source);assert(s and s.width==canvas[1] and s.height==canvas[2] and #s.frames==#plan.poses,'Source contract')
local original={}
for _,layer in ipairs(s.layers) do original[layer.name]=layer end
for _,name in ipairs(plan.anatomicalLayers or {'Body','Pants','Boots','Shirt','Head','Hair'}) do assert(original[name],'Missing anatomical layer: '..name)end
local function digest(layer)
  local h=2166136261
  for _,cel in ipairs(layer.cels) do
    h=((h~cel.position.x)*16777619)&0xffffffff;h=((h~cel.position.y)*16777619)&0xffffffff
    for pixel in cel.image:pixels() do h=((h~pixel())*16777619)&0xffffffff end
  end
  return string.format('%08x',h)
end
local before={};for name,layer in pairs(original) do before[name]=digest(layer)end
local back=s:newLayer();back.name='Generated garment - behind body';back.stackIndex=1
local front=s:newLayer();front.name='Generated garment - in front';front.stackIndex=original.Head.stackIndex
local hat=s:newLayer();hat.name='Generated headwear'
local metadata={recipe=plan.recipe,frames={},status='Procedural pattern prototype; artistic approval pending'}
for frame,pose in ipairs(plan.poses) do
  local images,metrics=geometry.render(plan.recipe,pose,s.width,s.height)
  s:newCel(back,frame,images.back,Point(0,0));s:newCel(front,frame,images.front,Point(0,0));s:newCel(hat,frame,images.hat,Point(0,0))
  metadata.frames[frame]={pose=pose,metrics=metrics}
end
metadata.originalLayerHashes={};metadata.originalLayersPreserved=true
for name,layer in pairs(original) do
  local after=digest(layer);assert(after==before[name],'Original layer changed: '..name)
  metadata.originalLayerHashes[name]=after
end
s:saveAs(plan.output)
local f=assert(io.open(plan.metadata,'w'));f:write(json.encode(metadata));f:close()
print('Generated '..#plan.poses..' pose-bound garment frames from parametric surfaces; body motion retained')
