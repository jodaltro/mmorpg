using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    // Compares authored roads on ONE terrain. No runtime generation or collider edits.
    public sealed class OrganicRoadLabController : MonoBehaviour
    {
        [SerializeField] private GameObject beforeSurface,afterSurface;
        [SerializeField] private GameObject[] roads;
        [SerializeField] private TextAsset[] roadData;
        [SerializeField] private Transform actor;
        [SerializeField] private Vector3 spawn;
        [SerializeField] private int selected=1;
        public int Selected=>selected;
        public TextAsset Road=>selected==0?null:roadData[selected-1];
        public void Configure(GameObject before,GameObject after,GameObject[] variants,TextAsset[] data,Transform player,Vector3 start)
        { beforeSurface=before;afterSurface=after;roads=variants;roadData=data;actor=player;spawn=start;Select(1); }
        public void Select(int value)
        {
            if(value<0||value>roads.Length)throw new ArgumentOutOfRangeException(nameof(value));
            selected=value;beforeSurface.SetActive(value==0);afterSurface.SetActive(value!=0);
            for(int i=0;i<roads.Length;i++)roads[i].SetActive(value==i+1);
            actor.position=spawn;var body=actor.GetComponent<Rigidbody2D>();body.position=spawn;
            if(Application.isPlaying)body.linearVelocity=Vector2.zero;
            Physics2D.SyncTransforms();
        }
        private void Update()
        {
            var keys=Keyboard.current;if(keys==null)return;
            if(keys.digit0Key.wasPressedThisFrame)Select(0);
            if(keys.digit1Key.wasPressedThisFrame)Select(1);
            if(keys.digit2Key.wasPressedThisFrame)Select(2);
            if(keys.digit3Key.wasPressedThisFrame)Select(3);
        }
    }
}
