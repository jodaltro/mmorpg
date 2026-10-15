using System;
using System.Collections.Generic;

namespace Mmorpg.Domain
{
    public enum EventType { CreatureDefeated, EvidenceCollected, TraceExamined, NpcInteracted, EvidenceDelivered, OpportunityDiscovered, AbilityUnlocked, CombatActionVerified }
    public enum OpportunityStatus { Unknown, Available, Started, Completed, Closed }
    public static class CombatActions { public const string PreparedDodge="prepared-dodge", TrainingHit="training-hit"; }
    [Serializable] public sealed class CombatPayload { public string actionId, encounterId, targetId, preparedAttackId; }
    [Serializable] public sealed class CreaturePayload { public string creatureId; public string encounterId; public bool observed; }
    [Serializable] public sealed class EvidencePayload { public string evidenceId; public string encounterId; public string recipientId; }
    [Serializable] public sealed class TracePayload { public string traceId; }
    [Serializable] public sealed class NpcPayload { public string npcId; public string sharedFact; }
    [Serializable] public sealed class DiscoveryPayload { public string definitionId; public string routeId; }

    // Explicit discriminated payload union; exactly one payload must match eventType.
    [Serializable] public sealed class GameEvent
    {
        public int version = 1, payloadVersion = 1;
        public string eventId, actorId, sourceId, worldId;
        public EventType eventType;
        public long timestamp;
        public CreaturePayload creature;
        public CombatPayload combat;
        public EvidencePayload evidence;
        public TracePayload trace;
        public NpcPayload npc;
        public DiscoveryPayload discovery;
        public GameEvent Copy() => new GameEvent {
            version=version, payloadVersion=payloadVersion, eventId=eventId, actorId=actorId, sourceId=sourceId, worldId=worldId, eventType=eventType, timestamp=timestamp,
            combat=combat==null?null:new CombatPayload{actionId=combat.actionId,encounterId=combat.encounterId,targetId=combat.targetId,preparedAttackId=combat.preparedAttackId},
            creature=creature==null?null:new CreaturePayload{creatureId=creature.creatureId,encounterId=creature.encounterId,observed=creature.observed},
            evidence=evidence==null?null:new EvidencePayload{evidenceId=evidence.evidenceId,encounterId=evidence.encounterId,recipientId=evidence.recipientId},
            trace=trace==null?null:new TracePayload{traceId=trace.traceId}, npc=npc==null?null:new NpcPayload{npcId=npc.npcId,sharedFact=npc.sharedFact},
            discovery=discovery==null?null:new DiscoveryPayload{definitionId=discovery.definitionId,routeId=discovery.routeId} };
    }
    [Serializable] public sealed class OpportunityRecord { public string id; public OpportunityStatus status; }
    [Serializable] public sealed class KnowledgeRecord { public string npcId, fact, sourceEventId; }
    [Serializable] public sealed class RelationRecord { public string npcId; public int trust; }
    [Serializable] public sealed class JourneySnapshot
    {
        public int version = 1;
        public string actorId, worldId;
        public WorldState world;
        public List<GameEvent> inputs = new List<GameEvent>();
        public List<GameEvent> facts = new List<GameEvent>();
        public List<string> abilities = new List<string>(), evidence = new List<string>(), delivered = new List<string>();
        public List<OpportunityRecord> opportunities = new List<OpportunityRecord>();
        public List<KnowledgeRecord> knowledge = new List<KnowledgeRecord>();
        public List<RelationRecord> relations = new List<RelationRecord>();
        public List<DecisionRecord> decisions = new List<DecisionRecord>();
    }
    public interface IJourneyPersistence { void Save(JourneySnapshot state); JourneySnapshot Load(); }
    // A future Jev policy ranks candidate IDs only. It cannot supply rewards or facts.
    public interface IConsequencePolicy { string Select(IReadOnlyList<string> eligible); }
    public sealed class DeterministicPolicy : IConsequencePolicy
    {
        public string Select(IReadOnlyList<string> eligible) => eligible.Count == 0 ? null : eligible[0];
    }
    public static class ForestContent
    {
        public const string World="offline-clearing", Actor="player", Wolf="corrupted-wolf", Trace="corrupted-tracks", Sample="corruption-sample";
        public const string Mira="mira", Orin="orin", Technique="weakness-reading", RouteA="forest-sample", RouteB="forest-observation";
    }
}
