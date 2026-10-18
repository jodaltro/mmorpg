local input=app.open(app.params["paint"]);local original=input.cels[1].image:clone();local mask=app.open(app.params["mask"]);local ownership=mask.cels[1].image:clone();local s=Sprite(966,966,ColorMode.RGB);s.layers[1].name="Temporary";local layers={};local images={};
do local l=s:newLayer();l.name="Shadow";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Foundation";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="WallsFront";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="WallsSide";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="TimbersFront";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="TimbersSide";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Door";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Windows";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Roof";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Eaves";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Chimney";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
do local l=s:newLayer();l.name="Details";table.insert(layers,l);table.insert(images,Image(966,966,ColorMode.RGB)) end
for y=0,965 do for x=0,965 do local color=original:getPixel(x,y);local alpha=app.pixelColor.rgbaA(color);if alpha>0 then local part=app.pixelColor.rgbaR(ownership:getPixel(x,y));if alpha<100 then part=1 end;images[part]:drawPixel(x,y,color) end end end
for i=1,#layers do s:newCel(layers[i],1,images[i],Point(0,0)) end;s:deleteLayer(s.layers[1]);s:saveAs(app.params["output"]);s:close();mask:close();input:close()
