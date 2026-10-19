using UnityEngine;
using UnityEngine.Rendering;

namespace Mmorpg.Runtime
{
    // Exterior-only volume: never fades or turns a roof into traversable ground.
    // The authored ground plane is separate from the visible upper silhouette.
    [DefaultExecutionOrder(1000)]
    public sealed class OpaqueStructureDepth : MonoBehaviour
    {
        [SerializeField] Transform actor;
        [SerializeField] SpriteRenderer actorBody;
        [SerializeField] Collider2D feet;
        [SerializeField] SortingGroup group;
        [SerializeField] Vector2[] outline;
        [SerializeField] Renderer[] visuals;
        public float DepthLine { get; private set; }
        public bool OccludesActor { get; private set; }
        public void Configure(Transform target,SpriteRenderer body,SortingGroup sorting,Vector2[] ground)
        {actor=target;actorBody=body;feet=target.GetComponent<Collider2D>();group=sorting;outline=ground;visuals=GetComponentsInChildren<Renderer>();}
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
            if(float.IsPositiveInfinity(front))foreach(var p in outline)front=Mathf.Min(front,p.y);
            return front;
        }
        void LateUpdate()
        {
            if(!actor||!actorBody||!group||outline==null||outline.Length<3)return;
            // Use the physical feet, never the padded animation canvas, to
            // select the ground side at a corner.
            float half=feet?feet.bounds.extents.x:.28f;
            DepthLine=Mathf.Min(FrontAt(actor.position.x),FrontAt(actor.position.x-half),FrontAt(actor.position.x+half));
            OccludesActor=actor.position.y>DepthLine+.02f;
            int order=100-Mathf.RoundToInt(DepthLine*16);
            bool overlap=false;foreach(var r in visuals)if(r&&r.bounds.Intersects(actorBody.bounds)){overlap=true;break;}
            group.sortingOrder=!overlap?order:OccludesActor?Mathf.Max(order,actorBody.sortingOrder+4):Mathf.Min(order,actorBody.sortingOrder-4);
        }
    }
}
