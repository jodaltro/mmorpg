using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Mmorpg.Runtime
{
    public sealed class ActionDebugPanel : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private GameObject window;
        [SerializeField] private TMP_Text output;
        private bool visible = true;
        private float nextRefresh;
        private string lastMessage;
        public void Configure(JourneySession story, OfflineAuthority combat, GameObject panel, TMP_Text text)
        { journey = story; authority = combat; window = panel; output = text; }
        private void OnEnable()
        {
            Application.logMessageReceived += Log;
            authority.AttackPerformed += Attack;
            authority.HitConfirmed += Hit;
            authority.PreparedAttackDodged += Dodge;
            ActionDebugTrace.Record("DEBUG", "Ativo; F8 mostra/oculta. Combate local, narrativa assíncrona.");
        }
        private void OnDisable()
        {
            Application.logMessageReceived -= Log;
            if(authority == null) return;
            authority.AttackPerformed -= Attack;
            authority.HitConfirmed -= Hit;
            authority.PreparedAttackDodged -= Dodge;
        }
        private void Attack(ActorHealth actor, Vector2 direction) => ActionDebugTrace.Record("ATAQUE", actor.name + " direção " + direction);
        private void Hit(ActorHealth actor, ActorHealth target) => ActionDebugTrace.Record("ACERTO", actor.name + " -> " + target.name + " vida " + target.State.Health);
        private void Dodge(ActorHealth actor, ActorHealth target, string id) => ActionDebugTrace.Record("ESQUIVA", target.name + " evitou " + actor.name);
        private void Log(string message, string stack, LogType type)
        {
            if(type == LogType.Warning || type == LogType.Error || type == LogType.Exception || type == LogType.Assert)
                ActionDebugTrace.Record(type.ToString(), message.Length > 160 ? message.Substring(0,160) : message);
        }
        private void Update()
        {
            if(Keyboard.current != null && Keyboard.current.f8Key.wasPressedThisFrame)
            { visible = !visible; window.SetActive(visible); }
            if(journey.Message != lastMessage)
            { lastMessage = journey.Message; ActionDebugTrace.Record("JORNADA", lastMessage); }
            if(!visible || Time.unscaledTime < nextRefresh || journey.Engine == null) return;
            nextRefresh = Time.unscaledTime + .2f;
            var player = journey.Player;
            bool pending = journey.DecisionPending || journey.WorldEvents != null && journey.WorldEvents.DecisionPending;
            var prior = journey.Engine.Snapshot().decisions;
            string state = pending ? "aguardando resposta" : journey.Engine.PendingMiraDecision()!=null ? "decisão elegível"
                : prior.Count > 0 ? "Mira já resolvida; sem pedido pendente" : "entregue amostra a Mira";
            output.text = $"DEBUG F8 · {Time.unscaledDeltaTime*1000:0.0}ms · HP {player.State.Health}\n" +
                $"{journey.NarrativeMode} · HTTP {ActionMetrics.Active?.NetworkOperations ?? 0}\n" +
                state + "\n" + ActionDebugTrace.Recent(3);
        }
    }
}
