using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class ActionTargetVisual : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private ActionCombat combat;
        [SerializeField] private ActorHealth target;
        [SerializeField] private SpriteRenderer indicator;
        [SerializeField] private Sprite weaknessArt,hunterArt;
        public void ConfigureArt(Sprite weakness,Sprite hunter){weaknessArt=weakness;hunterArt=hunter;}
        public void Configure(JourneySession story,ActionCombat abilities,ActorHealth actor,SpriteRenderer mark) {journey=story;combat=abilities;target=actor;indicator=mark;}
        private void LateUpdate()
        {
            bool weakness=journey.IsWeaknessMarked(target),hunter=combat.MarkedTarget==target;
            indicator.enabled=target.State.IsAlive&&(weakness||hunter);
            if(weaknessArt!=null&&hunterArt!=null){indicator.sprite=weakness?weaknessArt:hunterArt;indicator.color=Color.white;}
            else indicator.color=weakness?Color.yellow:Color.cyan;
            indicator.transform.position=target.transform.position+Vector3.up*.85f;
        }
    }
}
