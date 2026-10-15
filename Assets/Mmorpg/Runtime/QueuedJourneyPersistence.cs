using System;
using System.Threading.Tasks;
using Mmorpg.Domain;
namespace Mmorpg.Runtime
{
    // Action-only adapter: disk flushes run on one worker, without Unity objects or HTTP.
    public sealed class QueuedJourneyPersistence : IJourneyPersistence
    {
        private readonly IJourneyPersistence disk;
        private readonly object gate=new object();
        private JourneySnapshot pending;
        private string pendingCorrelation;
        private Task worker=Task.CompletedTask;
        private Exception failure;
        private bool running;
        public QueuedJourneyPersistence(IJourneyPersistence storage) => disk=storage;
        public void Save(JourneySnapshot snapshot)
            =>Save(snapshot,null);
        public void Save(JourneySnapshot snapshot,string correlation)
        {
            lock(gate)
            {
                if(failure!=null)throw new InvalidOperationException("Background save failed",failure);
                pending=snapshot; // CaptureSnapshot produces detached domain copies.
                pendingCorrelation=correlation;
                if(!running) {running=true;worker=Task.Run(WriteLoop);}
            }
        }
        private void WriteLoop()
        {
            while(true)
            {
                JourneySnapshot next;
                string correlation;
                lock(gate) {next=pending;correlation=pendingCorrelation;pending=null;pendingCorrelation=null;if(next==null){running=false;return;}}
                try {disk.Save(next);RuntimeDiagnostics.Persist(correlation,"local / salvo");}
                catch(Exception ex) {RuntimeDiagnostics.Persist(null,"erro local");lock(gate){failure=ex;pending=null;running=false;}return;}
            }
        }
        public void Flush()
        {
            Task current;lock(gate)current=worker;current.GetAwaiter().GetResult();
            lock(gate)if(failure!=null)throw new InvalidOperationException("Background save failed",failure);
        }
        public JourneySnapshot Load() {Flush();return disk.Load();}
    }
}
