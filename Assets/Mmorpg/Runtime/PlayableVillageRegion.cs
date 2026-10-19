using UnityEngine;
namespace Mmorpg.Runtime
{
    // Baked semantic region. No artwork or geometry is generated during Play.
    public sealed class PlayableVillageRegion : MonoBehaviour
    {
        [SerializeField] TextAsset layout;
        [SerializeField] Vector2 spawn;
        [SerializeField] Rect bounds;
        public TextAsset Layout => layout;
        public Vector2 Spawn => spawn;
        public Rect Bounds => bounds;
        public void Configure(TextAsset source, Vector2 start, Rect limits)
        { layout=source; spawn=start; bounds=limits; }
    }
}
