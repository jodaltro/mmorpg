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
        private LineRenderer sweep,blade,grip;private bool shown,wasBusy;
        private Vector2 lastSample;private int sampledFrame=-1;
        public float MaximumActiveTipError {get;private set;}
        public void Configure(SwordSwing value)=>sword=value;
        private LineRenderer Line(string name,Color color,float width)
        {var go=new GameObject(name);go.transform.SetParent(transform,false);var line=go.AddComponent<LineRenderer>();line.sharedMaterial=new Material(Shader.Find("Sprites/Default"));line.startColor=line.endColor=color;line.startWidth=line.endWidth=width;line.sortingOrder=2000;line.useWorldSpace=true;return line;}
        private void Awake(){sweep=Line("Physical Sweep",Color.cyan,.025f);blade=Line("Rendered Blade",Color.yellow,.035f);grip=Line("Grip",Color.magenta,.035f);sword.SweepSampled+=Sample;}
        private void Sample(Vector2 hand,Vector2 tip){if(physical.Count>=160)physical.Dequeue();physical.Enqueue(tip);lastSample=tip;sampledFrame=Time.frameCount;}
        private void LateUpdate()
        {
            if(Keyboard.current?.f7Key.wasPressedThisFrame==true)shown=!shown;
            if(sword.Busy&&!wasBusy){physical.Clear();visual.Clear();}wasBusy=sword.Busy;
            if(sword.Active)
            {
                if(visual.Count>=160)visual.Dequeue();float a=sword.VisualAngle*Mathf.Deg2Rad;var tip=sword.GripWorld+new Vector3(Mathf.Cos(a),Mathf.Sin(a))*sword.BladeLength;visual.Enqueue(tip);
                if(sampledFrame==Time.frameCount)MaximumActiveTipError=Mathf.Max(MaximumActiveTipError,Vector2.Distance(lastSample,tip));
            }
            sweep.enabled=blade.enabled=grip.enabled=shown;
            if(!shown)return;sweep.positionCount=physical.Count;sweep.SetPositions(physical.ToArray());blade.positionCount=2;
            float angle=sword.VisualAngle*Mathf.Deg2Rad;blade.SetPositions(new[]{sword.GripWorld,sword.GripWorld+new Vector3(Mathf.Cos(angle),Mathf.Sin(angle))*sword.BladeLength});
            grip.positionCount=13;for(int i=0;i<13;i++){float a=i/12f*Mathf.PI*2;grip.SetPosition(i,sword.GripWorld+new Vector3(Mathf.Cos(a),Mathf.Sin(a))*.07f);}
        }
        private void OnDestroy(){if(sword!=null)sword.SweepSampled-=Sample;foreach(var l in new[]{sweep,blade,grip})if(l!=null)Destroy(l.sharedMaterial);}
#else
        public void Configure(SwordSwing value)=>sword=value;
#endif
    }
}
