
local function clamp(x) return math.max(0,math.min(255,math.floor(x+.5))) end
local function revise(src,dst,kind,aged,seed)
 local s=app.open(src)
 for _,cel in ipairs(s.cels) do
  local im=cel.image:clone();local layer=cel.layer.name
  for it in im:pixels() do
   local c=it();local a=app.pixelColor.rgbaA(c)
   if a>0 and layer~="Shadow" and layer~="Shadow - ground plane" then
    local r,g,b=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c)
    local x,y=it.x+cel.position.x,it.y+cel.position.y
    local lum=.2126*r+.7152*g+.0722*b
    if kind=="barn" then
     if layer=="Roof" or layer=="Eaves" then
      r,g,b=r*.94,g*.93,b*.98+2
     elseif layer=="Foundation" then r,g,b=r*.96,g*.97,b*.99 end
    elseif kind=="castle" then
     if layer~="KeepRoof" and layer~="GateTimber" and layer~="KeepDoor" then
      r,g,b=r*.96,g*.975,b*.98+2
     end
    elseif kind=="vegetation" then
     if layer=="Canopy - dark volume" or layer=="Foliage - planes" or layer=="Highlights and accents" then
      if g>r*1.025 and g>b*1.06 then
       -- Separate cool pockets, leaf planes and warm upper-left light.
       local u=x/s.width;local v=y/s.height
       local plane=math.sin(x*.053+y*.031)+.55*math.sin(x*.107-y*.069)
       local light=math.max(-1,math.min(1,(.53-v)*1.3+(.50-u)*.45+plane*.23))
       local k=(lum-48)/104
       r=r*(.88+.10*k)+light*6;g=g*(1.04+.045*k)+light*9;b=b*(.76+.07*k)+light*1.5
       if layer=="Canopy - dark volume" and plane<-.85 then r,g,b=r-5,g-7,b-2 end
      end
     elseif layer=="Trunk - structure" or layer=="Bark and branches" then
      local grain=math.sin(x*1.7+y*.08)
      r,g,b=r*1.04+grain*3,g*.99+grain*2,b*.94
     end
    elseif kind=="motifs" then
     local old={}
     -- Row-aware palette mapping is injected below.
     local row=math.floor(y/32);local ramps={{{62,84,53},{74,96,58},{86,109,64},{98,123,71},{117,140,82},{142,159,101}},{{110,87,62},{129,103,70},{149,123,84},{170,144,102},{187,164,122},{204,185,145}},{{65,74,68},{86,96,82},{107,117,100},{128,138,117},{150,160,138},{174,181,158}},{{69,67,53},{87,80,59},{106,96,67},{128,115,79},{149,134,96},{170,155,116}},{{140,121,83},{157,138,94},{176,160,110},{196,181,128},{215,200,148},{229,215,169}},{{116,95,67},{137,114,79},{159,134,94},{177,154,112},{194,173,132},{209,191,152}}};local news={{{48,71,40},{64,91,44},{84,112,54},{106,132,64},{132,153,79},{162,173,106}},{{98,77,57},{125,96,67},{152,120,79},{175,146,99},{196,169,125},{216,194,151}},{{62,68,60},{85,94,80},{113,121,102},{146,150,128},{176,177,154},{204,199,171}},{{61,64,48},{80,80,57},{105,96,68},{130,118,80},{155,141,101},{180,164,125}},{{133,114,79},{155,134,92},{176,155,107},{197,177,124},{216,197,145},{231,214,167}},{{108,86,62},{132,106,73},{159,130,89},{179,154,109},{199,175,132},{217,196,155}}}; if ramps[row+1] then local best,dist=1,1e20;for j,p in ipairs(ramps[row+1]) do local d=(r-p[1])^2+(g-p[2])^2+(b-p[3])^2;if d<dist then best=j;dist=d end end; local p=news[row+1][best];r,g,b=p[1],p[2],p[3] end
    end
    if aged then
     -- Coherent small lichen colonies, smoke and worn grain, all clipped to
     -- already painted opaque planes. No invented geometry / collision.
     local u,v=x/s.width,y/s.height
     local colony=math.sin(x*.061+seed*.017)+math.sin(y*.091-x*.023)+.6*math.sin(x*.137+y*.117)
     local stone=layer=="Foundation" or layer=="KeepWalls" or layer=="CurtainWalls" or layer=="LeftTower" or layer=="RightTower"
     if stone and v>.49 and lum>55 and colony>1.60 and g>r*.70 then
      local t=.20+(colony-1.6)*.12;r=r*(1-t)+95*t;g=g*(1-t)+105*t;b=b*(1-t)+62*t
     elseif (layer=="Roof" or layer=="KeepRoof") and colony>1.95 and v>.20 then
      r,g,b=r*.94,g*.98,b*.92
     elseif (layer=="TimbersFront" or layer=="TimbersSide" or layer=="GateTimber") and colony>1.25 and lum>65 then
      r,g,b=r*1.04+2,g*1.03+2,b*1.04+2
     end
    end
    it(app.pixelColor.rgba(clamp(r),clamp(g),clamp(b),a))
   end
  end
  cel.image=im
 end
 s:saveAs(dst);s:close()
end

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio07R/SourceV1/rural-reference.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Architecture/house/maintained/Source/rural-reference.aseprite","house",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio07R/SourceV1/rural-reference.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Architecture/house/weathered/Source/rural-reference.aseprite","house",true,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio08/Barn/SourceV1/barn-reference.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Architecture/barn/maintained/Source/barn-reference.aseprite","barn",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio08/Barn/SourceV1/barn-reference.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Architecture/barn/weathered/Source/barn-reference.aseprite","barn",true,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio08/Castle/SourceV1/castle-reference.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Architecture/castle/maintained/Source/castle-reference.aseprite","castle",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio08/Castle/SourceV1/castle-reference.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Architecture/castle/weathered/Source/castle-reference.aseprite","castle",true,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio06/LibraryR5/oak.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Vegetation/Source/oak.aseprite","vegetation",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio06/LibraryR5/elm.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Vegetation/Source/elm.aseprite","vegetation",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio06/LibraryR5/hazel.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Vegetation/Source/hazel.aseprite","vegetation",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio06/LibraryR5/fern.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Vegetation/Source/fern.aseprite","vegetation",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio06/LibraryR5/reeds.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Vegetation/Source/reeds.aseprite","vegetation",false,910209)

revise("D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio04/Library/terrain-motifs.aseprite","D:/unity/Mmorpg/ArtSource/Labs/World2026/WorldStudio09/Terrain/Source/terrain-motifs.aseprite","motifs",false,910209)
