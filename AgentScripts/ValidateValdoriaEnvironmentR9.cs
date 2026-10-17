using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

public static class ValidateValdoriaEnvironmentR9
{
    public static async Task<string> MoveAndCapture()
    {
        if (!EditorApplication.isPlaying) throw new InvalidOperationException("R9 movement proof requires Play Mode.");
        if (!LocalJourneyProfile.Root.Contains(Path.Combine("Temp", "ValdoriaEnvironmentR9")))
            throw new InvalidOperationException("R9 personal-save isolation is not active.");
        var player = GameObject.Find("Player");
        if (player == null) throw new InvalidOperationException("R9 player is missing.");
        var body = player.GetComponent<ProductionSpriteAnimator>();
        var rb = player.GetComponent<Rigidbody2D>();
        var start = rb.position;
        var keyboard = InputSystem.devices.OfType<Keyboard>().FirstOrDefault(k => k.name == "ValdoriaR9ValidationKeyboard");
        bool created = keyboard == null;
        if (created) keyboard = InputSystem.AddDevice<Keyboard>("ValdoriaR9ValidationKeyboard");
        try
        {
            Directory.CreateDirectory("Docs/Validation/ValdoriaEnvironmentR9");
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(Key.D));
            await Task.Delay(220);
            var during = rb.position;
            var stateDuringInput = body.State;
            var directionDuringInput = body.DirectionIndex;
            var texture = ScreenCapture.CaptureScreenshotAsTexture();
            try { File.WriteAllBytes("Docs/Validation/ValdoriaEnvironmentR9/gameplay-r9-play.png", texture.EncodeToPNG()); }
            finally { UnityEngine.Object.Destroy(texture); }
            InputSystem.QueueStateEvent(keyboard, new KeyboardState());
            await Task.Delay(140);
            var finish = rb.position;
            if (Vector2.Distance(start, finish) < .15f) throw new InvalidOperationException("D input did not move the R9 player.");
            var evidence = new
            {
                scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                input = "InputSystem Keyboard D down/up",
                direction = "east",
                start = new[] { start.x, start.y },
                duringInput = new[] { during.x, during.y },
                finish = new[] { finish.x, finish.y },
                displacement = Vector2.Distance(start, finish),
                animatorStateDuringInput = stateDuringInput,
                animatorDirectionDuringInput = directionDuringInput,
                frame = Time.frameCount,
                isolatedProfile = LocalJourneyProfile.Root,
                capture = "Docs/Validation/ValdoriaEnvironmentR9/gameplay-r9-play.png"
            };
            File.WriteAllText("Docs/Validation/ValdoriaEnvironmentR9/play-movement.json", JsonConvert.SerializeObject(evidence, Formatting.Indented));
            return "R9 real Input System movement captured: " + start + " -> " + finish + ", state=" + body.State;
        }
        finally
        {
            InputSystem.QueueStateEvent(keyboard, new KeyboardState());
            if (created && keyboard != null) InputSystem.RemoveDevice(keyboard);
        }
    }
}
