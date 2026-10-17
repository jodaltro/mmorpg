-- Valdoria R10 pixel-art environment atlas.
-- Hand-authored clusters in Aseprite Lua, guided by the generated concept board.
-- The atlas is layered and all elements are native-resolution pixel art.
local output = assert(app.params.output, 'Pass --script-param output=...')
assert(not app.fs.isFile(output), 'Refusing to overwrite existing document')
local s = Sprite(1536, 1024, ColorMode.RGB)
s.filename = output
local function C(r,g,b,a) return Color(r,g,b,a or 255) end
local P = {
  ink=C(38,43,39), deep=C(49,61,48), grass0=C(61,91,54), grass1=C(78,111,61), grass2=C(100,131,68), grass3=C(133,151,77), grass4=C(170,168,91),
  dirt0=C(105,76,49), dirt1=C(137,96,54), dirt2=C(166,119,64), dirt3=C(194,150,87), dirt4=C(215,177,116),
  stone0=C(65,77,80), stone1=C(91,102,101), stone2=C(125,133,123), stone3=C(159,161,143), stone4=C(195,188,160),
  wood0=C(59,43,35), wood1=C(91,60,39), wood2=C(128,82,46), wood3=C(166,111,58), wood4=C(207,154,79),
  leaf0=C(37,76,48), leaf1=C(47,101,57), leaf2=C(65,128,64), leaf3=C(91,151,68), leaf4=C(123,172,82), leaf5=C(167,190,101),
  water0=C(36,79,94), water1=C(43,112,130), water2=C(56,145,157), water3=C(96,181,180), water4=C(171,207,190),
  blue=C(73,123,155), cream=C(221,205,164), flower=C(216,155,105), gold=C(225,190,112),
}
local function px(im,x,y,c) if x>=0 and y>=0 and x<im.width and y<im.height then im:drawPixel(x,y,c) end end
local function rect(im,x,y,w,h,c)
  for yy=math.max(0,y),math.min(im.height-1,y+h-1) do for xx=math.max(0,x),math.min(im.width-1,x+w-1) do px(im,xx,yy,c) end end
end
local function line(im,x1,y1,x2,y2,c,t)
  t=t or 1; local dx=math.abs(x2-x1); local sx=x1<x2 and 1 or -1; local dy=-math.abs(y2-y1); local sy=y1<y2 and 1 or -1; local err=dx+dy
  while true do rect(im,x1-math.floor(t/2),y1-math.floor(t/2),t,t,c); if x1==x2 and y1==y2 then break end; local e=2*err; if e>=dy then err=err+dy; x1=x1+sx end; if e<=dx then err=err+dx; y1=y1+sy end end
end
local function ellipse(im,cx,cy,rx,ry,c)
  for y=-ry,ry do for x=-rx,rx do if x*x*ry*ry+y*y*rx*rx<=rx*rx*ry*ry then px(im,cx+x,cy+y,c) end end end
end
local function poly(im,pts,c)
  local miny,maxy=im.height,0
  for _,p in ipairs(pts) do miny=math.min(miny,p[2]); maxy=math.max(maxy,p[2]) end
  for y=math.max(0,miny),math.min(im.height-1,maxy) do
    local xs={}
    for i=1,#pts do local a=pts[i]; local b=pts[i%#pts+1]; if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=math.floor(a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])) end end
    table.sort(xs); for i=1,#xs,2 do if xs[i+1] then rect(im,xs[i],y,xs[i+1]-xs[i]+1,1,c) end end
  end
end
local function rng(seed) local n=seed; return function(a,b) n=(n*1664525+1013904223)%4294967296; return a+(n%(b-a+1)) end end
local function newArt(name,w,h,x,y,draw)
  local layer=s:newLayer(); layer.name=name
  local im=Image(w,h,ColorMode.RGB); draw(im)
  s:newCel(layer,1,im,Point(x,y))
end

-- 16x16 world-unit ground tile: subtle, seamless clusters rather than a flat rectangle.
newArt('Ground - Valdoria meadow tile 512',512,512,0,0,function(im)
  local r=rng(620913)
  rect(im,0,0,512,512,P.grass0)
  for i=1,440 do local x=r(0,511); local y=r(0,511); local w=r(5,22); local h=r(3,13); ellipse(im,x,y,w,h,({P.grass1,P.grass1,P.grass2,P.grass0})[r(1,4)]) end
  for i=1,360 do local x=r(0,511); local y=r(0,511); local c=({P.grass2,P.grass3,P.dirt0,P.dirt1})[r(1,4)]; rect(im,x,y,r(1,3),r(1,2),c) end
  for i=1,70 do local x=r(0,511); local y=r(0,511); line(im,x,y,x+r(-5,5),y+r(-4,0),P.grass3,2); px(im,x+r(2,7),y-2,P.grass4) end
end)

