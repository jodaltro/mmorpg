local s=app.open(app.params["source"]);assert(s.width==3072 and s.height==1536 and #s.frames==1 and #s.layers==2,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Maintained lawns"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Maintained lawns.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Limestone promenades"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Limestone promenades.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
