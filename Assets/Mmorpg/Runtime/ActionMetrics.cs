using System;
using System.Collections.Generic;
using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class ActionMetrics : MonoBehaviour
    {
        public static ActionMetrics Active { get; private set; }
        private readonly List<float> frames=new List<float>();
        public int NetworkOperations { get; private set; }
        public int Exceptions { get; private set; }
        public int Actions { get; private set; }
        public double MaxCombatMs { get; private set; }
        public int MaxFeedbackFrames { get; private set; }
        private void OnEnable() {Active=this;Application.logMessageReceived+=Log;}
        private void OnDisable() {if(Active==this)Active=null;Application.logMessageReceived-=Log;}
        private void Log(string message,string stack,LogType type) {if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)Exceptions++;}
        private void Update() {if(Time.timeScale>0 && frames.Count<36000)frames.Add(Time.unscaledDeltaTime*1000);}
        public void RecordCombat(double milliseconds,int feedbackFrames) {Actions++;MaxCombatMs=Math.Max(MaxCombatMs,milliseconds);MaxFeedbackFrames=Math.Max(MaxFeedbackFrames,feedbackFrames);}
        public void RecordVisual(int frames) => MaxFeedbackFrames=Math.Max(MaxFeedbackFrames,frames);
        public static void NetworkStarted() {if(Active!=null)Active.NetworkOperations++;}
        public string Report()
        {
            var sorted=frames.ToArray();Array.Sort(sorted);double total=0;foreach(var f in sorted)total+=f;
            return $"frames={frames.Count}; meanMs={(frames.Count==0?0:total/frames.Count):F3}; p95Ms={(sorted.Length==0?0:sorted[(int)((sorted.Length-1)*.95)]):F3}; combatMaxMs={MaxCombatMs:F3}; actions={Actions}; feedbackFrames={MaxFeedbackFrames}; network={NetworkOperations}; errors={Exceptions}; unityFrame={Time.frameCount}";
        }
    }
}
