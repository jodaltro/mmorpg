using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 [DefaultExecutionOrder(500)]
 public sealed class Ground13RLab:MonoBehaviour
 {
  [SerializeField] Ground13Lab baseline;
  [SerializeField] Renderer[] historical,oldSurfaces,newSurfaces;
  [SerializeField] GameObject oldRoot,newRoot;
  [SerializeField] Material[] newMaterials;
  [SerializeField] Material clay;
  [SerializeField] int stage=2;
  public int Stage=>stage;
  public void Configure(Ground13Lab previous,Renderer[] ground12,GameObject ground13,GameObject candidate,Material white){baseline=previous;historical=ground12;oldRoot=ground13;newRoot=candidate;oldSurfaces=ground13.GetComponentsInChildren<Renderer>(true);newSurfaces=candidate.GetComponentsInChildren<Renderer>(true);newMaterials=Array.ConvertAll(newSurfaces,r=>r.sharedMaterial);clay=white;Select(2);}
  // A/B/C/D plus old blockout and unpacked comparison states. Only presentation changes.
  public void Select(int value){if(value<0||value>6)throw new ArgumentOutOfRangeException(nameof(value));stage=value;baseline.enabled=false;baseline.Select(value>=5?4:3);bool candidate=value==2||value==3||value==6;oldRoot.SetActive(!candidate&&value!=0);newRoot.SetActive(candidate);foreach(var r in historical)r.enabled=value==0;for(int i=0;i<newSurfaces.Length;i++)newSurfaces[i].sharedMaterial=value==3?clay:newMaterials[i];if(value==4)foreach(var r in oldSurfaces)r.sharedMaterial=clay;}
  public void EvidencePhase(int phase)=>baseline.EvidencePhase(phase);
  public void RefreshPresentation(){newSurfaces=newRoot.GetComponentsInChildren<Renderer>(true);newMaterials=Array.ConvertAll(newSurfaces,r=>r.sharedMaterial);Select(2);}
  void Awake()=>Select(stage);
  void Update(){var k=Keyboard.current;if(k==null)return;if(k.digit1Key.wasPressedThisFrame)Select(0);else if(k.digit2Key.wasPressedThisFrame)Select(1);else if(k.digit3Key.wasPressedThisFrame)Select(2);else if(k.digit4Key.wasPressedThisFrame)Select(3);else if(k.digit5Key.wasPressedThisFrame)Select(4);}
 }
}
