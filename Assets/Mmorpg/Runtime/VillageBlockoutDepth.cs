using UnityEngine;
using UnityEngine.Rendering;

namespace Mmorpg.Runtime
{
    // Neutral Village02 study: opaque exterior occlusion, independent of collision.
    // The baked base polygon is shared with physics; height never changes the base.
    public sealed class VillageBlockoutDepth : MonoBehaviour
    {
        [SerializeField] Transform actor;
        [SerializeField] SortingGroup group;
        [SerializeField] Vector2[] outline;
        public float DepthLine { get; private set; }
        public void Configure(Transform target, SortingGroup sorting, Vector2[] polygon)
        { actor=target; group=sorting; outline=polygon; }
        public float FrontAt(float x)
        {
            float front=float.PositiveInfinity;
            for(int i=0;i<outline.Length;i++)
            {
                var a=outline[i];var b=outline[(i+1)%outline.Length];
                if(Mathf.Abs(b.x-a.x)<.00001f)continue;
                float t=(x-a.x)/(b.x-a.x);
                if(t>=0&&t<=1)front=Mathf.Min(front,Mathf.Lerp(a.y,b.y,t));
            }
            if(float.IsPositiveInfinity(front))
            { front=outline[0].y;foreach(var p in outline)front=Mathf.Min(front,p.y); }
            return front;
        }
        void LateUpdate()
        {
            if(!actor||!group||outline==null||outline.Length<3)return;
            DepthLine=FrontAt(actor.position.x);
            group.sortingOrder=100-Mathf.RoundToInt(DepthLine*16);
        }
    }
}