-- Broad worn village road with stone setts and grassy broken edges.
newArt('Road - winding cobble earth',512,512,512,0,function(im)
  local r=rng(89214)
  -- Irregular diagonal lane, broad enough to read at the human scale.
  local pts={{174,0},{342,0},{332,84},{298,146},{318,224},{384,288},{376,364},{317,430},{284,512},{104,512},{137,423},{203,360},{224,299},{180,232},{151,157},{178,84}}
  poly(im,pts,P.dirt0)
  for i=1,90 do local x=r(0,511); local y=r(0,511); local center=212+math.floor(y*.26)+math.floor(28*math.sin(y/55)); local half=72+r(0,18); if math.abs(x-center)<half then ellipse(im,x,y,r(5,19),r(3,10),({P.dirt1,P.dirt2,P.dirt2,P.dirt3})[r(1,4)]) end end
  -- Embedded stones, each has a shadow, midtone, and sunlit upper edge.
  for i=1,105 do local y=r(4,507); local center=212+math.floor(y*.26)+math.floor(28*math.sin(y/55)); local x=center+r(-62,62); local w=r(5,17); local h=r(3,9); ellipse(im,x+1,y+2,w,h,P.dirt0); ellipse(im,x,y,w,h,({P.stone0,P.stone1,P.dirt3,P.dirt4})[r(1,4)]); line(im,x-w+2,y-h+1,x+w-2,y-h+1,P.stone3,1) end
  for i=1,110 do local y=r(0,511); local center=212+math.floor(y*.26)+math.floor(28*math.sin(y/55)); local x=center+(r(0,1)==0 and -1 or 1)*(75+r(0,28)); for k=0,2 do line(im,x+k*3,y+k*2,x+r(-7,7)+k*3,y+r(4,12)+k*2,({P.grass1,P.grass2,P.grass3})[k+1],1) end end
end)

-- Curving stream; transparent beyond the banks for free composition.
newArt('Water - forest stream',512,256,1024,0,function(im)
  local function cx(y) return 238+math.floor(70*math.sin(y/46))+math.floor(24*math.sin(y/17)) end
  for y=0,255 do local c=cx(y); local half=45+math.floor(5*math.sin(y/20)); rect(im,c-half-6,y,2,1,P.grass2); rect(im,c+half+4,y,3,1,P.grass1); rect(im,c-half,y,half*2,1,P.water0); rect(im,c-half+4,y,half*2-8,1,P.water1) end
  local r=rng(7324)
  for i=1,240 do local y=r(0,255); local c=cx(y); local x=c+r(-40,40); local len=r(3,16); line(im,x,y,x+len,y,P.water2,1); if r(0,3)==0 then px(im,x+1,y-1,P.water4) end end
  for i=1,85 do local y=r(0,255); local c=cx(y); local x=c+(r(0,1)==0 and -1 or 1)*(48+r(0,13)); ellipse(im,x,y,r(2,7),r(2,5),({P.stone0,P.stone1,P.stone2})[r(1,3)]); px(im,x-2,y-2,P.stone3) end
  for i=1,35 do local y=r(0,255); local c=cx(y); local x=c+(r(0,1)==0 and -1 or 1)*r(50,67); line(im,x,y,x+r(-8,8),y-r(8,20),P.grass2,2); px(im,x+r(-2,2),y-r(7,17),P.grass4) end
end)

