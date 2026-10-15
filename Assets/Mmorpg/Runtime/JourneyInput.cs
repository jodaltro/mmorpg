using UnityEngine;
using UnityEngine.InputSystem;

namespace Mmorpg.Runtime
{
    public sealed class JourneyInput : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private JourneyHud hud;
        public void Configure(JourneySession value,JourneyHud view) { journey=value; hud=view; }
        private void Update()
        {
            var k=Keyboard.current; if(k==null) return;
            if(k.tabKey.wasPressedThisFrame) hud.ToggleJournal();
            if(k.nKey.wasPressedThisFrame) journey.NewJourney();
            if(k.eKey.wasPressedThisFrame) journey.RequestInteraction(journey.Nearest());
            if(k.qKey.wasPressedThisFrame) journey.RequestWeakness();
        }
    }
}
