using System.Collections.Generic;
using Mmorpg.Domain;
using UnityEngine;

namespace Mmorpg.Runtime
{
    // Spatial adapter for the existing offline authority, shared by every player melee strike.
    [DefaultExecutionOrder(50)]
    public sealed class SwordSwing : MonoBehaviour
    {
        public enum SweepOriginPolicy { LegacyGrip, PlanarSweepOrigin }
        [SerializeField] private SweepOriginPolicy sweepOriginPolicy;
        public SweepOriginPolicy OriginPolicy => sweepOriginPolicy;
        public void ConfigureSweepOrigin(SweepOriginPolicy policy) { if(Busy)throw new System.InvalidOperationException("Cannot change sweep policy during a strike"); sweepOriginPolicy=policy; }
        public Vector2 PhysicalOriginWorld => Origin+PhysicalGrip(aim);
        public float AuthorizedRange => range;
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private ActorHealth actor;
        [SerializeField] private ActorMotor motor;
        [SerializeField] private SpriteRenderer body, blade;
        [SerializeField] private Transform hand;
        [SerializeField, Min(.02f)] private float activeDuration=.14f, recovery=.16f;
        [SerializeField, Range(30,160)] private float arc=110;
        [SerializeField, Min(.02f)] private float bladeWidth=.12f;
        [SerializeField] private Vector2 handOffset=new Vector2(.25f,.12f);
        [SerializeField] private float handDrop=.1f;
        [SerializeField] private Vector2[] preparedGrips;
        [SerializeField] private ProductionSpriteAnimator production;
        public void ConfigureProduction(ProductionSpriteAnimator value)=>production=value;
#if UNITY_EDITOR || DEVELOPMENT_BUILD
        public event System.Action<Vector2,Vector2> SweepSampled;
#endif
        // Authored presentation offsets. Legacy physics retains the original grip contract.
        public void ConfigureArtGrips(Vector2[] offsets)=>preparedGrips=offsets;
        private readonly Collider2D[] contacts=new Collider2D[48];
        private readonly HashSet<ActorHealth> damaged=new HashSet<ActorHealth>();
        private ContactFilter2D filter;
        private double started;
        private float preparation, range, previousProgress,attackStartAngle;
        private Vector2 aim, previousOrigin,previousGrip;
        private ActionStrike strike;
        private bool hit;
        private Rigidbody2D physicsBody;
        public bool Busy {get;private set;}
        public float VisualAngle {get;private set;}
        public Vector3 GripWorld => hand.position;
        // Manifest tip relative to imported grip pivot: (57-31,45-24)/32.
        public Vector3 VisualTipWorld => blade.transform.TransformPoint(new Vector3(26f/32,21f/32,0));
        public float BladeLength => Vector3.Distance(GripWorld,VisualTipWorld);
        public float SweepLength => Busy ? range-.25f : 0;
        public Vector2 AimDirection => motor.AimDirection;
        public Vector2 AttackDirection => aim;
        public float Elapsed => Busy ? Mathf.Max(0,(float)(Time.timeAsDouble-started)) : 0;
        public float AttackProgress => Mathf.Clamp01(Elapsed/Mathf.Max(.001f,preparation+activeDuration+recovery));
        public float PhaseProgress => !Busy ? 0 : VisualPhase=="preparation" ? Mathf.Clamp01(Elapsed/Mathf.Max(.001f,preparation)) : VisualPhase=="cut" ? Mathf.Clamp01((Elapsed-preparation)/activeDuration) : Mathf.Clamp01((Elapsed-preparation-activeDuration)/recovery);
        public bool Active => Busy && Time.timeAsDouble>=started+preparation && Time.timeAsDouble<started+preparation+activeDuration;
        public string VisualPhase=>!Busy?"idle":Time.timeAsDouble<started+preparation?"preparation":Time.timeAsDouble<started+preparation+activeDuration?"cut":"recovery";
        public string Feedback {get;private set;}="";
        public event System.Action<string> FeedbackProduced;
        public void Configure(OfflineAuthority server,ActorHealth owner,ActorMotor movement,SpriteRenderer character,Transform pivot,SpriteRenderer sword)
        {authority=server;actor=owner;motor=movement;body=character;hand=pivot;blade=sword;}
        private void Awake(){filter.SetLayerMask(1<<9);filter.useTriggers=true;physicsBody=actor.GetComponent<Rigidbody2D>();}
        public bool Begin(ActorHealth owner,Vector2 facing,float reach,ActionStrike kind,float windup)
        {
            if(Busy || owner!=actor || !actor.State.IsAlive || actor.State.IsDodging(Time.timeAsDouble) || facing.sqrMagnitude<.001f)return false;
            Busy=true;started=Time.timeAsDouble;preparation=windup;range=reach;aim=facing.normalized;strike=kind;
            attackStartAngle=VisualAngle;
            previousProgress=0;previousOrigin=Origin;previousGrip=PhysicalGrip(aim);damaged.Clear();hit=false;
            Feedback="";FeedbackProduced?.Invoke("attack");authority.NotifySwordAttack(actor,aim);return true;
        }
        private Vector2 Origin => physicsBody.position;
        // Planar policy has zero calibration offset: physical root, independent of art/sector.
        // The existing range-.25 capsule length and root-distance/LOS gates remain unchanged.
        private Vector2 PhysicalGrip(Vector2 facing)=>sweepOriginPolicy==SweepOriginPolicy.LegacyGrip?Grip(Vector2.zero,facing):Vector2.zero;
        private Vector2 Grip(Vector2 center,Vector2 facing)
        {
            if(production!=null&&production.CurrentFrame!=null)
                return center+(Vector2)(production.Body.transform.TransformPoint(production.CurrentFrame.hand)-transform.position);
            if(preparedGrips!=null&&preparedGrips.Length==4)
            {
                int direction=Mathf.Abs(facing.x)>Mathf.Abs(facing.y)?(facing.x<0?1:3):(facing.y>0?2:0);
                return center+preparedGrips[direction];
            }
            return center+new Vector2(facing.x*handOffset.x-facing.y*handOffset.y,facing.y*handOffset.y-handDrop);
        }
        private void Update()
        {
            if(!Busy)return;
            if(!actor.State.IsAlive || actor.State.IsDodging(Time.timeAsDouble)) {Busy=false;FeedbackProduced?.Invoke("cancel");return;}
            float elapsed=(float)(Time.timeAsDouble-started);
            float progress=Mathf.Clamp01((elapsed-preparation)/activeDuration);
            if(elapsed>=preparation && previousProgress<1) Sweep(previousProgress,progress,previousOrigin,Origin);
            previousProgress=progress;previousOrigin=Origin;previousGrip=PhysicalGrip(aim);
            if(elapsed>=preparation+activeDuration+recovery)
            {Busy=false;Feedback=hit?"Acerto":"Sem acerto";FeedbackProduced?.Invoke(hit?"hit":"miss");}
        }
        private void Sweep(float from,float to,Vector2 oldOrigin,Vector2 origin)
        {
            // Sample the complete swept interval even on slow frames. Blade capsule includes
            // a padding covering the gap between angular/translation samples.
            int steps=Mathf.Max(1,Mathf.CeilToInt((to-from)*arc/3),Mathf.CeilToInt(Vector2.Distance(oldOrigin,origin)/.04f));
            for(int i=0;i<=steps;i++)
            {
                float u=i/(float)steps;float angle=Mathf.Atan2(aim.y,aim.x)*Mathf.Rad2Deg+Mathf.Lerp(-arc/2,arc/2,Mathf.Lerp(from,to,u));
                var direction=new Vector2(Mathf.Cos(angle*Mathf.Deg2Rad),Mathf.Sin(angle*Mathf.Deg2Rad));
                Vector2 center=Vector2.Lerp(oldOrigin,origin,u),grip=center+Vector2.Lerp(previousGrip,PhysicalGrip(aim),u),tip=grip+direction*(range-.25f);
#if UNITY_EDITOR || DEVELOPMENT_BUILD
                SweepSampled?.Invoke(grip,tip);
#endif
                Vector2 delta=tip-grip;float width=bladeWidth+.04f;
                int count=Physics2D.OverlapCapsule((grip+tip)*.5f,new Vector2(delta.magnitude+width,width),CapsuleDirection2D.Horizontal,Mathf.Atan2(delta.y,delta.x)*Mathf.Rad2Deg,filter,contacts);
                for(int j=0;j<count;j++)
                {
                    var target=contacts[j].GetComponentInParent<ActorHealth>();
                    if(target==null || target==actor || damaged.Contains(target) || !target.State.IsAlive || target.Faction==actor.Faction)continue;
                    Vector2 point=contacts[j].ClosestPoint(center);
                    if(Vector2.Distance(center,point)>range+width || !authority.HasLineOfSight(center,point) || !authority.HasLineOfSight(grip,point))continue;
                    damaged.Add(target);if(authority.ResolveDamage(actor,target,strike))hit=true;
                }
            }
        }
        private void LateUpdate()
        {
            Vector2 facing=Busy?aim:motor.Facing;
            float elapsed=(float)(Time.timeAsDouble-started),offset=0;
            if(Busy)offset=elapsed<preparation?Mathf.Lerp(-arc*.3f,-arc/2,Mathf.Clamp01(elapsed/preparation)):
                elapsed<preparation+activeDuration?Mathf.Lerp(-arc/2,arc/2,(elapsed-preparation)/activeDuration):Mathf.Lerp(arc/2,0,(elapsed-preparation-activeDuration)/recovery);
            VisualAngle=Mathf.Atan2(facing.y,facing.x)*Mathf.Rad2Deg+offset;
            if(production!=null&&production.CurrentFrame!=null)
            {
                float baseAngle=Mathf.Atan2(facing.y,facing.x)*Mathf.Rad2Deg;
                if(!Busy)VisualAngle=production.CurrentFrame.holdAngle;
                else if(elapsed<preparation)VisualAngle=Mathf.LerpAngle(attackStartAngle,baseAngle-arc/2,Mathf.Clamp01(elapsed/Mathf.Max(.001f,preparation)));
                else if(elapsed>=preparation+activeDuration)VisualAngle=Mathf.LerpAngle(baseAngle+arc/2,production.CurrentFrame.holdAngle,Mathf.SmoothStep(0,1,Mathf.Clamp01((elapsed-preparation-activeDuration)/recovery)));
            }
            hand.position=(Vector2)transform.position+Grip(Vector2.zero,facing);hand.rotation=Quaternion.Euler(0,0,VisualAngle);
            hand.localScale=Vector3.one;
            blade.sortingOrder=body.sortingOrder+(production!=null&&production.CurrentFrame!=null?production.CurrentFrame.depth:(facing.y>.25f?-1:1));blade.enabled=actor.State.IsAlive;
            blade.color=Busy && elapsed>=preparation && elapsed<preparation+activeDuration?new Color(1,1,.65f):Color.white;
        }
    }
}