-- Stone and timber cottage body; a tall readable door anchors the new character scale.
newArt('Cottage - timber stone walls and door',320,256,0,512,function(im)
  poly(im,{{25,69},{161,19},{295,69},{295,224},{25,224}},P.ink)
  poly(im,{{31,72},{160,27},{289,72},{289,216},{31,216}},P.stone1)
  -- Individual block joints with cool shadow and warm upper-left facets.
  local r=rng(418)
  for row=0,7 do local y=80+row*17; local off=(row%2)*18; for x=34+off,280,43 do local shade=({P.stone0,P.stone2,P.stone1})[r(1,3)]; rect(im,x,y,35,13,shade); line(im,x+1,y+1,x+28,y+1,P.stone3,1); rect(im,x+5,y+5,3,2,P.stone4) end end
  -- Exposed dark timber frame and lintel.
  line(im,37,76,37,211,P.wood0,9); line(im,283,76,283,211,P.wood0,9); line(im,43,78,160,36,P.wood0,9); line(im,160,36,277,78,P.wood0,9)
  line(im,44,82,44,207,P.wood3,2); line(im,276,82,276,207,P.wood3,2)
  -- Large three-unit door with threshold, planks, iron straps, handle and warm interior.
  rect(im,113,115,93,103,P.ink); rect(im,119,120,81,98,P.wood0); rect(im,124,125,71,89,P.wood2)
  for x=132,188,14 do line(im,x,128,x,208,P.wood1,3); line(im,x+2,128,x+2,205,P.wood3,1) end
  rect(im,118,117,84,7,P.wood3); rect(im,119,133,81,4,P.wood1); rect(im,119,192,81,4,P.wood1); rect(im,118,213,86,8,P.stone0); rect(im,114,221,94,9,P.stone3)
  ellipse(im,186,171,3,4,P.gold); px(im,185,169,P.cream)
  -- Small bright window and flower box.
  rect(im,56,108,42,42,P.ink); rect(im,61,113,32,31,P.wood3); rect(im,65,117,24,23,P.blue); line(im,77,117,77,140,P.wood0,3); line(im,65,128,89,128,P.wood0,3); rect(im,55,149,44,6,P.wood1)
  for i=1,10 do local x=58+i*4; line(im,x,155,x-2,163,P.grass2,2); px(im,x-3,154+((i%3)*2),i%2==0 and P.flower or P.gold) end
  -- Foundation blocks and two steps.
  rect(im,22,221,278,18,P.stone0); for x=25,290,34 do rect(im,x,223,29,13,P.stone2); line(im,x+2,224,x+24,224,P.stone4,1) end
  rect(im,105,239,112,8,P.stone1); rect(im,115,247,92,7,P.stone2)
end)

-- Separate overhanging shingle roof; kept as its own occlusion layer.
newArt('Cottage - layered walnut shingle roof',384,192,320,512,function(im)
  poly(im,{{20,87},{188,11},{362,89},{340,151},{184,89},{48,147}},P.ink)
  poly(im,{{30,84},{188,20},{352,86},{330,139},{184,79},{56,137}},P.wood1)
  -- Alternating shingle rows with warm edges and cool shadow underneath.
  for row=0,10 do local y=38+row*9; local left=40+row*3; local right=338-row*1; local offset=(row%2)*13; for x=left+offset,right,26 do line(im,x,y,x+20,y-7,P.wood3,4); line(im,x+2,y-1,x+18,y-7,P.wood4,1); line(im,x+20,y-7,x+25,y-5,P.wood0,2) end end
  -- Ridge cap, fascia, and lichen flecks.
  line(im,187,18,351,84,P.wood4,5); line(im,35,86,184,23,P.wood4,4); line(im,55,139,184,83,P.wood3,5); line(im,184,83,331,143,P.wood0,7); line(im,188,82,333,138,P.wood4,2)
  local r=rng(613); for i=1,35 do local x=r(45,328); local y=r(51,126); px(im,x,y,({P.grass2,P.grass3,P.wood4})[r(1,3)]) end
  -- Dormer window silhouette.
  poly(im,{{127,69},{190,42},{249,69},{242,105},{132,105}},P.ink); poly(im,{{136,70},{190,48},{239,70},{233,99},{140,99}},P.wood2)
  rect(im,157,70,64,26,P.blue); rect(im,187,69,5,29,P.wood0); line(im,159,82,219,82,P.wood0,3); rect(im,153,97,73,4,P.wood4)
end)

