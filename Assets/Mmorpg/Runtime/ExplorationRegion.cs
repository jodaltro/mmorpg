using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class ExplorationRegion : MonoBehaviour
    {
        [SerializeField] private string title;
        [SerializeField] private Vector2 safeEntry;
        public string Title=>title;
        public Vector2 SafeEntry=>safeEntry;
        public void Configure(string name,Vector2 entry){title=name;safeEntry=entry;}
        private void OnTriggerEnter2D(Collider2D other)
        {var player=other.GetComponent<ActorHealth>();if(player!=null&&player.Faction==Faction.Player)FindAnyObjectByType<ExplorationWorld>()?.Enter(this);}
    }
}
