local s=app.open(app.params["source"]);assert(s.width==414 and s.height==276 and #s.frames==1 and #s.layers==3,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Masonry"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Masonry.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Coping"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Coping.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Foundation"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Foundation.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
