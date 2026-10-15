using System.Collections;
using Mmorpg.Domain;
using TMPro;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public sealed class WorldEventSession : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private SpriteRenderer clueVisual;
        [SerializeField] private TMP_Text noticeText, clueText;
        [SerializeField] private WorldEventSettings settings=new WorldEventSettings();
        [SerializeField] private DecisionMode decisionMode=DecisionMode.Deterministic;
        [SerializeField] private string endpoint="http://127.0.0.1:8091/v1/decisions/evaluate";
        [SerializeField, Range(1,35)] private int timeoutSeconds=8;
        private double nextTick, nextCheckpoint;
        private bool deciding;
        private long presentedRevision=-1;
        private long eligibilityRevision=-1;
        private int eligibilityInputs=-1;
        public WorldEventOrchestrator World { get; private set; }
        public bool DecisionPending => deciding;
        public void CancelPendingForTransition(){StopAllCoroutines();deciding=false;}
        public void Configure(JourneySession value,SpriteRenderer clue,TMP_Text notice,TMP_Text label) { journey=value; clueVisual=clue; noticeText=notice; clueText=label; }
        public void ResetForNewJourney() { StopAllCoroutines(); deciding=false; World=null; }
        public void ConfigureDecisions(DecisionMode mode,string url,int timeout=8) { decisionMode=mode; endpoint=url; timeoutSeconds=timeout; }
        public void Initialize(JourneySnapshot saved,IWorldClock testClock=null)
        {
            StopAllCoroutines(); deciding=false;
            var snapshot=journey.Engine.Snapshot(); var clock=testClock??new WorldClock(saved?.world?.gameTime??0);
            World=saved?.world==null?new WorldEventOrchestrator(snapshot.actorId,snapshot.worldId,clock,settings):WorldEventOrchestrator.Restore(saved.world,journey.Engine,clock);
            nextTick=Time.unscaledTimeAsDouble+1; nextCheckpoint=Time.unscaledTimeAsDouble+5;
            OnJourneyChanged(); RefreshPresentation();
        }
        public void OnJourneyChanged()
        {
            if(World==null) return;
            bool changed=World.Synchronize(journey.Engine)|World.Tick(journey.Engine);
            if(changed) journey.Save();
            var evaluation=World.PendingEvaluation();var inputs=journey.Engine.Snapshot().inputs;
            if(eligibilityRevision!=World.Revision||eligibilityInputs!=inputs.Count)
            {eligibilityRevision=World.Revision;eligibilityInputs=inputs.Count;RuntimeDiagnostics.Trace(inputs.Count>0?inputs[inputs.Count-1].eventId:null,"EligibilityCandidates",(evaluation?.candidates.Count??0).ToString());}
            if(!deciding&&evaluation!=null) { deciding=true; StartCoroutine(Resolve(World,journey.Engine)); }
        }
        private IEnumerator Resolve(WorldEventOrchestrator world,JourneyEngine engine)
        {
            long epoch=SessionEpoch.Current;
            yield return new WorldDecisionCoordinator(new WorldDecisionClient(decisionMode,endpoint,timeoutSeconds)).Resolve(world,engine,()=>epoch==SessionEpoch.Current&&isActiveAndEnabled&&World==world&&journey.Engine==engine,changed=>{
                if(epoch!=SessionEpoch.Current)return;
                deciding=false; if(changed&&World==world&&journey.Engine==engine) { journey.Save(); RefreshPresentation(); }
            });
        }
        public bool ConverseWithOrin()
        {
            if(World==null) return false;
            bool changed=World.Interact(ForestContent.Orin,journey.Engine); OnJourneyChanged(); journey.Save(); return changed;
        }
        public bool IsAvailable(InteractionKind kind) => World!=null&&(kind==InteractionKind.NoticeBoard||kind==InteractionKind.NewTracks&&World.ClueVisible);
        public bool Interact(InteractionKind kind) { bool changed=World.Interact(kind==InteractionKind.NoticeBoard?"notice-board":WorldEventContent.Tracks,journey.Engine); OnJourneyChanged(); return changed; }
        public string InteractionMessage(InteractionKind kind) => kind==InteractionKind.NoticeBoard?(World.NoticePublished?"Quadro da vila: Mira confirmou resina corrompida. Cuidado com a ameaça na floresta.":"Quadro da vila: nenhum aviso confirmado sobre a floresta."):"Novos vestígios: resina recente em marcas diferentes. Compartilhe a descoberta com Orin.";
        private void Update()
        {
            if(World==null||Time.unscaledTimeAsDouble<nextTick) return;
            nextTick=Time.unscaledTimeAsDouble+1; OnJourneyChanged(); RefreshPresentation();
            if(Time.unscaledTimeAsDouble>=nextCheckpoint) { nextCheckpoint=Time.unscaledTimeAsDouble+5; journey.Save(); }
        }
        private void RefreshPresentation()
        {
            if(World==null) return;
            var state=World.Snapshot();
            RuntimeDiagnostics.Observe(state.scheduled.FindAll(e=>!e.executed&&!e.cancelled).Count,state.opportunities.Find(o=>o.status==WorldOpportunityStatus.Started)?.id,World.Revision);
            if(presentedRevision!=World.Revision){presentedRevision=World.Revision;RuntimeDiagnostics.Trace(state.decisions.Count>0?state.decisions[state.decisions.Count-1].eventId:null,"Presentation","WorldRefresh");}
            clueVisual.enabled=World.ClueVisible; clueText.enabled=World.ClueVisible;
            noticeText.text=World.NoticePublished?"QUADRO DA VILA\nNovo aviso · E para ler":"QUADRO DA VILA\nE para consultar";
        }
        private void OnDisable() { StopAllCoroutines(); deciding=false; if(World!=null&&journey!=null) { World.Tick(journey.Engine); journey.Save(); journey.FlushPersistence(); } }
    }
}
