using System;
using System.Collections.Generic;
using System.Linq;

namespace Mmorpg.Domain
{
    // Only validated authority facts enter this reducer. No NPC script depends on another NPC.
    public sealed class JourneyEngine
    {
        private readonly JourneySnapshot state;
        private readonly IConsequencePolicy policy;
        public JourneyEngine(string actorId=ForestContent.Actor, string worldId=ForestContent.World, IConsequencePolicy policy=null)
        {
            if (string.IsNullOrWhiteSpace(actorId) || string.IsNullOrWhiteSpace(worldId)) throw new ArgumentException("Identity required");
            state=new JourneySnapshot{actorId=actorId,worldId=worldId}; this.policy=policy??new DeterministicPolicy();
            state.opportunities.Add(new OpportunityRecord{id=ForestContent.RouteA});
            state.opportunities.Add(new OpportunityRecord{id=ForestContent.RouteB});
            state.relations.Add(new RelationRecord{npcId=ForestContent.Mira}); state.relations.Add(new RelationRecord{npcId=ForestContent.Orin});
        }
        public bool HasAbility(string id) => state.abilities.Contains(id);
        public bool HasTrace => state.facts.Any(e=>e.eventType==EventType.TraceExamined);
        public bool HasPreparedDodge
        {
            get { foreach(var fact in state.facts) if(fact.eventType==EventType.CombatActionVerified && fact.combat.actionId==CombatActions.PreparedDodge)return true;return false; }
        }
        public bool OrinBriefed => Knows(ForestContent.Orin,ForestContent.Trace);
        public bool HasSample => state.evidence.Contains(ForestContent.Sample);
        public bool Knows(string npc,string fact) => state.knowledge.Any(k=>k.npcId==npc&&k.fact==fact);
        public OpportunityStatus Status(string id) => state.opportunities.Single(o=>o.id==id).status;
        public bool Defeated(string encounter) => state.facts.Any(e=>e.eventType==EventType.CreatureDefeated&&e.creature.encounterId==encounter);

        public long StateVersion => state.inputs.Count+state.decisions.Count;
        public DecisionContext PendingMiraDecision()
        {
            var cause=state.inputs.LastOrDefault(e=>e.eventType==EventType.EvidenceDelivered&&e.evidence.recipientId==ForestContent.Mira);
            if(cause==null||state.decisions.Any(d=>d.eventId==cause.eventId)||!Knows(ForestContent.Mira,ForestContent.Sample)||Status(ForestContent.RouteA)!=OpportunityStatus.Completed) return null;
            return new DecisionContext{eventId=cause.eventId,actorId=state.actorId,worldId=state.worldId,stateVersion=StateVersion,policyId=MiraReactions.Policy,
                characterFacts=state.facts.Where(f=>f.eventType!=EventType.NpcInteracted).Select(f=>f.eventType.ToString()).Distinct().OrderBy(f=>f,StringComparer.Ordinal).ToList(),
                npcKnowledge=state.knowledge.Where(k=>k.npcId==ForestContent.Mira).Select(k=>k.fact).OrderBy(f=>f,StringComparer.Ordinal).ToList(),
                regionState=new List<string>{"forest-corruption-confirmed"},eligibleConsequences=MiraReactions.Options.ToList()};
        }
        // Authority applies advisory IDs only after checking the current revision and eligibility.
        public bool TryApplyDecision(DecisionRecord result)
        {
            var context=PendingMiraDecision();
            if(context==null||!MiraReactions.ValidMetadata(result)||result.eventId!=context.eventId||result.actorId!=context.actorId||result.worldId!=context.worldId||result.policyId!=context.policyId||result.stateVersion!=StateVersion||!context.eligibleConsequences.Contains(result.selectedConsequence)||state.decisions.Any(d=>d.decisionId==result.decisionId)) return false;
            state.decisions.Add(result.Copy()); state.version=2;
            Learn(ForestContent.Mira,result.selectedConsequence,result.eventId); return true;
        }

