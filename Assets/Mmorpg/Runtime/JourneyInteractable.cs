using UnityEngine;

namespace Mmorpg.Runtime
{
    public enum InteractionKind { Mira, Orin, Trace, Sample, NoticeBoard, NewTracks, Passage }
    public sealed class JourneyInteractable : MonoBehaviour
    {
        [SerializeField] private InteractionKind kind;
        [SerializeField] private float range=1.4f;
        public InteractionKind Kind => kind;
        public float Range => range;
        public void Configure(InteractionKind value) => kind=value;
    }
}
