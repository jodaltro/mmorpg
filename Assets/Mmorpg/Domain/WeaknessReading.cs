using System;

namespace Mmorpg.Domain
{
    [Serializable] public sealed class WeaknessParameters
    {
        public float range=3;
        public double duration=5, cooldown=8;
        public int bonus=10, maximumBonus=10;
        public bool IsValid => range>0&&!float.IsInfinity(range)&&duration>0&&cooldown>=duration&&!double.IsInfinity(duration)&&!double.IsInfinity(cooldown)&&bonus>0&&maximumBonus>0;
    }
    public sealed class WeaknessReading
    {
        private readonly WeaknessParameters rules;
        private string marked;
        private double expires, nextUse;
        public WeaknessReading(WeaknessParameters parameters)
        {
            if(parameters==null||!parameters.IsValid) throw new ArgumentException("Invalid weakness parameters");
            rules=new WeaknessParameters{range=parameters.range,duration=parameters.duration,cooldown=parameters.cooldown,bonus=parameters.bonus,maximumBonus=parameters.maximumBonus};
        }
        public float Range => rules.range;
        public double NextUse => nextUse;
        public string Marked(double now) => now<expires?marked:null;
        public bool TryMark(bool learned,bool actorAlive,string targetId,bool targetValid,float distance,double now)
        {
            if(!learned||!actorAlive||!targetValid||string.IsNullOrWhiteSpace(targetId)||distance<0||float.IsNaN(distance)||distance>rules.range||double.IsNaN(now)||double.IsInfinity(now)||now<nextUse) return false;
            marked=targetId; expires=now+rules.duration; nextUse=now+rules.cooldown; return true;
        }
        public int Bonus(string targetId,double now) => !double.IsNaN(now)&&!double.IsInfinity(now)&&Marked(now)==targetId&&marked!=null?Math.Min(rules.bonus,rules.maximumBonus):0;
        public void ConfirmHit(string targetId,double now) { if(Bonus(targetId,now)>0) marked=null; }
    }
}
