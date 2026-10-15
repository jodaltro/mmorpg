using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class WorldArtSorting : MonoBehaviour
    {
        [SerializeField] private SpriteRenderer visual;
        [SerializeField] private Transform anchor;
        public void Configure(SpriteRenderer sprite,Transform groundAnchor){visual=sprite;anchor=groundAnchor;}
        private void LateUpdate()=>visual.sortingOrder=100-Mathf.RoundToInt(anchor.position.y*16);
    }
}
