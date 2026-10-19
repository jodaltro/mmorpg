using System.Collections.Generic;
using Gamekit3D;
using UnityEngine;

// Integration boundary: existing kit health/AI/feedback, independent damage timing.
public sealed class GamekitCombatAuthority : MonoBehaviour
{
    public bool player;
    public float range = 2.5f, cooldown = 0.65f, windup = 0.2f;
    public int acceptedAttacks, confirmedHits;
    public Damageable health;
    public MeleeWeapon weapon;
    float nextAttack, resolveAt = -1;
    ChomperBehavior enemy;
    void Awake()
    {
        health = GetComponent<Damageable>();
        enemy = GetComponent<ChomperBehavior>();
        weapon = GetComponentInChildren<MeleeWeapon>(true);
    }
    void FixedUpdate()
    {
        if (health.currentHitPoints <= 0) { resolveAt = -1; return; }
        if (resolveAt >= 0 && Time.time >= resolveAt) { resolveAt = -1; Resolve(); }
        bool intent = player
            ? PlayerInput.Instance != null && PlayerInput.Instance.Attack && GetComponent<PlayerController>().canAttack
            : enemy != null && enemy.target != null && Vector3.Distance(transform.position, enemy.target.transform.position) <= range;
        if (!intent || Time.time < nextAttack) return;
        nextAttack = Time.time + cooldown;
        resolveAt = Time.time + windup;
        acceptedAttacks++;
    }
    void Resolve()
    {
        var seen = new HashSet<Damageable>();
        Vector3 origin = transform.position + Vector3.up;
        foreach (var collider in Physics.OverlapSphere(origin, range, ~0, QueryTriggerInteraction.Ignore))
        {
            var target = collider.GetComponentInParent<Damageable>();
            if (target == null || target == health || !seen.Add(target) || target.currentHitPoints <= 0) continue;
            bool isPlayer = target.GetComponent<PlayerController>() != null;
            if (isPlayer == player) continue;
            Vector3 delta = target.transform.position - transform.position;
            delta.y = 0;
            if (delta.magnitude > range || Vector3.Dot(transform.forward, delta.normalized) < 0.15f) continue;
            Vector3 destination = target.transform.position + Vector3.up;
            bool blocked = false;
            foreach (var hit in Physics.RaycastAll(origin, (destination-origin).normalized, Vector3.Distance(origin,destination), ~0, QueryTriggerInteraction.Ignore))
            {
                if (!hit.collider.transform.IsChildOf(transform) && !hit.collider.transform.IsChildOf(target.transform)) { blocked = true; break; }
            }
            if (blocked) continue;
            int before = target.currentHitPoints;
            target.ApplyDamage(new Damageable.DamageMessage { amount = weapon.damage, damager = weapon, direction = delta.normalized, damageSource = transform.position, throwing = false, stopCamera = false });
            if (target.currentHitPoints >= before) continue;
            confirmedHits++;
            if (weapon.hitAudio != null) weapon.hitAudio.PlayRandomClip();
            if (weapon.hitParticlePrefab != null)
            {
                var fx = Instantiate(weapon.hitParticlePrefab, destination, Quaternion.identity);
                fx.Play(); Destroy(fx.gameObject, 3f);
            }
        }
    }
}
