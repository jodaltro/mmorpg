-- Contextual depth masks authored from semantic polygons, never dark-pixel detection.
-- Input is a temporary flattened export. Source artwork is never saved over.
local input = app.activeSprite
assert(input and input.width == 1536 and input.height == 800)
local recipe = json.decode(io.open(app.params.recipe, "r"):read("*a"))
local pixels = input.cels[1].image
local output = app.params.output
local document = Sprite(1536, 800, ColorMode.RGB)
document:deleteLayer(document.layers[1])
for _,item in ipairs(recipe.objects) do
  if item.silhouette then
    local layer = document:newLayer()
    layer.name = item.id
    local image = Image(1536,800,ColorMode.RGB)
    image:clear()
    for y=0,799 do
      local crossings = {}
      local poly = item.silhouette
      local j = #poly
      for i=1,#poly do
        local a,b = poly[i],poly[j]
        if (a[2]>y+.5) ~= (b[2]>y+.5) then
          table.insert(crossings,(b[1]-a[1])*(y+.5-a[2])/(b[2]-a[2])+a[1])
        end
        j=i
      end
      table.sort(crossings)
      for i=1,#crossings,2 do
        for x=math.max(0,math.ceil(crossings[i]-.5)),math.min(1535,math.ceil(crossings[i+1]-.5)-1) do
          image:drawPixel(x,y,pixels:getPixel(x,y))
        end
      end
    end
    document:newCel(layer,1,image,Point(0,0))
    image:saveAs(output.."/"..item.id..".png")
  end
end
document:saveAs(output.."/valdoria-depth.aseprite")
print("Exported semantic silhouette layers; artistic review pending")
