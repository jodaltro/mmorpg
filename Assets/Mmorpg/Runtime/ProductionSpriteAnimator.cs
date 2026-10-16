using UnityEngine;
namespace Mmorpg.Runtime
{
    // Input -> body/frame/grip (40) -> physical Sweep (50) -> weapon LateUpdate -> effects (120).
    [DefaultExecutionOrder(40)]
    public sealed class ProductionSpriteAnimator : MonoBehaviour
    {
        [SerializeField] private ProductionCharacterSet art;
        [SerializeField] private ActorMotor motor;
        [SerializeField] private ActorHealth health;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private SpriteRenderer visual;
        [SerializeField] private ProductionCharacterStates characterStates;
        public void ConfigureStates(ProductionCharacterStates value)=>characterStates=value;
        private Rigidbody2D body;
        private float walkTime, stillTime, dodgeTime;
        public ProductionFrame CurrentFrame { get; private set; }
        public string State { get; private set; } = "idle";
        public int DirectionIndex { get; private set; }
        public Vector2 VisualFacing => DirectionIndex == 0 ? Vector2.down : DirectionIndex == 1 ? Vector2.left : DirectionIndex == 2 ? Vector2.up : Vector2.right;
        public SpriteRenderer Body => visual;
        public event System.Action<string> VisualEvent;
        public void Configure(ProductionCharacterSet set, ActorHealth actor, SpriteRenderer renderer, SwordSwing weapon)
        { art=set; health=actor; motor=actor.GetComponent<ActorMotor>(); visual=renderer; sword=weapon; }
        private void Awake() { body=motor.GetComponent<Rigidbody2D>(); Select("idle",0,0); }
        private void Select(string action, int direction, float time)
        {
            var clip=art.Find(action,direction)??art.Find("idle",direction);
            var next=clip?.At(time); bool changed=next!=CurrentFrame; CurrentFrame=next;
            if(next!=null) { visual.sprite=next.sprite; if(changed)foreach(string marker in next.events)OnProductionVisualEvent(marker); }
            visual.flipX=false; State=action; DirectionIndex=direction;
        }
        private int MapDirection(Vector2 facing, bool stabilize)
        {
            if(facing.sqrMagnitude<.001f)return DirectionIndex;
            float x=Mathf.Abs(facing.x), y=Mathf.Abs(facing.y);
            // A small angular dead band, not a timer: immediate changes away from diagonals.
            if(stabilize && Mathf.Abs(x-y)<Mathf.Max(x,y)*.15f && Vector2.Dot(VisualFacing,facing)>0)return DirectionIndex;
            return x>y ? (facing.x<0?1:3) : (facing.y>0?2:0);
        }
        private void Update()
        {
            if(art==null||body==null)return;
            if(characterStates!=null&&characterStates.TrySelect(art,Time.timeAsDouble,out string confirmedAction,out int confirmedDirection,out float confirmedTime))
            {Select(confirmedAction,confirmedDirection,confirmedTime);return;}
            if(!health.State.IsAlive)return;
            bool dodging=health.State.IsDodging(Time.timeAsDouble);
            // Sword Update ends the strike later in this frame. Use the same confirmed clock
            // so its terminal recovery pose and the weapon cannot disagree for one frame.
            bool attacking=sword.Busy&&sword.AttackProgress<1;
            bool moving=motor.MovementDirection.sqrMagnitude>.01f&&body.linearVelocity.sqrMagnitude>.04f;
            Vector2 facing=dodging ? motor.MovementDirection : attacking ? sword.AttackDirection : moving ? body.linearVelocity : VisualFacing;
            int d=MapDirection(facing,!attacking);
            string action="idle"; float time=0;
            if(dodging) { action="dodge"; dodgeTime+=Time.deltaTime; time=dodgeTime; }
            else if(attacking)
            {
                dodgeTime=0;
                string phase=sword.VisualPhase;
                var phaseClip=art.Find("attack-"+phase,d);
                var attack=art.Find("attack",d);
                action=phaseClip!=null ? "attack-"+phase : "attack";
                if(phaseClip!=null)time=sword.PhaseProgress*Mathf.Max(0,phaseClip.Duration-.00001f);
                else if(attack!=null)
                {
                    // Existing two stances: ready during windup, final stance through recovery.
                    // Longer legacy clips play by authored durations across the confirmed strike.
                    time=attack.frames.Length<=2 ? (phase=="preparation"?0:Mathf.Max(0,attack.Duration-.00001f)) : sword.AttackProgress*Mathf.Max(0,attack.Duration-.00001f);
                }
            }
            else if(moving)
            {
                dodgeTime=0; stillTime=0; action="walk";
                walkTime+=Time.deltaTime*Mathf.Clamp(body.linearVelocity.magnitude/art.referenceSpeed,.2f,1.8f); time=walkTime;
            }
            else { dodgeTime=0; stillTime+=Time.deltaTime; if(stillTime>.18f)walkTime=0; }
            Select(action,d,time);
            if(attacking&&!dodging)State="attack-"+sword.VisualPhase;
        }
        public void OnProductionVisualEvent(string marker)=>VisualEvent?.Invoke(marker);
    }
}
