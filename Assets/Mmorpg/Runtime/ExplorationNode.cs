using UnityEngine;
namespace Mmorpg.Runtime
{
    public enum ExplorationNodeKind { Resource, Npc, Inscription }
    public sealed class ExplorationNode : MonoBehaviour
    {
        [SerializeField] private string sourceId,itemId,itemLabel,dialogue;
        [SerializeField] private int quantity=1;
        [SerializeField] private ExplorationNodeKind kind;
        [SerializeField] private SpriteRenderer visual;
        public string SourceId=>sourceId;
        public string Prompt=>kind==ExplorationNodeKind.Resource?"Coletar "+itemLabel:name;
        public void Configure(string source,string item,string label,int count,ExplorationNodeKind type,string words,SpriteRenderer sprite)
        {sourceId=source;itemId=item;itemLabel=label;quantity=count;kind=type;dialogue=words;visual=sprite;}
        public bool Available(ExplorationWorld world)=>kind!=ExplorationNodeKind.Resource||!world.State.collected.Contains(sourceId);
        public void Refresh(ExplorationWorld world) {if(visual!=null&&kind==ExplorationNodeKind.Resource)visual.color=Available(world)?Color.white:new Color(.25f,.25f,.25f,.3f);}
        public void Interact(ExplorationWorld world)
        {
            if(kind==ExplorationNodeKind.Resource)
            { if(world.State.Collect(sourceId,itemId,itemLabel,quantity)){world.Notify("+"+quantity+" "+itemLabel);world.Save();Refresh(world);} }
            else {if(!world.State.discoveries.Contains(sourceId))world.State.discoveries.Add(sourceId);world.ShowDialogue(name,dialogue);world.Save();}
        }
    }
}
