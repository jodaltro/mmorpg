local s=app.open(app.params["source"]);assert(s.width==1838 and s.height==1364 and #s.frames==1 and #s.layers==5,"Authored house source contract");local root=app.params["root"]
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["CurtainConnectors"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/CurtainConnectors.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["LeftTower"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/LeftTower.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["RightTower"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/RightTower.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["ArchChamber"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/ArchChamber.png")
for _,l in ipairs(s.layers) do l.isVisible=false end;s.layers["TimberGate"].isVisible=true;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/TimberGate.png")
for _,l in ipairs(s.layers) do l.isVisible=true end;local im=Image(s.spec);im:drawSprite(s,1);im:saveAs(root.."/composite.png");s:close()
