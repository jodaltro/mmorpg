using Cinemachine;
using Gamekit3D;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

public sealed class Action3DSession : MonoBehaviour
{
    public int interactions;
    public GameObject gate;
    public UnityEngine.UI.Text status;
    void Awake()
    {
        CinemachineCore.GetInputAxis = Axis;
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }
    static float Axis(string axis)
    {
        var input = PlayerInput.Instance;
        if (input == null) return 0;
        return axis == "Mouse X" || axis == "CameraX" ? input.CameraInput.x : input.CameraInput.y;
    }
    void Update()
    {
        var actor = PlayerController.instance;
        if (status != null && actor != null)
        {
            var health = actor.GetComponent<Damageable>();
            status.text = "VALDORIA | ACTION 3D\nVida " + Mathf.Max(0, health.currentHitPoints) + " / " + health.maxHitPoints
                + "\nWASD mover | Mouse camera | Clique atacar | Espaco saltar\nE no pedestal: recuperar vida e abrir passagem\nR reiniciar arena | Esc liberar mouse | Botao direito capturar"
                + (interactions > 0 ? "\nPassagem aberta. Pedestal ativado." : "\nExplore a arena e enfrente o Chomper.");
        }
        var keyboard = Keyboard.current;
        if (keyboard == null) return;
        if (keyboard.escapeKey.wasPressedThisFrame)
        {
            bool captured = Cursor.lockState == CursorLockMode.Locked;
            Cursor.lockState = captured ? CursorLockMode.None : CursorLockMode.Locked;
            Cursor.visible = captured;
        }
        if (Mouse.current != null && Mouse.current.rightButton.wasPressedThisFrame) { Cursor.lockState = CursorLockMode.Locked; Cursor.visible = false; }
        if (keyboard.rKey.wasPressedThisFrame) SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
    }
    public void Interact()
    {
        interactions++;
        PlayerController.instance.GetComponent<Damageable>().ResetDamage();
        if (gate != null) gate.SetActive(false);
    }
    void OnDestroy()
    {
        CinemachineCore.GetInputAxis = UnityEngine.Input.GetAxis;
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }
}
