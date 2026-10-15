using TMPro;
using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class WorldLabelProximity : MonoBehaviour
    {
        [SerializeField] private TMP_Text label;
        [SerializeField] private Transform player;
        [SerializeField] private float distance=2.2f;
        public void Configure(TMP_Text text,Transform target){label=text;player=target;}
        private void LateUpdate(){if(label!=null&&player!=null)label.enabled=Vector2.Distance(player.position,transform.position)<distance;}
    }
}
