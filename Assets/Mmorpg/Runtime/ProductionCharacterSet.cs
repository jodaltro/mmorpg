using System;
using UnityEngine;
namespace Mmorpg.Runtime
{
    [CreateAssetMenu(menuName="Mmorpg/Production Character")]
    public sealed class ProductionCharacterSet : ScriptableObject
    {
        public string characterId;
        public float pixelsPerUnit=32, referenceSpeed=3.5f;
        public ProductionClip[] clips=Array.Empty<ProductionClip>();
        public ProductionClip Find(string action,int direction)=>Array.Find(clips,c=>c.action==action&&c.direction==direction);
    }
    [Serializable] public sealed class ProductionClip
    {
        public string action,status;
        public int direction;
        public bool loop;
        public ProductionFrame[] frames=Array.Empty<ProductionFrame>();
        public float Duration {get {float t=0;foreach(var f in frames)t+=f.seconds;return t;}}
        public ProductionFrame At(float time)
        {
            if(frames.Length==0)return null;
            float t=loop?Mathf.Repeat(time,Mathf.Max(.001f,Duration)):Mathf.Max(0,time);
            foreach(var f in frames){if(t<f.seconds)return f;t-=f.seconds;}return frames[frames.Length-1];
        }
    }
    [Serializable] public sealed class ProductionFrame
    {
        public Sprite sprite;
        public Vector2 hand;
        public float seconds=.1f,holdAngle;
        public int depth=1;
        public string source;
        public string[] events=Array.Empty<string>();
    }
}
