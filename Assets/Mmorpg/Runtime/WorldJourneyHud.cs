using System.Linq;
using System.Text;
using Newtonsoft.Json.Linq;
using TMPro;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public sealed class WorldJourneyHud : MonoBehaviour
    {
        [SerializeField] private WorldJourneySession journey;
        [SerializeField] private TMP_InputField email,password,characterName,characterId;
        [SerializeField] private TMP_Text title,status,details,pageLabel;
        [SerializeField] private UnityEngine.UI.Button login,logout,previous,next;
        [SerializeField] private UnityEngine.UI.Button[] actionButtons;
        private int page;
        public void Configure(WorldJourneySession model,TMP_InputField mail,TMP_InputField secret,TMP_InputField name,TMP_InputField id,TMP_Text heading,TMP_Text message,TMP_Text journal,TMP_Text pages,UnityEngine.UI.Button connect,UnityEngine.UI.Button disconnect,UnityEngine.UI.Button prev,UnityEngine.UI.Button forward,UnityEngine.UI.Button[] actions)
        {journey=model;email=mail;password=secret;characterName=name;characterId=id;title=heading;status=message;details=journal;pageLabel=pages;login=connect;logout=disconnect;previous=prev;next=forward;actionButtons=actions;}
        private void Awake()
        {
            login.onClick.AddListener(()=>{string secret=password.text;password.text="";StartCoroutine(journey.Connect(email.text,secret,characterName.text,characterId.text));});
            logout.onClick.AddListener(journey.SignOut);previous.onClick.AddListener(()=>{page=Mathf.Max(0,page-1);Refresh();});next.onClick.AddListener(()=>{page++;Refresh();});Refresh();
        }
        public void RememberCharacter(string id)=>characterId.text=id;
        private string Name(string id)
        {
            if(journey.Content==null)return id;
            foreach(string category in new[]{"regions","abilities","items","creatures","npcs","nodes","opportunities"})
            {var entry=journey.Content[category].FirstOrDefault(x=>x.Value<string>("id")==id);if(entry!=null)return entry.Value<string>("name");}
            return id=="training-dummy"?"Alvo de treino":id;
        }
        private string Label(JToken a)
        {
            string kind=a.Value<string>("kind"),target=a.Value<string>("target");
            string verb=kind=="travel"?"Viajar":kind=="talk"?"Conversar":kind=="gather"?"Investigar / extrair":kind=="challenge"?"Enfrentar":kind=="loot"?"Coletar":kind=="complete"?"Realizar":kind=="ignore"?"Ignorar":kind=="equip"?"Equipar":kind=="use"?"Usar":kind=="ability"?"Técnica":kind=="attack"?"Atacar":kind=="dodge"?"Esquivar":kind=="guard"?"Defender":kind=="approach"?"Aproximar":kind=="retreat"?"Recuar":kind=="rest"?"Descansar": "Aguardar";
            return verb+(string.IsNullOrEmpty(target)?"":": "+Name(target));
        }
        private string Phase(string phase)=>phase=="preparing"?"Preparando golpe":phase=="exposed"?"Vulnerável":phase=="hidden"?"Oculto":phase=="defeated"?"Derrotado":phase=="escaped"?"Encontro encerrado":"Em guarda";
        private string ItemUse(JToken item)
        {
            string use=item.Value<string>("use"),slot=item.Value<string>("slot"),id=item.Value<string>("id");
            if(use=="heal")return "Cura "+item.Value<int>("power");if(use=="antidote")return "Remove veneno";if(use=="burn")return "Aplica queimadura";if(use=="purify")return "Cura e purifica";if(use=="evidence")return "Evidência histórica";
            if(use=="equipment")return slot=="weapon"?"+"+item.Value<int>("power")+" de dano":slot=="armor"||slot=="cloak"?"Proteção "+item.Value<int>("power"):slot=="charm"?"Proteção contra veneno":id=="mining-pick"?"Extrai veios minerais":"Permite Combustão Alquímica";
            return "Material de investigação, forja ou alquimia";
        }
        public void Refresh()
        {
            if(journey==null)return;status.text=journey.Busy?"Confirmando ação…":journey.Message;login.interactable=!journey.Busy;logout.interactable=!journey.Busy;
            var state=journey.State;title.text=state==null?"JORNADAS DE VALDORIA":Name(state.Value<string>("regionId"))+"   •   Vida "+state.Value<int>("hp");
            var actions=state?["actions"]?.Where(a=>a.Value<string>("kind")!="complete"&&a.Value<string>("kind")!="ignore"||state["journey"]["opportunities"].Value<string>(a.Value<string>("target"))=="available").ToArray()??new JToken[0];
            int count=Mathf.Max(1,Mathf.CeilToInt((float)actions.Length/actionButtons.Length));page=Mathf.Clamp(page,0,count-1);pageLabel.text=$"Ações {page+1}/{count}";
            previous.interactable=!journey.Busy&&page>0;next.interactable=!journey.Busy&&page<count-1;
            for(int i=0;i<actionButtons.Length;i++)
            {var button=actionButtons[i];button.onClick.RemoveAllListeners();int index=page*actionButtons.Length+i;button.gameObject.SetActive(index<actions.Length);if(index>=actions.Length)continue;var action=actions[index];button.GetComponentInChildren<TMP_Text>().text=Label(action);button.interactable=!journey.Busy;button.onClick.AddListener(()=>journey.Submit(action.Value<string>("kind"),action.Value<string>("target")));}
            var text=new StringBuilder();if(state==null){text.Append("Cada jornada guarda descobertas, técnicas, materiais e relações.\n\nUse WASD para caminhar. Escolha interações e turnos pelos botões.\n\nDeixe o ID vazio para criar; guarde o ID exibido para continuar o personagem.\n\nA sessão precisa de uma conta de desenvolvimento e do backend local.");}
            else
            {
                var s=state["journey"];var encounter=s["encounter"];
                if(encounter is JObject){text.AppendLine(Name(encounter.Value<string>("creature"))+": "+encounter.Value<int>("hp")+" de vida");text.AppendLine(Phase(encounter.Value<string>("phase"))+"   Distância: "+encounter.Value<int>("range"));text.AppendLine("Preparo: defenda, esquive ou interrompa. Voo: aproxime ou use técnicas.\n");}
                text.AppendLine("TÉCNICAS");foreach(var a in state["abilities"]){string id=a.Value<string>();text.Append(Name(id));int remaining=Mathf.Max(0,s["cooldowns"].Value<int?>(id).GetValueOrDefault()-s.Value<int>("step"));text.AppendLine(remaining>0?$" ({remaining} turnos)":"");}
                text.AppendLine("\nINVENTÁRIO");foreach(var item in ((JObject)state["inventory"]).Properties()){text.Append(Name(item.Name)+" × "+item.Value);var def=journey.Content["items"].First(x=>x.Value<string>("id")==item.Name);text.AppendLine(" • "+ItemUse(def));}
                text.AppendLine("\nOPORTUNIDADES");foreach(var o in ((JObject)s["opportunities"]).Properties().Where(x=>x.Value.Value<string>()=="available"||x.Value.Value<string>()=="pending")){text.AppendLine(Name(o.Name));var def=journey.Content["opportunities"].First(x=>x.Value<string>("id")==o.Name);foreach(var cost in ((JObject)def["costs"]).Properties())text.AppendLine("  "+Name(cost.Name)+" × "+cost.Value);}
                text.AppendLine("\nRELAÇÕES / FONTES");foreach(var rel in ((JObject)state["relationships"]).Properties())text.AppendLine(Name(rel.Name)+": confiança "+rel.Value+" • "+(s["knowledge"][rel.Name]?.Count()??0)+" informações obtidas em conversa e descobertas.");
            }
            details.text=text.ToString();
        }
    }
}
