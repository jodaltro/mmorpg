local root=app.params["root"]
do local m=app.open(root.."/module-door-arched.png");m:saveAs(root.."/module-door-arched.aseprite");m:close() end
do local m=app.open(root.."/module-door-square.png");m:saveAs(root.."/module-door-square.aseprite");m:close() end
do local m=app.open(root.."/module-window-timber.png");m:saveAs(root.."/module-window-timber.aseprite");m:close() end
do local s=Sprite(512,512,ColorMode.RGB);s.layers[1].name="Temporary"
local l=s:newLayer();l.name="00 Ground shadow";local t=app.open(root.."/A-layer0.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="01 Foundation and moisture protection";local t=app.open(root.."/A-layer1.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="02 Stone and timber walls";local t=app.open(root.."/A-layer2.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="03 Timber framing";local t=app.open(root.."/A-layer3.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="04 Door modules";local t=app.open(root.."/A-layer4.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="05 Window modules";local t=app.open(root.."/A-layer5.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="06 Roof planes and eaves";local t=app.open(root.."/A-layer6.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="07 Chimney masonry";local t=app.open(root.."/A-layer7.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="08 Porch and posts";local t=app.open(root.."/A-layer8.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="09 Dormer and trim";local t=app.open(root.."/A-layer9.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
s:deleteLayer(s.layers[1]);s:saveAs(root.."/A.aseprite");s:close() end
do local s=Sprite(512,512,ColorMode.RGB);s.layers[1].name="Temporary"
local l=s:newLayer();l.name="00 Ground shadow";local t=app.open(root.."/B-layer0.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="01 Foundation and moisture protection";local t=app.open(root.."/B-layer1.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="02 Stone and timber walls";local t=app.open(root.."/B-layer2.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="03 Timber framing";local t=app.open(root.."/B-layer3.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="04 Door modules";local t=app.open(root.."/B-layer4.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="05 Window modules";local t=app.open(root.."/B-layer5.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="06 Roof planes and eaves";local t=app.open(root.."/B-layer6.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="07 Chimney masonry";local t=app.open(root.."/B-layer7.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="08 Porch and posts";local t=app.open(root.."/B-layer8.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="09 Dormer and trim";local t=app.open(root.."/B-layer9.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
s:deleteLayer(s.layers[1]);s:saveAs(root.."/B.aseprite");s:close() end
do local s=Sprite(512,512,ColorMode.RGB);s.layers[1].name="Temporary"
local l=s:newLayer();l.name="00 Ground shadow";local t=app.open(root.."/C-layer0.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="01 Foundation and moisture protection";local t=app.open(root.."/C-layer1.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="02 Stone and timber walls";local t=app.open(root.."/C-layer2.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="03 Timber framing";local t=app.open(root.."/C-layer3.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="04 Door modules";local t=app.open(root.."/C-layer4.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="05 Window modules";local t=app.open(root.."/C-layer5.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="06 Roof planes and eaves";local t=app.open(root.."/C-layer6.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="07 Chimney masonry";local t=app.open(root.."/C-layer7.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="08 Porch and posts";local t=app.open(root.."/C-layer8.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
local l=s:newLayer();l.name="09 Dormer and trim";local t=app.open(root.."/C-layer9.png");s:newCel(l,1,t.cels[1].image,Point(0,0));t:close();
s:deleteLayer(s.layers[1]);s:saveAs(root.."/C.aseprite");s:close() end
