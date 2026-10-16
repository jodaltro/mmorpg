using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    // The cyan samples come from the actual overlap loop, not a reconstructed animation.
    [DefaultExecutionOrder(130)]
    public sealed class SwordSweepDebug : MonoBehaviour
    {
        [SerializeField] private SwordSwing sword;
#if UNITY_EDITOR || DEVELOPMENT_BUILD
        private readonly Queue<Vector3> physical=new Queue<Vector3>(),visual=new Queue<Vector3>();
        private LineRenderer sweep,blade,grip,origin;private UnityEngine.UI.Text legend;private bool shown,wasBusy;
        private Vector2 lastOrigin,lastSample;private int sampledFrame=-1;
        public float MaximumActiveTipError {get;private set;}
        public int ConfirmedHits {get;private set;}
        public float LastTargetDistance {get;private set;}=-1;
        private OfflineAuthority authority;private ActorHealth actor;
        private void BeginTrace(){physical.Clear();visual.Clear();MaximumActiveTipError=0;ConfirmedHits=0;LastTargetDistance=-1;wasBusy=true;}
        private void Hit(ActorHealth attacker,ActorHealth target){if(attacker!=actor)return;ConfirmedHits++;var collider=target.GetComponent<Collider2D>();Vector2 root=actor.GetComponent<Rigidbody2D>().position;LastTargetDistance=Vector2.Distance(root,collider!=null?collider.ClosestPoint(root):(Vector2)target.transform.position);}
        public void Configure(SwordSwing value)=>sword=value;
        private LineRenderer Line(string name,Color color,float width)
        {var go=new GameObject(name);go.transform.SetParent(transform,false);var line=go.AddComponent<LineRenderer>();line.sharedMaterial=new Material(Shader.Find("Sprites/Default"));line.startColor=line.endColor=color;line.startWidth=line.endWidth=width;line.sortingOrder=2000;line.useWorldSpace=true;return line;}
        private void Awake(){sweep=Line("Physical Sweep",Color.cyan,.025f);blade=Line("Rendered Blade",Color.yellow,.035f);grip=Line("Grip",Color.magenta,.035f);origin=Line("Actual Physical Segment",Color.green,.035f);sword.SweepSampled+=Sample;actor=GetComponent<ActorHealth>();authority=FindAnyObjectByType<OfflineAuthority>();if(authority!=null)authority.HitConfirmed+=Hit;
            var canvasObject=new GameObject("Sweep Legend",typeof(Canvas));canvasObject.transform.SetParent(transform,false);var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;canvas.sortingOrder=3000;
            var label=new GameObject("Legend",typeof(RectTransform),typeof(UnityEngine.UI.Text));label.transform.SetParent(canvasObject.transform,false);legend=label.GetComponent<UnityEngine.UI.Text>();legend.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");legend.fontSize=16;legend.raycastTarget=false;legend.supportRichText=true;legend.alignment=TextAnchor.UpperLeft;var rect=legend.rectTransform;rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(12,-120);rect.sizeDelta=new Vector2(570,95);}
        private void Sample(Vector2 hand,Vector2 tip){if(sword.Busy&&!wasBusy)BeginTrace();if(physical.Count>=160)physical.Dequeue();physical.Enqueue(tip);lastOrigin=hand;lastSample=tip;sampledFrame=Time.frameCount;}
        private void LateUpdate()
        {
            if(Keyboard.current?.f7Key.wasPressedThisFrame==true)shown=!shown;
            if(sword.Busy&&!wasBusy)BeginTrace();wasBusy=sword.Busy;
            if(sword.Active)
            {
                if(visual.Count>=160)visual.Dequeue();var tip=sword.VisualTipWorld;visual.Enqueue(tip);
                if(sampledFrame==Time.frameCount)MaximumActiveTipError=Mathf.Max(MaximumActiveTipError,Vector2.Distance(lastSample,tip));
            }
            sweep.enabled=blade.enabled=grip.enabled=origin.enabled=shown;legend.enabled=shown;
            if(!shown)return;
            legend.text="F7  <color=magenta>Mao visual</color> / <color=yellow>Lamina visual</color>\n<color=cyan>Pontas reais amostradas</color> / <color=lime>Segmento fisico real</color>\n"+sword.OriginPolicy+"  alcance="+sword.AuthorizedRange.ToString("F2")+"  separacao das pontas="+MaximumActiveTipError.ToString("F2")+"\nHitConfirmed="+ConfirmedHits+"  distancia ao collider confirmado="+(LastTargetDistance<0?"--":LastTargetDistance.ToString("F2"));
            origin.positionCount=2;origin.SetPositions(new[]{(Vector3)lastOrigin,(Vector3)lastSample});
            sweep.positionCount=physical.Count;sweep.SetPositions(physical.ToArray());blade.positionCount=2;
            blade.SetPositions(new[]{sword.GripWorld,sword.VisualTipWorld});
            grip.positionCount=13;for(int i=0;i<13;i++){float a=i/12f*Mathf.PI*2;grip.SetPosition(i,sword.GripWorld+new Vector3(Mathf.Cos(a),Mathf.Sin(a))*.07f);}
        }
        private void OnDestroy(){if(authority!=null)authority.HitConfirmed-=Hit;if(sword!=null)sword.SweepSampled-=Sample;foreach(var l in new[]{sweep,blade,grip,origin})if(l!=null)Destroy(l.sharedMaterial);}
#else
        public void Configure(SwordSwing value)=>sword=value;
#endif
    }
}
