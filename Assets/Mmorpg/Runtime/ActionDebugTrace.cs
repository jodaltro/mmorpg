using System.Collections.Generic;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public static class ActionDebugTrace
    {
        private static readonly Queue<string> entries = new Queue<string>();
        public static void Record(string category, string message)
        {
            entries.Enqueue($"[{Time.realtimeSinceStartup:0.0}] {category}: {message}");
            while (entries.Count > 14) entries.Dequeue();
        }
        public static string Recent(int count = 14)
        {
            var all = entries.ToArray();
            return string.Join("\n", all, System.Math.Max(0, all.Length-count), System.Math.Min(count,all.Length));
        }
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void Reset() => entries.Clear();
    }
}
