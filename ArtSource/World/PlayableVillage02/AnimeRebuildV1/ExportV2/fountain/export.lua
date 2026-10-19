local s=app.open(app.params["source"]);assert(s.width==162 and s.height==108 and #s.frames==1 and #s.layers==3,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Basin"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Basin.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Water"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Water.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["Spout"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/Spout.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
