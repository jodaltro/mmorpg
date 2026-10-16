using UnityEngine;
namespace Mmorpg.Runtime
{
    // Existing cardinal IDs are stable. The new diagonal IDs belong only to opt-in art sets.
    public static class ProductionDirections
    {
        private static readonly int[] Sectors={0,7,3,6,2,5,1,4};
        public static Vector2 Vector(int index)=>index switch
        {
            0=>Vector2.down,1=>Vector2.left,2=>Vector2.up,3=>Vector2.right,
            4=>new Vector2(-1,-1).normalized,5=>new Vector2(-1,1).normalized,
            6=>new Vector2(1,1).normalized,7=>new Vector2(1,-1).normalized,_=>Vector2.right
        };
        public static int Eight(Vector2 facing,int previous,bool stabilize)
        {
            if(facing.sqrMagnitude<.001f)return previous;
            float angle=Mathf.Atan2(facing.x,-facing.y)*Mathf.Rad2Deg;
            if(stabilize&&Vector2.Angle(Vector(previous),facing)<=25.5f)return previous;
            return Sectors[(Mathf.RoundToInt(angle/45)+8)%8];
        }
    }
}
