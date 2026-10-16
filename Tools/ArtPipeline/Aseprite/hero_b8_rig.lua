-- B8: source-pixel rig, Aseprite Lua only. New destination required.
local out=assert(app.params.output)
assert(not app.fs.isFile(out),'Refusing overwrite')
local src=app.open('ArtSource/Labs/Aseprite/HeroB7/hero-walk-south-r2.aseprite')
local function source(li)
 local im=Image(96,96,ColorMode.RGB);local c=src.layers[li]:cel((li==1 or li==5) and 3 or 1)
 im:drawImage(c.image,c.position);return im
end
local parts={}
local function part(name,li,y0,y1,a,b,parent,z,limit)
 local im=source(li);local mask=Image(96,96,ColorMode.RGB)
 for y=y0,y1 do for x=0,95 do local p=im:getPixel(x,y);if app.pixelColor.rgbaA(p)>0 then mask:drawPixel(x,y,p) end end end
 parts[#parts+1]={name=name,im=mask,a=a,b=b,parent=parent,z=z,limit=limit,li=li,y0=y0,y1=y1,sourceFrame=(li==1 or li==5) and 3 or 1}
end
-- Anatomical right is screen left. Overlap at joints prevents transparent seams.
part('R thigh',1,69,77,{44,70},{43,76},'Pelvis',1,55)
part('R shin',1,75,82,{43,76},{42,82},'R thigh',2,80)
part('R boot',1,81,88,{42,82},{42,88},'R shin',3,25)
part('L thigh',2,69,78,{51,70},{52,76},'Pelvis',4,55)
part('L shin',2,75,82,{52,76},{53,82},'L thigh',5,80)
part('L boot',2,81,88,{53,82},{53,88},'L shin',6,25)
part('Pelvis',3,0,95,{48,69},{48,73},'Torso',7,10)
part('Torso',4,0,95,{48,52},{48,68},'Root',8,8)
part('L upper arm',5,0,65,{59,55},{63,64},'Torso',9,30)
part('L forearm',5,63,74,{63,64},{63,74},'L upper arm',10,50)
part('L hand',5,73,95,{63,74},{63,76},'L forearm',11,20)
part('R upper arm',6,0,65,{35,55},{32,64},'Torso',12,30)
part('R forearm',6,63,74,{32,64},{32,74},'R upper arm',13,50)
part('R hand',6,73,95,{32,74},{32,76},'R forearm',14,20)
part('Head',7,0,95,{48,46},{48,50},'Torso',15,0)
part('Hair',8,0,95,{48,46},{48,50},'Head',16,0)
part('Clothes',9,0,95,{48,52},{48,68},'Torso',17,8)
local s=Sprite(96,96,ColorMode.RGB);for i=2,8 do s:newEmptyFrame() end
local layers={};for i,p in ipairs(parts) do local l=i==1 and s.layers[1] or s:newLayer();l.name=p.name;layers[i]=l end
local guide=s:newLayer();guide.name='Joints (hidden)';guide.isVisible=false
local function pt(x,y)return {x,y} end
local function render(p,a,b)
 local im=Image(96,96,ColorMode.RGB)
 local u,v=p.b[1]-p.a[1],p.b[2]-p.a[2];local len=math.sqrt(u*u+v*v)
 local du,dv=b[1]-a[1],b[2]-a[2];local dl=math.sqrt(du*du+dv*dv)
 -- Endpoint retarget in longitudinal axis; perpendicular thickness preserved.
 for y=0,95 do for x=0,95 do
  local dx,dy=x-a[1],y-a[2]
  local along=(dx*du+dy*dv)/(dl*dl);local across=(-dx*dv+dy*du)/dl
  local sx=math.floor(p.a[1]+along*u-across*v/len+0.5)
  local sy=math.floor(p.a[2]+along*v+across*u/len+0.5)
  if sx>=0 and sx<96 and sy>=0 and sy<96 then local c=p.im:getPixel(sx,sy);if app.pixelColor.rgbaA(c)>0 then im:drawPixel(x,y,c) end end
 end end
 return im
end
local json=assert(io.open(out..'.rig.json','w'))
json:write('{"status":"experimental-unapproved","ppu":32,"pivot":[48,70],"speed":3.5,"dt":0.03,"parts":[')
for i,p in ipairs(parts) do
 if i>1 then json:write(',') end
 json:write(string.format('{"name":"%s","parent":"%s","depth":%d,"pivot":[%d,%d],"endpoint":[%d,%d],"angleLimit":%d,"mask":"source alpha clipped by layer and y band","palette":"source only","sourceLayer":%d,"sourceFrame":%d,"sourceYRange":[%d,%d]}',p.name,p.parent,p.z,p.a[1],p.a[2],p.b[1],p.b[2],p.limit,p.li,p.sourceFrame,p.y0,p.y1))
end
json:write('],"frames":[')
for f=0,7 do
 local half=math.floor(f/4);local q=f%4;local hip=({0,1,2,1,0,-1,-2,-1})[f+1]
 local absorb=({0,1,0,-1,0,1,0,-1})[f+1]
 local joints={};local support=half==0 and 'L' or 'R'
 local function leg(side)
  local left=side=='L';local x=left and 53 or 42
  local supporting=side==support
  local sole=supporting and (89-3.36*q) or ({77,78,81,85})[q+1]
  local ax=supporting and x or (left and ({53,50,49,52})[q+1] or ({42,45,46,43})[q+1])
  local h=pt((left and 51 or 43)+hip,70+absorb)
  local k=pt(supporting and (x+hip*.5) or (left and 48 or 47),supporting and ((70+absorb+sole-6)*.5+1) or (({71,70,72,74})[q+1]))
  local a=pt(ax,sole-6)
  joints[side..' thigh']={h,k};joints[side..' shin']={k,a};joints[side..' boot']={a,pt(ax,sole)}
 end
 leg('L');leg('R')
 local arm=({-2,-1,0,2,2,1,0,-2})[f+1]
 for _,side in ipairs({'R','L'}) do
  local right=side=='R';local sign=right and 1 or -1
  local sh=pt(right and 35 or 59,55+sign*arm*.25)
  local el=pt((right and 32 or 61)+sign*arm*.4,64+sign*arm*.5)
  local hand=pt((right and 33 or 61)+sign*arm*.5,72+sign*arm)
  joints[side..' upper arm']={sh,el};joints[side..' forearm']={el,hand};joints[side..' hand']={hand,pt(hand[1],hand[2]+2)}
 end
 joints.Pelvis={pt(48+hip,69+absorb),pt(48+hip,73+absorb)}
 joints.Torso={pt(48,52),pt(48+hip*.3,68+absorb*.5)};joints.Clothes=joints.Torso
 joints.Head={pt(48,46),pt(48,50)};joints.Hair=joints.Head
 local gi=Image(96,96,ColorMode.RGB)
 for i,p in ipairs(parts) do
  local j=assert(joints[p.name]);s:newCel(layers[i],f+1,render(p,j[1],j[2]),Point(0,0))
  for _,v in ipairs(j) do gi:drawPixel(math.floor(v[1]+.5),math.floor(v[2]+.5),Color(255,0,255)) end
 end
 s:newCel(guide,f+1,gi,Point(0,0));s.frames[f+1].duration=.03
 if f>0 then json:write(',') end
 json:write(string.format('{"frame":%d,"duration":0.03,"support":"%s","joints":{',f,support))
 for i,p in ipairs(parts) do
  if i>1 then json:write(',') end;local j=joints[p.name]
  json:write(string.format('"%s":[[%.3f,%.3f],[%.3f,%.3f]]',p.name,j[1][1],j[1][2],j[2][1],j[2][2]))
 end
 json:write('}}')
end
json:write(']}');json:close()
local tag=s:newTag(1,8);tag.name='walk_south_rig_candidate';s:saveAs(out)
print('B8 saved: 8 poses, 17 parts, hidden joints. CPU source-pixel retarget.')
