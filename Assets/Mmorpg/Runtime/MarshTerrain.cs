using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class MarshTerrain : MonoBehaviour
    {
        private void OnTriggerEnter2D(Collider2D other){var motor=other.GetComponent<ActorMotor>();if(motor!=null&&other.GetComponent<ActorHealth>()?.Faction==Faction.Player)motor.SetTerrainSpeed(.6f);}
        private void OnTriggerExit2D(Collider2D other){other.GetComponent<ActorMotor>()?.SetTerrainSpeed(1);}
    }
}