-- Broad crown: manually grouped foliage masses, top-left dappled light, darker underside.
newArt('Oak - broad leafy crown',256,256,704,512,function(im)
  local blobs={{127,76,55,43},{82,97,43,48},{174,102,48,46},{108,139,47,45},{158,147,48,40},{56,132,31,32},{199,135,31,32},{126,43,31,27}}
  for _,b in ipairs(blobs) do ellipse(im,b[1]+3,b[2]+7,b[3],b[4],P.deep) end
  for _,b in ipairs(blobs) do ellipse(im,b[1],b[2],b[3],b[4],P.leaf0) end
  local r=rng(4418)
  for i=1,480 do local x=r(24,232); local y=r(30,183); local c=({P.leaf1,P.leaf1,P.leaf2,P.leaf2,P.leaf3,P.leaf4,P.leaf5})[r(1,7)]; ellipse(im,x,y,r(3,9),r(2,6),c) end
  for i=1,36 do local x=r(29,226); local y=r(65,174); line(im,x,y,x+r(-5,5),y+r(3,7),P.leaf5,1) end
end)
newArt('Oak - trunk and roots',128,160,1024,256,function(im)
  poly(im,{{50,14},{78,14},{83,94},{113,145},{100,153},{73,115},{65,153},{52,153},{52,115},{25,151},{12,145},{41,94}},P.ink)
  poly(im,{{54,18},{73,18},{75,93},{91,139},{79,131},{65,107},{61,142},{55,142},{56,101},{35,139},{27,143},{46,91}},P.wood1)
  line(im,59,25,58,95,P.wood3,6); line(im,69,27,68,88,P.wood2,4); line(im,76,93,94,137,P.wood3,4); line(im,53,98,35,137,P.wood2,4)
  for i=1,12 do line(im,48+i*2,52,48+i*2,72,P.wood0,1) end
  ellipse(im,64,149,54,8,P.deep); ellipse(im,64,146,47,5,P.grass1)
end)

-- Footbridge broad planks, stone abutments and handrails.
newArt('Bridge - timber footbridge',320,128,1160,512,function(im)
  poly(im,{{14,43},{271,43},{307,91},{47,91}},P.ink); poly(im,{{22,43},{270,43},{294,82},{49,82}},P.wood1)
  for i=0,12 do local x=26+i*20; line(im,x,45,x+17,77,P.wood3,4); line(im,x+2,46,x+16,73,P.wood4,1); px(im,x+4,58,P.wood0) end
  -- Rails in perspective with posts and square caps.
  line(im,29,36,266,36,P.wood0,7); line(im,43,26,277,26,P.wood0,7); line(im,35,33,270,33,P.wood4,2); line(im,50,23,281,23,P.wood3,2)
  for _,x in ipairs({32,91,152,213,271}) do line(im,x,23,x+6,57,P.wood0,7); rect(im,x-3,17,12,8,P.wood3); px(im,x,18,P.gold) end
  rect(im,39,81,31,22,P.stone0); rect(im,257,81,32,22,P.stone0); rect(im,45,82,22,12,P.stone2); rect(im,263,82,22,12,P.stone2)
end)

