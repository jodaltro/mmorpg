using System;
using System.Linq;
using Mmorpg.Domain;
using UnityEngine;
using EventType = Mmorpg.Domain.EventType;

namespace Mmorpg.Runtime
{
    public sealed class JourneySession : MonoBehaviour
    {
        public const string Encounter="clearing-wolf-01";
        public const string ObservationEncounter="clearing-wolf-observation";
        public string CurrentEncounter => Engine.Defeated(Encounter)&&Engine.OrinBriefed&&Engine.Status(ForestContent.RouteB)!=OpportunityStatus.Unknown&& !Engine.Snapshot().facts.Any(e=>e.eventType==EventType.CreatureDefeated&&e.creature.encounterId==Encounter&&e.creature.observed)?ObservationEncounter:Encounter;
        public static Func<IJourneyPersistence> PersistenceFactory;
        [SerializeField] private GameSession session;
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private JourneyInteractable[] interactions;
        [SerializeField] private SpriteRenderer sampleVisual;
        [SerializeField] private SpriteRenderer markVisual;
        [SerializeField] private TrainingDummy trainingDummy;
        public void ConfigureTrainingDummy(TrainingDummy value) => trainingDummy=value;
        [SerializeField] private WeaknessParameters weaknessParameters=new WeaknessParameters();
        [SerializeField] private DecisionMode decisionMode=DecisionMode.Deterministic;
        [SerializeField] private string decisionEndpoint="http://127.0.0.1:8091/v1/decisions/evaluate";
        [SerializeField, Range(1,35)] private int decisionTimeoutSeconds=8;
        [SerializeField] private WorldEventSession worldEvents;
        public WorldEventSession WorldEvents => worldEvents;
        public void ConfigureWorldEvents(WorldEventSession value,JourneyInteractable[] targets) { worldEvents=value; interactions=targets; }
        private bool deciding;
        [SerializeField] private string isolatedSaveName;
        public void ConfigureIsolatedSave(string name) => isolatedSaveName = name;
        public bool DecisionPending => deciding;
        public DecisionMode NarrativeMode => decisionMode;
        public void ConfigureDecisions(DecisionMode mode,string endpoint,int timeoutSeconds=8)
        { decisionMode=mode; decisionEndpoint=endpoint; decisionTimeoutSeconds=timeoutSeconds; }
        private IJourneyPersistence persistence;
        private bool savingBlocked;
        private bool persistenceSuspended;
        public void SuspendPersistence()=>persistenceSuspended=true;
        public void ResumePersistence()=>persistenceSuspended=false;
        public void FlushPersistenceOrThrow(){if(persistence is QueuedJourneyPersistence queue)queue.Flush();}
        public void CancelPendingForTransition(){StopAllCoroutines();deciding=false;worldEvents?.CancelPendingForTransition();}
        public JourneyEngine Engine { get; private set; }
        public WeaknessReading Weakness { get; private set; }
        public string Message { get; private set; }="Explore a clareira. E: interagir perto de pessoas e rastros.";
        public ActorHealth Player => session.Player;
        public ActorHealth Wolf => session.Wolf;
        public JourneyInteractable[] Interactions => (JourneyInteractable[])interactions.Clone();
        public void Configure(GameSession game,OfflineAuthority server,JourneyInteractable[] targets,SpriteRenderer sample,SpriteRenderer mark)
        { session=game; authority=server; interactions=targets; sampleVisual=sample; markVisual=mark; }
        private void Awake() { Engine=new JourneyEngine(); Weakness=new WeaknessReading(weaknessParameters); }
        private void OnEnable() { authority.HitConfirmed+=OnHit; authority.PreparedAttackDodged+=OnPreparedDodge; }
        private void OnDisable() { if(authority!=null) { authority.HitConfirmed-=OnHit; authority.PreparedAttackDodged-=OnPreparedDodge; } StopAllCoroutines(); deciding=false; FlushPersistence(); }
        public void FlushPersistence()
        {
            if(!(persistence is QueuedJourneyPersistence queue)) return;
            try {queue.Flush();} catch(Exception ex) {Debug.LogWarning("Falha ao concluir save: "+ex.Message);}
        }
        private void OnApplicationQuit() {if(persistence is QueuedJourneyPersistence){Save();FlushPersistence();}}
        private void Start()
        {
            persistence=PersistenceFactory?.Invoke()??new JsonJourneyPersistence(System.IO.Path.Combine(Application.persistentDataPath,string.IsNullOrEmpty(isolatedSaveName)?"journey-v1.json":isolatedSaveName));
            if(!string.IsNullOrEmpty(isolatedSaveName) && persistence is JsonJourneyPersistence) persistence=new QueuedJourneyPersistence(persistence);
            if(!string.IsNullOrEmpty(isolatedSaveName)) Message="Valdoria. Converse com Mira; caminhe até a floresta e investigue a corrupção.";
            Continue();
        }
        public void Continue()
        {
            StopAllCoroutines(); deciding=false; worldEvents?.ResetForNewJourney();
            try
            {
                var saved=persistence.Load(); Engine=saved==null?new JourneyEngine():JourneyEngine.Restore(saved); savingBlocked=false;
                if(Engine.Defeated(CurrentEncounter)&&Wolf.State.IsAlive) Wolf.RestoreDefeated();
                if(persistence is JsonJourneyPersistence local&&local.RecoveryMessage!=null) Message=local.RecoveryMessage;
                worldEvents?.Initialize(saved);
                ResolveMira();
            }
            catch(Exception ex) { savingBlocked=true; Message="Não foi possível continuar: "+ex.Message+" Use N para nova jornada."; Debug.LogWarning(Message); }
        }
        public void NewJourney()
        {
            var fresh=new JourneyEngine();
            try { persistence.Save(fresh.Snapshot()); savingBlocked=false; worldEvents?.ResetForNewJourney(); Engine=fresh; session.Restart(); }
            catch(Exception ex) { Message="Nova jornada não foi salva: "+ex.Message; Debug.LogWarning(Message); }
        }
        private GameEvent Event(EventType type,string source) => new GameEvent{eventId=Guid.NewGuid().ToString("N"),eventType=type,actorId=ForestContent.Actor,worldId=ForestContent.World,sourceId=source,timestamp=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()};
        private bool Submit(GameEvent fact)
        {
            if(!Engine.ApplyValidated(fact)) return false;
            RuntimeDiagnostics.Fact(fact.eventId,fact.eventType.ToString());
            ActionDebugTrace.Record("FATO CONFIRMADO", fact.eventType.ToString());
            worldEvents?.OnJourneyChanged(); Save(fact.eventId); return true;
        }
        public JourneySnapshot CaptureSnapshot() { var snapshot=Engine.Snapshot(); if(worldEvents!=null&&worldEvents.World!=null) { snapshot.version=3; snapshot.world=worldEvents.World.Snapshot(); } return snapshot; }
        public void Save(string correlation=null)
        {
            if(savingBlocked||persistenceSuspended||persistence==null) return;
            try { SaveOrThrow(correlation); }
            catch(Exception ex) { Message="Falha ao salvar; estado mantido em memória: "+ex.Message; Debug.LogWarning(Message); }
        }
        public void SaveOrThrow(string correlation=null)
        {
            if(savingBlocked||persistence==null)throw new System.IO.InvalidDataException("Save da jornada bloqueado");
            if(persistenceSuspended)return;
            var snapshot=CaptureSnapshot();correlation=correlation??snapshot.facts.LastOrDefault()?.eventId;
            try
            {
                if(persistence is QueuedJourneyPersistence queue){RuntimeDiagnostics.Persist(correlation,"local / enfileirado");queue.Save(snapshot,correlation);}
                else {persistence.Save(snapshot);RuntimeDiagnostics.Persist(correlation,"local / salvo");}
            }
            catch{RuntimeDiagnostics.Persist(correlation,"erro local");throw;}
        }
        private void ResolveMira()
        {
            if(deciding||Engine.PendingMiraDecision()==null) return;
            deciding=true;
            StartCoroutine(ResolveMiraRoutine(Engine));
        }
        private System.Collections.IEnumerator ResolveMiraRoutine(JourneyEngine requestedEngine)
        {
            long epoch=SessionEpoch.Current;
            var client=new LocalDecisionClient(decisionMode,decisionEndpoint,decisionTimeoutSeconds);
            yield return new MiraDecisionOrchestrator(client).Resolve(requestedEngine,()=>epoch==SessionEpoch.Current&&isActiveAndEnabled&&Engine==requestedEngine,applied=>{
                if(epoch!=SessionEpoch.Current||Engine!=requestedEngine) return;
                deciding=false;
                if(applied)
                {
                    string previous=Message;
                    string correlation=Engine.Snapshot().decisions.LastOrDefault()?.eventId;
                    Save(correlation);
                    if(Message==previous&&previous.StartsWith("Mira:",StringComparison.Ordinal)) Message=Engine.Dialogue(ForestContent.Mira);
                    RuntimeDiagnostics.Trace(correlation,"Presentation","MiraUpdated");
                }
            });
        }
        private void OnHit(ActorHealth attacker,ActorHealth target)
        {
            if(attacker==Player&&trainingDummy!=null&&target==trainingDummy.Health&&worldEvents?.World?.Status(WorldEventContent.Training)==WorldOpportunityStatus.Started) { var training=Event(EventType.CombatActionVerified,"combat"); training.combat=new CombatPayload{actionId=CombatActions.TrainingHit,encounterId="training-session",targetId=TrainingDummy.TargetId}; Submit(training); }
            if(attacker!=Player||target!=Wolf||target.State.IsAlive) return;
            var fact=Event(EventType.CreatureDefeated,"combat"); fact.creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId=CurrentEncounter};
            if(Submit(fact)) Message="Lobo corrompido derrotado. Há uma amostra junto ao corpo. E para coletar.";
        }
        private void OnPreparedDodge(ActorHealth attacker,ActorHealth target,string attackId)
        {
            if(attacker!=Wolf||target!=Player) return;
            var fact=Event(EventType.CombatActionVerified,"combat"); fact.combat=new CombatPayload{actionId=CombatActions.PreparedDodge,encounterId=CurrentEncounter,targetId=ForestContent.Wolf,preparedAttackId=attackId}; Submit(fact);
        }
        public bool RequestWeakness()
        {
            var candidates=authority.ActionMode?UnityEngine.Object.FindObjectsByType<ActorHealth>(FindObjectsSortMode.None).Where(t=>t.Faction!=Faction.Player).ToArray():trainingDummy==null?new[]{Wolf}:new[]{Wolf,trainingDummy.Health};
            var target=candidates.Where(t=>t.State.IsAlive&&Vector2.Distance(Player.transform.position,t.transform.position)<=Weakness.Range&&authority.HasLineOfSight(Player.transform.position,t.transform.position))
                .OrderBy(t=>Vector2.Distance(Player.transform.position,t.transform.position)).FirstOrDefault();
            float distance=target==null?float.PositiveInfinity:Vector2.Distance(Player.transform.position,target.transform.position);
            bool accepted=Weakness.TryMark(Engine.HasAbility(ForestContent.Technique)||Player.GetComponent<ActionCombat>()?.TestMode==true,Player.State.IsAlive,TargetId(target),target!=null,distance,Time.timeAsDouble);
            Message=accepted?"Leitura de Fraquezas: alvo marcado. O próximo acerto recebe bônus.":"Leitura indisponível: técnica, alvo, alcance ou cooldown.";
            return accepted;
        }
        private string TargetId(ActorHealth target) => target==null?null:target==Wolf?CurrentEncounter:trainingDummy!=null&&target==trainingDummy.Health?TrainingDummy.TargetId:authority.ActionMode?target.name:null;
        public int AttackBonus(ActorHealth attacker,ActorHealth target,double now) => attacker==Player?Weakness.Bonus(TargetId(target),now):0;
        public void ConfirmAttackBonus(ActorHealth attacker,ActorHealth target,double now) { if(attacker==Player) Weakness.ConfirmHit(TargetId(target),now); }
        public bool IsWeaknessMarked(ActorHealth target) => target != null && Weakness.Marked(Time.timeAsDouble) == TargetId(target);
        public bool IsAvailable(JourneyInteractable item)
        {
            if(item!=null&&(item.Kind==InteractionKind.NoticeBoard||item.Kind==InteractionKind.NewTracks)) return worldEvents!=null&&worldEvents.IsAvailable(item.Kind);
            return item!=null&& (item.Kind!=InteractionKind.Sample||Engine.Defeated(Encounter)&&!Engine.HasSample&&!Engine.Snapshot().delivered.Contains(ForestContent.Sample));
        }
        public JourneyInteractable Nearest()
        { return interactions.Where(IsAvailable).Where(i=>Vector2.Distance(Player.transform.position,i.transform.position)<=i.Range && authority.HasLineOfSight(Player.transform.position,i.transform.position,i.GetComponent<Collider2D>())).OrderBy(i=>Vector2.Distance(Player.transform.position,i.transform.position)).FirstOrDefault(); }
        public bool RequestInteraction(JourneyInteractable item)
        {
            if(!Player.State.IsAlive||item==null||!interactions.Contains(item)||!IsAvailable(item)||Vector2.Distance(Player.transform.position,item.transform.position)>item.Range||!authority.HasLineOfSight(Player.transform.position,item.transform.position,item.GetComponent<Collider2D>())) return false;
            GameEvent fact;
            switch(item.Kind)
            {
                case InteractionKind.Passage:
                    Message="Passagem para a Floresta Cinzenta. Continue caminhando pelo caminho; atenção aos preparos das criaturas."; return true;
                case InteractionKind.NoticeBoard:
                case InteractionKind.NewTracks:
                    bool worldChanged=worldEvents.Interact(item.Kind); Message=worldEvents.InteractionMessage(item.Kind); Save(); return worldChanged;
                case InteractionKind.Trace:
                    fact=Event(EventType.TraceExamined,ForestContent.Trace); fact.trace=new TracePayload{traceId=ForestContent.Trace};
                    bool examined=Submit(fact); Message="Rastros: pegadas profundas e resina escura. Orin pode interpretá-las."; return examined;
                case InteractionKind.Sample:
                    fact=Event(EventType.EvidenceCollected,"sample-drop"); fact.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId=Encounter};
                    bool collected=Submit(fact); Message="Amostra coletada. Mira pode investigar a corrupção."; return collected;
                default:
                    string npc=item.Kind==InteractionKind.Mira?ForestContent.Mira:ForestContent.Orin;
                    // First talk establishes contact. A subsequent deliberate interaction delivers.
                    bool talked=Engine.Snapshot().facts.Any(e=>e.eventType==EventType.NpcInteracted&&e.npc.npcId==npc);
                    if(npc==ForestContent.Mira&&talked&&Engine.HasSample)
                    { fact=Event(EventType.EvidenceDelivered,npc); fact.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId=Encounter,recipientId=npc}; }
                    else { fact=Event(EventType.NpcInteracted,npc); fact.npc=new NpcPayload{npcId=npc,sharedFact=npc==ForestContent.Orin&&Engine.HasTrace?ForestContent.Trace:null}; }
                    bool changed=Submit(fact);
                    if(npc==ForestContent.Orin&&worldEvents!=null) changed|=worldEvents.ConverseWithOrin();
                    Message=Engine.Dialogue(npc);
                    if(npc==ForestContent.Orin&&!string.IsNullOrEmpty(worldEvents?.World?.OrinDialogue)) Message=worldEvents.World.OrinDialogue;
                    if(npc==ForestContent.Mira) ResolveMira();
                    if(npc==ForestContent.Orin&&!Wolf.State.IsAlive&&Engine.Status(ForestContent.RouteB)==OpportunityStatus.Started) Message+=" R: continuar em um novo encontro corrompido para observar em combate.";
                    return changed;
            }
        }
        private void LateUpdate()
        {
            sampleVisual.transform.position=Wolf.transform.position+Vector3.down*0.7f;
            var sample=interactions.First(i=>i.Kind==InteractionKind.Sample); sampleVisual.enabled=IsAvailable(sample);
            markVisual.enabled=Wolf.State.IsAlive&&Weakness.Marked(Time.timeAsDouble)==CurrentEncounter;
            if(trainingDummy!=null) trainingDummy.SetMarked(Weakness.Marked(Time.timeAsDouble)==TrainingDummy.TargetId);
        }
    }
}
