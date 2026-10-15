using TMPro;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public sealed class TrainingDummy : MonoBehaviour
    {
        public const string TargetId="training-dummy";
        [SerializeField] private ActorHealth health;
        [SerializeField] private TMP_Text label;
        [SerializeField] private SpriteRenderer mark;
        [SerializeField] private float recoverySeconds=2;
        private int previousHealth, lastDamage;
        private double recoverAt;
        public ActorHealth Health => health;
        public int LastDamage => lastDamage;
        public void Configure(ActorHealth actor,TMP_Text text,SpriteRenderer marker) { health=actor; label=text; mark=marker; }
        private void OnEnable() { if(health.State!=null) previousHealth=health.State.Health; health.Changed+=OnChanged; }
        private void Start() => previousHealth=health.State.Health;
        private void OnDisable() { if(health!=null) health.Changed-=OnChanged; }
        private void OnChanged()
        {
            if(health.State.Health<previousHealth) { lastDamage=previousHealth-health.State.Health; recoverAt=Time.timeAsDouble+recoverySeconds; }
            previousHealth=health.State.Health;
        }
        public void SetMarked(bool value) => mark.enabled=value&&health.State.IsAlive;
        private void Update()
        {
            if(health.State.Health<health.State.MaximumHealth&&Time.timeAsDouble>=recoverAt) health.RestoreTrainingHealth();
            label.text=$"Boneco de treino\n{health.State.Health}/{health.State.MaximumHealth}  |  Último dano: {lastDamage}\nQ: marcar · J/clique: atacar";
        }
    }
}
