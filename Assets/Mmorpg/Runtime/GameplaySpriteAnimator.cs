using UnityEngine;
namespace Mmorpg.Runtime
{
    // Observes confirmed state only. Never moves the physical root or causes damage.
    [DefaultExecutionOrder(100)]
    public sealed class GameplaySpriteAnimator : MonoBehaviour
    {
        [SerializeField] private GameplaySpriteSet art;
        [SerializeField] private ActorMotor motor;
        [SerializeField] private ActorHealth health;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private WolfBrain wolf;
        [SerializeField] private SpatialCreatureBrain creature;
        [SerializeField] private SpriteRenderer visual;
        private double hurtUntil, deathAt;
        private float walkClock;
        private bool wasAlive=true;
        private Rigidbody2D body;
        public string PresentationState {get;private set;}="idle";
        public int DirectionIndex {get;private set;}
        public void Configure(GameplaySpriteSet set,ActorMotor movement,ActorHealth actor,SpriteRenderer renderer,SwordSwing weapon=null)
        {art=set;motor=movement;health=actor;visual=renderer;sword=weapon;wolf=actor.GetComponent<WolfBrain>();creature=actor.GetComponent<SpatialCreatureBrain>();}
        private void OnEnable(){if(health!=null)health.Changed+=Damaged;}
        private void Awake(){if(motor!=null)body=motor.GetComponent<Rigidbody2D>();}
        private void OnDisable(){if(health!=null)health.Changed-=Damaged;}
        private void Damaged()=>hurtUntil=Time.timeAsDouble+art.hurtSeconds;
        private static int Direction(Vector2 v)=>Mathf.Abs(v.x)>Mathf.Abs(v.y)?(v.x<0?1:3):(v.y>0?2:0);
        private void LateUpdate()
        {
            if(art==null||motor==null||health==null||visual==null)return;
            double now=Time.timeAsDouble;
            bool moving=motor.Direction.sqrMagnitude>.01f && body!=null && body.linearVelocity.sqrMagnitude>.04f;
            Vector2 facing=sword!=null?sword.AimDirection:motor.Facing;
            if(health.State.IsDodging(now)&&motor.Direction.sqrMagnitude>.01f)facing=motor.Direction;
            DirectionIndex=Direction(facing);
            var idle=art.At(art.idle,DirectionIndex,visual.sprite);
            Sprite frame=idle;string state="idle";
            if(!health.State.IsAlive)
            {
                if(wasAlive)deathAt=now;
                state="death";
                if(art.death!=null&&art.death.Length>0)frame=art.death[Mathf.Min(art.death.Length-1,(int)((now-deathAt)/art.deathSeconds*art.death.Length))];
                // No invented death drawing: absent native death uses a timed fade.
                else {var color=visual.color;color.a=Mathf.Lerp(.55f,0,Mathf.Clamp01((float)(now-deathAt)/art.deathSeconds));visual.color=color;}
            }
            else if(now<hurtUntil){state="hurt";frame=art.At(art.hurt,DirectionIndex,idle);}
            else if(health.State.IsDodging(now)){state="dodge";frame=art.At(art.dodge,DirectionIndex,idle);}
            else if(sword!=null && sword.Busy)
            {
                state=sword.Active?"attack-active":"attack-stance";
                frame=art.At(sword.Active?art.attackB:art.attackA,DirectionIndex,idle);
            }
            else if(wolf!=null&&(wolf.Mode==WolfMode.Windup||wolf.Mode==WolfMode.Charge))
            {state=wolf.Mode==WolfMode.Windup?"windup":"attack-active";frame=art.At(wolf.Mode==WolfMode.Charge?art.attackB:art.attackA,DirectionIndex,idle);}
            else if(creature!=null && creature.Mode==CreatureMode.Windup)
            {state="windup";frame=art.At(art.attackA,DirectionIndex,idle);}
            else if(moving)
            {
                state="walk";walkClock+=Time.deltaTime;
                frame=art.At(((int)(walkClock*art.walkFps)&1)==0?art.walkA:art.walkB,DirectionIndex,idle);
            }
            if(state!="walk")walkClock=0;
            visual.sprite=frame;visual.flipX=false;PresentationState=state;wasAlive=health.State.IsAlive;
        }
    }
}