        public bool ApplyValidated(GameEvent input)
        {
            if (!ValidEnvelope(input) || input.eventId.StartsWith("derived:",StringComparison.Ordinal) || state.facts.Any(e=>e.eventId==input.eventId)) return false;
            var e=input.Copy();
            switch(e.eventType)
            {
                case EventType.CombatActionVerified:
                    if(e.sourceId!="combat"||string.IsNullOrWhiteSpace(e.combat.encounterId)||state.inputs.Any(f=>f.eventType==EventType.CombatActionVerified&&f.combat.actionId==e.combat.actionId)) return false;
                    if(e.combat.actionId==CombatActions.PreparedDodge) { if(e.combat.targetId!=ForestContent.Wolf||string.IsNullOrWhiteSpace(e.combat.preparedAttackId)) return false; }
                    else if(e.combat.actionId!=CombatActions.TrainingHit||e.combat.targetId!="training-dummy") return false;
                    break;
                case EventType.CreatureDefeated:
                    if(e.sourceId!="combat"||e.creature.creatureId!=ForestContent.Wolf||string.IsNullOrWhiteSpace(e.creature.encounterId)||Defeated(e.creature.encounterId)) return false;
                    // observed is computed here, never accepted as an input claim.
                    e.creature.observed=HasTrace&&OrinBriefed;
                    break;
                case EventType.TraceExamined:
                    if(e.sourceId!=ForestContent.Trace||e.trace.traceId!=ForestContent.Trace||HasTrace) return false;
                    break;
                case EventType.EvidenceCollected:
                    if(e.sourceId!="sample-drop"||e.evidence.evidenceId!=ForestContent.Sample||!Defeated(e.evidence.encounterId)||HasSample||state.delivered.Contains(ForestContent.Sample)) return false;
                    state.evidence.Add(ForestContent.Sample); break;
                case EventType.EvidenceDelivered:
                    if(e.sourceId!=ForestContent.Mira||e.evidence.recipientId!=ForestContent.Mira||e.evidence.evidenceId!=ForestContent.Sample||!HasSample||!state.facts.Any(f=>f.eventType==EventType.EvidenceCollected&&f.evidence.encounterId==e.evidence.encounterId)) return false;
                    state.evidence.Remove(ForestContent.Sample); state.delivered.Add(ForestContent.Sample);
                    Learn(ForestContent.Mira,ForestContent.Sample,e.eventId); break;
                case EventType.NpcInteracted:
                    if(string.IsNullOrWhiteSpace(e.npc.sharedFact)) e.npc.sharedFact=null;
                    if((e.npc.npcId!=ForestContent.Mira&&e.npc.npcId!=ForestContent.Orin)||e.sourceId!=e.npc.npcId) return false;
                    if(!string.IsNullOrEmpty(e.npc.sharedFact))
                    {
                        if(e.npc.npcId!=ForestContent.Orin||e.npc.sharedFact!=ForestContent.Trace||!HasTrace) return false;
                        Learn(ForestContent.Orin,ForestContent.Trace,e.eventId);
                    }
                    // Repeating identical information is a semantic no-op, even with a new event ID.
                    if(state.facts.Any(f=>f.eventType==EventType.NpcInteracted&&f.npc.npcId==e.npc.npcId&&f.npc.sharedFact==e.npc.sharedFact)) return false;
                    break;
                default: return false; // discoveries and rewards originate only in consequences
            }
            state.inputs.Add(e.Copy()); state.facts.Add(e);
            RefreshOpportunities(e);
            Resolve(e);
            return true;
        }
        private bool ValidEnvelope(GameEvent e)
        {
            if(e==null||e.version!=1||e.payloadVersion!=1||string.IsNullOrWhiteSpace(e.eventId)||e.actorId!=state.actorId||e.worldId!=state.worldId||e.timestamp<0||string.IsNullOrWhiteSpace(e.sourceId)||!Enum.IsDefined(typeof(EventType),e.eventType)) return false;
            int count=(e.creature!=null?1:0)+(e.evidence!=null?1:0)+(e.trace!=null?1:0)+(e.npc!=null?1:0)+(e.discovery!=null?1:0)+(e.combat!=null?1:0);
            if(count!=1) return false;
            return e.eventType==EventType.CombatActionVerified?e.combat!=null:e.eventType==EventType.CreatureDefeated?e.creature!=null:
                e.eventType==EventType.EvidenceCollected||e.eventType==EventType.EvidenceDelivered?e.evidence!=null:
                e.eventType==EventType.TraceExamined?e.trace!=null:e.eventType==EventType.NpcInteracted?e.npc!=null:e.discovery!=null;
        }
        private void Learn(string npc,string fact,string source)
        { if(!Knows(npc,fact)) state.knowledge.Add(new KnowledgeRecord{npcId=npc,fact=fact,sourceEventId=source}); }
        private void RefreshOpportunities(GameEvent cause)
        {
            if(HasSample||state.delivered.Contains(ForestContent.Sample)) Discover(ForestContent.RouteA,cause);
            if(HasTrace) Discover(ForestContent.RouteB,cause);
            if(OrinBriefed&&Status(ForestContent.RouteB)==OpportunityStatus.Available) SetStatus(ForestContent.RouteB,OpportunityStatus.Started);
            if(state.delivered.Contains(ForestContent.Sample)&&Status(ForestContent.RouteA)==OpportunityStatus.Available) SetStatus(ForestContent.RouteA,OpportunityStatus.Started);
        }
        private void Discover(string route,GameEvent cause)
        {
            if(Status(route)!=OpportunityStatus.Unknown) return;
            SetStatus(route,OpportunityStatus.Available);
            Derived(EventType.OpportunityDiscovered,route,route,cause);
        }
        private void SetStatus(string id,OpportunityStatus value) => state.opportunities.Single(o=>o.id==id).status=value;
        public IReadOnlyList<string> EligibleConsequences()
        {
            var eligible=new List<string>();
            if(Status(ForestContent.RouteA)==OpportunityStatus.Started&&state.delivered.Contains(ForestContent.Sample)) eligible.Add(ForestContent.RouteA);
            if(Status(ForestContent.RouteB)==OpportunityStatus.Started&&state.facts.Any(e=>e.eventType==EventType.CreatureDefeated&&e.creature.observed)) eligible.Add(ForestContent.RouteB);
            return eligible.AsReadOnly();
        }
        private void Resolve(GameEvent cause)
        {
            // Selection is advisory; validate against newly generated candidates every time.
            var eligible=EligibleConsequences();
            for(int i=0;i<2&&eligible.Count>0;i++)
            {
                string selected=policy.Select(eligible);
                if(selected==null||!eligible.Contains(selected)) break;
                SetStatus(selected,OpportunityStatus.Completed);
                string npc=selected==ForestContent.RouteA?ForestContent.Mira:ForestContent.Orin;
                state.relations.Single(r=>r.npcId==npc).trust++;
                Learn(npc,selected,cause.eventId);
                if(!HasAbility(ForestContent.Technique)) { state.abilities.Add(ForestContent.Technique); Derived(EventType.AbilityUnlocked,ForestContent.Technique,selected,cause); }
                eligible=EligibleConsequences();
            }
        }
        private void Derived(EventType type,string definition,string route,GameEvent cause)
        {
            state.facts.Add(new GameEvent{eventId=$"derived:{type}:{definition}",eventType=type,actorId=state.actorId,worldId=state.worldId,sourceId="journey-rules",timestamp=cause.timestamp,discovery=new DiscoveryPayload{definitionId=definition,routeId=route}});
        }
        public string Dialogue(string npc)
        {
            if(npc==ForestContent.Mira)
            {
                var reaction=state.decisions.FirstOrDefault(d=>d.policyId==MiraReactions.Policy);
                return reaction!=null?MiraReactions.Text(reaction.selectedConsequence)+" Observe as falhas na defesa; aprenda Leitura de Fraquezas.":Knows(npc,ForestContent.Sample)?"Mira: A amostra confirma a corrupção. Observe as falhas na defesa; aprenda Leitura de Fraquezas.":HasSample?"Mira: Você trouxe uma amostra? Pressione E novamente para entregá-la.":"Mira: A floresta parece doente. Preciso de uma amostra para entender a causa.";
            }
            if(npc==ForestContent.Orin) return Knows(npc,ForestContent.RouteB)?"Orin: Você observou a defesa do lobo em combate. Confio no seu olhar, mesmo que já conheça a técnica.":OrinBriefed?"Orin: Esses rastros são anormais. Enfrente o lobo corrompido e observe suas aberturas.":"Orin: Examine os rastros antes de tirar conclusões. Ainda não recebi evidências.";
            return "";
        }
        public JourneySnapshot Snapshot()
        {
            return new JourneySnapshot{world=state.world?.Copy(),version=state.version,decisions=state.decisions.Select(d=>d.Copy()).ToList(),actorId=state.actorId,worldId=state.worldId, inputs=state.inputs.Select(e=>e.Copy()).ToList(), facts=state.facts.Select(e=>e.Copy()).ToList(),abilities=state.abilities.ToList(),evidence=state.evidence.ToList(),delivered=state.delivered.ToList(),opportunities=state.opportunities.Select(o=>new OpportunityRecord{id=o.id,status=o.status}).ToList(),knowledge=state.knowledge.Select(k=>new KnowledgeRecord{npcId=k.npcId,fact=k.fact,sourceEventId=k.sourceEventId}).ToList(),relations=state.relations.Select(r=>new RelationRecord{npcId=r.npcId,trust=r.trust}).ToList()};
        }
        // Reconstruct from the verified log; persisted caches must agree with the reducer.
        public static JourneyEngine Restore(JourneySnapshot saved)
        {
            if(saved==null||(saved.version!=1&&saved.version!=2&&saved.version!=3)||saved.inputs==null||saved.decisions==null||(saved.version==1&&saved.decisions.Count>0)) throw new ArgumentException("Unsupported or incomplete save");
            var engine=new JourneyEngine(saved.actorId,saved.worldId);
            int decisionIndex=0;
            for(int i=0;i<=saved.inputs.Count;i++)
            {
                while(decisionIndex<saved.decisions.Count&&saved.decisions[decisionIndex]!=null&&saved.decisions[decisionIndex].stateVersion==engine.StateVersion)
                    if(!engine.TryApplyDecision(saved.decisions[decisionIndex++])) throw new ArgumentException("Invalid decision history");
                if(i<saved.inputs.Count&&!engine.ApplyValidated(saved.inputs[i])) throw new ArgumentException("Invalid event history");
            }
            if(decisionIndex!=saved.decisions.Count) throw new ArgumentException("Invalid decision revision/order");
            if(saved.world!=null) { if(saved.version!=3) throw new ArgumentException("World state requires save v3"); WorldEventOrchestrator.Restore(saved.world,engine,new SimulatedWorldClock()); engine.state.world=saved.world.Copy(); engine.state.version=3; }
            if(Signature(saved)!=Signature(engine.state)) throw new ArgumentException("State does not agree with event history");
            return engine;
        }
        private static string Signature(JourneySnapshot s)
        {
            if(s.facts==null||s.abilities==null||s.evidence==null||s.delivered==null||s.opportunities==null||s.knowledge==null||s.relations==null) throw new ArgumentException("Missing state");
            return string.Join("|",s.inputs.Select(EventSignature))+"/"+string.Join("|",s.facts.Select(EventSignature)) + "/"+string.Join(",",s.abilities)+"/"+string.Join(",",s.evidence)+"/"+string.Join(",",s.delivered)+"/"+string.Join(",",s.opportunities.Select(o=>$"{o.id}:{o.status}"))+"/"+string.Join(",",s.knowledge.Select(k=>$"{k.npcId}:{k.fact}:{k.sourceEventId}"))+"/"+string.Join(",",s.relations.Select(r=>$"{r.npcId}:{r.trust}"));
        }
        private static string EventSignature(GameEvent e) => $"{e.version}:{e.payloadVersion}:{e.eventId}:{e.actorId}:{e.worldId}:{e.eventType}:{e.timestamp}:{e.sourceId}:{e.creature?.creatureId}:{e.creature?.encounterId}:{e.creature?.observed}:{e.evidence?.evidenceId}:{e.evidence?.encounterId}:{e.evidence?.recipientId}:{e.trace?.traceId}:{e.npc?.npcId}:{e.npc?.sharedFact}:{e.discovery?.definitionId}:{e.discovery?.routeId}:{e.combat?.actionId}:{e.combat?.encounterId}:{e.combat?.targetId}:{e.combat?.preparedAttackId}";
    }
}
