local G=dofile(assert(app.params.geometry))
local file=assert(io.open(assert(app.params.recipe),'r'));local raw=file:read('*a');file:close()
assert(pcall(G.validate,json.decode(raw)))
local invalid={}
local p=json.decode(raw);p.components[1].profile[2][1]=0;invalid[#invalid+1]=p
p=json.decode(raw);p.components[1].profile[1][2]=99;invalid[#invalid+1]=p
p=json.decode(raw);p.components[1].rows=0;invalid[#invalid+1]=p
p=json.decode(raw);p.components[1].kind='unknown_surface';invalid[#invalid+1]=p
for _,recipe in ipairs(invalid) do assert(not pcall(G.validate,recipe),'Unsafe recipe accepted')end
print('Valid recipe accepted; four unsafe schema/geometry cases rejected')
