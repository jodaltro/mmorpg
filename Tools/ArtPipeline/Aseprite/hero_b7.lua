-- Original pixel construction for B7. All contours use integer pixel coordinates.
-- Run master first; review its export before authoring the four walk key poses.
local out=assert(app.params.output)
assert(not app.fs.isFile(out),'Refusing to overwrite artwork')
local mode=app.params.mode or 'master'
local count=mode=='walk' and 4 or 1
local s=Sprite(96,96,ColorMode.RGB)
for f=2,count do s:newEmptyFrame() end
local C={ink=Color(24,28,39),edge=Color(40,43,53),navy=Color(30,49,76),blue=Color(42,69,102),mid=Color(57,90,126),light=Color(81,118,150),seam=Color(118,147,165),
  steel0=Color(58,70,81),steel1=Color(98,117,129),steel2=Color(155,173,179),steel3=Color(203,211,200),
  hair0=Color(49,32,31),hair1=Color(82,49,34),hair2=Color(121,74,43),hair3=Color(160,105,57),
  skin0=Color(145,83,57),skin1=Color(199,135,87),skin2=Color(234,179,119),skin3=Color(249,208,152),
  leather0=Color(55,37,33),leather1=Color(94,59,40),leather2=Color(140,91,52),leather3=Color(180,128,72),
  pants0=Color(29,34,46),pants1=Color(46,53,66),pants2=Color(67,73,82),gold=Color(192,152,82)}
local im
local function dot(x,y,c) if x>=0 and y>=0 and x<96 and y<96 then im:drawPixel(x,y,C[c] or c) end end
local function line(x0,y0,x1,y1,c)
  local dx,dy=math.abs(x1-x0),-math.abs(y1-y0)
  local sx,sy=x0<x1 and 1 or -1,y0<y1 and 1 or -1
  local e=dx+dy
  while true do dot(x0,y0,c); if x0==x1 and y0==y1 then break end
    local e2=2*e; if e2>=dy then e=e+dy;x0=x0+sx end; if e2<=dx then e=e+dx;y0=y0+sy end
  end
end
local function poly(p,c)
  local minY,maxY=95,0
  for _,v in ipairs(p) do minY=math.min(minY,v[2]);maxY=math.max(maxY,v[2]) end
  for y=minY,maxY do
    for x=0,95 do
      local inside=false;local j=#p
      for i=1,#p do
        local a,b=p[i],p[j]
        if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
        j=i
      end
      if inside then dot(x,y,c) end
    end
  end
  for i=1,#p do local a,b=p[i],p[i%#p+1];line(a[1],a[2],b[1],b[2],c) end
end
local layers={'Perna direita','Perna esquerda','Quadril','Tronco','Braco esquerdo','Braco direito','Cabeca','Cabelo','Detalhes roupa','Guias pivo','Guias contato','Marcadores maos'}
local metadata={}
local function leg(p)
  -- p: hip, knee, ankle; boot polygon has an individual toe profile, never rotated.
  local h,k,a=p.h,p.k,p.a
  poly({{h-3,69},{h+3,70},{k+3,76},{a+2,p.y},{a-3,p.y},{k-3,77}},'ink')
  poly({{h-2,71},{h+2,71},{k+2,76},{a+1,p.y-1},{a-2,p.y-1},{k-2,76}},'pants1')
  line(h-1,72,k-1,76,'pants2');line(k-1,77,a-1,p.y-2,'pants0')
  poly(p.boot,'ink');poly(p.fill,'leather1')
  line(a-2,p.y,a+2,p.y,'leather2');line(a-2,p.y+1,a-2,p.y+3,'leather2')
  if p.shine then line(p.shine[1],p.shine[2],p.shine[3],p.shine[4],'leather2') end
