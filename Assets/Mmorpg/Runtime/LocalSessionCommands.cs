using System;
using System.IO;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;
namespace Mmorpg.Runtime
{
    [DefaultExecutionOrder(-1000)]
    public sealed class LocalSessionCommands : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private ExplorationWorld exploration;
        [SerializeField] private SessionMenuView menu;
        private bool transitioning,paused;
        private static bool overridesBound;
        private static Func<Mmorpg.Domain.IJourneyPersistence> previousFactory;
        private static string previousExplorationDirectory;
        public bool ConfirmationOpen {get;private set;}
        public string LastError {get;private set;}
        public string LastBackup {get;private set;}
        public void Configure(JourneySession story,ExplorationWorld world,SessionMenuView view){journey=story;exploration=world;menu=view;}
        private void Awake()
        {
            Time.timeScale=1;SessionEpoch.Advance();RuntimeDiagnostics.Reset();RuntimeDiagnostics.Configure(journey.NarrativeMode);
            try
            {
                if(!overridesBound){previousFactory=JourneySession.PersistenceFactory;previousExplorationDirectory=ExplorationWorld.ValidationDirectory;overridesBound=true;}
                string directory=LocalJourneyProfile.Root;
                // Bind ownership before opening identity; a corrupt profile never falls back to a personal save.
                JourneySession.PersistenceFactory=()=>new JsonJourneyPersistence(Path.Combine(directory,"journey.json"));
                ExplorationWorld.ValidationDirectory=directory;
                LocalJourneyProfile.Open();
            }
            catch(Exception){journey.enabled=false;exploration.enabled=false;if(journey.WorldEvents!=null)journey.WorldEvents.enabled=false;enabled=false;Debug.LogError("Perfil B4 inválido. Nenhum save original foi alterado.");}
        }
        private void Update()
        {
            var k=Keyboard.current;if(k==null||transitioning)return;
#if UNITY_EDITOR || DEVELOPMENT_BUILD
            if(k.f5Key.wasPressedThisFrame){Restart();return;}
            if(k.rKey.wasPressedThisFrame&&(k.leftCtrlKey.isPressed||k.rightCtrlKey.isPressed)&&(k.leftShiftKey.isPressed||k.rightShiftKey.isPressed)){RequestNewJourney();return;}
#endif
            if(k.escapeKey.wasPressedThisFrame)
            {
                if(exploration.DialogueOpen){exploration.CloseDialogue();return;}
                if(ConfirmationOpen){Continue();return;}
                if(paused)Continue();else{paused=true;Time.timeScale=0;menu.ShowMenu();}
            }
        }
        public void Continue(){ConfirmationOpen=false;paused=false;Time.timeScale=1;menu.Hide();}
        public void RequestNewJourney()
        {
#if UNITY_EDITOR || DEVELOPMENT_BUILD
            if(!OfflineAllowed())return;
            ConfirmationOpen=true;paused=true;Time.timeScale=0;menu.ShowConfirmation(LocalJourneyProfile.IdentityId);
#endif
        }
        private bool OfflineAllowed()
        {
            if(!OnlineSessionRegistry.AnyAuthenticated)return true;
            LastError="Saia explicitamente da sessão online antes de reiniciar a jornada offline.";paused=true;Time.timeScale=0;menu.ShowError(LastError);return false;
        }
        public void Restart()=>Transition(false);
        public void ConfirmNewJourney()
        {
#if UNITY_EDITOR || DEVELOPMENT_BUILD
            if(ConfirmationOpen)Transition(true);
#endif
        }
        private void Transition(bool reset)
        {
            if(transitioning||!OfflineAllowed())return;
            transitioning=true;
            try
            {
                SessionEpoch.Advance();journey.CancelPendingForTransition();
                journey.SaveOrThrow();journey.FlushPersistenceOrThrow();exploration.SaveOrThrow();
                // OnDisable must not re-create the old journey after the allowlist has been reset.
                journey.SuspendPersistence();exploration.SuspendPersistence();
                if(reset)LastBackup=LocalJourneyProfile.BackupAndReset();
                ConfirmationOpen=false;Time.timeScale=1;
                SceneManager.LoadScene(SceneManager.GetActiveScene().path);
            }
            catch(Exception ex)
            {
                journey.ResumePersistence();exploration.ResumePersistence();transitioning=false;
                LastError="Reinício cancelado; dados preservados. "+ex.GetType().Name;paused=true;Time.timeScale=0;menu.ShowError(LastError);
            }
        }
        private void OnDestroy()
        {
            Time.timeScale=1;if(transitioning||!overridesBound)return;
            JourneySession.PersistenceFactory=previousFactory;ExplorationWorld.ValidationDirectory=previousExplorationDirectory;overridesBound=false;
        }
    }
}
