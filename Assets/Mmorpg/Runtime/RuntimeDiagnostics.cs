using System;
using System.Collections.Generic;
using System.Linq;
using Mmorpg.Domain;
namespace Mmorpg.Runtime
{
    public sealed class DiagnosticSnapshot
    {
        public string Go="NÃO VERIFICADO",Database="NÃO VERIFICADO",Jev="NÃO CONFIGURADO",Provider="determinístico local";
        public string LastEvent="—",Consequence="—",Opportunity="—",Persistence="—",LastDecision="—";
        public long GoMs=-1,DatabaseMs=-1;
        public int Evaluations,Events;
        public long Revision;
        public float Fps;
        public string[] History=Array.Empty<string>();
    }
    // Only sanitized IDs and stages. No prompts, URLs with credentials, payloads or tokens.
    public static class RuntimeDiagnostics
    {
        private static readonly object gate=new object();
        private static readonly Queue<string> history=new Queue<string>();
        private static DiagnosticSnapshot state=new DiagnosticSnapshot();
        private static readonly HashSet<string> pending=new HashSet<string>();
        private static string Short(string value)=>string.IsNullOrEmpty(value)?"—":new string(value.Where(c=>char.IsLetterOrDigit(c)||"-_.:".Contains(c)).Take(48).ToArray());
        public static void Reset(){lock(gate){state=new DiagnosticSnapshot();history.Clear();pending.Clear();}}
        public static DiagnosticSnapshot Read()
        {
            lock(gate)return new DiagnosticSnapshot{Go=state.Go,Database=state.Go=="ONLINE"?state.Database:"NÃO VERIFICADO",Jev=state.Jev,Provider=state.Provider,LastEvent=state.LastEvent,Consequence=state.Consequence,Opportunity=state.Opportunity,Persistence=state.Persistence,LastDecision=state.LastDecision,GoMs=state.GoMs,DatabaseMs=state.DatabaseMs,Evaluations=pending.Count,Events=state.Events,Revision=state.Revision,Fps=state.Fps,History=history.ToArray()};
        }
        public static void Trace(string correlation,string stage,string detail)
        {
#if UNITY_EDITOR || DEVELOPMENT_BUILD
            lock(gate){while(history.Count>=64)history.Dequeue();history.Enqueue(DateTime.UtcNow.ToString("HH:mm:ss")+" "+Short(correlation)+" | "+Short(stage)+" | "+Short(detail));}
#endif
        }
        public static void Configure(DecisionMode mode){lock(gate){state.Provider=mode==DecisionMode.OpenRouter?"OpenRouter via Go":"determinístico local";state.Jev=mode==DecisionMode.OpenRouter?"NÃO VERIFICADO":"NÃO CONFIGURADO";}}
        public static void Fact(string id,string type){lock(gate)state.LastEvent=Short(type)+" "+Short(id).Substring(0,Math.Min(8,Short(id).Length));Trace(id,"GameplayEvent",type);}
        public static void Begin(string id,int candidates,bool remote)
        {lock(gate){pending.Add(id);state.Jev=remote?"PROCESSANDO":"FALLBACK DETERMINÍSTICO";}Trace(id,"EligibilityCandidates",candidates.ToString());Trace(id,"Decision",remote?"waiting":"deterministic");}
        public static void End(string id,DecisionRecord record,long elapsed,bool realHttp)
        {
            lock(gate)
            {
                pending.Remove(id);bool local=record?.provider=="deterministic";
                state.Jev=record==null?"ERRO":record.fallback?"FALLBACK DETERMINÍSTICO":local?"LOCAL / NÃO CONFIGURADO":"CONCLUÍDA";
                state.LastDecision=realHttp?elapsed+"ms HTTP / "+Short(record?.provider):"local / sem chamada IA";
                if(realHttp&&record!=null&&!local)state.LastDecision+=" · provedor "+record.latencyMs+"ms"+(record.usage?.cost.HasValue==true?" · $"+record.usage.cost.Value.ToString("0.######",System.Globalization.CultureInfo.InvariantCulture):"");
            }
            Trace(id,"Decision",record==null?"error":record.fallback?"fallback":"completed");
        }
        public static void Applied(string id,string consequence,bool accepted)
        {if(accepted)lock(gate)state.Consequence=Short(consequence);Trace(id,"Validation",accepted?"accepted":"rejected");if(accepted)Trace(id,"Consequence",consequence);}
        public static void Persist(string id,string result){lock(gate)state.Persistence=result;Trace(id,"Persistence",result);}
        public static void Observe(int events,string opportunity,long revision){lock(gate){state.Events=events;state.Opportunity=Short(opportunity);state.Revision=revision;}}
        public static void Health(string status,long milliseconds){lock(gate){state.Go=status;state.GoMs=milliseconds;if(status!="ONLINE"){state.Database="NÃO VERIFICADO";state.DatabaseMs=-1;}}}
        public static void Database(bool success,long ms){lock(gate){state.Database=success?"OK (operação real)":"DEGRADADO";state.DatabaseMs=ms;}}
        public static void Frames(float fps){lock(gate)state.Fps=fps;}
        public static void CancelPending(){lock(gate){pending.Clear();state.Jev="CANCELADO / sessão";}}
    }
}
