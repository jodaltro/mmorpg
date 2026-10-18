"""Retained Aseprite edit for the second Ground13 water interpretation."""
import shutil
import ground13 as g

def main():
 out=g.refuse(g.BASE/'SourceV2');out.mkdir(parents=True)
 for file in (g.BASE/'SourceV1').glob('*.aseprite'):shutil.copyfile(file,out/file.name)
 code=f'local s=app.open({g.e.n.q(out/"water-material.aseprite")});local l=s:newLayer();l.name="Broken sky masses - quiet reflection planes";'
 polygons=[[(7,16),(20,13),(32,16),(40,21),(30,26),(18,25),(5,22)],[(72,16),(83,13),(98,17),(106,22),(94,27),(80,24),(69,22)],[(8,82),(19,79),(34,82),(43,87),(30,92),(17,90),(6,86)],[(74,82),(85,79),(103,84),(110,90),(96,95),(80,91),(70,87)]]
 for frame in range(4):
  shift=[0,1,2,1][frame];alpha=[32,38,43,38][frame];code+='do local im=Image(s.spec);'
  for poly in polygons:
   for y in range(min(p[1] for p in poly),max(p[1] for p in poly)+1):
    for x in range(min(p[0] for p in poly),max(p[0] for p in poly)+1):
     inside=False
     for a,b in zip(poly,poly[1:]+poly[:1]):
      if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
     if inside:code+=f'im:drawPixel({x+shift},{y},app.pixelColor.rgba(120,158,143,{alpha}));'
  code+=f's:newCel(l,{frame+1},im,Point(0,0));end;'
 code+=f's:saveAs({g.e.n.q(out/"water-material.aseprite")});s:close();'
 g.e.n.lua(code,out/'water-mass-edit.lua')

if __name__=='__main__':main()
