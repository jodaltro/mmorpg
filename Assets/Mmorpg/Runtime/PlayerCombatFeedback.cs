using TMPro;
using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class PlayerCombatFeedback : MonoBehaviour
    {
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private ActorHealth player;
        [SerializeField] private ActorMotor motor;
        [SerializeField] private SpriteRenderer character;
        [SerializeField] private Sprite[] walkFrames;
        [SerializeField] private LineRenderer trail, impact;
        [SerializeField] private TMP_Text notice;
        [SerializeField] private AudioSource audioSource;
        [SerializeField] private AudioClip stepAudio,attackAudio,hitAudio,dodgeAudio,deathAudio;
        public event System.Action<string> AudioRequested;
        private double trailUntil,impactUntil,noticeUntil,nextStep;
        private bool dodging;
        [SerializeField] private bool sheetArt;
        [SerializeField] private bool preparedVfx;
        public void ConfigurePreparedVfx()=>preparedVfx=true;
        public void ConfigureSheetArt(){sheetArt=true;walkFrames=System.Array.Empty<Sprite>();}
        public void Configure(OfflineAuthority server,SwordSwing weapon,ActorHealth owner,ActorMotor movement,SpriteRenderer sprite,Sprite[] frames,LineRenderer slash,LineRenderer burst,TMP_Text text,AudioSource source)
        {authority=server;sword=weapon;player=owner;motor=movement;character=sprite;walkFrames=frames;trail=slash;impact=burst;notice=text;audioSource=source;}
        private void OnEnable(){authority.HitConfirmed+=Hit;sword.FeedbackProduced+=Feedback;player.Changed+=Damage;}
        private void OnDisable(){if(authority!=null)authority.HitConfirmed-=Hit;if(sword!=null)sword.FeedbackProduced-=Feedback;if(player!=null)player.Changed-=Damage;}
        private void Play(string cue,AudioClip clip){AudioRequested?.Invoke(cue);if(clip!=null)audioSource.PlayOneShot(clip);}
        private void Damage(){notice.text="Dano recebido";noticeUntil=Time.timeAsDouble+.65;}
        private void Feedback(string cue)
        {if(cue=="attack") {trailUntil=Time.timeAsDouble+.65;Play(cue,attackAudio);}if(cue=="miss"){notice.text="Sem acerto · ajuste a distância ou a direção";noticeUntil=Time.timeAsDouble+.7;}}
        private void Hit(ActorHealth attacker,ActorHealth target)
        {
            if(attacker!=player)return;
            impactUntil=Time.timeAsDouble+.14;
            for(int i=0;i<8;i++){float a=i*Mathf.PI/4;impact.SetPosition(i,target.transform.position+new Vector3(Mathf.Cos(a),Mathf.Sin(a),0)*(i%2==0?.4f:.12f));}
            impact.sortingOrder=target.GetComponent<SpriteRenderer>().sortingOrder+3;
            notice.text=target.State.IsAlive?"Acerto":"Inimigo derrotado";noticeUntil=Time.timeAsDouble+.7;Play(target.State.IsAlive?"hit":"death",target.State.IsAlive?hitAudio:deathAudio);
        }
        private void LateUpdate()
        {
            double now=Time.timeAsDouble;
            bool moving=motor.Direction.sqrMagnitude>.01f && player.State.IsAlive;
            if(walkFrames.Length>0)character.sprite=walkFrames[moving?(int)(Time.time*9)%walkFrames.Length:0];
            if(!sheetArt)character.flipX=motor.Facing.x<-.1f;
            if(moving&&now>=nextStep){nextStep=now+.25;Play("step",stepAudio);}
            bool dodge=player.State.IsDodging(now);if(dodge&&!dodging)Play("dodge",dodgeAudio);dodging=dodge;
            trail.enabled=!preparedVfx && sword.Active && now<trailUntil;
            if(trail.enabled){for(int i=0;i<10;i++){float a=(sword.VisualAngle-i*3)*Mathf.Deg2Rad;trail.SetPosition(i,sword.GripWorld+new Vector3(Mathf.Cos(a),Mathf.Sin(a),0)*sword.BladeLength);}trail.sortingOrder=character.sortingOrder+2;}
            impact.enabled=!sheetArt && now<impactUntil;
            if(now>=noticeUntil)notice.text="";
        }
    }
}
