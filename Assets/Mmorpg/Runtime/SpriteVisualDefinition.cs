using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class SpriteVisualDefinition : MonoBehaviour
    {
        [SerializeField] private GameplaySpriteSet sprites;
        [SerializeField] private SpriteRenderer visual;
        public GameplaySpriteSet Sprites=>sprites;
        public SpriteRenderer Renderer=>visual;
        public void Configure(GameplaySpriteSet set,SpriteRenderer renderer){sprites=set;visual=renderer;}
    }
}
