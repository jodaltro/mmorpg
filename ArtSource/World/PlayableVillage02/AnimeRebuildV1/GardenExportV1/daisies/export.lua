local s=app.open(app.params["source"]);assert(s.width==64 and s.height==48 and #s.frames==1 and #s.layers==2,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Blossoms"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Blossoms.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Foliage"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Foliage.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
