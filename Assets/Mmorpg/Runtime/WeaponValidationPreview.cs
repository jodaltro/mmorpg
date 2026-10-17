using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    // Opt-in R7 presentation study. No inventory, damage, projectile or persistence authority.
    [DefaultExecutionOrder(60)]
    public sealed class WeaponValidationPreview : MonoBehaviour
    {
        [SerializeField] private ProductionSpriteAnimator animator;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private PlayerController controller;
        [SerializeField] private ActionCombat combat;
        [SerializeField] private ActionSliceHud hud;
        [SerializeField] private ActorHealth health;
        [SerializeField] private ActorMotor motor;
        [SerializeField] private Rigidbody2D body;
        [SerializeField] private SpriteRenderer blade;
        [SerializeField] private Sprite[] bowFrames;
        [SerializeField] private TMP_Text hint;
        [SerializeField] private CameraFollow cameraFollow;
        [SerializeField] private Transform defaultCameraTarget,bowCameraFocus;
        [SerializeField] private bool reportPreviewFacing;
        private bool animatorWasEnabled,controllerWasEnabled,combatWasEnabled,hudWasEnabled,swordWasEnabled,bladeWasActive;
        private Sprite originalSprite;
        private double started;
        private int ignoreInputThrough;
        public bool BowSelected {get;private set;}
        public bool Playing {get;private set;}
        public int ViewIndex {get;private set;}
        public int PoseIndex {get;private set;}
        public void Configure(ProductionSpriteAnimator art,SwordSwing weapon,PlayerController input,ActionCombat abilities,ActionSliceHud interfaceHud,ActorHealth actor,SpriteRenderer equipped,Sprite[] frames,TMP_Text label)
        {animator=art;sword=weapon;controller=input;combat=abilities;hud=interfaceHud;health=actor;motor=actor.GetComponent<ActorMotor>();body=actor.GetComponent<Rigidbody2D>();blade=equipped;bowFrames=frames;hint=label;}
        public void ConfigureFraming(CameraFollow follow,Transform original,Transform focus){cameraFollow=follow;defaultCameraTarget=original;bowCameraFocus=focus;}
        public void ConfigureStateFacing(bool report)=>reportPreviewFacing=report;
        private void Awake(){health.Changed+=OnHealthChanged;hint.gameObject.SetActive(false);}
        public string SelectBow(int view)
        {
            if(!health.State.IsAlive)return "Retome após a morte antes de validar uma arma.";
            if(sword.Busy||combat.Committed||health.State.IsDodging(Time.timeAsDouble))return "Conclua o golpe ou a esquiva antes de trocar. Esc para continuar.";
            if(bowFrames==null||bowFrames.Length!=74)return "Prévia do arco indisponível.";
            if(!BowSelected)
            {
                originalSprite=animator.Body.sprite;animatorWasEnabled=animator.enabled;controllerWasEnabled=controller.enabled;combatWasEnabled=combat.enabled;hudWasEnabled=hud.enabled;swordWasEnabled=sword.enabled;bladeWasActive=blade.gameObject.activeSelf;
                animator.enabled=false;controller.enabled=false;combat.enabled=false;hud.enabled=false;sword.enabled=false;blade.gameObject.SetActive(false);motor.SetIntent(Vector2.zero,0);body.linearVelocity=Vector2.zero;BowSelected=true;
                if(cameraFollow!=null&&bowCameraFocus!=null)cameraFollow.Configure(bowCameraFocus);
            }
            ViewIndex=Mathf.Clamp(view,0,1);Playing=false;PoseIndex=0;ignoreInputThrough=Time.frameCount+1;ShowFrame();
            if(reportPreviewFacing)animator.SetPreviewFacing(ViewIndex==0?0:3);
            hint.text="ARCO · "+(ViewIndex==0?"frontal":"lateral")+"   |   Clique / J: puxada   |   V: vista   |   Esc: armas\nValidação estacionária de pose · sem projéteis";hint.gameObject.SetActive(true);return null;
        }
        public void SelectSword()
        {
            if(!BowSelected)return;
            BowSelected=false;Playing=false;
            // During scene unload the HUD or visual children may already be destroyed.
            if(animator!=null){if(animator.Body!=null)animator.Body.sprite=originalSprite;animator.enabled=animatorWasEnabled;}
            if(controller!=null)controller.enabled=controllerWasEnabled;
            if(combat!=null)combat.enabled=combatWasEnabled;
            if(hud!=null)hud.enabled=hudWasEnabled;
            if(sword!=null)sword.enabled=swordWasEnabled;
            if(blade!=null)blade.gameObject.SetActive(bladeWasActive);
            if(blade!=null&&health!=null&&!health.State.IsAlive)blade.enabled=false;
            if(hint!=null)hint.gameObject.SetActive(false);
            if(motor!=null)motor.SetIntent(Vector2.zero,0);
            if(cameraFollow!=null&&defaultCameraTarget!=null)cameraFollow.Configure(defaultCameraTarget);
        }
        public void PlayDraw(){if(!BowSelected||Playing||Time.timeScale==0)return;started=Time.timeAsDouble;PoseIndex=0;Playing=true;}
        private void ShowFrame()=>animator.Body.sprite=bowFrames[ViewIndex*37+PoseIndex];
        private void OnHealthChanged(){if(BowSelected){SelectSword();if(reportPreviewFacing&&animator!=null)animator.RefreshConfirmedState();}}
        private void Update()
        {
            if(!BowSelected||Time.timeScale==0)return;
            var k=Keyboard.current;
            if(Time.frameCount>ignoreInputThrough)
            {
                if(k?.vKey.wasPressedThisFrame==true)SelectBow(1-ViewIndex);
                bool click=Mouse.current?.leftButton.wasPressedThisFrame==true&&(EventSystem.current==null||!EventSystem.current.IsPointerOverGameObject());
                if(k?.jKey.wasPressedThisFrame==true||click)PlayDraw();
            }
            if(Playing){int pose=(int)((Time.timeAsDouble-started)*24);if(pose>=37){Playing=false;PoseIndex=0;}else PoseIndex=pose;}
            ShowFrame();
        }
        private void OnDisable(){if(BowSelected)SelectSword();}
        private void OnDestroy(){if(health!=null)health.Changed-=OnHealthChanged;}
    }
}
