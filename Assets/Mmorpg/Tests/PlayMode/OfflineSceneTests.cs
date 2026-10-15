using System.Collections;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace Mmorpg.Tests
{
    public sealed class OfflineSceneTests
    {
        private GameSession session;
        private OfflineAuthority authority;
        [UnitySetUp] public IEnumerator Load()
        {
            Application.runInBackground = true;
            JourneySession.PersistenceFactory=()=>new MemoryJourneyPersistence();
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity");
            session = Object.FindAnyObjectByType<GameSession>();
            authority = Object.FindAnyObjectByType<OfflineAuthority>();
            session.Player.GetComponent<PlayerController>().enabled = false;
            session.Wolf.GetComponent<WolfBrain>().enabled = false;
            yield return null;
        }
        [TearDown] public void CleanPersistence() => JourneySession.PersistenceFactory=null;
        private void Place(Vector2 player,Vector2 wolf)
        {
            session.Player.transform.position = player;
            session.Wolf.transform.position = wolf;
            session.Player.GetComponent<Rigidbody2D>().position = player;
            session.Wolf.GetComponent<Rigidbody2D>().position = wolf;
            Physics2D.SyncTransforms();
        }
        [UnityTest] public IEnumerator PlayerCanMoveAndCollidesWithRock()
        {
            Place(new Vector2(-2,0),new Vector2(8,0));
            var motor=session.Player.GetComponent<ActorMotor>(); motor.SetIntent(Vector2.right,CombatRules.PlayerSpeed);
            yield return new WaitForSeconds(0.3f);
            Assert.That(session.Player.transform.position.x,Is.GreaterThan(-1.3f));
            Place(new Vector2(-2.5f,2),new Vector2(8,0)); motor.SetIntent(Vector2.left,CombatRules.PlayerSpeed);
            yield return new WaitForSeconds(0.6f);
            Assert.That(session.Player.transform.position.x,Is.GreaterThan(-3.05f));
        }
        [UnityTest] public IEnumerator ThreeAttacksKillWolfAndRestartRestoresActors()
        {
            Place(Vector2.zero,new Vector2(0.8f,0));
            for(int i=0;i<3;i++) { Assert.That(authority.RequestAttack(session.Player,Vector2.right),Is.True); yield return new WaitForSeconds(0.45f); }
            Assert.That(session.Wolf.State.IsAlive,Is.False);
            Assert.That(session.Wolf.GetComponent<Rigidbody2D>().simulated,Is.False);
            Assert.That(session.Finished,Is.True);
            session.Restart(); yield return null; yield return null;
            var restored=Object.FindAnyObjectByType<GameSession>();
            Assert.That(restored.Player.State.Health,Is.EqualTo(100)); Assert.That(restored.Wolf.State.Health,Is.EqualTo(60));
        }
        [UnityTest] public IEnumerator DodgeBlocksWolfDamageThenPlayerCanDie()
        {
            Place(Vector2.zero,new Vector2(0.8f,0));
            Assert.That(authority.RequestDodge(session.Player),Is.True);
            Assert.That(authority.RequestAttack(session.Wolf,Vector2.left),Is.True);
            Assert.That(session.Player.State.Health,Is.EqualTo(100));
            yield return new WaitForSeconds(1.15f);
            for(int i=0;i<7;i++) { authority.RequestAttack(session.Wolf,Vector2.left); yield return new WaitForSeconds(1.15f); }
            Assert.That(session.Player.State.IsAlive,Is.False);
            Assert.That(authority.RequestDodge(session.Player),Is.False);
        }
        [UnityTest] public IEnumerator WallAndFacingBlockMelee()
        {
            Place(new Vector2(0,-2.2f),new Vector2(0,-3.1f));
            authority.RequestAttack(session.Player,Vector2.down);
            Assert.That(session.Wolf.State.Health,Is.EqualTo(60));
            yield return new WaitForSeconds(0.45f);
            Place(Vector2.zero,new Vector2(0.8f,0)); authority.RequestAttack(session.Player,Vector2.left);
            Assert.That(session.Wolf.State.Health,Is.EqualTo(60));
        }
        [UnityTest] public IEnumerator WolfPatrolsChasesAndAttacksWithWindup()
        {
            var wolf=session.Wolf.GetComponent<WolfBrain>(); wolf.enabled=true;
            Place(new Vector2(-9,0),new Vector2(3,0));
            yield return new WaitForSeconds(0.3f);
            Assert.That(wolf.Mode,Is.EqualTo(WolfMode.Patrol));
            Assert.That(session.Wolf.transform.position.x,Is.GreaterThan(3));
            Place(Vector2.zero,new Vector2(2,0)); yield return new WaitForSeconds(0.1f);
            Assert.That(wolf.Mode,Is.EqualTo(WolfMode.Chase));
            Place(Vector2.zero,new Vector2(0.8f,0)); yield return new WaitForSeconds(0.1f);
            Assert.That(wolf.Mode,Is.EqualTo(WolfMode.Windup));
            Assert.That(session.Player.State.Health,Is.EqualTo(100));
            yield return new WaitForSeconds(0.4f);
            Assert.That(session.Player.State.Health,Is.EqualTo(85));
        }
        [UnityTest] public IEnumerator KeyboardMovesAttacksAndDodgesThroughPlayerController()
        {
            var keyboard=InputSystem.AddDevice<Keyboard>();
            try
            {
                Place(Vector2.zero,new Vector2(0.8f,0));
                session.Player.GetComponent<PlayerController>().enabled=true;
                InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.D));
                yield return new WaitForSeconds(0.05f);
                Assert.That(session.Player.GetComponent<ActorMotor>().Facing,Is.EqualTo(Vector2.right));
                InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.J));
                yield return null; yield return null;
                Assert.That(session.Wolf.State.Health,Is.EqualTo(40));
                Place(Vector2.zero,new Vector2(8,0));
                InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.D,Key.Space));
                yield return null; yield return new WaitForFixedUpdate();
                Assert.That(session.Player.State.IsDodging(Time.timeAsDouble),Is.True);
                Assert.That(session.Player.GetComponent<Rigidbody2D>().linearVelocity.x,Is.GreaterThan(CombatRules.PlayerSpeed));
                InputSystem.QueueStateEvent(keyboard,new KeyboardState());
            }
            finally { InputSystem.RemoveDevice(keyboard); }
        }
    }
}
