using System;
using System.Collections.Generic;
namespace Mmorpg.Domain
{
    [Serializable] public sealed class ExplorationItem { public string id, name; public int quantity; }
    [Serializable] public sealed class ExplorationSave
    {
        public int version=1;
        public string region="Valdoria";
        public float x=-8,y=-1;
        public List<ExplorationItem> inventory=new List<ExplorationItem>();
        public List<string> collected=new List<string>(), discoveries=new List<string>();
        public bool Collect(string source,string item,string label,int count)
        {
            if(string.IsNullOrEmpty(source)||string.IsNullOrEmpty(item)||count<=0||collected.Contains(source))return false;
            var entry=inventory.Find(i=>i.id==item);
            if(entry==null){entry=new ExplorationItem{id=item,name=label};inventory.Add(entry);}
            entry.quantity+=count;collected.Add(source);return true;
        }
    }
}
