using Mmorpg.Domain;
using TMPro;
using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class RpgSkillBar : MonoBehaviour
    {
        [SerializeField] private ActorHealth player;
        [SerializeField] private ActionCombat combat;
        [SerializeField] private JourneySession journey;
        [SerializeField] private UnityEngine.UI.Image[] cooldowns;
        [SerializeField] private TMP_Text[] labels;
        public void Configure(ActorHealth actor,ActionCombat abilities,JourneySession story,UnityEngine.UI.Image[] fills,TMP_Text[] captions)
        {player=actor;combat=abilities;journey=story;cooldowns=fills;labels=captions;}
        private void Update()
        {
            double now=Time.timeAsDouble;
            Set(0,player.State.AttackRemaining(now),combat.BasicCooldown,true);
            Set(1,combat.HeavyRemaining,combat.HeavyCooldown,true);
            Set(2,player.State.DodgeRemaining(now),CombatRules.DodgeCooldown,true);
            Set(3,System.Math.Max(0,journey.Weakness.NextUse-now),8,journey.Engine.HasAbility(ForestContent.Technique));
            Set(4,combat.CounterRemaining,ActionCombatRules.CounterCooldown,combat.CounterUnlocked);
            Set(5,combat.MarkRemaining,ActionCombatRules.MarkCooldown,combat.MarkUnlocked);
        }
        private void Set(int i,double seconds,double duration,bool available)
        {cooldowns[i].fillAmount=available?Mathf.Clamp01((float)(seconds/duration)):1;labels[i].color=available?new Color(.94f,.91f,.8f):new Color(.5f,.52f,.55f);}
    }
}
