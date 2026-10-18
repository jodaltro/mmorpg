local root=app.params["root"]
local s=Sprite(128,192,ColorMode.RGB)
s.layers[1].name="Temporary"
for f=2,4 do s:newEmptyFrame(f) end
local layer=s:newLayer();layer.name="Shallow water"
local t=app.open(root.."/frame-0-Shallow_water.png");s:newCel(layer,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-1-Shallow_water.png");s:newCel(layer,2,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-2-Shallow_water.png");s:newCel(layer,3,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-3-Shallow_water.png");s:newCel(layer,4,t.cels[1].image,Point(0,0));t:close()
local layer=s:newLayer();layer.name="Deep water"
local t=app.open(root.."/frame-0-Deep_water.png");s:newCel(layer,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-1-Deep_water.png");s:newCel(layer,2,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-2-Deep_water.png");s:newCel(layer,3,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-3-Deep_water.png");s:newCel(layer,4,t.cels[1].image,Point(0,0));t:close()
local layer=s:newLayer();layer.name="Reflections"
local t=app.open(root.."/frame-0-Reflections.png");s:newCel(layer,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-1-Reflections.png");s:newCel(layer,2,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-2-Reflections.png");s:newCel(layer,3,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-3-Reflections.png");s:newCel(layer,4,t.cels[1].image,Point(0,0));t:close()
local layer=s:newLayer();layer.name="Shore sediment"
local t=app.open(root.."/frame-0-Shore_sediment.png");s:newCel(layer,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-1-Shore_sediment.png");s:newCel(layer,2,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-2-Shore_sediment.png");s:newCel(layer,3,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-3-Shore_sediment.png");s:newCel(layer,4,t.cels[1].image,Point(0,0));t:close()
local layer=s:newLayer();layer.name="Localized foam"
local t=app.open(root.."/frame-0-Localized_foam.png");s:newCel(layer,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-1-Localized_foam.png");s:newCel(layer,2,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-2-Localized_foam.png");s:newCel(layer,3,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-3-Localized_foam.png");s:newCel(layer,4,t.cels[1].image,Point(0,0));t:close()
local layer=s:newLayer();layer.name="Flow strokes"
local t=app.open(root.."/frame-0-Flow_strokes.png");s:newCel(layer,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-1-Flow_strokes.png");s:newCel(layer,2,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-2-Flow_strokes.png");s:newCel(layer,3,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/frame-3-Flow_strokes.png");s:newCel(layer,4,t.cels[1].image,Point(0,0));t:close()
s:deleteLayer(s.layers[1]);for _,f in ipairs(s.frames) do f.duration=0.18 end
local tag=s:newTag(1,4);tag.name="water_flow";s:saveAs(root.."/water-motifs.aseprite")
for i,f in ipairs(s.frames) do local im=Image(s.spec);im:drawSprite(s,i);im:saveAs(root.."/water-frame-"..(i-1)..".png") end
