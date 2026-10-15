using System;
using System.Collections;
using Mmorpg.Domain;

namespace Mmorpg.Runtime
{
    // Asynchronous selection wraps, and never blocks, the existing synchronous route policy.
    public sealed class MiraDecisionOrchestrator
    {
        private readonly ILocalDecisionClient client;
        public MiraDecisionOrchestrator(ILocalDecisionClient client) { this.client=client; }
        public IEnumerator Resolve(JourneyEngine engine,Func<bool> stillCurrent,Action<bool> completed)
        {
            var context=engine.PendingMiraDecision();
            if(context==null) { completed(false); yield break; }
            DecisionRecord result=null;
            yield return client.Evaluate(context,value=>result=value);
            if(!stillCurrent()) { completed(false); yield break; }
            bool applied=engine.TryApplyDecision(result);
            RuntimeDiagnostics.Applied(context.eventId,result?.selectedConsequence,applied);
            if(!applied)
            {
                // Discard stale/invalid results. A NEW local decision uses freshly generated candidates.
                var fresh=engine.PendingMiraDecision();
                if(fresh!=null){var fallback=MiraReactions.Deterministic(fresh,fresh.stateVersion!=context.stateVersion?"state_changed":"invalid_local_response");applied=engine.TryApplyDecision(fallback);RuntimeDiagnostics.Applied(fresh.eventId,fallback.selectedConsequence,applied);}
            }
            completed(applied);
        }
    }
}
