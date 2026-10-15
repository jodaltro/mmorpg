using System;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Mmorpg.Runtime
{
    public sealed class WorldJourneyView : MonoBehaviour
    {
        [Serializable] public sealed class Area { public string id;public GameObject root; }
        [SerializeField] private Area[] areas;
        [SerializeField] private Transform player;
        [SerializeField] private SpriteRenderer opponent;
        private string current;
        public string CurrentRegion=>current;
        public void Configure(Area[] map,Transform hero,SpriteRenderer enemy){areas=map;player=hero;opponent=enemy;}
        public void PresentJson(string authoritativeProjection)=>Present(JObject.Parse(authoritativeProjection));
        public void Present(JObject state)
        {
            string region=state.Value<string>("regionId");if(current!=region){current=region;foreach(var area in areas)area.root.SetActive(area.id==region);player.position=new Vector3(-5,-3,0);}
            var e=state["journey"]["encounter"] as JObject;opponent.gameObject.SetActive(e!=null);if(e!=null){opponent.transform.position=new Vector3(3+e.Value<int>("range"),0,0);opponent.color=e.Value<string>("phase")=="preparing"?new Color(1,.55f,.1f):e.Value<string>("phase")=="defeated"?Color.gray:new Color(.6f,.75f,.8f);}
        }
        private void Update()
        {
            if(player==null||current==null||Keyboard.current==null||UnityEngine.EventSystems.EventSystem.current?.currentSelectedGameObject?.GetComponent<TMPro.TMP_InputField>()!=null)return;
            var k=Keyboard.current;Vector2 move=new Vector2((k.dKey.isPressed?1:0)-(k.aKey.isPressed?1:0),(k.wKey.isPressed?1:0)-(k.sKey.isPressed?1:0));
            Vector3 p=player.position+(Vector3)ActorMotor.Cardinal(move)*3*Time.deltaTime;player.position=new Vector3(Mathf.Clamp(p.x,-8,8),Mathf.Clamp(p.y,-5,5),0);
        }
    }
}
