using UnityEngine;
namespace Mmorpg.Runtime
{
    // For a standalone animated visual prefab. No health, AI or authority.
    public sealed class VisualSpriteLoop : MonoBehaviour
    {
        [SerializeField] private SpriteRenderer visual;
        [SerializeField] private Sprite[] frames;
        [SerializeField,Min(1)] private float fps=6;
        private float clock;
        public void Configure(SpriteRenderer renderer,Sprite[] poses){visual=renderer;frames=poses;}
        private void Update(){if(frames==null||frames.Length==0)return;clock+=Time.deltaTime;visual.sprite=frames[(int)(clock*fps)%frames.Length];}
    }
}
