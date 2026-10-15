using System;
using System.Collections.Generic;
using UnityEngine.Networking;
namespace Mmorpg.Runtime
{
    // Epoch is independent of actor/world IDs. Old callbacks cannot cross a reload/reset boundary.
    public static class SessionEpoch
    {
        private static readonly HashSet<UnityWebRequest> requests=new HashSet<UnityWebRequest>();
        public static long Current {get;private set;}
        public static void Track(UnityWebRequest request)=>requests.Add(request);
        public static void Untrack(UnityWebRequest request)=>requests.Remove(request);
        public static void Advance()
        {
            Current++;
            foreach(var r in requests)try{r.Abort();}catch(InvalidOperationException){}
            requests.Clear();RuntimeDiagnostics.CancelPending();
        }
    }
}
