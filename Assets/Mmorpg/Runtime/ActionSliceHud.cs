using System.Linq;
using Mmorpg.Domain;
using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    public sealed class ActionSliceHud : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private JourneyHud journal;
        [SerializeField] private ActionCombat combat;
        [SerializeField] private TMP_Text techniques, panelText;
        [SerializeField] private GameObject panel;
        private bool inventory, paused, confirmNewJourney;
        [SerializeField] private bool externalPauseMenu;
        public void ConfigureSessionMenu()=>externalPauseMenu=true;
        [SerializeField] private ExplorationWorld exploration;
        public void ConfigureExploration(ExplorationWorld world)=>exploration=world;
        public void Configure(JourneySession story,JourneyHud diary,ActionCombat abilities,TMP_Text bar,TMP_Text secondary,GameObject window)
        {journey=story;journal=diary;combat=abilities;techniques=bar;panelText=secondary;panel=window;}
        private void Update()
        {
            var k=Keyboard.current;if(k==null)return;
            if(externalPauseMenu&&Time.timeScale==0)return;
            if(exploration!=null && exploration.DialogueOpen && k.escapeKey.wasPressedThisFrame){exploration.CloseDialogue();return;}
            if(!externalPauseMenu&&k.escapeKey.wasPressedThisFrame && (exploration==null || !exploration.DialogueOpen)) {paused=!paused;Time.timeScale=paused?0:1;panel.SetActive(paused);inventory=false;confirmNewJourney=false;}
            if(paused && exploration==null && k.nKey.wasPressedThisFrame)
            {
                if(confirmNewJourney) { Time.timeScale=1; journey.NewJourney(); return; }
                confirmNewJourney=true;
            }
            if(!paused)
            {
                if(k.tabKey.wasPressedThisFrame)journal.ToggleJournal();
                if(k.iKey.wasPressedThisFrame) {inventory=!inventory;panel.SetActive(inventory);}
                if(k.eKey.wasPressedThisFrame && (exploration==null || !exploration.HandleInteraction())) journey.RequestInteraction(journey.Nearest());
                if(k.qKey.wasPressedThisFrame) journey.RequestWeakness();
            }
            if(paused && exploration!=null)panelText.text="PAUSA\nEsc: continuar\n\nWASD - explorar  |  E - interagir\nI - inventário  |  Tab - diário\nR após morrer: retomar no ponto seguro";
            else if(paused)panelText.text=confirmNewJourney
                ?"NOVA JORNADA\nN novamente: reiniciar o slice e substituir seu save local\nEsc: cancelar\n\nNão altera outros saves ou o backend."
                :"PAUSA\nEsc: continuar\nR: retornar à vila mantendo a jornada\nN: começar uma nova jornada\n\nCombate local — narrativa via backend";
            else if(inventory && exploration!=null)panelText.text=exploration.InventoryText();
            else if(inventory)panelText.text="INVENTÁRIO  [I]\n\n"+(journey.Engine.HasSample?"Amostra corrompida × 1":"Nenhuma amostra carregada")+"\n\nE junto de Mira: entregar evidência";
            techniques.text=$"Pesado {combat.HeavyRemaining:0.0}s  |  Q Leitura  |  F Contra {(combat.CounterUnlocked?combat.CounterRemaining.ToString("0.0")+"s":"bloqueado")}  |  C Marca {(combat.MarkUnlocked?combat.MarkRemaining.ToString("0.0")+"s":"bloqueada")}";
#if UNITY_EDITOR
            if(k.f9Key.wasPressedThisFrame)combat.ConfigureIsolatedAbilityTest(!combat.TestMode);
            if(combat.TestMode)techniques.text+="\nTESTE ISOLADO: F9 — não grava desbloqueios";
#endif
        }
        private void OnDisable() { if(paused)Time.timeScale=1; }
    }
}
