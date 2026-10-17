local p=app.params['root']
local a=app.open(p..'/surfaces.png')
a.layers[1].name='Surfaces - clusters and transition masks'
local notes=a:newLayer(); notes.name='Paint refinements (editable)'
a:saveAs(p..'/materials-v1.aseprite')
a:close()
local c=app.open(p..'/cliffs.png'); c.layers[1].name='Rock faces - upper left light'
local l=c:newLayer(); l.name='Paint refinements (editable)'
c:saveAs(p..'/cliffs-v1.aseprite'); c:close()
