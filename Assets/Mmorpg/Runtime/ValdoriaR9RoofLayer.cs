using UnityEngine;
namespace Mmorpg.Runtime
{
    [DefaultExecutionOrder(111)]
    public sealed class ValdoriaR9RoofLayer : MonoBehaviour
    {
        [SerializeField] SpriteRenderer wall;
        [SerializeField] SpriteRenderer roof;
        public void Configure(SpriteRenderer wallRenderer, SpriteRenderer roofRenderer) { wall = wallRenderer; roof = roofRenderer; }
        private void LateUpdate()
        {
            if (wall == null || roof == null) return;
            roof.sortingLayerID = wall.sortingLayerID;
            roof.sortingOrder = wall.sortingOrder + 1;
        }
    }

}