end
-- Authored silhouettes: hips, bent knees, ankle and toe contours are per pose.
local legs={
  master={
    {h=43,k=42,a=41,y=81,boot={{38,80},{44,80},{44,85},{46,87},{45,88},{37,88},{37,86}},fill={{39,81},{43,81},{43,85},{45,87},{38,87},{38,85}},shine={39,86,43,86}},
    {h=52,k=53,a=54,y=81,boot={{51,80},{57,80},{58,86},{59,87},{58,88},{50,88},{49,87},{51,84}},fill={{52,81},{56,81},{56,85},{58,87},{51,87},{52,84}},shine={53,86,56,86}}},
  walk={
    {
      {h=43,k=43,a=42,y=78,boot={{39,77},{45,77},{45,81},{46,82},{44,84},{39,83},{38,81}},fill={{40,78},{44,78},{44,81},{45,82},{40,82}},shine={40,80,42,80}},
      {h=51,k=52,a=53,y=82,boot={{50,81},{56,81},{56,85},{59,86},{59,88},{50,88},{49,86}},fill={{51,82},{55,82},{55,85},{58,86},{58,87},{50,87}},shine={51,86,55,86}}},
    {
      {h=44,k=47,a=47,y=78,boot={{44,77},{49,77},{50,80},{49,83},{46,83},{44,81}},fill={{45,78},{48,78},{49,80},{48,82},{46,81}},shine={46,79,48,79}},
      {h=51,k=52,a=51,y=82,boot={{48,81},{54,81},{54,85},{56,86},{55,88},{47,88},{47,86}},fill={{49,82},{53,82},{53,85},{55,86},{54,87},{48,87}},shine={49,86,52,86}}},
    {
      {h=44,k=43,a=42,y=82,boot={{39,81},{45,81},{45,85},{46,87},{45,88},{36,88},{36,86},{39,84}},fill={{40,82},{44,82},{44,85},{45,87},{37,87},{39,85}},shine={38,86,42,86}},
      {h=52,k=52,a=53,y=78,boot={{50,77},{56,77},{57,81},{56,83},{51,84},{50,82}},fill={{51,78},{55,78},{56,81},{55,82},{51,82}},shine={52,80,54,80}}},
    {
      {h=44,k=43,a=44,y=82,boot={{41,81},{47,81},{48,85},{48,88},{40,88},{39,86},{41,84}},fill={{42,82},{46,82},{46,85},{47,87},{40,87},{42,85}},shine={42,86,45,86}},
      {h=51,k=48,a=48,y=78,boot={{45,77},{50,77},{52,80},{50,83},{47,83},{46,81}},fill={{46,78},{49,78},{50,80},{49,82},{47,81}},shine={47,79,49,79}}}
  }
}
local armSwing=mode=='walk' and {{2,-2},{0,0},{-2,2},{0,0}} or {{0,0}}
local function shifted(points,dx,dy)
  local result={};for _,p in ipairs(points) do result[#result+1]={p[1]+dx,p[2]+dy} end;return result
end
-- Revision 2: bent forearms, lateral palm travel and a retracting support boot.
local gestures=mode=='walk' and {
  {{e=32,h=32,y=74},{e=61,h=60,y=69}},
  {{e=33,h=35,y=72},{e=62,h=61,y=72}},
  {{e=33,h=35,y=69},{e=63,h=63,y=74}},
  {{e=32,h=34,y=72},{e=61,h=60,y=72}}
} or {{{e=33,h=34,y=72},{e=62,h=61,y=72}}}
for f=1,count do
  s.frames[f].duration=0.12
  local poses=mode=='walk' and legs.walk[f] or legs.master
  local swing=armSwing[f]
  local gesture=gestures[f]
  local hip=mode=='walk' and ({0,1,0,-1})[f] or 0
  if mode=='walk' and (f==2 or f==4) then
    local p=poses[f==2 and 2 or 1]
    p.boot=shifted(p.boot,0,-3);p.fill=shifted(p.fill,0,-3);p.y=p.y-3
    p.shine={p.shine[1],p.shine[2]-3,p.shine[3],p.shine[4]-3}
  end
  metadata[f]={rightHand={gesture[1].h,gesture[1].y},leftHand={gesture[2].h,gesture[2].y},pivot={48,70},feet={48,88},equipmentAngle=-135,equipmentDepth=1,duration=0.12}
  for li,name in ipairs(layers) do
    local l
    if f==1 then if li==1 then l=s.layers[1] else l=s:newLayer() end;l.name=name;l.isVisible=li<10
    else l=s.layers[li] end
    im=Image(96,96,ColorMode.RGB)
    if li==1 then leg(poses[1])
    elseif li==2 then leg(poses[2])
    elseif li==3 then
      poly(shifted({{39,66},{56,66},{57,73},{53,76},{49,74},{47,72},{44,75},{39,74},{38,71}},hip,0),'ink')
      poly(shifted({{40,67},{54,67},{55,72},{52,74},{48,71},{44,73},{40,72}},hip,0),'navy')
      line(40+hip,69,45+hip,70,'mid');line(50+hip,70,54+hip,69,'blue')
    elseif li==4 then
      poly({{42,49},{52,49},{58,53},{56,61},{54,67},{55,70},{50,72},{46,70},{40,71},{39,66},{38,56}},'ink')
      poly({{42,51},{52,51},{56,54},{54,62},{53,66},{40,67},{40,60},{39,56}},'blue')
      poly({{42,52},{46,54},{46,62},{43,65},{40,64},{40,58}},'mid')
      poly({{52,53},{55,54},{53,65},{49,66},{49,58}},'navy')
      poly({{43,50},{46,52},{48,53},{50,50},{52,51},{50,55},{47,57},{43,54}},'ink')
      line(43,51,47,55,'seam');line(47,55,51,51,'mid')
      line(43,58,42,62,'light');line(50,59,51,63,'blue')
    elseif li==5 or li==6 then
      local left=li==5;local x=left and 57 or 33;local a=left and swing[2] or swing[1]
      local g=gesture[left and 2 or 1];local e,h,y=g.e,g.h,g.y
      -- Shoulder, elbow taper and rounded glove stay on independent editable cels.
      poly({{x+1,52},{x+5,54},{x+6,59},{e+3,64},{h+3,y-1},{h+2,y+3},{h-2,y+3},{h-4,y},{e-3,64},{x-2,59}},'ink')
      poly({{x,55},{x+4,55},{x+4,59},{e+2,63},{e,65},{e-2,63},{x-1,59}},'blue')
      line(x,57,e-1,62,'light');line(x+4,59,e+2,63,'navy')
      poly({{e-2,64},{e+2,64},{h+2,y-3},{h-1,y-1},{h-3,y-3}},'leather0')
      line(e-2,65,e+1,65,'leather3')
      poly({{h-2,y-1},{h+1,y-2},{h+2,y},{h+1,y+2},{h-2,y+2},{h-3,y}},'leather1')
      line(h-2,y-1,h,y-1,'leather2');dot(h-1,y,'leather3')
      -- Small steel shoulder plates, stepped outline with light from upper-left.
      poly({{x-1,52},{x+3,51},{x+6,54},{x+5,58},{x+1,59},{x-2,57}},'steel0')
      poly({{x,52},{x+3,52},{x+5,54},{x+3,57},{x,57},{x-1,55}},'steel1')
      line(x,52,x+3,52,'steel3');line(x-1,53,x-1,55,'steel2');line(x,56,x+3,56,'steel2')
    elseif li==7 then
      poly({{43,40},{52,40},{55,44},{54,48},{51,51},{46,52},{42,49},{40,45}},'hair0')
      poly({{43,41},{51,41},{53,44},{52,48},{49,50},{46,50},{43,48},{42,45}},'skin1')
      poly({{43,43},{50,42},{51,45},{49,46},{48,48},{44,47}},'skin2')
      line(43,44,45,44,'skin3');line(47,44,49,44,'skin3')
      line(43,45,45,45,'ink');line(49,45,51,45,'ink')
      dot(44,45,'steel3');dot(49,45,'steel3');dot(47,47,'skin3');line(46,49,49,49,'skin0')
      dot(41,45,'skin1');dot(54,45,'skin0')
    elseif li==8 then
      poly({{41,39},{43,36},{47,35},{51,36},{54,38},{55,41},{54,45},{52,46},{52,41},{49,42},{48,40},{45,42},{43,42},{43,46},{41,45},{40,42}},'hair0')
      poly({{42,39},{45,37},{49,36},{52,38},{53,40},{50,41},{48,39},{45,41},{42,42}},'hair1')
      poly({{43,38},{46,36},{49,37},{47,39},{44,40},{42,40}},'hair2')
      line(44,38,46,37,'hair3');line(49,38,51,39,'hair2');line(41,41,41,43,'hair1')
    elseif li==9 then
      -- Diagonal baldric and belt; no weapon pixels.
      poly({{53,53},{55,54},{44,67},{41,67}},'leather0')
      line(53,54,43,66,'leather2');line(53,55,44,66,'leather1')
      poly({{40,65},{46,66},{53,65},{54,68},{47,69},{40,68}},'leather0')
      line(41,66,45,67,'leather2');line(49,67,53,66,'leather1')
      poly({{46,66},{49,66},{49,69},{46,69}},'gold');line(47,67,48,67,'leather0')
      poly({{54,66},{57,67},{57,71},{54,72},{53,69}},'leather0');line(54,67,56,68,'leather2')
    elseif li==10 then
      line(46,70,50,70,Color(255,225,0));line(48,68,48,72,Color(255,225,0))
    elseif li==11 then
      line(30,88,66,88,Color(0,190,190))
    else
      local m=metadata[f];dot(m.rightHand[1],m.rightHand[2],Color(255,0,255));dot(m.leftHand[1],m.leftHand[2],Color(0,255,0))
    end
    s:newCel(l,f,im,Point(0,0))
  end
end
local tag=s:newTag(1,count);tag.name=mode=='walk' and 'walk_south_candidate' or 'idle_south_candidate'
local palette=Palette(28);local idx=0
for _,name in ipairs({'ink','edge','navy','blue','mid','light','seam','steel0','steel1','steel2','steel3','hair0','hair1','hair2','hair3','skin0','skin1','skin2','skin3','leather0','leather1','leather2','leather3','pants0','pants1','pants2','gold'}) do palette:setColor(idx,C[name]);idx=idx+1 end
s:setPalette(palette)
s:saveAs(out)
local file=assert(io.open(out..'.anchors.json','w'))
file:write('{"status":"experimental-unapproved","coordinates":"top-left pixels","ppu":32,"frames":[')
for i,m in ipairs(metadata) do
  if i>1 then file:write(',') end
  file:write(string.format('{"rightHand":[%d,%d],"leftHand":[%d,%d],"pivot":[48,70],"feet":[48,88],"equipmentAngle":-135,"equipmentDepth":1,"duration":0.12}',m.rightHand[1],m.rightHand[2],m.leftHand[1],m.leftHand[2]))
end
file:write(']}\n');file:close()
print('B7 '..mode..': '..#s.frames..' frames, '..#s.layers..' layers. Experimental, no production approval.')
