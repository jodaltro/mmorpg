namespace Mmorpg.Domain
{
    // Prepared transport boundary, not a deployed online simulation. Actor identity
    // must be bound to an authenticated session by any future remote implementation.
    public enum RealtimeIntentKind { Move, BasicAttack, HeavyAttack, Dodge, WeaknessReading, Counterattack, HunterMark, Interact }
    public struct RealtimeIntent
    {
        public int Version;
        public long Sequence;
        public RealtimeIntentKind Kind;
        public float DirectionX, DirectionY;
        public string TargetInstanceId;
        // No damage, defeat, reward, health or client-authoritative timestamp.
    }
    public interface IRealtimeAuthority
    {
        bool Submit(RealtimeIntent intention);
    }
}
