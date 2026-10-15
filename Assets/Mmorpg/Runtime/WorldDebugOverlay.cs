using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
    public sealed class WorldDebugOverlay : MonoBehaviour
    {
        [SerializeField] private GameObject panel;
        [SerializeField] private TMP_Text text;
        private bool expanded;private float next;
        public bool Visible=>panel.activeSelf;
        public void Configure(GameObject root,TMP_Text label){panel=root;text=label;}
        private void Awake(){panel.SetActive(false);}
        private void Update()
        {
#if UNITY_EDITOR || DEVELOPMENT_BUILD
            var k=Keyboard.current;
            if(k?.f8Key.wasPressedThisFrame==true){if(k.leftCtrlKey.isPressed||k.rightCtrlKey.isPressed)expanded=!expanded;else panel.SetActive(!panel.activeSelf);next=0;}
            if(!panel.activeSelf||Time.unscaledTime<next)return;next=Time.unscaledTime+.25f;
            var s=RuntimeDiagnostics.Read();
            text.text=$"WORLD DEBUG    {s.Fps:0} FPS\nMODE  {(OnlineSessionRegistry.AnyAuthenticated?"ONLINE":"OFFLINE")}\nGO  {s.Go}  {(s.GoMs<0?"—":s.GoMs+"ms")}\nSUPABASE  {s.Database}\nJEV  {s.Jev}\n{s.Provider}\nLAST  {s.LastDecision}\nEVENTS {s.Events}  |  EVAL {s.Evaluations}\n{s.LastEvent}\n{s.Consequence}\nOPP {s.Opportunity}  v{s.Revision}\nSAVE {s.Persistence}\nF8 ocultar · Ctrl+F8 histórico";
            if(expanded)text.text+="\n\n"+string.Join("\n",s.History.Skip(System.Math.Max(0,s.History.Length-4)).Select(HistoryRow));
            ((RectTransform)panel.transform).SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,expanded?410:245);
#else
            panel.SetActive(false);enabled=false;
#endif
        }
        private static string HistoryRow(string record)
        {
            var parts=record.Split(new[]{" | "},System.StringSplitOptions.None);if(parts.Length!=3)return record;
            int split=parts[0].IndexOf(' ');if(split<0)return record;
            string id=parts[0].Substring(split+1);if(id.Length>8)id=id.Substring(0,8);
            string stage=parts[1]=="EligibilityCandidates"?"Candidates":parts[1]=="Presentation"?"View":parts[1]=="Persistence"?"Save":parts[1]=="Validation"?"Validate":parts[1]=="Consequence"?"Apply":parts[1];
            if(stage.Length>12)stage=stage.Substring(0,12);
            string detail=parts[2].Length>26?parts[2].Substring(0,24)+"..":parts[2];
            return parts[0].Substring(0,split)+" "+id+" "+stage+"\n"+detail;
        }
    }
}
