using TMPro;
using UnityEngine;
using UnityEngine.UI;
namespace Mmorpg.Runtime
{
    public sealed class SessionMenuView : MonoBehaviour
    {
        [SerializeField] private LocalSessionCommands commands;
        [SerializeField] private GameObject menu,confirmation,settings;
        [SerializeField] private TMP_Text confirmationText,error;
        [SerializeField] private Button resume,restart,newJourney,options,quit,confirm,cancel,back;
        [SerializeField] private Slider volume;
        [SerializeField] private GameObject weaponValidation;
        [SerializeField] private UnityEngine.UI.Button weapons;
        public void ConfigureWeaponValidation(GameObject page,UnityEngine.UI.Button button){weaponValidation=page;weapons=button;}
        public void Configure(LocalSessionCommands owner,GameObject main,GameObject confirmPanel,GameObject settingsPanel,TMP_Text description,TMP_Text errorText,Button[] buttons,Slider audio)
        {commands=owner;menu=main;confirmation=confirmPanel;settings=settingsPanel;confirmationText=description;error=errorText;resume=buttons[0];restart=buttons[1];newJourney=buttons[2];options=buttons[3];quit=buttons[4];confirm=buttons[5];cancel=buttons[6];back=buttons[7];volume=audio;}
        private void Awake()
        {
            resume.onClick.AddListener(commands.Continue);restart.onClick.AddListener(commands.Restart);newJourney.onClick.AddListener(commands.RequestNewJourney);
            options.onClick.AddListener(()=>{menu.SetActive(false);settings.SetActive(true);});quit.onClick.AddListener(Quit);
            confirm.onClick.AddListener(commands.ConfirmNewJourney);cancel.onClick.AddListener(commands.Continue);back.onClick.AddListener(ShowMenu);
            volume.SetValueWithoutNotify(AudioListener.volume);volume.onValueChanged.AddListener(value=>AudioListener.volume=value);
            if(weapons!=null)weapons.onClick.AddListener(()=>{Hide();weaponValidation.SetActive(true);});
#if !UNITY_EDITOR && !DEVELOPMENT_BUILD
            newJourney.gameObject.SetActive(false);
#endif
            Hide();
        }
        public void Hide(){menu.SetActive(false);confirmation.SetActive(false);settings.SetActive(false);if(weaponValidation!=null)weaponValidation.SetActive(false);error.text="";}
        public void ShowMenu(){Hide();menu.SetActive(true);}
        public void ShowConfirmation(string identity)
        {
            Hide();confirmation.SetActive(true);confirmationText.text="NOVA JORNADA LOCAL\n\nPerfil: "+identity.Substring(0,8)+"\n\nApaga inventário, habilidades, oportunidades, fatos e estados locais deste perfil de desenvolvimento.\n\nUm backup verificado será criado antes da limpeza. Saves anteriores e Supabase serão preservados.";
        }
        public void ShowError(string text){ShowMenu();error.text=text;}
        private static void Quit()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying=false;
#else
            Application.Quit();
#endif
        }
    }
}
