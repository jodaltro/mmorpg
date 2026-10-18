local s=app.open(app.params["source"])
app.command.SpriteSize{ui=false,width=966,height=966,method="nearest"}
app.command.ColorQuantization{ui=false,maxColors=128,withAlpha=true,algorithm="octree"}
app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"}
app.command.ChangePixelFormat{ui=false,format="rgb"}
s:saveAs(app.params["output"])
s:close()
