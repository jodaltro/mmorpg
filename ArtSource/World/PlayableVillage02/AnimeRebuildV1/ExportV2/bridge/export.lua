local s=app.open(app.params["source"]);assert(s.width==796 and s.height==1195 and #s.frames==1 and #s.layers==4,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Deck"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Deck.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["LeftRail"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/LeftRail.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["RightRail"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/RightRail.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Abutments"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Abutments.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
