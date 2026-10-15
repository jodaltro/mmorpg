using UnityEngine;
namespace Mmorpg.Runtime
{
    [DefaultExecutionOrder(120)]
    public sealed class SwordPresentationEffects : MonoBehaviour
    {
        [SerializeField] private SwordSwing sword;
        [SerializeField] private ActorHealth health;
        [SerializeField] private SpriteRenderer body,slash,dust;
        [SerializeField] private Sprite[] dustFrames;
        private bool wasDodging;
        private double dustAt=double.NegativeInfinity;
        public void Configure(SwordSwing weapon,ActorHealth actor,SpriteRenderer character,SpriteRenderer arc,SpriteRenderer ground,Sprite[] frames)
        {sword=weapon;health=actor;body=character;slash=arc;dust=ground;dustFrames=frames;}
        private void LateUpdate()
        {
            bool dodging=health.State.IsDodging(Time.timeAsDouble);
            if(dodging&&!wasDodging){dustAt=Time.timeAsDouble;dust.transform.position=health.transform.position+Vector3.down*.52f;}
            wasDodging=dodging;
            slash.enabled=health.State.IsAlive&&sword.Active;
            if(slash.enabled)
            {
                float a=sword.VisualAngle*Mathf.Deg2Rad;
                slash.transform.position=sword.GripWorld+new Vector3(Mathf.Cos(a),Mathf.Sin(a),0)*sword.BladeLength*.6f;
                slash.transform.rotation=Quaternion.Euler(0,0,sword.VisualAngle);slash.sortingOrder=body.sortingOrder+2;
            }
            int frame=(int)((Time.timeAsDouble-dustAt)*18);
            dust.enabled=frame>=0&&frame<dustFrames.Length;
            if(dust.enabled){dust.sprite=dustFrames[frame];dust.sortingOrder=body.sortingOrder-2;}
        }
    }
}
