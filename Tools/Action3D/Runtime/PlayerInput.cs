using System.Collections;
using UnityEngine;
using UnityEngine.InputSystem;

// API adapter for the Game Kit prefab's existing script GUID.
public class PlayerInput : MonoBehaviour
{
    public static PlayerInput Instance { get; private set; }
    public bool playerControllerInputBlocked;
    bool externalBlocked;
    InputAction move, look, jump, attack, pause;
    float attackUntil;
    public Vector2 MoveInput => HaveControl() && !playerControllerInputBlocked ? move.ReadValue<Vector2>() : Vector2.zero;
    public Vector2 CameraInput => HaveControl() && !playerControllerInputBlocked ? look.ReadValue<Vector2>() * 0.08f : Vector2.zero;
    public bool JumpInput => HaveControl() && !playerControllerInputBlocked && jump.IsPressed();
    public bool Attack => HaveControl() && !playerControllerInputBlocked && Time.unscaledTime < attackUntil;
    public bool Pause => pause.WasPressedThisFrame();
    void Awake()
    {
        Instance = this;
        move = new InputAction("Move", InputActionType.Value);
        move.AddCompositeBinding("2DVector").With("Up", "<Keyboard>/w").With("Down", "<Keyboard>/s").With("Left", "<Keyboard>/a").With("Right", "<Keyboard>/d");
        move.AddBinding("<Gamepad>/leftStick");
        look = new InputAction("Look", InputActionType.Value, "<Mouse>/delta");
        look.AddBinding("<Gamepad>/rightStick").WithProcessor("scaleVector2(x=16,y=16)");
        jump = new InputAction("Jump", InputActionType.Button, "<Keyboard>/space");
        jump.AddBinding("<Gamepad>/buttonSouth");
        attack = new InputAction("Attack", InputActionType.Button, "<Mouse>/leftButton");
        attack.AddBinding("<Gamepad>/buttonWest");
        pause = new InputAction("Pause", InputActionType.Button, "<Keyboard>/escape");
    }
    void OnEnable() { move.Enable(); look.Enable(); jump.Enable(); attack.Enable(); pause.Enable(); }
    void OnDisable() { move.Disable(); look.Disable(); jump.Disable(); attack.Disable(); pause.Disable(); }
    void OnDestroy() { move.Dispose(); look.Dispose(); jump.Dispose(); attack.Dispose(); pause.Dispose(); if (Instance == this) Instance = null; }
    void Update() { if (attack.WasPressedThisFrame()) attackUntil = Time.unscaledTime + 0.08f; }
    public bool HaveControl() => !externalBlocked;
    public void ReleaseControl() { externalBlocked = true; }
    public void GainControl() { externalBlocked = false; }
}
