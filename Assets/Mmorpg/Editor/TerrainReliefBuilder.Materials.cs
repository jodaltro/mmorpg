using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json.Linq;
// Same 2D relief pipeline, with continuous scalar contours and world-space UVs.
public static partial class TerrainReliefBuilder
{
 struct Point {public Vector2 p;public float s,h,light,faceLight;public Point(Vector2 p,float s,float h,float light=1,float faceLight=.65f){this.p=p;this.s=s;this.h=h;this.light=light;this.faceLight=faceLight;}}
 sealed class ContinuousBatch
 {
  public readonly List<Vector3> vertices=new List<Vector3>();readonly List<Vector2> uv=new List<Vector2>();readonly List<Color> colors=new List<Color>();readonly List<int> triangles=new List<int>();
  public void Polygon(List<Point> points,float width,float height,bool elevated,Color tint)
  {
   int n=vertices.Count;foreach(var p in points){vertices.Add(new Vector3(p.p.x,height-p.p.y+(elevated?p.h:0),0));uv.Add(new Vector2(p.p.x/width,1-p.p.y/height));colors.Add(tint*(elevated?new Color(p.light,p.light,p.light,1):Color.white));}
   for(int i=1;i<points.Count-1;i++){triangles.Add(n);triangles.Add(n+i);triangles.Add(n+i+1);}
  }
  public void Wall(Point a,Point b,float width,float height)
  {
   int n=vertices.Count;
   vertices.AddRange(new[]{new Vector3(a.p.x,height-a.p.y+a.h),new Vector3(b.p.x,height-b.p.y+b.h),new Vector3(b.p.x,height-b.p.y),new Vector3(a.p.x,height-a.p.y)});
   // World-space mapping across the wall; no 32px face restart.
   foreach(var v in vertices.Skip(n))uv.Add(new Vector2(v.x/width,v.y/height));
   foreach(var p in new[]{a,b,b,a})colors.Add(new Color(p.faceLight,p.faceLight,p.faceLight,1));
   triangles.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});
  }
  public MeshRenderer Save(Transform parent,string destination,string name,Material material,int sorting)
  {
   if(vertices.Count==0)return null;var mesh=new Mesh{name=name};mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();
   AssetDatabase.CreateAsset(mesh,destination+"/"+name+".asset");var go=new GameObject(name);go.transform.SetParent(parent);go.AddComponent<MeshFilter>().sharedMesh=mesh;var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.sortingOrder=sorting;return r;
  }
 }
 static Point Interpolate(Point a,Point b)
 {float t=a.s/(a.s-b.s);return new Point(Vector2.Lerp(a.p,b.p,t),0,Mathf.Lerp(a.h,b.h,t),Mathf.Lerp(a.light,b.light,t),Mathf.Lerp(a.faceLight,b.faceLight,t));}
 static List<Point> Clip(List<Point> polygon)
 {
  var result=new List<Point>();for(int i=0;i<polygon.Count;i++){var a=polygon[i];var b=polygon[(i+1)%polygon.Count];if(a.s>=0)result.Add(a);if((a.s>=0)!=(b.s>=0))result.Add(Interpolate(a,b));}return result;
 }
 public static (MeshRenderer[] tops,MeshRenderer[] faces) AddContinuous(GameObject root,JObject field,string destination,Material material,Material faceMaterial)
 {
  if(Directory.Exists(destination))throw new IOException("Refuse continuous relief overwrite");Directory.CreateDirectory(destination);AssetDatabase.Refresh();
  var samples=(JArray)field["samples"];float step=(float)field["stepUnits"],width=(float)field["sizeUnits"][0],height=(float)field["sizeUnits"][1];int rows=samples.Count-1,cols=((JArray)samples[0]).Count-1;
  var topList=new List<MeshRenderer>();var faceList=new List<MeshRenderer>();
  Func<int,int,float> H=(x,y)=>(float)samples[Mathf.Clamp(y,0,rows)][Mathf.Clamp(x,0,cols)][1];
  Func<int,int,float> S=(x,y)=>(float)samples[Mathf.Clamp(y,0,rows)][Mathf.Clamp(x,0,cols)][0];
  Func<int,int,float> Face=(x,y)=>{var g=new Vector2(S(x+1,y)-S(x-1,y),S(x,y+1)-S(x,y-1)).normalized;return Mathf.Clamp(.62f+g.x*.12f-g.y*.06f,.45f,.80f);};
  Func<int,int,Point> sample=(x,y)=>new Point(new Vector2(x*step,y*step),(float)samples[y][x][0],H(x,y),Mathf.Clamp(.92f+(H(x-1,y)-H(x+1,y))*.27f+(H(x,y+1)-H(x,y-1))*.20f,.67f,1.10f),Face(x,y));
  for(int groupY=0;groupY<rows;groupY+=4)
  {
   var top=new ContinuousBatch();var side=new ContinuousBatch();
   for(int y=groupY;y<Math.Min(rows,groupY+4);y++)for(int x=0;x<cols;x++)
   {
    var a=sample(x,y);var b=sample(x+1,y);var c=sample(x+1,y+1);var d=sample(x,y+1);
    foreach(var triangle in new[]{new List<Point>{a,b,c},new List<Point>{a,c,d}})
    {
     var clipped=Clip(triangle);if(clipped.Count<3)continue;
     // Continuous vertex tint from smooth height derivatives, shared at grid vertices.
     top.Polygon(clipped,width,height,true,Color.white);
     for(int i=0;i<clipped.Count;i++){var p=clipped[i];var q=clipped[(i+1)%clipped.Count];if(Mathf.Abs(p.s)<.00001f&&Mathf.Abs(q.s)<.00001f)side.Wall(p,q,width,height);}
    }
   }
   int order=100-Mathf.RoundToInt((height-(groupY+4)*step)*16);
   var t=top.Save(root.transform,destination,"ContinuousTop_"+groupY,material,order);if(t!=null)topList.Add(t);
   var f=side.Save(root.transform,destination,"ContinuousFace_"+groupY,faceMaterial,order+1);if(f!=null)faceList.Add(f);
  }
  return (topList.ToArray(),faceList.ToArray());
 }
}
