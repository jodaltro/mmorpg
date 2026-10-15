using System.Linq;
using System.Text;
using Mmorpg.Domain;
using TMPro;
using UnityEngine;
using EventType = Mmorpg.Domain.EventType;

namespace Mmorpg.Runtime
{
    public sealed class JourneyHud : MonoBehaviour
    {
        [SerializeField] private JourneySession journey;
        [SerializeField] private TMP_Text dialogue, hint, journalText;
        [SerializeField] private GameObject journalPanel;
        [SerializeField] private ExplorationWorld exploration;
        public void ConfigureExploration(ExplorationWorld world)=>exploration=world;
        public bool JournalOpen => journalPanel.activeSelf;
        [SerializeField] private bool temporaryMessages;
        private string lastMessage;
        private double messageUntil;
        private readonly System.Collections.Generic.Queue<string> messages=new System.Collections.Generic.Queue<string>();
        public void ConfigureTemporaryMessages()=>temporaryMessages=true;
        public void Configure(JourneySession value,TMP_Text message,TMP_Text prompt,TMP_Text journal,GameObject panel)
        { journey=value; dialogue=message; hint=prompt; journalText=journal; journalPanel=panel; }
        public void ToggleJournal() => journalPanel.SetActive(!journalPanel.activeSelf);
        private void Update()
        {
            if(journey.Message!=lastMessage){lastMessage=journey.Message;messageUntil=Time.unscaledTimeAsDouble+5;if(temporaryMessages){if(messages.Count==6)messages.Dequeue();messages.Enqueue(lastMessage);}}
            dialogue.text=temporaryMessages?(Time.unscaledTimeAsDouble<messageUntil&&lastMessage.Length<=140?lastMessage:""):journey.Message;
            var nearest=journey.Nearest();
            hint.text=(nearest==null?"":$"E: {nearest.name}    ")+(journey.Engine.HasAbility(ForestContent.Technique)?$"Q: Leitura de Fraquezas ({Mathf.CeilToInt((float)System.Math.Max(0,journey.Weakness.NextUse-Time.timeAsDouble))}s)":"Técnica ainda desconhecida");
            if(!JournalOpen) return;
            var state=journey.Engine.Snapshot(); var text=new StringBuilder("DIÁRIO DE JORNADA  [Tab para fechar]\n\n");
            if(!state.facts.Any()) text.AppendLine("Ainda não há descobertas. Explore, observe e converse.");
            foreach(var fact in state.facts)
            {
                switch(fact.eventType)
                {
                    case EventType.CreatureDefeated: text.AppendLine("• Enfrentei e derrotei o lobo corrompido."); break;
                    case EventType.TraceExamined: text.AppendLine("• Examinei pegadas com resina escura."); break;
                    case EventType.EvidenceCollected: text.AppendLine("• Recolhi uma amostra da corrupção."); break;
                    case EventType.EvidenceDelivered: text.AppendLine("• Entreguei a amostra a Mira."); break;
                    case EventType.OpportunityDiscovered: text.AppendLine(fact.discovery.routeId==ForestContent.RouteA?"• Descoberta: investigar a amostra com Mira.":"• Descoberta: compreender rastros com Orin."); break;
                    case EventType.AbilityUnlocked: text.AppendLine("• Técnica: Leitura de Fraquezas — Q marca; próximo acerto +10."); break;
                }
            }
            text.AppendLine("\nConhecimento e relações:");
            foreach(var decision in state.decisions) text.AppendLine("• Reação registrada: "+MiraReactions.Text(decision.selectedConsequence));
            foreach(var relation in state.relations) text.AppendLine($"{(relation.npcId==ForestContent.Mira?"Mira":relation.npcId==ForestContent.Orin?"Orin":"Contato")}: confiança {relation.trust}");
            foreach(var opportunity in state.opportunities.Where(o=>o.status!=OpportunityStatus.Unknown)) text.AppendLine($"{(opportunity.id==ForestContent.RouteA?"Amostra de Mira":"Observação de Orin")}: {StatusText(opportunity.status)}");
            text.Append(journey.WorldEvents?.World?.Journal());
            text.Append(exploration?.JournalText());
            if(temporaryMessages)text.Append("\nMensagens recentes:\n"+string.Join("\n",messages));
            journalText.text=text.ToString();
        }
        private static string StatusText(OpportunityStatus status) => status==OpportunityStatus.Available?"disponível":status==OpportunityStatus.Started?"em andamento":status==OpportunityStatus.Completed?"concluída":"encerrada";
    }
}
