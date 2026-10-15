using UnityEngine;
namespace Mmorpg.Runtime
{
    [DefaultExecutionOrder(110)]
    public sealed class SpriteGroundShadow : MonoBehaviour
    {
        [SerializeField] private SpriteRenderer owner,shadow;
        public void Configure(SpriteRenderer body,SpriteRenderer projection){owner=body;shadow=projection;}
        private void LateUpdate(){shadow.sortingOrder=owner.sortingOrder-1;shadow.enabled=owner.enabled&&owner.color.a>.05f;}
    }
}
