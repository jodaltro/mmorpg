using System;
using System.Collections.Generic;
using System.Linq;

namespace Mmorpg.Domain
{
    public enum WorldOpportunityStatus { Hidden, Discovered, Started, Completed, Expired, Closed }
    public enum WorldTimeBasis { Game, Real }
    public enum KnowledgeSource { Observation, Conversation, Message, PublicNotice }
    public interface IWorldClock { long GameMilliseconds { get; } long RealMilliseconds { get; } }
    public sealed class SimulatedWorldClock : IWorldClock
    {
        public long GameMilliseconds { get; set; }
        public long RealMilliseconds { get; set; }
        public void Advance(long milliseconds) { GameMilliseconds+=milliseconds; RealMilliseconds+=milliseconds; }
    }
    [Serializable] public sealed class WorldEventSettings
    {
        public long alertDelayMilliseconds=15000, opportunityLifetimeMilliseconds=900000;
        public WorldTimeBasis alertTimeBasis=WorldTimeBasis.Game;
        public string alertAfterFactKind, alertAfterNpcId;
        public int maximumActiveOpportunities=3, maximumDuePerTick=2;
        public WorldEventSettings Copy() => (WorldEventSettings)MemberwiseClone();
        public bool Valid => alertDelayMilliseconds>=0&&alertDelayMilliseconds<=31536000000L&&opportunityLifetimeMilliseconds>0&&opportunityLifetimeMilliseconds<=31536000000L&&maximumActiveOpportunities>=1&&maximumActiveOpportunities<=3&&maximumDuePerTick>=1&&maximumDuePerTick<=16&&Enum.IsDefined(typeof(WorldTimeBasis),alertTimeBasis)&&(string.IsNullOrEmpty(alertAfterFactKind)||alertAfterFactKind==WorldEventContent.Tracking)&&(string.IsNullOrEmpty(alertAfterNpcId)||alertAfterNpcId==ForestContent.Orin);
    }
    [Serializable] public sealed class WorldFact
    {
        public int version=1;
        public string id, kind, subjectId, causeId;
        public long gameTime, realTime;
        public WorldFact Copy() => (WorldFact)MemberwiseClone();
    }
    [Serializable] public sealed class WorldKnowledge
    {
        public string npcId, factId, causeId, senderId;
        public KnowledgeSource source;
        public WorldKnowledge Copy() => (WorldKnowledge)MemberwiseClone();
    }
    [Serializable] public sealed class WorldOpportunity
    {
        public int version=1;
        public string id, candidateId, causeId;
        public WorldOpportunityStatus status;
        public bool discovered;
        public long expiresAtGameTime;
        public WorldOpportunity Copy() => (WorldOpportunity)MemberwiseClone();
    }
    [Serializable] public sealed class ScheduledConsequence
    {
        public int version=1;
        public string id, actionId, causeId, requiredFactKind, requiredNpcId;
        public WorldTimeBasis timeBasis;
        public long dueAt, createdRevision;
        public string afterFactKind, afterNpcId;
        public bool executed, cancelled;
        public ScheduledConsequence Copy() => (ScheduledConsequence)MemberwiseClone();
    }
    [Serializable] public sealed class EventCandidate
    {
        public int version=1;
        public string id, type, scope, causeId, ruleId;
        public List<string> context=new List<string>(), authorizedActions=new List<string>();
        public WorldCondition conditions;
    }
    [Serializable] public sealed class WorldEvaluation
    {
        public int version=1;
        // eventId is the stable evaluation identity in the existing Decisions wire contract.
        public string eventId, actorId, worldId, policyId=WorldEventContent.Policy;
        public long stateVersion;
        public List<string> characterFacts=new List<string>(), npcKnowledge=new List<string>(), regionState=new List<string>(), eligibleConsequences=new List<string>();
        public List<EventCandidate> candidates=new List<EventCandidate>();
    }
    [Serializable] public sealed class WorldCommand
    {
        public string id, kind, target, causeId;
        public long gameTime, realTime;
        public DecisionRecord decision;
        public WorldCommand Copy() { var c=(WorldCommand)MemberwiseClone(); c.decision=decision?.Copy(); return c; }
    }
    [Serializable] public sealed class WorldState
    {
        public int version=1;
        public string actorId, worldId;
        public long revision, gameTime, realTime;
        public bool forestThreat, noticePublished, noticeRead;
        public WorldEventSettings settings=new WorldEventSettings();
        public List<WorldFact> facts=new List<WorldFact>();
        public List<WorldOpportunity> opportunities=new List<WorldOpportunity>();
        public List<ScheduledConsequence> scheduled=new List<ScheduledConsequence>();
        public List<WorldKnowledge> knowledge=new List<WorldKnowledge>();
        public List<DecisionRecord> decisions=new List<DecisionRecord>();
        public List<WorldCommand> history=new List<WorldCommand>();
        public List<WorldEligibilityAudit> eligibilityHistory=new List<WorldEligibilityAudit>();
        public List<string> consideredCandidates=new List<string>();
        public WorldState Copy() => new WorldState { version=version,actorId=actorId,worldId=worldId,revision=revision,gameTime=gameTime,realTime=realTime,forestThreat=forestThreat,noticePublished=noticePublished,noticeRead=noticeRead,settings=settings.Copy(),facts=facts.Select(f=>f.Copy()).ToList(),opportunities=opportunities.Select(o=>o.Copy()).ToList(),scheduled=scheduled.Select(s=>s.Copy()).ToList(),knowledge=knowledge.Select(k=>k.Copy()).ToList(),decisions=decisions.Select(d=>d.Copy()).ToList(),history=history.Select(h=>h.Copy()).ToList(),eligibilityHistory=eligibilityHistory.Select(e=>e.Copy()).ToList(),consideredCandidates=consideredCandidates.ToList() };
    }
    public static class WorldEventContent
    {
        public const string Policy="world-context-v1", Alert="forest-alert", Tracks="new-threat-tracks", Training="hunter-training", None="none";
        public const string Investigation="investigation-confirmed", Tracking="tracking-confirmed", Combat="wolf-defeated", Dodge="prepared-attack-dodged", TrainingHit="training-hit-confirmed";
        public static string Title(string id) => id==Alert?"O Alerta da Floresta":id==Tracks?"Rastros de uma Nova Ameaça":id==Training?"O Caçador Observa o Jogador":"";
        public static DecisionRecord Deterministic(WorldEvaluation c,string reason=null) => new DecisionRecord { eventId=c.eventId,actorId=c.actorId,worldId=c.worldId,policyId=c.policyId,stateVersion=c.stateVersion,decisionId="offline:"+c.eventId,selectedConsequence=new DeterministicPolicy().Select(c.eligibleConsequences),provider="deterministic",model="deterministic-v1",fallback=reason!=null,fallbackReason=reason };
    }
}
