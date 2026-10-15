using System;
using System.IO;
using System.Linq;
using System.Text;
using Mmorpg.Domain;
using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    public sealed class ExplorationWorld : MonoBehaviour
    {
        public static string ValidationDirectory;
        [SerializeField] private JourneySession journey;
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private PlayerController controller;
        [SerializeField] private TMP_Text regionText,contextText,dialogueText;
        [SerializeField] private GameObject dialoguePanel;
        [SerializeField] private ExplorationNode[] nodes;
        [SerializeField] private ExplorationRegion[] regions;
        public ExplorationSave State {get;private set;}=new ExplorationSave();
        public bool DialogueOpen=>dialoguePanel.activeSelf;
        public string Notice {get;private set;}="";
        private string path;
        private bool blocked;
        [SerializeField] private bool externalSessionCommands;
        private bool persistenceSuspended;
        public void ConfigureSessionCommands()=>externalSessionCommands=true;
        public void SuspendPersistence()=>persistenceSuspended=true;
        public void ResumePersistence()=>persistenceSuspended=false;
        private double noticeUntil;
        public void Configure(JourneySession story,OfflineAuthority server,PlayerController input,TMP_Text region,TMP_Text context,TMP_Text words,GameObject panel,ExplorationNode[] targets,ExplorationRegion[] areas)
        {journey=story;authority=server;controller=input;regionText=region;contextText=context;dialogueText=words;dialoguePanel=panel;nodes=targets;regions=areas;}
        private void Start()
        {
            path=Path.Combine(ValidationDirectory??Application.persistentDataPath,"marco06b1-exploration.json");
            try {if(File.Exists(path)){var saved=JsonUtility.FromJson<ExplorationSave>(File.ReadAllText(path));if(saved==null||saved.version!=1||saved.inventory==null||saved.collected==null||saved.discoveries==null||!regions.Any(r=>r.Title==saved.region))throw new InvalidDataException("Save incompatível");State=saved;}}
            catch(Exception e){blocked=true;Notify("Save não carregado: "+e.Message);Debug.LogWarning(Notice);}
            // Restore to authored, unobstructed regional entry. Arbitrary coordinates are never trusted.
            var area=regions.FirstOrDefault(r=>r.Title==State.region);
            if(area!=null)journey.Player.GetComponent<Rigidbody2D>().position=area.SafeEntry;
            foreach(var node in nodes)node.Refresh(this);
        }
        public bool IsSafePosition(Vector2 position)=>regions.First(r=>r.Title=="Valdoria").GetComponent<BoxCollider2D>().bounds.Contains(position);
        public void Enter(ExplorationRegion region)
        {if(State.region==region.Title)return;State.region=region.Title;if(!State.discoveries.Contains("region:"+region.Title))State.discoveries.Add("region:"+region.Title);State.x=region.SafeEntry.x;State.y=region.SafeEntry.y;Notify(region.Title);Save();}
        public ExplorationNode Nearest()=>nodes.Where(n=>n!=null&&n.gameObject.activeInHierarchy&&n.Available(this)&&Vector2.Distance(journey.Player.transform.position,n.transform.position)<1.35f&&authority.HasLineOfSight(journey.Player.transform.position,n.transform.position,n.GetComponent<Collider2D>())).OrderBy(n=>Vector2.Distance(journey.Player.transform.position,n.transform.position)).FirstOrDefault();
        public bool HandleInteraction()
        {
            if(DialogueOpen){CloseDialogue();return true;}
            if(!journey.Player.State.IsAlive)return true;
            var node=Nearest();var old=journey.Nearest();
            if(node!=null&&(old==null||Vector2.Distance(journey.Player.transform.position,node.transform.position)<Vector2.Distance(journey.Player.transform.position,old.transform.position))) {node.Interact(this);return true;}
            if(old!=null){journey.RequestInteraction(old);if(old.Kind==InteractionKind.Mira||old.Kind==InteractionKind.Orin)ShowDialogue(old.name,journey.Message);return true;}
            return false;
        }
        public void Notify(string text){Notice=text;noticeUntil=Time.timeAsDouble+4;}
        public void ShowDialogue(string npc,string words){dialogueText.text=npc+"\n\n"+words+"\n\nE ou Esc: fechar";dialoguePanel.SetActive(true);controller.enabled=false;journey.Player.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);}
        public void CloseDialogue(){dialoguePanel.SetActive(false);controller.enabled=true;}
        private void Update()
        {
            regionText.text=State.region;
            var node=Nearest();contextText.text=(node==null?"":"E · "+node.Prompt)+(Time.timeAsDouble<noticeUntil?"\n"+Notice:"");
            
            if(!externalSessionCommands&&Keyboard.current?.rKey.wasPressedThisFrame==true&&!journey.Player.State.IsAlive)UnityEngine.SceneManagement.SceneManager.LoadScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene().path);
        }
        public string InventoryText()
        {
            var text=new StringBuilder("INVENTÁRIO  [I]\n\n");
            foreach(var item in State.inventory)text.AppendLine(item.name+" × "+item.quantity);
            if(journey.Engine.HasSample)text.AppendLine("Amostra corrompida × 1");
            if(State.inventory.Count==0&&!journey.Engine.HasSample)text.AppendLine("A mochila está vazia.");
            return text.ToString();
        }
        public string JournalText()=>"\nExploração:\n"+string.Join("\n",State.discoveries.Select(id=>id.StartsWith("region:")?"• Visitei "+id.Substring(7):"• Conversei / examinei: "+(nodes.FirstOrDefault(n=>n.SourceId==id)?.name??"Descoberta local")));
        public void Save()
        {
            if(persistenceSuspended)return;
            try {SaveOrThrow();}
            catch(Exception e){Notify("Falha ao salvar: "+e.Message);Debug.LogWarning(Notice);}
        }
        public void SaveOrThrow()
        {
            if(blocked)throw new InvalidDataException("Save de exploração bloqueado");
            if(persistenceSuspended||path==null)return;
            Directory.CreateDirectory(Path.GetDirectoryName(path));string temp=path+".tmp";File.WriteAllText(temp,JsonUtility.ToJson(State,true));if(File.Exists(path))File.Replace(temp,path,path+".bak");else File.Move(temp,path);
        }
        private void OnApplicationQuit()=>Save();
        private void OnDisable(){Save();if(controller!=null)controller.enabled=true;}
    }
}

