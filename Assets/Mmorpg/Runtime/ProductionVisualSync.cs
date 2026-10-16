using UnityEngine;
namespace Mmorpg.Runtime
{
    // Keep existing gameplay/feedback references on the physical root, render the body on a child.
    [DefaultExecutionOrder(110)]
    public sealed class ProductionVisualSync : MonoBehaviour
    {
        [SerializeField] private SpriteRenderer proxy,body;
        [SerializeField] private bool holdAnimatedDeath;
        public void ConfigureAnimatedDeath(bool hold)=>holdAnimatedDeath=hold;
        private double diedAt=-1;
        public void Configure(SpriteRenderer source,SpriteRenderer destination){proxy=source;body=destination;}
        private void LateUpdate()
        {
            var color=proxy.color;var health=proxy.GetComponent<ActorHealth>();
            if(health!=null&&!health.State.IsAlive)
            {
                if(holdAnimatedDeath)color=Color.white;
                else {if(diedAt<0)diedAt=Time.timeAsDouble;color.a*=1-Mathf.Clamp01((float)(Time.timeAsDouble-diedAt)/.45f);}
            }
            else diedAt=-1;
            body.color=color;body.sortingLayerID=proxy.sortingLayerID;body.sortingOrder=proxy.sortingOrder;body.enabled=proxy.enabled;
        }
    }
}
