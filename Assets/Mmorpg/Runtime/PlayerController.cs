using Mmorpg.Domain;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Mmorpg.Runtime
{
    [RequireComponent(typeof(ActorMotor), typeof(ActorHealth))]
    public sealed class PlayerController : MonoBehaviour
    {
        [SerializeField] private OfflineAuthority authority;
        private ActorMotor motor;
        private ActorHealth health;
        private Vector2 dodgeDirection;
        [SerializeField] private ActionCombat actionCombat;
        [SerializeField, Range(0,1)] private float attackMovement = .55f;
        public void ConfigureAction(ActionCombat value) => actionCombat = value;
        public void Configure(OfflineAuthority value) => authority = value;
        private void Awake() { motor = GetComponent<ActorMotor>(); health = GetComponent<ActorHealth>(); }
        private void Update()
        {
            var keyboard = Keyboard.current;
            if (Time.timeScale == 0) return;
            if (!health.State.IsAlive || keyboard == null) { motor.SetIntent(Vector2.zero, 0); return; }
            Vector2 mouseFacing = motor.Facing;
            if(actionCombat!=null && Mouse.current!=null && Camera.main!=null)
            {
                mouseFacing=(Vector2)Camera.main.ScreenToWorldPoint(Mouse.current.position.ReadValue())-(Vector2)transform.position;
                motor.Aim(mouseFacing); // Same-frame mouse input must orient a stationary dodge too.
            }
            Vector2 move = new Vector2(
                (keyboard.dKey.isPressed || keyboard.rightArrowKey.isPressed ? 1 : 0) - (keyboard.aKey.isPressed || keyboard.leftArrowKey.isPressed ? 1 : 0),
                (keyboard.wKey.isPressed || keyboard.upArrowKey.isPressed ? 1 : 0) - (keyboard.sKey.isPressed || keyboard.downArrowKey.isPressed ? 1 : 0));
            if ((keyboard.spaceKey.wasPressedThisFrame || keyboard.leftShiftKey.wasPressedThisFrame) && authority.RequestDodge(health))
                dodgeDirection = move == Vector2.zero ? motor.Facing : actionCombat != null ? move.normalized : ActorMotor.Cardinal(move);
            motor.SetIntent(health.State.IsDodging(Time.timeAsDouble) ? dodgeDirection : move,
                health.State.IsDodging(Time.timeAsDouble) ? CombatRules.DodgeSpeed : CombatRules.PlayerSpeed);
            if (actionCombat != null)
            {
                motor.Aim(mouseFacing);
                if (actionCombat.Committed && !health.State.IsDodging(Time.timeAsDouble))
                { motor.SetIntent(move, CombatRules.PlayerSpeed * attackMovement); motor.Aim(mouseFacing); }
                if (Mouse.current != null && Mouse.current.rightButton.wasPressedThisFrame) actionCombat.RequestHeavy(motor.Facing);
                if (keyboard.fKey.wasPressedThisFrame) actionCombat.RequestCounter(motor.Facing);
                if (keyboard.cKey.wasPressedThisFrame) actionCombat.RequestHunterMark();
            }
            if ((actionCombat == null || !actionCombat.Committed) && (keyboard.jKey.wasPressedThisFrame || (Mouse.current != null && Mouse.current.leftButton.wasPressedThisFrame)))
                authority.RequestAttack(health, motor.Facing);
        }
    }
}
