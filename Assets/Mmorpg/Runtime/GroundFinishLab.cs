using System;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Mmorpg.Runtime
{
 // Presentation only: all four states share the same world physics/nav/props.
 public sealed class GroundFinishLab:MonoBehaviour
 {
  [Serializable] public sealed class Surface{public Renderer renderer;public Material before,baseLayer,transitions,final;}
  [SerializeField] Surface[] surfaces;[SerializeField] SpriteRenderer oldAccess;[SerializeField] int stage=3;
  public int Stage=>stage;
  public void Configure(Surface[] bindings,SpriteRenderer access){surfaces=bindings;oldAccess=access;Select(3);}
  public void Select(int value){if(value<0||value>3)throw new ArgumentOutOfRangeException(nameof(value));stage=value;foreach(var s in surfaces)if(s.renderer)s.renderer.sharedMaterial=value==0?s.before:value==1?s.baseLayer:value==2?s.transitions:s.final;if(oldAccess)oldAccess.enabled=value==0;}
  void Awake()=>Select(stage);
  void Update(){var k=Keyboard.current;if(k==null)return;if(k.digit1Key.wasPressedThisFrame)Select(0);if(k.digit2Key.wasPressedThisFrame)Select(1);if(k.digit3Key.wasPressedThisFrame)Select(2);if(k.digit4Key.wasPressedThisFrame)Select(3);}
 }
}
