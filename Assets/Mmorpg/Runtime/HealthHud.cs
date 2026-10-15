using TMPro;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public sealed class HealthHud : MonoBehaviour
    {
        [SerializeField] private GameSession session;
        [SerializeField] private UnityEngine.UI.Image healthFill;
        [SerializeField] private TMP_Text healthText;
        [SerializeField] private TMP_Text statusText;
        [SerializeField] private bool actionMode;
        public void ConfigureAction() => actionMode=true;
        public void Configure(GameSession value, UnityEngine.UI.Image fill, TMP_Text health, TMP_Text status)
        { session = value; healthFill = fill; healthText = health; statusText = status; }
        [SerializeField] private ExplorationWorld exploration;
        public void ConfigureExploration(ExplorationWorld world)=>exploration=world;
        private void Update()
        {
            var player = session.Player.State;
            healthFill.fillAmount = (float)player.Health / player.MaximumHealth;
            healthText.text = $"VIDA  {player.Health} / {player.MaximumHealth}";
            if(exploration!=null){statusText.text=player.IsAlive?"":"VOC? MORREU\nR: retomar no ponto seguro";return;}
            if(actionMode) {statusText.text=!player.IsAlive?"VOCÊ MORREU\nR: retornar à vila":session.Player.transform.position.x<0?"VALDORIA · COMBATE LOCAL":"FLORESTA CINZENTA · COMBATE LOCAL";return;}
            statusText.text = !player.IsAlive ? "VOCE MORREU\nR para reiniciar"
                : !session.Wolf.State.IsAlive ? "LOBO CORROMPIDO DERROTADO\nExplore e converse"
                : $"CLAREIRA OFFLINE\nLobo: {session.Wolf.State.Health} / {session.Wolf.State.MaximumHealth}";
        }
    }
}
