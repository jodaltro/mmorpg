using UnityEngine;
namespace Mmorpg.Runtime
{
    // Direction order: south, west, north, east. Art data contains no gameplay rules.
    [CreateAssetMenu(menuName="Mmorpg/Gameplay Sprite Set")]
    public sealed class GameplaySpriteSet : ScriptableObject
    {
        public Sprite[] idle, walkA, walkB, attackA, attackB, dodge, hurt, death;
        [Min(1)] public float walkFps=8;
        [Min(.01f)] public float hurtSeconds=.12f, deathSeconds=.45f;
        public Sprite At(Sprite[] poses,int direction,Sprite fallback)
            => poses!=null && direction<poses.Length && poses[direction]!=null?poses[direction]:fallback;
    }
}
