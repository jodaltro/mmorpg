using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    // Baked alternatives only. No generation, imports or persistence at runtime.
    public sealed class TerrainLabController : MonoBehaviour
    {
        [SerializeField] private GameObject[] alternatives;
        [SerializeField] private TextAsset[] regions;
        [SerializeField] private Transform actor;
        [SerializeField] private Vector3 spawn;
        [SerializeField] private int selected;
        public int Selected => selected;
        public TextAsset Region => regions[selected];
        public void Configure(GameObject[] roots, TextAsset[] data, Transform player, Vector3 start)
        { alternatives=roots;regions=data;actor=player;spawn=start;Select(0); }
        public void Select(int index)
        {
            if(index<0 || index>=alternatives.Length)throw new ArgumentOutOfRangeException(nameof(index));
            selected=index;
            for(int i=0;i<alternatives.Length;i++)alternatives[i].SetActive(i==index);
            actor.position=spawn;
            var body=actor.GetComponent<Rigidbody2D>();
            body.position=spawn;
            if(Application.isPlaying)body.linearVelocity=Vector2.zero;
            Physics2D.SyncTransforms();
        }
        private void Update()
        {
            var keys=Keyboard.current;if(keys==null)return;
            if(keys.digit1Key.wasPressedThisFrame)Select(0);
            if(keys.digit2Key.wasPressedThisFrame)Select(1);
            if(keys.digit3Key.wasPressedThisFrame)Select(2);
        }
    }
}
