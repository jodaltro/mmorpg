-- Parametric garment surfaces, orthographic projection and native-pixel rasterization.
-- Geometry is authored here; character poses are never generated or altered.
local G={}
local pc=app.pixelColor
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function vec(x,y,z)return {x=x,y=y,z=z}end
local function sub(a,b)return vec(a.x-b.x,a.y-b.y,a.z-b.z)end
local function cross(a,b)return vec(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)end
local function norm(a)local d=math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z);if d<1e-8 then return vec(0,0,1)end;return vec(a.x/d,a.y/d,a.z/d)end
local function mix(a,b,t)return a+(b-a)*t end
local function color(hex)return pc.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255)end
local yaw={south=0,west=-math.pi/2,north=math.pi,east=math.pi/2}

local function profile(points,t)
  for i=2,#points do local a,b=points[i-1],points[i];if t<=b[1] then local f=(t-a[1])/(b[1]-a[1]);return mix(a[2],b[2],f),mix(a[3] or 0,b[3] or 0,f)end end
  local p=points[#points];return p[2],p[3] or 0
end

function G.validate(recipe)
  assert(recipe.schema=='parametric-garment-v1','Unsupported garment schema')
  assert(#recipe.components>0 and #recipe.components<=16,'Invalid component count')
  for _,part in ipairs(recipe.components) do
    assert(part.kind=='panel' or part.kind=='revolve','Supported surfaces: panel, revolve')
    assert(part.anchor=='shoulders' or part.anchor=='head' or part.anchor=='waist','Unknown attachment')
    assert(part.occlusion==nil or part.occlusion=='depth' or part.occlusion=='back_mounted','Unknown body occlusion rule')
    if part.directions then assert(#part.directions>0,'Empty component directions');for _,d in ipairs(part.directions) do assert(yaw[d],'Unknown component direction')end end
    assert(part.profile and #part.profile>=2 and part.profile[1][1]==0 and part.profile[#part.profile][1]==1,'Profile must cover [0,1]')
    for i,p in ipairs(part.profile) do assert(p[2]>=0 and p[2]<=24,'Profile radius outside canvas budget');if i>1 then assert(p[1]>part.profile[i-1][1],'Profile knots must increase')end end
    assert(part.length>0 and part.length<=34,'Invalid pattern length')
    assert(part.material and #recipe.materials[part.material].ramp>=3,'Material ramp missing')
    assert((part.columns or 24)>=4 and (part.columns or 24)<=64,'Invalid tessellation')
    assert((part.rows or 16)>=1 and (part.rows or 16)<=64,'Invalid row count')
    assert((part.folds or 0)>=0 and (part.folds or 0)<=16,'Invalid fold count')
    assert((part.foldDepth or 0)>=0 and (part.foldDepth or 0)<=4,'Invalid fold depth')
    assert((part.slit or 0)>=0 and (part.slit or 0)<=.5,'Invalid slit')
  end
end

local function mesh(part)
  local vertices,triangles={},{}
  local nx=part.columns or 24;local ny=part.rows or 16
  for j=0,ny do
    local v=j/ny;local width,depth=profile(part.profile,v)
    for i=0,nx do
      local u=i/nx;local p
      if part.kind=='panel' then
        local fold=(part.foldDepth or 0)*math.sin(u*math.pi*(part.folds or 4))*math.sin(v*math.pi*.75)
        local hem=(part.scallop or 0)*v^8*math.cos(u*math.pi*6)
        p=vec((u*2-1)*width,depth+fold,part.length*v+hem)
      else
        local angle=2*math.pi*u
        p=vec(math.cos(angle)*width,math.sin(angle)*width*(part.depthRatio or 1),-part.length*v)
        p.x=p.x+(part.lean or 0)*v*v
        p.y=p.y+depth
      end
      p.u=u;p.v=v;vertices[#vertices+1]=p
    end
  end
  for j=0,ny-1 do for i=0,nx-1 do
    local a=j*(nx+1)+i+1;local b=a+1;local c=a+nx+1;local d=c+1
    triangles[#triangles+1]={a,c,b};triangles[#triangles+1]={b,c,d}
  end end
  return vertices,triangles
end

local function project(p,a,direction,offset)
  local angle=yaw[direction];local c,s=math.cos(angle),math.sin(angle)
  local x=p.x+(offset[1] or 0);local depth=p.y+(offset[2] or 0);local down=p.z+(offset[3] or 0)
  local worldX=x*c-depth*s;local worldDepth=x*s+depth*c
  return {x=a.x+worldX,y=a.y+down-worldDepth*.38,depth=worldDepth,world=vec(worldX,worldDepth,-down),u=p.u,v=p.v}
end

local function shade(mat,normal,u,v,part)
  -- Fixed upper-left light, quantized palette and stable UV folds; no random per-frame texture.
  local n=normal;if n.z<0 then n=vec(-n.x,-n.y,-n.z)end
  local light=norm(vec(-.55,-.35,.9));local diffuse=clamp(n.x*light.x+n.y*light.y+n.z*light.z,0,1)
  local crease=(part.folds or 0)>0 and math.cos(u*math.pi*(part.folds or 4))*.07 or 0
  local band=clamp(.28+diffuse*.57+crease-(v*.06),0,1)
  local isTrim=(part.kind=='panel' and (u<.045 or u>.955 or v>.945)) or (part.kind=='revolve' and part.trimBand and v>part.trimBand[1] and v<part.trimBand[2])
  if isTrim and mat.trim then return color(mat.trim[clamp(math.floor(band*#mat.trim)+1,1,#mat.trim)])end
  return color(mat.ramp[clamp(math.floor(band*#mat.ramp)+1,1,#mat.ramp)])
end

local function edge(a,b,x,y)return (x-a.x)*(b.y-a.y)-(y-a.y)*(b.x-a.x)end

function G.render(recipe,pose,width,height)
  G.validate(recipe)
  local behind=Image(width,height,ColorMode.RGB);local front=Image(width,height,ColorMode.RGB);local hat=Image(width,height,ColorMode.RGB)
  local buffers={};local metrics={triangles=0,fragments=0,clippedFragments=0}
  for _,part in ipairs(recipe.components) do
    local visible=not part.directions
    if part.directions then for _,d in ipairs(part.directions) do if d==pose.direction then visible=true end end end
    if visible then
    local anchor=pose[part.anchor];assert(anchor,'Attachment not measured')
    local vertices,triangles=mesh(part);local projected={}
    for i,p in ipairs(vertices) do projected[i]=project(p,anchor,pose.direction,part.offset or {0,0,0})end
    local coverage,depths,colors={},{},{}
    for _,tri in ipairs(triangles) do
      local a,b,c=projected[tri[1]],projected[tri[2]],projected[tri[3]]
      local area=edge(a,b,c.x,c.y);metrics.triangles=metrics.triangles+1
      if math.abs(area)>1e-7 then
        local normal=norm(cross(sub(b.world,a.world),sub(c.world,a.world)))
        local minx=math.floor(math.min(a.x,b.x,c.x));local maxx=math.ceil(math.max(a.x,b.x,c.x));local miny=math.floor(math.min(a.y,b.y,c.y));local maxy=math.ceil(math.max(a.y,b.y,c.y))
        for y=miny,maxy do for x=minx,maxx do
          local w0=edge(b,c,x+.5,y+.5)/area;local w1=edge(c,a,x+.5,y+.5)/area;local w2=1-w0-w1
          if w0>=-1e-6 and w1>=-1e-6 and w2>=-1e-6 then
            if x<0 or y<0 or x>=width or y>=height then metrics.clippedFragments=metrics.clippedFragments+1
            else
              local u=w0*a.u+w1*b.u+w2*c.u;local v=w0*a.v+w1*b.v+w2*c.v
              local slit=part.slit or 0;local cut=part.kind=='panel' and v>1-slit and math.abs(u-.5)<(v-(1-slit))*.18
              if not cut then
                local z=w0*a.depth+w1*b.depth+w2*c.depth;local key=y*width+x
                if not depths[key] or z<depths[key] then
                  depths[key]=z;coverage[key]=true;colors[key]=shade(recipe.materials[part.material],normal,u,v,part)
                end
              end
            end
          end
        end end
      end
    end
    local outline=color(recipe.materials[part.material].outline)
    for key in pairs(coverage) do
      local y=math.floor(key/width);local x=key%width
      if not coverage[key-1] or not coverage[key+1] or not coverage[key-width] or not coverage[key+width] then colors[key]=outline end
      local layer
      if part.occlusion=='back_mounted' then
        -- A raster character has no per-limb depth map. Side-view arms/torso stay in front
        -- of a back-mounted item; north exposes the back and therefore the item.
        layer=(pose.direction=='north') and front or behind
      elseif part.anchor=='head' then layer=hat
      elseif depths[key]<-.15 then layer=front else layer=behind end
      -- Render-order buffer is per output layer, not per pattern, so overlapping panels respect depth.
      local bufferName=(layer==hat and 'hat' or layer==front and 'front' or 'back');buffers[bufferName]=buffers[bufferName] or {}
      local z=depths[key]
      if not buffers[bufferName][key] or z<buffers[bufferName][key] then
        layer:drawPixel(x,y,colors[key]);buffers[bufferName][key]=z;metrics.fragments=metrics.fragments+1
      end
    end
    end
  end
  return {back=behind,front=front,hat=hat},metrics
end

return G
