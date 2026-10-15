namespace Mmorpg.Domain
{
    public enum ActionStrike { Basic, Heavy, Counter, Wolf, Venom, Golem, Poison }
    public static class ActionCombatRules
    {
        public static int Damage(ActionStrike strike, bool armored, bool exposed)
        {
            int amount = strike == ActionStrike.Basic ? 20 : strike == ActionStrike.Heavy ? 36 :
                strike == ActionStrike.Counter ? 30 : strike == ActionStrike.Golem ? 28 :
                strike == ActionStrike.Venom ? 8 : strike == ActionStrike.Poison ? 4 : 15;
            return armored && !exposed && strike != ActionStrike.Counter ? System.Math.Max(1, amount - 14) : amount;
        }
        public const double HeavyWindup = 0.38, HeavyCooldown = 1.2, CounterWindow = 1.4, CounterCooldown = 3;
        public const double MarkDuration = 8, MarkCooldown = 10, PoisonDuration = 4;
    }
}
