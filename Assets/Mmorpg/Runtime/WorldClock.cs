using System;
using Mmorpg.Domain;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public sealed class WorldClock : IWorldClock
    {
        private readonly long offset;
        private readonly double startedAt;
        public WorldClock(long savedGameTime) { offset=savedGameTime; startedAt=Time.timeAsDouble; }
        public long GameMilliseconds => offset+(long)(Math.Max(0,Time.timeAsDouble-startedAt)*1000);
        public long RealMilliseconds => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    }
}
