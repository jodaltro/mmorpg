using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine.InputSystem;

namespace Mmorpg.Tests
{
    // Keep desktop input from replacing Keyboard.current while scene tests inject a test keyboard.
    // Disable only Unity's enabled native devices, then restore their original enabled state.
    [SetUpFixture]
    public sealed class SceneInputIsolation
    {
        private readonly List<InputDevice> disabled=new List<InputDevice>();
        [OneTimeSetUp] public void IsolateDesktopInput()
        {
            foreach(var device in InputSystem.devices)
                if(device.native&&device.enabled&&(device is Keyboard||device is Mouse)) {
                    InputSystem.ResetDevice(device); InputSystem.DisableDevice(device); disabled.Add(device);
                }
        }
        [OneTimeTearDown] public void RestoreDesktopInput()
        {
            foreach(var device in disabled) if(device.added) InputSystem.EnableDevice(device);
            disabled.Clear();
        }
    }
}
