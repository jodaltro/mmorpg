local s=app.open(app.params["source"]);assert(s.width==1436 and s.height==957 and #s.frames==1 and #s.layers==5,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Walls"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Walls.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Roof"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Roof.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Foundation"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Foundation.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Openings"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Openings.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Details"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Details.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
