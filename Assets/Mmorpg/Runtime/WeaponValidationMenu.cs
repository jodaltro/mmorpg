using TMPro;
using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class WeaponValidationMenu : MonoBehaviour
    {
        [SerializeField] private WeaponValidationPreview preview;
        [SerializeField] private LocalSessionCommands commands;
        [SerializeField] private SessionMenuView sessionMenu;
        [SerializeField] private TMP_Text description;
        [SerializeField] private UnityEngine.UI.Button sword,bowSouth,bowEast,test,back;
        public void Configure(WeaponValidationPreview player,LocalSessionCommands owner,SessionMenuView menu,TMP_Text label,UnityEngine.UI.Button[] buttons)
        {preview=player;commands=owner;sessionMenu=menu;description=label;sword=buttons[0];bowSouth=buttons[1];bowEast=buttons[2];test=buttons[3];back=buttons[4];}
        private void Awake()
        {
            sword.onClick.AddListener(()=>{preview.SelectSword();Refresh();});bowSouth.onClick.AddListener(()=>Select(0));bowEast.onClick.AddListener(()=>Select(1));test.onClick.AddListener(commands.Continue);back.onClick.AddListener(sessionMenu.ShowMenu);
        }
        private void OnEnable()=>Refresh();
        private void Select(int view){string error=preview.SelectBow(view);Refresh();if(error!=null)description.text=error;}
        private void Refresh()
        {
            if(preview==null)return;
            description.text=preview.BowSelected?"Selecionado: Arco · "+(preview.ViewIndex==0?"frontal":"lateral")+"\n\nPuxada aprovada. Clique / J reproduz a sequência.\nV alterna a vista; Esc volta ao menu.\n\nTeste estacionário de pose, sem projéteis.":"Selecionado: Espada\n\nWASD: movimentação · Clique / J: básico\nBotão direito: pesado\n\nA troca vale só nesta sessão de validação.";
        }
    }
}
