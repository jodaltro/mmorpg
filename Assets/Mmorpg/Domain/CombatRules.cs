namespace Mmorpg.Domain
{
    public static class CombatRules
    {
        public const int PlayerHealth = 100;
        public const int WolfHealth = 60;
        public const int PlayerDamage = 20;
        public const int WolfDamage = 15;
        public const float PlayerSpeed = 3.5f;
        public const float DodgeSpeed = 9f;
        public const float AttackRange = 1.25f;
        public const float WolfRange = 1.05f;
        public const double AttackCooldown = 0.4;
        public const double DodgeDuration = 0.22;
        public const double DodgeCooldown = 0.9;
        public const double WolfCooldown = 1.1;
        public const double DamageImmunity = 0.35;
    }
}
