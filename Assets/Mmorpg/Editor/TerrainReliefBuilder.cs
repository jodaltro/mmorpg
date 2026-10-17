using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json.Linq;

// Bakes planar 2D quads: elevation shapes the presentation of blocked terrain only.
// Shared corner positions eliminate cracks; physics stays on the semantic footprint.
public static partial class TerrainReliefBuilder
{
    public static void Add(GameObject root,JObject region,string destination)
    {
        if(Directory.Exists(destination))throw new IOException("Refuse relief overwrite: "+destination);
        Directory.CreateDirectory(destination);AssetDatabase.Refresh();
        const string art="Assets/Mmorpg/Art/Experimental/ValdoriaTerrainStudio01/";
        var sheet=AssetDatabase.LoadAssetAtPath<Texture2D>(art+"surfaces.png");
        var cliff=AssetDatabase.LoadAssetAtPath<Texture2D>(art+"cliffs.png");
        var shader=Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default");
        var topMaterial=new Material(shader){mainTexture=sheet};var faceMaterial=new Material(shader){mainTexture=cliff};
        AssetDatabase.CreateAsset(topMaterial,destination+"/RockSurface.mat");AssetDatabase.CreateAsset(faceMaterial,destination+"/RockFaces.mat");
        int w=(int)region["size"][0],h=(int)region["size"][1];
        var blocked=region["layers"]["blocked"];var height=region["layers"]["elevationMilli"];var ids=region["presentation"]["tileIndices"];
        Func<int,int,bool> solid=(x,y)=>x>=0&&y>=0&&x<w&&y<h&&(bool)blocked[y*w+x];
        Func<int,int,float> corner=(x,y)=>{
            float sum=0;int count=0;
            for(int dy=-1;dy<=0;dy++)for(int dx=-1;dx<=0;dx++)
                if(x+dx>=0&&y+dy>=0&&x+dx<w&&y+dy<h){sum+=(float)height[(y+dy)*w+x+dx]/1000;count++;}
            return Mathf.Clamp((sum/count-.48f)*9,.65f,4.8f);
        };
        var relief=new GameObject("Relief - shared elevation corners (visual only)");relief.transform.SetParent(root.transform);
        for(int y=0;y<h;y++)
        {
            var top=new Batch();var faces=new Batch();
            for(int x=0;x<w;x++)
            {
                if(!solid(x,y))continue;
                float nw=corner(x,y),ne=corner(x+1,y),sw=corner(x,y+1),se=corner(x+1,y+1);
                Vector3 a=new Vector3(x,h-y+nw),b=new Vector3(x+1,h-y+ne),c=new Vector3(x+1,h-y-1+se),d=new Vector3(x,h-y-1+sw);
                // Coarse directional lighting from semantic slope; no high-frequency visual noise.
                float light=Mathf.Clamp(.94f+(nw-ne)*.27f+(sw-nw)*.20f,.62f,1.15f);
                var tint=new Color(light,light,light,1);
                int id=(int)ids[y*w+x];var uv=new Rect((id%16)*32f/sheet.width,1-(id/16+1)*32f/sheet.height,32f/sheet.width,32f/sheet.height);
                top.Quad(a,b,c,d,uv,tint);
                int variant=id%4;var faceUv=new Rect((variant*32+6f)/128,15f/64,20f/128,30f/64);
                if(!solid(x,y+1))faces.Quad(d,c,new Vector3(x+1,h-y-1),new Vector3(x,h-y-1),faceUv,new Color(.78f,.80f,.73f,1));
                if(!solid(x-1,y))faces.Quad(a,d,new Vector3(x,h-y-1),new Vector3(x,h-y),faceUv,new Color(.89f,.91f,.82f,1));
                if(!solid(x+1,y))faces.Quad(c,b,new Vector3(x+1,h-y),new Vector3(x+1,h-y-1),faceUv,new Color(.61f,.68f,.65f,1));
            }
            int order=100-Mathf.RoundToInt((h-y-1)*16);
            top.Save(relief.transform,destination,"Top_"+y,topMaterial,order);
            faces.Save(relief.transform,destination,"Face_"+y,faceMaterial,order+1);
        }
    }
    sealed class Batch
    {
        readonly List<Vector3> vertices=new List<Vector3>();readonly List<Vector2> uv=new List<Vector2>();
        readonly List<Color> colors=new List<Color>();readonly List<int> indices=new List<int>();
        public void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Rect tex,Color color)
        {
            int n=vertices.Count;vertices.AddRange(new[]{a,b,c,d});
            uv.AddRange(new[]{new Vector2(tex.xMin,tex.yMax),new Vector2(tex.xMax,tex.yMax),new Vector2(tex.xMax,tex.yMin),new Vector2(tex.xMin,tex.yMin)});
            colors.AddRange(new[]{color,color,color,color});indices.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});
        }
        public void Save(Transform parent,string folder,string name,Material material,int sorting)
        {
            if(vertices.Count==0)return;
            var mesh=new Mesh{name=name};mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(indices,0);mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh,folder+"/"+name+".asset");
            var go=new GameObject(name);go.transform.SetParent(parent);go.AddComponent<MeshFilter>().sharedMesh=mesh;
            var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.sortingOrder=sorting;
        }
    }
}