-- Hand-detailed well, cart, benches, fences, wayfinding, lantern, mossy stone and flowers.
newArt('Well - stone lip and oak winch',128,160,320,704,function(im)
  ellipse(im,64,139,56,16,P.ink); rect(im,9,92,110,48,P.stone0); for row=0,2 do for x=13+(row%2)*14,112,28 do rect(im,x,95+row*14,23,11,({P.stone1,P.stone2,P.stone3})[(x+row)%3+1]); line(im,x+2,96+row*14,x+15,96+row*14,P.stone4,1) end end
  ellipse(im,64,91,56,18,P.ink); ellipse(im,64,88,53,15,P.stone3); ellipse(im,64,88,40,10,P.water1); ellipse(im,64,86,33,6,P.water2)
  line(im,37,82,37,27,P.wood0,7); line(im,91,82,91,27,P.wood0,7); line(im,36,28,92,28,P.wood3,6); line(im,45,26,45,73,P.wood2,3); line(im,82,26,82,73,P.wood2,3)
  line(im,60,29,60,71,P.wood0,3); rect(im,49,64,22,21,P.wood1); rect(im,52,66,16,15,P.wood3); line(im,50,69,68,69,P.wood0,2)
  for _,x in ipairs({16,112}) do rect(im,x-5,132,10,17,P.wood3); px(im,x,135,P.gold) end
end)
newArt('Cart - loaded market wagon',192,128,448,832,function(im)
  ellipse(im,58,101,28,27,P.ink); ellipse(im,58,100,21,21,P.wood0); ellipse(im,58,100,14,14,P.wood3); ellipse(im,58,100,5,5,P.gold)
  ellipse(im,145,101,28,27,P.ink); ellipse(im,145,100,21,21,P.wood0); ellipse(im,145,100,14,14,P.wood3); ellipse(im,145,100,5,5,P.gold)
  poly(im,{{26,42},{162,42},{177,83},{40,83}},P.ink); poly(im,{{33,44},{156,44},{167,76},{43,76}},P.wood2)
  for x=42,156,18 do line(im,x,46,x+5,74,P.wood0,3); line(im,x+2,46,x+6,72,P.wood4,1) end
  line(im,32,39,159,39,P.wood4,5); line(im,39,83,39,94,P.wood0,4); line(im,168,81,173,94,P.wood0,4)
  -- Produce sacks and crates.
  rect(im,48,22,42,23,P.wood0); rect(im,52,25,34,17,P.wood3); line(im,54,32,83,32,P.wood1,2); line(im,68,26,68,40,P.wood1,2)
  ellipse(im,115,35,17,13,P.grass1); ellipse(im,137,34,16,14,P.grass2); px(im,113,29,P.gold); px(im,140,28,P.grass4)
end)
newArt('Fence - modular timber rails',320,96,0,800,function(im)
  for _,x in ipairs({18,88,158,228,298}) do poly(im,{{x-7,30},{x+7,30},{x+5,91},{x-5,91}},P.ink); rect(im,x-4,34,8,52,P.wood2); rect(im,x-7,28,14,7,P.wood4); line(im,x-4,39,x-4,80,P.wood3,1) end
  for _,y in ipairs({45,72}) do poly(im,{{10,y},{300,y},{306,y+9},{8,y+9}},P.ink); line(im,16,y+2,296,y+2,P.wood3,4); line(im,15,y+7,298,y+7,P.wood1,2) end
  for i=1,24 do local x=12+i*12; px(im,x,44,P.gold) end
end)
newArt('Bench - village oak',128,80,640,832,function(im)
  poly(im,{{12,25},{112,25},{118,44},{17,44}},P.ink); for _,y in ipairs({27,35}) do line(im,19,y,106,y+2,P.wood3,6); line(im,20,y,103,y+2,P.wood4,1) end
  for _,x in ipairs({28,93}) do line(im,x,42,x-4,72,P.wood0,6); line(im,x+12,43,x+17,72,P.wood0,6); line(im,x-3,72,x+20,72,P.wood2,4) end
  line(im,22,55,103,55,P.wood1,5); line(im,26,53,98,53,P.wood3,2)
end)
newArt('Flower patch - bluebell and marigold',128,80,800,832,function(im)
  local r=rng(921)
  for i=1,35 do local x=r(8,119); local y=r(31,73); ellipse(im,x,y+3,r(3,8),r(2,4),P.deep); line(im,x,y,x+r(-4,4),y-r(9,22),P.grass2,2); local c=({P.gold,P.flower,P.blue,P.cream,P.grass4})[r(1,5)]; ellipse(im,x+r(-4,4),y-r(9,22),r(2,4),r(2,3),c); px(im,x,y-r(22,9),P.cream) end
end)
newArt('Boulders - moss capped stones',160,96,0,896,function(im)
  poly(im,{{10,73},{20,47},{48,38},{64,23},{94,31},{110,18},{142,36},{153,65},{137,81},{36,85}},P.ink)
  poly(im,{{17,68},{27,48},{51,43},{65,29},{92,37},{109,25},{135,41},{145,64},{131,76},{39,78}},P.stone1)
  poly(im,{{28,50},{49,43},{66,30},{91,38},{107,28},{131,42},{115,51},{91,47},{76,58},{49,55}},P.grass1)
  for i=1,45 do local r=rng(723+i); local x=r(24,140); local y=r(42,72); px(im,x,y,({P.stone2,P.stone3,P.stone4,P.grass2})[r(1,4)]) end
  line(im,31,66,55,69,P.stone3,2); line(im,82,54,104,57,P.stone3,2)
end)
newArt('Shrubs - berries and leaf clusters',192,144,960,768,function(im)
  local r=rng(1245)
  for _,b in ipairs({{45,88,37,30},{94,67,45,38},{145,88,38,30},{73,103,42,25},{127,104,43,25}}) do ellipse(im,b[1]+2,b[2]+7,b[3],b[4],P.deep) end
  for _,b in ipairs({{45,84,37,30},{94,62,45,38},{145,84,38,30},{73,99,42,25},{127,100,43,25}}) do ellipse(im,b[1],b[2],b[3],b[4],P.leaf1) end
  for i=1,180 do local x=r(22,173); local y=r(50,109); ellipse(im,x,y,r(2,6),r(2,4),({P.leaf2,P.leaf3,P.leaf4,P.leaf5})[r(1,4)]) end
  for i=1,14 do local x=r(26,166); local y=r(66,101); px(im,x,y,P.flower); px(im,x+1,y-1,P.gold) end
end)
newArt('Signpost - hand painted village marker',96,128,1152,832,function(im)
  poly(im,{{41,41},{53,41},{58,119},{38,119}},P.ink); rect(im,43,47,7,66,P.wood2); line(im,45,52,45,108,P.wood4,1)
  poly(im,{{9,23},{74,23},{86,33},{75,48},{10,48}},P.ink); poly(im,{{14,27},{70,27},{78,34},{70,43},{14,43}},P.wood3); line(im,18,30,66,30,P.wood4,2); line(im,21,39,62,39,P.wood1,1)
  for _,x in ipairs({16,67}) do px(im,x,35,P.gold) end
end)
newArt('Lantern - iron and warm amber glass',64,128,1280,832,function(im)
  line(im,32,2,32,24,P.wood0,5); poly(im,{{18,22},{46,22},{43,72},{21,72}},P.ink); rect(im,23,28,18,38,P.gold); rect(im,26,31,12,30,P.cream); rect(im,21,22,22,7,P.stone0); rect(im,21,67,22,7,P.stone0); line(im,31,25,31,67,P.wood0,2); line(im,18,75,46,75,P.wood0,4); ellipse(im,32,82,12,6,C(225,190,112,70))
end)

