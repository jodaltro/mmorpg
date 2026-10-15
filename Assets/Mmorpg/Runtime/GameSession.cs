using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace Mmorpg.Runtime
{
    public sealed class GameSession : MonoBehaviour
    {
        [SerializeField] private ActorHealth player;
        [SerializeField] private ActorHealth wolf;
        public ActorHealth Player => player;
        public ActorHealth Wolf => wolf;
        public bool Finished => !player.State.IsAlive || !wolf.State.IsAlive;
        public void Configure(ActorHealth hero, ActorHealth enemy) { player = hero; wolf = enemy; }
        private void Update()
        {
            if (Keyboard.current != null && Keyboard.current.rKey.wasPressedThisFrame) Restart();
        }
        public void Restart() => SceneManager.LoadScene(SceneManager.GetActiveScene().path);
    }
}
