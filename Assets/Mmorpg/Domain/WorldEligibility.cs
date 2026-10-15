using System;
using System.Collections.Generic;
using System.Linq;

namespace Mmorpg.Domain
{
    public enum WorldConditionKind { And, Or, Fact, NpcKnowledge, RegionalThreat, OpportunityState, PreviousEvent, GameTimeAtLeast }
    [Serializable] public sealed class WorldCondition
    {
        public string ruleId, value, subjectId;
        public WorldConditionKind kind;
        public long time;
        public List<WorldCondition> children=new List<WorldCondition>();
    }
    [Serializable] public sealed class EligibilityEvidence
    {
        public string candidateId, ruleId;
        public bool eligible;
        public List<string> passedRules=new List<string>(), rejectedRules=new List<string>();
    }
    [Serializable] public sealed class WorldEligibilityAudit
    {
        public long revision;
        public List<EligibilityEvidence> evidence=new List<EligibilityEvidence>();
        public WorldEligibilityAudit Copy() => new WorldEligibilityAudit{revision=revision,evidence=evidence.Select(e=>new EligibilityEvidence{candidateId=e.candidateId,ruleId=e.ruleId,eligible=e.eligible,passedRules=e.passedRules.ToList(),rejectedRules=e.rejectedRules.ToList()}).ToList()};
    }
    public static class WorldEligibility
    {
        public static bool Evaluate(WorldCondition c,WorldState s,EligibilityEvidence evidence)
        {
            bool result;
            switch(c.kind)
            {
                case WorldConditionKind.And: result=c.children.Select(x=>Evaluate(x,s,evidence)).ToArray().All(x=>x); break;
                case WorldConditionKind.Or: result=c.children.Select(x=>Evaluate(x,s,evidence)).ToArray().Any(x=>x); break;
                case WorldConditionKind.Fact: result=s.facts.Any(f=>f.kind==c.value); break;
                case WorldConditionKind.NpcKnowledge: result=s.knowledge.Any(k=>k.npcId==c.subjectId&&s.facts.Any(f=>f.id==k.factId&&f.kind==c.value)); break;
                case WorldConditionKind.RegionalThreat: result=s.forestThreat; break;
                case WorldConditionKind.OpportunityState: result=s.opportunities.Any(o=>o.id==c.subjectId&&o.status.ToString()==c.value); break;
                case WorldConditionKind.PreviousEvent: result=s.scheduled.Any(x=>x.actionId==c.value&&x.executed); break;
                case WorldConditionKind.GameTimeAtLeast: result=s.gameTime>=c.time; break;
                default: result=false; break;
            }
            (result?evidence.passedRules:evidence.rejectedRules).Add(c.ruleId); return result;
        }
        private static WorldCondition Fact(string kind) => new WorldCondition{kind=WorldConditionKind.Fact,value=kind,ruleId="fact:"+kind};
        private static WorldCondition Known(string npc,string kind) => new WorldCondition{kind=WorldConditionKind.NpcKnowledge,value=kind,subjectId=npc,ruleId="knowledge:"+npc+":"+kind};
        private static WorldCondition And(string id,params WorldCondition[] conditions) => new WorldCondition{kind=WorldConditionKind.And,ruleId=id,children=conditions.ToList()};
        public static IReadOnlyList<EventCandidate> Definitions() => new[] {
            new EventCandidate{id=WorldEventContent.Alert,type="delayed-public-notice",scope="region",ruleId="alert-v1",authorizedActions=new List<string>{"schedule-notice"},conditions=And("alert-v1",Fact(WorldEventContent.Investigation),Known(ForestContent.Mira,WorldEventContent.Investigation),new WorldCondition{kind=WorldConditionKind.RegionalThreat,ruleId="regional-threat"})},
            new EventCandidate{id=WorldEventContent.Tracks,type="interactive-investigation",scope="character-region",ruleId="tracks-v1",authorizedActions=new List<string>{"spawn-tracks"},conditions=And("tracks-v1",Fact(WorldEventContent.Tracking),Fact(WorldEventContent.Combat),new WorldCondition{kind=WorldConditionKind.RegionalThreat,ruleId="regional-threat"})},
            new EventCandidate{id=WorldEventContent.Training,type="optional-training",scope="character",ruleId="training-v1",authorizedActions=new List<string>{"offer-training"},conditions=And("training-v1",Fact(WorldEventContent.Dodge),Known(ForestContent.Orin,WorldEventContent.Dodge))}
        };
    }
}
