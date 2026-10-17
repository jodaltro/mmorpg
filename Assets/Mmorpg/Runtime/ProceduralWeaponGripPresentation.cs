using System;
using System.Collections.Generic;
using UnityEngine;

namespace Mmorpg.Runtime
{
    // Baked weapon-driven IK/contact masks. Presentation only; SwordSwing owns all hits/timing.
    [DefaultExecutionOrder(200)]
    public sealed class ProceduralWeaponGripPresentation : MonoBehaviour
    {
        [Serializable]
        public struct ContactFrame
        {
            public Sprite body;
            public Sprite fingers;
        }

        [SerializeField] private SpriteRenderer body;
        [SerializeField] private SpriteRenderer blade;
        [SerializeField] private SpriteRenderer fingers;
        [SerializeField] private ActorHealth actor;
        [SerializeField] private ContactFrame[] frames;
        private readonly Dictionary<Sprite, Sprite> masks = new Dictionary<Sprite, Sprite>();

        public void Configure(SpriteRenderer character, SpriteRenderer weapon,
            SpriteRenderer foreground, ActorHealth health, ContactFrame[] contacts)
        {
            body = character;
            blade = weapon;
            fingers = foreground;
            actor = health;
            frames = contacts;
            IndexFrames();
        }

        private void Awake() => IndexFrames();

        private void IndexFrames()
        {
            masks.Clear();
            if (frames == null) return;
            foreach (var frame in frames)
                if (frame.body != null && frame.fingers != null)
                    masks[frame.body] = frame.fingers;
        }

        private void LateUpdate()
        {
            bool visible = actor.State.IsAlive && blade.enabled && blade.gameObject.activeInHierarchy
                && body.sprite != null && masks.TryGetValue(body.sprite, out var mask);
            fingers.enabled = visible;
            if (!visible) return;
            fingers.sprite = masks[body.sprite];
            fingers.transform.SetPositionAndRotation(body.transform.position, body.transform.rotation);
            fingers.transform.localScale = body.transform.localScale;
            fingers.sortingLayerID = blade.sortingLayerID;
            fingers.sortingOrder = Mathf.Max(body.sortingOrder, blade.sortingOrder) + 1;
            fingers.color = body.color;
            fingers.flipX = body.flipX;
            fingers.flipY = body.flipY;
        }

        private void OnDisable()
        {
            if (fingers != null) fingers.enabled = false;
        }
    }
}
