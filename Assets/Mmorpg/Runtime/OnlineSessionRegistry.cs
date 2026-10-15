using System;
using System.Collections.Generic;
namespace Mmorpg.Runtime
{
    public static class OnlineSessionRegistry
    {
        private static readonly List<WeakReference<SupabaseSession>> sessions=new List<WeakReference<SupabaseSession>>();
        public static void Register(SupabaseSession session){sessions.RemoveAll(w=>!w.TryGetTarget(out _));sessions.Add(new WeakReference<SupabaseSession>(session));}
        public static bool AnyAuthenticated {get {foreach(var w in sessions)if(w.TryGetTarget(out var s)&&s.HasSession)return true;return false;}}
    }
}
