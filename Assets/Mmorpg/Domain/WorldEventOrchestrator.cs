using System;
using System.Collections.Generic;
using System.Linq;

namespace Mmorpg.Domain
{
    // Consumes authority-produced Journey facts. Owns no inventory, abilities or progression rules.
    public sealed class WorldEventOrchestrator
    {
        private readonly WorldState state;
        private readonly IWorldClock clock;
        public long Revision => state.revision;
        public WorldEventOrchestrator(string actorId,string worldId,IWorldClock clock,WorldEventSettings settings=null)
        {
            if(string.IsNullOrWhiteSpace(actorId)||string.IsNullOrWhiteSpace(worldId)||clock==null||(settings!=null&&!settings.Valid)) throw new ArgumentException("Invalid world configuration");
            this.clock=clock; state=new WorldState{actorId=actorId,worldId=worldId,settings=(settings??new WorldEventSettings()).Copy()};
        }
        public WorldState Snapshot() => state.Copy();
        private WorldCommand Command(string kind,string target=null,string cause=null) => new WorldCommand {
            id=kind+":"+state.revision,kind=kind,target=target,causeId=cause,gameTime=Math.Max(state.gameTime,clock.GameMilliseconds),realTime=Math.Max(state.realTime,clock.RealMilliseconds) };
        public bool Synchronize(JourneyEngine journey)
        {
            bool changed=false;
            foreach(var input in journey.Snapshot().inputs)
            {
                if(FactKind(input)==null||state.history.Any(h=>h.kind=="import"&&h.causeId==input.eventId)) continue;
                changed|=Apply(Command("import",cause:input.eventId),journey);
            }
            return changed;
        }
        private static string FactKind(GameEvent e)
        {
            switch(e.eventType) {
                case EventType.EvidenceDelivered: return WorldEventContent.Investigation;
                case EventType.TraceExamined: return WorldEventContent.Tracking;
                case EventType.CreatureDefeated: return WorldEventContent.Combat;
                case EventType.NpcInteracted: return string.IsNullOrEmpty(e.npc.sharedFact)?null:"tracking-report";
                case EventType.CombatActionVerified: return e.combat.actionId==CombatActions.PreparedDodge?WorldEventContent.Dodge:WorldEventContent.TrainingHit;
                default: return null;
            }
        }
        public IReadOnlyList<EligibilityEvidence> ExplainEligibility()
        {
            var output=new List<EligibilityEvidence>();
            foreach(var c in WorldEligibility.Definitions())
            {
                var evidence=new EligibilityEvidence{candidateId=c.id,ruleId=c.ruleId};
                evidence.eligible=WorldEligibility.Evaluate(c.conditions,state,evidence);
                if(state.consideredCandidates.Contains(c.id)||state.consideredCandidates.Contains(DeferredKey(c.id))) { evidence.eligible=false; evidence.rejectedRules.Add("already-considered"); }
                if(state.opportunities.Count(Active)>=state.settings.maximumActiveOpportunities) { evidence.eligible=false; evidence.rejectedRules.Add("active-limit"); }
                output.Add(evidence);
            }
            return output;
        }
        private string DeferredKey(string id) => $"deferred:{id}:{state.facts.Count}:{state.knowledge.Count}:{state.forestThreat}";
        private static bool Active(WorldOpportunity o) => o.status==WorldOpportunityStatus.Hidden||o.status==WorldOpportunityStatus.Discovered||o.status==WorldOpportunityStatus.Started;
        public WorldEvaluation PendingEvaluation()
        {
            var ids=ExplainEligibility().Where(e=>e.eligible).Select(e=>e.candidateId).ToArray();
            if(ids.Length==0) return null;
            var candidates=WorldEligibility.Definitions().Where(c=>ids.Contains(c.id)).ToList();
            foreach(var c in candidates) {
                string kind=c.id==WorldEventContent.Alert?WorldEventContent.Investigation:c.id==WorldEventContent.Tracks?WorldEventContent.Tracking:WorldEventContent.Dodge;
                c.causeId=state.facts.First(f=>f.kind==kind).id;
                c.context=state.facts.Select(f=>f.kind).Distinct().OrderBy(x=>x,StringComparer.Ordinal).ToList();
            }
            return new WorldEvaluation{eventId="world:"+state.facts.First().causeId+":"+state.revision,actorId=state.actorId,worldId=state.worldId,stateVersion=state.revision,candidates=candidates,
                characterFacts=state.facts.Select(f=>f.kind).Distinct().OrderBy(x=>x,StringComparer.Ordinal).ToList(),
                npcKnowledge=state.knowledge.Select(k=>k.npcId+":"+state.facts.Single(f=>f.id==k.factId).kind).Distinct().OrderBy(x=>x,StringComparer.Ordinal).ToList(),
                regionState=new List<string>{state.forestThreat?"forest-threat":"forest-safe"},eligibleConsequences=ids.Concat(new[]{WorldEventContent.None}).ToList()};
        }
        public bool TryApplyDecision(DecisionRecord decision,JourneyEngine journey)
        {
            var command=Command("decision"); command.decision=decision?.Copy(); return Apply(command,journey);
        }
        public bool ResolveDeterministic(JourneyEngine journey,string reason=null)
        {
            bool changed=false;
            // One evaluation per independent candidate, at most the three definitions; no selection starvation.
            for(int i=0;i<3;i++) { var c=PendingEvaluation(); if(c==null) break; changed|=TryApplyDecision(WorldEventContent.Deterministic(c,reason),journey); }
            return changed;
        }
        public bool Tick(JourneyEngine journey)
        {
            var c=Command("tick");
            bool changed=Apply(c,journey);
            // Clock checkpoints do not increment the decision revision or grow the audit log.
            state.gameTime=c.gameTime; state.realTime=c.realTime; return changed;
        }
        public bool Interact(string target,JourneyEngine journey) => Apply(Command("interact",target),journey);
        public bool SetRegionalThreat(bool threatened,string authorityCauseId,JourneyEngine journey) => Apply(Command("region",threatened?"threat":"safe",authorityCauseId),journey);
        public WorldOpportunityStatus? Status(string id) => state.opportunities.FirstOrDefault(o=>o.id==id)?.status;
        public bool ClueVisible => state.opportunities.Any(o=>o.id==WorldEventContent.Tracks&&Active(o));
        public bool NoticePublished => state.noticePublished;
        public string OrinDialogue => Status(WorldEventContent.Training)==WorldOpportunityStatus.Discovered?"Orin: Você evitou um golpe preparado. E novamente: aceitar um treino opcional no boneco.":Status(WorldEventContent.Training)==WorldOpportunityStatus.Started?"Orin: Acerte o boneco para praticar o momento do contra-ataque. Sem recompensa de habilidade.":Status(WorldEventContent.Training)==WorldOpportunityStatus.Completed?"Orin: Sua preparação foi registrada. Podemos explorar uma especialização no futuro.":Status(WorldEventContent.Tracks)==WorldOpportunityStatus.Completed?"Orin: A resina nos novos vestígios aponta outra ameaça. Registrei nossa investigação.":"";
        public string Journal()
        {
            var lines=state.opportunities.Where(o=>o.discovered).Select(o=>WorldEventContent.Title(o.id)+": "+o.status).ToList();
            if(state.noticeRead) lines.Insert(0,"Quadro: ameaça confirmada por Mira; aviso público da vila.");
            return lines.Count==0?"":"\nAcontecimentos do mundo:\n"+string.Join("\n",lines);
        }
        private bool Apply(WorldCommand c,JourneyEngine journey)
        {
            if(c==null||c.id!=c.kind+":"+state.revision||c.gameTime<state.gameTime||c.realTime<state.realTime||c.gameTime<0||c.realTime<0||c.gameTime>long.MaxValue-31536000000L||c.realTime>long.MaxValue-31536000000L||state.history.Count>=8192) return false;
            var js=journey.Snapshot();
            if(js.actorId!=state.actorId||js.worldId!=state.worldId) return false;
            bool changed=false;
            switch(c.kind)
            {
                case "import":
                    var input=js.inputs.FirstOrDefault(e=>e.eventId==c.causeId);
                    if(input==null||FactKind(input)==null||state.facts.Any(f=>f.causeId==c.causeId)) return false;
                    var fact=new WorldFact{id="fact:"+input.eventId,kind=FactKind(input),subjectId=state.actorId,causeId=input.eventId,gameTime=c.gameTime,realTime=c.realTime};
                    state.facts.Add(fact);
                    if(fact.kind==WorldEventContent.Combat||fact.kind==WorldEventContent.Investigation) state.forestThreat=true;
                    if(fact.kind=="tracking-report") { var trace=state.facts.FirstOrDefault(f=>f.kind==WorldEventContent.Tracking); if(trace!=null) Learn(ForestContent.Orin,trace.id,KnowledgeSource.Conversation,state.actorId,c.id); }
                    if(fact.kind==WorldEventContent.Investigation) Learn(ForestContent.Mira,fact.id,KnowledgeSource.Observation,state.actorId,c.id);
                    if(fact.kind==WorldEventContent.TrainingHit&&Status(WorldEventContent.Training)==WorldOpportunityStatus.Started) {
                        state.opportunities.Single(o=>o.id==WorldEventContent.Training).status=WorldOpportunityStatus.Completed;
                        Learn(ForestContent.Orin,fact.id,KnowledgeSource.Message,state.actorId,c.id);
                    }
                    changed=true; break;
                case "decision":
                    var context=PendingEvaluation(); var d=c.decision;
                    if(context==null||d==null||d.eventId!=context.eventId||d.actorId!=state.actorId||d.worldId!=state.worldId||d.policyId!=WorldEventContent.Policy||d.stateVersion!=state.revision||!context.eligibleConsequences.Contains(d.selectedConsequence)||!ValidDecision(d,context)||state.decisions.Any(x=>x.decisionId==d.decisionId)) return false;
                    state.decisions.Add(d.Copy());
                    if(d.selectedConsequence==WorldEventContent.None) state.consideredCandidates.AddRange(context.candidates.Select(x=>DeferredKey(x.id)));
                    else {
                        var selected=context.candidates.Single(x=>x.id==d.selectedConsequence); state.consideredCandidates.Add(selected.id);
                        if(selected.id==WorldEventContent.Alert) {
                            // Alert uses a persistent agenda, not a player quest slot.
                            state.scheduled.Add(new ScheduledConsequence{id="schedule:"+selected.id,actionId="publish-notice",causeId=selected.causeId,timeBasis=state.settings.alertTimeBasis,
                                dueAt=checked((state.settings.alertTimeBasis==WorldTimeBasis.Game?c.gameTime:c.realTime)+state.settings.alertDelayMilliseconds),requiredFactKind=WorldEventContent.Investigation,requiredNpcId=ForestContent.Mira,createdRevision=state.revision,afterFactKind=state.facts.Any(f=>f.kind==state.settings.alertAfterFactKind)?null:state.settings.alertAfterFactKind,afterNpcId=state.settings.alertAfterNpcId});
                        } else state.opportunities.Add(new WorldOpportunity{id=selected.id,candidateId=selected.id,causeId=selected.causeId,discovered=selected.id!=WorldEventContent.Tracks,status=selected.id==WorldEventContent.Tracks?WorldOpportunityStatus.Hidden:WorldOpportunityStatus.Discovered,expiresAtGameTime=checked(c.gameTime+state.settings.opportunityLifetimeMilliseconds)});
                    }
                    changed=true; break;
                case "tick":
                    foreach(var o in state.opportunities.Where(o=>Active(o)&&c.gameTime>=o.expiresAtGameTime)) { o.status=WorldOpportunityStatus.Expired; changed=true; }
                    foreach(var scheduled in state.scheduled.Where(s=>!s.executed&&!s.cancelled&&(s.timeBasis==WorldTimeBasis.Game?c.gameTime:c.realTime)>=s.dueAt).OrderBy(s=>s.dueAt).ThenBy(s=>s.id,StringComparer.Ordinal).Take(state.settings.maximumDuePerTick)) {
                        bool futureFact=string.IsNullOrEmpty(scheduled.afterFactKind)||state.history.Skip((int)scheduled.createdRevision+1).Any(h=>h.kind=="import"&&state.facts.Any(f=>f.causeId==h.causeId&&f.kind==scheduled.afterFactKind));
                        bool futureNpc=string.IsNullOrEmpty(scheduled.afterNpcId)||state.history.Skip((int)scheduled.createdRevision+1).Any(h=>h.kind=="interact"&&h.target==scheduled.afterNpcId);
                        if(!futureFact||!futureNpc) continue;
                        bool valid=state.forestThreat&&state.facts.Any(f=>f.id==scheduled.causeId&&f.kind==scheduled.requiredFactKind)&&Knows(scheduled.requiredNpcId,scheduled.causeId);
                        if(!valid) scheduled.cancelled=true;
                        else { scheduled.executed=true; state.noticePublished=true; Learn(ForestContent.Orin,scheduled.causeId,KnowledgeSource.PublicNotice,"notice-board",scheduled.id); }
                        changed=true;
                    }
                    break;
                case "region":
                    if(!state.facts.Any(f=>f.id==c.causeId)||!(c.target=="safe"||c.target=="threat")||state.forestThreat==(c.target=="threat")) return false;
                    state.forestThreat=c.target=="threat";
                    if(!state.forestThreat) foreach(var o in state.opportunities.Where(o=>o.id==WorldEventContent.Tracks&&Active(o))) o.status=WorldOpportunityStatus.Closed;
                    changed=true; break;
                case "interact":
                    if(c.target=="notice-board") { if(!state.noticePublished||state.noticeRead) return false; state.noticeRead=true; changed=true; }
                    else if(c.target==WorldEventContent.Tracks) {
                        var o=state.opportunities.FirstOrDefault(x=>x.id==WorldEventContent.Tracks);
                        if(o==null||o.status!=WorldOpportunityStatus.Hidden||c.gameTime>=o.expiresAtGameTime||!state.forestThreat) return false;
                        o.status=WorldOpportunityStatus.Discovered; o.discovered=true; changed=true;
                    } else if(c.target==ForestContent.Orin) {
                        if(state.scheduled.Any(s=>!s.executed&&!s.cancelled&&s.afterNpcId==c.target&&!state.history.Skip((int)s.createdRevision+1).Any(h=>h.kind=="interact"&&h.target==c.target))) changed=true;
                        foreach(var f in state.facts.Where(f=>f.kind==WorldEventContent.Dodge||f.kind==WorldEventContent.Tracking)) changed|=Learn(ForestContent.Orin,f.id,KnowledgeSource.Conversation,state.actorId,c.id);
                        var tracks=state.opportunities.FirstOrDefault(o=>o.id==WorldEventContent.Tracks&&o.status==WorldOpportunityStatus.Discovered&&c.gameTime<o.expiresAtGameTime);
                        if(tracks!=null&&state.forestThreat) { tracks.status=WorldOpportunityStatus.Completed; Learn(ForestContent.Orin,tracks.causeId,KnowledgeSource.Conversation,state.actorId,c.id); changed=true; }
                        var training=state.opportunities.FirstOrDefault(o=>o.id==WorldEventContent.Training&&o.status==WorldOpportunityStatus.Discovered&&c.gameTime<o.expiresAtGameTime);
                        if(training!=null) { training.status=WorldOpportunityStatus.Started; changed=true; }
                    } else return false;
                    break;
                default: return false;
            }
            if(!changed) return false;
            state.gameTime=c.gameTime; state.realTime=c.realTime; state.history.Add(c.Copy()); state.revision++; state.eligibilityHistory.Add(new WorldEligibilityAudit{revision=state.revision,evidence=ExplainEligibility().ToList()}); return true;
        }
        private static bool ValidDecision(DecisionRecord d,WorldEvaluation context)
        {
            if(!MiraReactions.ValidMetadataFor(d,context.eligibleConsequences)) return false;
            if(d.provider!="deterministic"&&d.provider!="TypeSafe") return false;
            if(d.provider=="deterministic"&&d.model!="deterministic-v1") return false;
            if(d.provider=="TypeSafe"&&d.model!="typesafe/jev-1.13"&&!(d.model.Length==26&&d.model.StartsWith("typesafe/jev-1.13-",StringComparison.Ordinal)&&d.model.Substring(18).All(char.IsDigit))) return false;
            if(d.probabilities!=null&&(d.probabilities.Count!=context.eligibleConsequences.Count||context.eligibleConsequences.Any(id=>!d.probabilities.ContainsKey(id)))) return false;
            return d.decisionId.Length<=256&&(!d.fallback||new[]{"local_service_unavailable","local_endpoint_rejected","state_changed","invalid_local_response","missing_api_key","provider_timeout","provider_unavailable","provider_http_error","invalid_response","invalid_choice","invalid_probabilities","invalid_usage","low_confidence","provider_error"}.Contains(d.fallbackReason));
        }
        private bool Knows(string npc,string factId) => state.knowledge.Any(k=>k.npcId==npc&&k.factId==factId);
        private bool Learn(string npc,string factId,KnowledgeSource source,string sender,string cause)
        {
            if(!state.facts.Any(f=>f.id==factId)||Knows(npc,factId)) return false;
            state.knowledge.Add(new WorldKnowledge{npcId=npc,factId=factId,source=source,senderId=sender,causeId=cause}); return true;
        }
        public static WorldEventOrchestrator Restore(WorldState saved,JourneyEngine journey,IWorldClock clock)
        {
            if(saved==null||saved.version!=1||saved.settings==null||!saved.settings.Valid||saved.history==null||saved.history.Count>8192) throw new ArgumentException("Unsupported world save");
            var replayClock=new SimulatedWorldClock(); var replay=new WorldEventOrchestrator(saved.actorId,saved.worldId,replayClock,saved.settings);
            foreach(var command in saved.history) {
                if(command==null) throw new ArgumentException("Missing world command");
                replayClock.GameMilliseconds=command.gameTime; replayClock.RealMilliseconds=command.realTime;
                if(!replay.Apply(command,journey)) throw new ArgumentException("Invalid world history");
            }
            if(saved.gameTime<replay.state.gameTime||saved.realTime<replay.state.realTime) throw new ArgumentException("World clock moved backwards");
            replay.state.gameTime=saved.gameTime; replay.state.realTime=saved.realTime;
            if(Signature(saved)!=Signature(replay.state)) throw new ArgumentException("World projections disagree with history");
            var result=new WorldEventOrchestrator(saved.actorId,saved.worldId,clock,saved.settings);
            foreach(var command in saved.history) if(!result.Apply(command,journey)) throw new ArgumentException("Invalid world replay");
            result.state.gameTime=saved.gameTime; result.state.realTime=saved.realTime; return result;
        }
        private static string DecisionSignature(DecisionRecord d) => d==null?"":string.Join("~",d.version,d.eventId,d.actorId,d.worldId,d.policyId,d.stateVersion,d.decisionId,d.selectedConsequence,d.model,d.provider,d.fallback,d.fallbackReason,d.latencyMs,d.confidence,string.Join(",",d.probabilities?.OrderBy(p=>p.Key,StringComparer.Ordinal).Select(p=>p.Key+"="+p.Value)??Enumerable.Empty<string>()),d.usage?.input_tokens,d.usage?.output_tokens,d.usage?.cost,d.attempt==null?"":DecisionSignature(new DecisionRecord{decisionId=d.attempt.decisionId,model=d.attempt.model,provider=d.attempt.provider,selectedConsequence=d.attempt.selectedConsequence,confidence=d.attempt.confidence,probabilities=d.attempt.probabilities,usage=d.attempt.usage}));
        private static string Signature(WorldState s) => string.Join("/",s.version,s.actorId,s.worldId,s.revision,s.gameTime,s.realTime,s.forestThreat,s.noticePublished,s.noticeRead,
            string.Join("|",s.facts.Select(f=>$"{f.version}:{f.id}:{f.kind}:{f.subjectId}:{f.causeId}:{f.gameTime}:{f.realTime}")),
            string.Join("|",s.opportunities.Select(o=>$"{o.version}:{o.id}:{o.candidateId}:{o.causeId}:{o.status}:{o.discovered}:{o.expiresAtGameTime}")),
            string.Join("|",s.scheduled.Select(x=>$"{x.version}:{x.id}:{x.actionId}:{x.causeId}:{x.requiredFactKind}:{x.requiredNpcId}:{x.timeBasis}:{x.dueAt}:{x.executed}:{x.cancelled}:{x.createdRevision}:{x.afterFactKind}:{x.afterNpcId}")),
            string.Join("|",s.knowledge.Select(k=>$"{k.npcId}:{k.factId}:{k.causeId}:{k.senderId}:{k.source}")),string.Join("|",s.decisions.Select(DecisionSignature)),string.Join("|",s.eligibilityHistory.Select(a=>a.revision+":"+string.Join(";",a.evidence.Select(e=>e.candidateId+":"+e.ruleId+":"+e.eligible+":"+string.Join(",",e.passedRules)+":"+string.Join(",",e.rejectedRules))))),string.Join(",",s.consideredCandidates),
            string.Join("|",s.history.Select(h=>$"{h.id}:{h.kind}:{h.target}:{h.causeId}:{h.gameTime}:{h.realTime}:{DecisionSignature(h.decision)}")));
    }
}