-- Refinement pass: material-specific small clusters, edge wear, grain and highlights.
-- Kept as separate editable layers so an artist can tune or remove a material pass.
newArt('Ground detail - blade clusters and wildflowers',512,512,0,0,function(im)
  local r=rng(99017)
  for i=1,1450 do local x=r(0,511); local y=r(0,511); local h=r(2,7); local lean=r(-3,3); local c=({P.grass2,P.grass2,P.grass3,P.grass4,P.deep})[r(1,5)]; line(im,x,y,x+lean,y-h,c,1); if r(0,4)==0 then px(im,x+lean+1,y-h,P.grass4) end end
  for i=1,230 do local x=r(0,511); local y=r(0,511); if r(0,5)==0 then px(im,x,y,P.dirt2); px(im,x+1,y,P.dirt3) end end
  for i=1,30 do local x=r(16,496); local y=r(16,496); ellipse(im,x,y,3,2,P.grass3); px(im,x-2,y-2,P.gold); px(im,x+2,y-1,P.cream); px(im,x,y-3,P.cream); px(im,x,y,P.dirt3) end
end)
newArt('Road detail - broken stone grain and footprints',512,512,512,0,function(im)
  local r=rng(71904)
  for i=1,210 do local y=r(5,505); local axis=212+math.floor(y*.26)+math.floor(28*math.sin(y/55)); local x=axis+r(-64,64); local w=r(4,12); local h=r(2,6); ellipse(im,x,y,w,h,P.dirt0); ellipse(im,x-1,y-1,w-1,h-1,({P.stone1,P.stone2,P.dirt3,P.dirt4})[r(1,4)]); line(im,x-w+2,y-h,x+w-3,y-h,P.stone3,1); if r(0,2)==0 then line(im,x-2,y,x+1,y+2,P.stone0,1) end end
  for i=1,34 do local y=r(10,500); local axis=212+math.floor(y*.26)+math.floor(28*math.sin(y/55)); local x=axis+r(-54,54); line(im,x,y,x+r(2,7),y+r(1,3),P.dirt4,1); line(im,x+3,y+2,x+5,y+3,P.dirt1,1) end
  for i=1,65 do local y=r(0,511); local axis=212+math.floor(y*.26)+math.floor(28*math.sin(y/55)); local side=r(0,1)==0 and -1 or 1; local x=axis+side*r(73,103); line(im,x,y,x+r(-4,4),y-r(5,8),P.grass3,1); px(im,x+side*2,y-8,P.grass4) end
end)
newArt('Stream detail - ripples, foam and bank reeds',512,256,1024,0,function(im)
  local r=rng(45013)
  for i=1,440 do local y=r(1,254); local c=238+math.floor(70*math.sin(y/46))+math.floor(24*math.sin(y/17)); local x=c+r(-38,38); local n=r(3,18); line(im,x,y,x+n,y,P.water3,1); if r(0,3)==0 then line(im,x+2,y-1,x+n-2,y-1,P.water4,1) end end
  for i=1,90 do local y=r(0,255); local c=238+math.floor(70*math.sin(y/46))+math.floor(24*math.sin(y/17)); local side=r(0,1)==0 and -1 or 1; local x=c+side*r(48,66); line(im,x,y,x+side*r(-4,4),y-r(9,21),P.grass3,2); px(im,x+side*2,y-r(11,19),P.grass4) end
  for i=1,48 do local y=r(0,255); local c=238+math.floor(70*math.sin(y/46))+math.floor(24*math.sin(y/17)); local x=c+r(-35,35); px(im,x,y,P.water4); px(im,x+1,y,P.water3); if r(0,2)==0 then px(im,x+3,y-1,P.cream) end end
end)
newArt('Cottage detail - mortar, timber grain and hardware',320,256,0,512,function(im)
  local r=rng(7150)
  -- Irregular block joints and chipped corners make each stone read separately.
  for row=0,8 do local y=78+row*16; local off=(row%2)*19; for x=33+off,283,41 do line(im,x,y,x+30,y,P.stone0,1); line(im,x+31,y,x+35,y+1,P.stone3,1); if r(0,2)==0 then line(im,x+5,y+9,x+8,y+11,P.ink,1) end end end
  for i=1,32 do local x=r(37,280); local y=r(85,208); px(im,x,y,P.stone4); px(im,x+1,y,P.stone2) end
  -- Door plank grain and iron nail heads.
  for x=128,188,14 do line(im,x,132,x+r(-1,1),185,P.wood1,1); line(im,x+3,138,x+3,178,P.wood4,1); for y=137,190,24 do px(im,x,y,P.stone0); px(im,x+1,y,P.gold) end end
  rect(im,116,109,88,3,P.wood4); line(im,119,117,200,117,P.stone3,1); px(im,190,170,P.cream); px(im,186,172,P.wood0)
  -- Carved lintel and shutter slats.
  line(im,108,109,211,109,P.wood0,2); line(im,111,106,208,106,P.wood4,1)
  for y=117,139,5 do line(im,60,y,92,y,P.wood4,1) end
end)
newArt('Roof detail - offset shingle scales and moss',384,192,320,512,function(im)
  local r=rng(5519)
  for row=0,11 do local y=31+row*8; local left=34+row*2; local right=351-row; local off=(row%2)*12; for x=left+off,right,24 do line(im,x,y,x+18,y-7,P.wood0,4); line(im,x+1,y-1,x+17,y-7,P.wood4,2); line(im,x+4,y-1,x+15,y-5,P.wood3,1); px(im,x+18,y-7,P.gold) end end
  for i=1,70 do local x=r(38,344); local y=r(42,134); if r(0,4)==0 then px(im,x,y,P.grass3); px(im,x+1,y,P.grass2) end end
  line(im,31,83,180,20,P.wood4,2); line(im,194,24,347,85,P.wood3,2)
end)
newArt('Oak detail - individual leaves and sun dapples',256,256,704,512,function(im)
  local r=rng(98121)
  for i=1,1050 do local x=r(24,233); local y=r(25,184); local rx=r(1,3); local c=({P.leaf1,P.leaf2,P.leaf2,P.leaf3,P.leaf4,P.leaf5})[r(1,6)]; ellipse(im,x,y,rx,r(1,2),c); if r(0,8)==0 then px(im,x+1,y-2,P.gold) end end
  for i=1,95 do local x=r(35,220); local y=r(45,170); line(im,x,y,x+r(-5,5),y+r(-3,3),P.leaf0,1) end
end)
newArt('Oak detail - bark channels and root highlights',128,160,1024,256,function(im)
  local r=rng(129)
  for i=1,18 do local x=r(46,75); local y=r(25,105); line(im,x,y,x+r(-3,3),y+r(13,38),({P.wood0,P.wood3,P.wood4})[r(1,3)],1) end
  for i=1,12 do local x=r(25,103); line(im,x,136,x+r(-12,12),r(145,152),P.wood3,1) end
  ellipse(im,62,68,4,7,P.wood0); ellipse(im,62,68,2,4,P.wood4); line(im,52,41,71,36,P.wood4,1)
end)
newArt('Bridge detail - grain, pegs, rope and water marks',320,128,1160,512,function(im)
  local r=rng(8891)
  for x=26,276,20 do line(im,x,48,x+15,74,P.wood1,1); line(im,x+2,47,x+12,67,P.wood4,1); px(im,x+5,51,P.gold); px(im,x+5,72,P.wood0) end
  for x=35,275,59 do ellipse(im,x,25,2,2,P.stone3); px(im,x,25,P.cream); line(im,x-3,30,x+2,34,P.wood1,1) end
  line(im,41,33,265,33,P.wood4,1); line(im,32,42,47,82,P.wood4,1); line(im,270,42,284,79,P.wood3,1)
end)
newArt('Prop detail - well blocks and winch grain',128,160,320,704,function(im)
  local r=rng(2034)
  for row=0,2 do for x=12+(row%2)*13,111,28 do line(im,x,95+row*14,x+19,95+row*14,P.stone4,1); if r(0,1)==1 then px(im,x+5,100+row*14,P.stone0) end end end
  for x=53,67,4 do line(im,x,67,x,82,P.wood4,1) end
  for _,x in ipairs({38,90}) do px(im,x,35,P.gold); px(im,x,40,P.wood4) end
  line(im,42,27,87,27,P.wood4,1)
end)
newArt('Prop detail - market cart grain and hardware',192,128,448,832,function(im)
  local r=rng(502)
  for x=44,153,18 do line(im,x,47,x+5,72,P.wood4,1); px(im,x+2,48,P.gold); px(im,x+4,75,P.wood0) end
  for _,cx in ipairs({58,145}) do for i=1,12 do local a=i*0.52; px(im,cx+math.floor(math.cos(a)*17),100+math.floor(math.sin(a)*17),P.wood4) end end
  for i=1,18 do local x=r(110,150); local y=r(24,43); px(im,x,y,P.grass4); if i%3==0 then px(im,x+1,y,P.gold) end end
end)
newArt('Prop detail - fence joins and seat carving',320,96,0,800,function(im)
  for _,x in ipairs({18,88,158,228,298}) do line(im,x-6,48,x+5,49,P.wood4,1); line(im,x-6,73,x+5,74,P.wood4,1); px(im,x,36,P.gold) end
  for x=24,293,28 do line(im,x,49,x+5,50,P.wood0,1); line(im,x,76,x+5,77,P.wood0,1) end
end)
newArt('Flower detail - petal forms and seed centers',128,80,800,832,function(im)
  local r=rng(16083)
  for i=1,42 do local x=r(8,120); local y=r(30,72); if r(0,2)==0 then px(im,x,y,P.cream); px(im,x-2,y,P.gold); px(im,x+2,y,P.flower); px(im,x,y-2,P.cream); px(im,x,y+2,P.flower) end end
  for i=1,24 do local x=r(10,117); local y=r(38,75); line(im,x,y,x+r(-3,3),y-r(2,6),P.grass4,1) end
end)
newArt('Berry detail - berries with reflective pixels',192,144,960,768,function(im)
  local r=rng(12018)
  for i=1,36 do local x=r(26,170); local y=r(69,104); ellipse(im,x,y,2,2,P.flower); px(im,x-1,y-1,P.cream); px(im,x+2,y+1,P.wood0) end
end)
newArt('Stone detail - chipped edges and moss',160,96,0,896,function(im)
  local r=rng(8817)
  for i=1,44 do local x=r(25,143); local y=r(38,75); px(im,x,y,({P.stone3,P.stone4,P.grass3})[r(1,3)]); if r(0,1)==1 then px(im,x+1,y,P.stone2) end end
  for i=1,24 do local x=r(31,131); local y=r(32,52); px(im,x,y,P.grass4); px(im,x+1,y+1,P.grass2) end
end)
newArt('Sign and lantern detail - painted grain and glow',96,128,1152,832,function(im)
  line(im,17,29,69,29,P.cream,1); line(im,20,41,66,41,P.wood1,1); px(im,18,34,P.gold); px(im,76,35,P.gold)
end)
newArt('Lantern glass detail - amber facets',64,128,1280,832,function(im)
  line(im,25,31,25,57,P.cream,1); px(im,37,35,P.gold); px(im,35,47,P.cream); line(im,23,27,40,27,P.stone3,1)
end)

local bg=s.layers[1]; bg.name='Atlas guide (hidden)'; bg.isVisible=false
s:saveAs(output)
print('Created layered hand-authored Valdoria R10 pixel-art source atlas')
