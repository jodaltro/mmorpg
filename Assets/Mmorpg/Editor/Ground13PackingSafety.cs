using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using Newtonsoft.Json;
// Preserve original renderers wherever equal-depth opaque pixels can overlap.
// This deliberately keeps some calls: a lower count cannot justify changed order.
public static class Ground13PackingSafety
{
 sealed class Pixels{public int w,h;public Color32[] pixels;public bool monochrome;public Color32 color;}
 static string PathOf(Transform t)=>t.parent?PathOf(t.parent)+"/"+t.name:t.name;
 static long Key(int x,int y)=>((long)x<<32)|(uint)y;
 static HashSet<long> Raster(Renderer r,Pixels texture)
 {
  Vector3[] points;Vector2[] uv;int[] indices;
  if(r is SpriteRenderer s){points=s.sprite.vertices.Select(v=>r.transform.TransformPoint(v)).ToArray();uv=s.sprite.uv;indices=s.sprite.triangles.Select(i=>(int)i).ToArray();}
  else{var mesh=r.GetComponent<MeshFilter>().sharedMesh;points=mesh.vertices.Select(v=>r.transform.TransformPoint(v)).ToArray();uv=mesh.uv;indices=mesh.triangles;}
  var result=new HashSet<long>();
  for(int i=0;i<indices.Length;i+=3)
  {
   int ia=indices[i],ib=indices[i+1],ic=indices[i+2];Vector2 a=(Vector2)points[ia]*32,b=(Vector2)points[ib]*32,c=(Vector2)points[ic]*32;float det=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y);if(Mathf.Abs(det)<.000001f)continue;
   int left=Mathf.FloorToInt(Mathf.Min(a.x,b.x,c.x)),right=Mathf.CeilToInt(Mathf.Max(a.x,b.x,c.x)),bottom=Mathf.FloorToInt(Mathf.Min(a.y,b.y,c.y)),top=Mathf.CeilToInt(Mathf.Max(a.y,b.y,c.y));
   for(int y=bottom;y<top;y++)for(int x=left;x<right;x++)
   {
    float px=x+.5f,py=y+.5f,u=((b.y-c.y)*(px-c.x)+(c.x-b.x)*(py-c.y))/det,v=((c.y-a.y)*(px-c.x)+(a.x-c.x)*(py-c.y))/det,w=1-u-v;if(u<-.00001f||v<-.00001f||w<-.00001f)continue;Vector2 sample=uv[ia]*u+uv[ib]*v+uv[ic]*w;int tx=Mathf.Clamp(Mathf.FloorToInt(sample.x*texture.w),0,texture.w-1),ty=Mathf.Clamp(Mathf.FloorToInt(sample.y*texture.h),0,texture.h-1);if(texture.pixels[ty*texture.w+tx].a==0)continue;
    // Conservative one-native-pixel halo protects camera subpixel sampling.
    for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++)result.Add(Key(x+dx,y+dy));
   }
  }
  return result;
 }
 public static HashSet<Renderer> Preserve(Renderer[] renderers)
 {
  var images=new Dictionary<string,Pixels>();var samples=new Dictionary<Renderer,HashSet<long>>();var sources=new Dictionary<Renderer,string>();var keep=new HashSet<Renderer>();var edges=new List<object>();
  foreach(var r in renderers)
  {
   string path=AssetDatabase.GetAssetPath(r is SpriteRenderer s?s.sprite.texture:r.sharedMaterial.mainTexture);sources[r]=path;
   if(!images.ContainsKey(path)){var texture=new Texture2D(2,2,TextureFormat.RGBA32,false);if(!texture.LoadImage(File.ReadAllBytes(path)))throw new IOException("Cannot read packing input");var pixels=texture.GetPixels32();var colors=pixels.Where(p=>p.a>0).Select(p=>new Color32(p.r,p.g,p.b,255)).Distinct().Take(2).ToArray();images[path]=new Pixels{w=texture.width,h=texture.height,pixels=pixels,monochrome=colors.Length==1,color=colors.Length>0?colors[0]:default};UnityEngine.Object.DestroyImmediate(texture);}
   samples[r]=Raster(r,images[path]);
  }
  foreach(var group in renderers.GroupBy(r=>new{r.sortingLayerID,r.sortingOrder}))
  {
   var rr=group.ToArray();for(int i=0;i<rr.Length;i++)for(int j=i+1;j<rr.Length;j++)
   {
    var a=images[sources[rr[i]]];var b=images[sources[rr[j]]];if(a.monochrome&&b.monochrome&&a.color.Equals(b.color))continue;
    if(!samples[rr[i]].Overlaps(samples[rr[j]]))continue;keep.Add(rr[i]);keep.Add(rr[j]);edges.Add(new{first=PathOf(rr[i].transform),second=PathOf(rr[j].transform),rr[i].sortingOrder});
   }
  }
  Directory.CreateDirectory("Docs/Validation/ValdoriaGround13/QA");File.WriteAllText("Docs/Validation/ValdoriaGround13/QA/packing-order-protection.json",JsonConvert.SerializeObject(new{sourceCount=renderers.Length,retainedCount=keep.Count,policy="Original renderer retained for mixed-colour overlap at equal sorting layer/order; conservative1px halo. Equal monochrome shadow colours commute.",retained=keep.Select(r=>PathOf(r.transform)).OrderBy(s=>s).ToArray(),edges},Formatting.Indented));return keep;
 }
}
