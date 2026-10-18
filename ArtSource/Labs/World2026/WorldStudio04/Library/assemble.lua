local root=app.params["root"]
local s=app.open(app.params["source"])
s:resize(768,192)
for i=#s.layers,1,-1 do s:deleteLayer(s.layers[i]) end
local t=app.open(root.."/Pigment_-_contact_masses.png");local l=s:newLayer();l.name="Pigment - contact masses";s:newCel(l,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/Forms_-_diverse_silhouettes.png");local l=s:newLayer();l.name="Forms - diverse silhouettes";s:newCel(l,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/Edges_-_upper_left_light.png");local l=s:newLayer();l.name="Edges - upper left light";s:newCel(l,1,t.cels[1].image,Point(0,0));t:close()
local t=app.open(root.."/Accents_-_structured_wear.png");local l=s:newLayer();l.name="Accents - structured wear";s:newCel(l,1,t.cels[1].image,Point(0,0));t:close()
local l=s:newLayer();l.name="Paint refinements"
app.activeSprite=s
s:saveAs(root.."/terrain-motifs.aseprite")
s:saveCopyAs(root.."/motifs.png")
s:close()
