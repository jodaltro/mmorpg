using UnityEngine;
namespace Mmorpg.Runtime
{
    // Immutable authored semantic source. Rendering and collision are baked separately.
    public sealed class TerrainRegionData : MonoBehaviour
    {
        [SerializeField] private TextAsset worldRegion;
        public TextAsset WorldRegion => worldRegion;
        public void Configure(TextAsset source)=>worldRegion=source;
    }
}
