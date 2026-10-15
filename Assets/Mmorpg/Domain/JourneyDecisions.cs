using System;
using System.Collections.Generic;
using System.Linq;

namespace Mmorpg.Domain
{
    // Wire-neutral values: no transport or engine dependencies.
    [Serializable] public sealed class DecisionContext
    {
        public int version=1;
        public string eventId, actorId, worldId, policyId;
        public long stateVersion;
        public List<string> characterFacts=new List<string>(), npcKnowledge=new List<string>(), regionState=new List<string>(), eligibleConsequences=new List<string>();
    }
    [Serializable] public sealed class DecisionUsage
    {
        // JSON adapter serializes properties; Unity's asset serializer does not own these metrics.
        public long? input_tokens { get; set; }
        public long? output_tokens { get; set; }
        public double? cost { get; set; }
        public DecisionUsage Copy() => (DecisionUsage)MemberwiseClone();
    }
    [Serializable] public sealed class DecisionRecord
    {
        public int version=1;
        public string eventId, actorId, worldId, policyId, decisionId, selectedConsequence, model, provider, fallbackReason;
        public long stateVersion, latencyMs;
        public bool fallback;
        public double? confidence { get; set; }
        public Dictionary<string,double> probabilities { get; set; }
        public DecisionUsage usage;
        public DecisionAttempt attempt;
        public DecisionRecord Copy()
        {
            var copy=(DecisionRecord)MemberwiseClone();
            copy.probabilities=probabilities==null?null:new Dictionary<string,double>(probabilities);
            copy.usage=usage?.Copy(); copy.attempt=attempt?.Copy(); return copy;
        }
    }
    [Serializable] public sealed class DecisionAttempt
    {
        public string decisionId, model, provider, selectedConsequence;
        public double? confidence { get; set; }
        public Dictionary<string,double> probabilities { get; set; }
        public DecisionUsage usage;
        public DecisionAttempt Copy()
        {
            var copy=(DecisionAttempt)MemberwiseClone();
            copy.probabilities=probabilities==null?null:new Dictionary<string,double>(probabilities);
            copy.usage=usage?.Copy(); return copy;
        }
    }
    public static class MiraReactions
    {
        public const string Policy="mira-reaction-v1", Scientific="mira-scientific", Concern="mira-concern", Suspicion="mira-suspicion", Neutral="mira-neutral";
        public static IReadOnlyList<string> Options => new[]{Scientific,Concern,Suspicion,Neutral};
        public static string Text(string id)
        {
            switch(id)
            {
                case Scientific: return "Mira: Fascinante. A resina da amostra pode revelar como a corrupção se espalha.";
                case Concern: return "Mira: Essa corrupção me preocupa. Precisamos proteger a floresta enquanto investigamos.";
                case Suspicion: return "Mira: A amostra é válida, mas desconfio da origem dessa resina. Vou examiná-la com cuidado.";
                case Neutral: return "Mira: Recebi a amostra. Vou registrar o que sabemos sobre a corrupção.";
                default: return "";
            }
        }
        public static DecisionRecord Deterministic(DecisionContext context,string reason=null) => new DecisionRecord {
            eventId=context.eventId,actorId=context.actorId,worldId=context.worldId,policyId=context.policyId,stateVersion=context.stateVersion,
            decisionId="offline:"+context.eventId,selectedConsequence=new DeterministicPolicy().Select(context.eligibleConsequences),
            model="deterministic-v1",provider="deterministic",fallback=reason!=null,fallbackReason=reason };
        public static bool ValidMetadata(DecisionRecord r,bool requireSelectedProbability=true) => ValidMetadataFor(r,Options,requireSelectedProbability);
        public static bool ValidMetadataFor(DecisionRecord r,IReadOnlyList<string> options,bool requireSelectedProbability=true)
        {
            if(r==null||r.version!=1||string.IsNullOrWhiteSpace(r.decisionId)||string.IsNullOrWhiteSpace(r.model)||string.IsNullOrWhiteSpace(r.provider)||r.latencyMs<0) return false;
            if(r.confidence.HasValue&&!Probability(r.confidence.Value)) return false;
            if(r.probabilities!=null&&(r.probabilities.Any(p=>!options.Contains(p.Key)||!Probability(p.Value))||Math.Abs(r.probabilities.Sum(p=>p.Value)-1)>0.02||(requireSelectedProbability&&!r.probabilities.ContainsKey(r.selectedConsequence??"")))) return false;
            if(r.attempt!=null&&((!string.IsNullOrEmpty(r.attempt.selectedConsequence)&&!options.Contains(r.attempt.selectedConsequence))||!ValidMetadataFor(new DecisionRecord{
                decisionId=r.attempt.decisionId,model=r.attempt.model,provider=r.attempt.provider,selectedConsequence=r.attempt.selectedConsequence,
                confidence=r.attempt.confidence,probabilities=r.attempt.probabilities,usage=r.attempt.usage},options,false))) return false;
            return r.usage==null||((!r.usage.input_tokens.HasValue||r.usage.input_tokens>=0)&&(!r.usage.output_tokens.HasValue||r.usage.output_tokens>=0)&&(!r.usage.cost.HasValue||(!double.IsNaN(r.usage.cost.Value)&&!double.IsInfinity(r.usage.cost.Value)&&r.usage.cost>=0)));
        }
        private static bool Probability(double value) => !double.IsNaN(value)&&value>=0&&value<=1;
    }
}
