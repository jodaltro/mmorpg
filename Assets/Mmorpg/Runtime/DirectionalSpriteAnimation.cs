using UnityEngine;
namespace Mmorpg.Runtime
{
    // Presentation only: row 0 idle, rows 1/2 locomotion, eight mouse-facing directions.
    public sealed class DirectionalSpriteAnimation : MonoBehaviour
    {
        [SerializeField] private ActorMotor motor;
        [SerializeField] private ActorHealth health;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private SpriteRenderer visual;
        [SerializeField] private Sprite[] frames;
        [SerializeField, Min(1)] private float framesPerSecond=8;
        public void Configure(ActorMotor movement,ActorHealth actor,SpriteRenderer sprite,Sprite[] art,SwordSwing weapon=null)
        {motor=movement;health=actor;visual=sprite;frames=art;sword=weapon;}
        private void LateUpdate()
        {
            if(frames==null||frames.Length<24)return;
            Vector2 aim=sword!=null?(sword.Busy?sword.AttackDirection:sword.AimDirection):motor.Facing;
            int direction=(Mathf.RoundToInt((-Mathf.Atan2(aim.y,aim.x)*Mathf.Rad2Deg-90)/45)+16)%8;
            bool moving=health.State.IsAlive&&motor.Direction.sqrMagnitude>.01f;
            int row=moving?1+(int)(Time.time*framesPerSecond)%2:0;
            visual.sprite=frames[row*8+direction];visual.flipX=false;
        }
    }
}
