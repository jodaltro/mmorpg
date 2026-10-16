using System;
using System.Linq;
using System.IO;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;
public static class BuildWeaponValidationMenuR7
{
 public static string Inspect(){var view=UnityEngine.Object.FindAnyObjectByType<SessionMenuView>(FindObjectsInactive.Include);return string.Join("\n",view.GetComponentsInChildren<RectTransform>(true).Select(r=>r.name+" size="+r.sizeDelta+" pos="+r.anchoredPosition));}
 public static string ClearConsole(){typeof(EditorApplication).Assembly.GetType("UnityEditor.LogEntries").GetMethod("Clear").Invoke(null,null);return "Cleared current console after archiving the fixed unload error.";}
 static TMP_FontAsset font;
 static RectTransform Rect(Transform parent,string name,Vector2 size,Vector2 position){var go=new GameObject(name,typeof(RectTransform));go.transform.SetParent(parent,false);var r=go.GetComponent<RectTransform>();r.anchorMin=r.anchorMax=r.pivot=new Vector2(.5f,.5f);r.sizeDelta=size;r.anchoredPosition=position;return r;}
 static TMP_Text Label(Transform parent,string name,string text,float size,Vector2 box,Vector2 position){var r=Rect(parent,name,box,position);var t=r.gameObject.AddComponent<TextMeshProUGUI>();t.font=font;t.fontSize=size;t.text=text;t.alignment=TextAlignmentOptions.Center;t.color=new Color(.94f,.93f,.86f);t.raycastTarget=false;return t;}
 static UnityEngine.UI.Button Button(Transform parent,string name,string text,Vector2 position,Vector2 size){var r=Rect(parent,name,size,position);var im=r.gameObject.AddComponent<UnityEngine.UI.Image>();im.color=new Color(.19f,.25f,.28f,.98f);var b=r.gameObject.AddComponent<UnityEngine.UI.Button>();b.targetGraphic=im;var colors=b.colors;colors.highlightedColor=new Color(.7f,.85f,.9f);colors.pressedColor=new Color(.5f,.7f,.8f);b.colors=colors;Label(r,"Text",text,18,size-Vector2.one*8,Vector2.zero);return b;}
 public static string Create()
 {
  var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(EditorApplication.isPlaying||scene.isDirty||scene.path!="Assets/Mmorpg/Scenes/HumanoidSwordR7.unity")throw new Exception("Clean stopped R7 scene required");
  var view=UnityEngine.Object.FindAnyObjectByType<SessionMenuView>(FindObjectsInactive.Include);var serialized=new SerializedObject(view);var pause=(GameObject)serialized.FindProperty("menu").objectReferenceValue;
  if(pause.transform.parent.Find("WeaponValidation")!=null||UnityEngine.Object.FindAnyObjectByType<WeaponValidationPreview>()!=null)throw new Exception("Refusing to overwrite existing weapon menu");
  font=pause.transform.Find("Title").GetComponent<TMP_Text>().font;
  var events=UnityEngine.Object.FindObjectsByType<UnityEngine.EventSystems.EventSystem>(FindObjectsInactive.Include);if(events.Length!=1||events[0].GetComponent<UnityEngine.InputSystem.UI.InputSystemUIInputModule>()==null)throw new Exception("Existing single Input System UI required");
  ((RectTransform)pause.transform).sizeDelta=new Vector2(340,370);((RectTransform)pause.transform.Find("Title")).anchoredPosition=new Vector2(0,155);
  string[] fields={"resume","restart","newJourney","options","quit"};float[] ys={112,70,28,-14,-98};for(int i=0;i<fields.Length;i++)((RectTransform)((UnityEngine.UI.Button)serialized.FindProperty(fields[i]).objectReferenceValue).transform).anchoredPosition=new Vector2(0,ys[i]);
  var open=Button(pause.transform,"ValidateWeapons","Validar armas",new Vector2(0,-56),new Vector2(290,34));
  var page=Rect(pause.transform.parent,"WeaponValidation",new Vector2(570,400),Vector2.zero);page.gameObject.AddComponent<UnityEngine.UI.Image>().color=new Color(.055f,.075f,.095f,.98f);
  Label(page,"Title","VALIDAR ARMAS",24,new Vector2(520,34),new Vector2(0,167));
  var description=Label(page,"Description","",17,new Vector2(510,146),new Vector2(0,67));
  var buttons=new[]{Button(page,"WeaponSword","Espada",new Vector2(-174,-36),new Vector2(162,40)),Button(page,"WeaponBowSouth","Arco · frontal",new Vector2(0,-36),new Vector2(162,40)),Button(page,"WeaponBowEast","Arco · lateral",new Vector2(174,-36),new Vector2(162,40)),Button(page,"WeaponTest","Continuar e testar",new Vector2(0,-94),new Vector2(330,40)),Button(page,"WeaponBack","Voltar",new Vector2(0,-149),new Vector2(200,34))};
  var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var actor=journey.Player;var animator=actor.GetComponent<ProductionSpriteAnimator>();var sword=actor.GetComponent<SwordSwing>();var blade=actor.GetComponentsInChildren<SpriteRenderer>(true).Single(r=>r.name=="EquippedSword");
  var canvas=view.GetComponentInParent<Canvas>();var hint=Label(canvas.transform,"WeaponValidationHint","",16,new Vector2(650,52),Vector2.zero);var hr=hint.rectTransform;hr.anchorMin=hr.anchorMax=new Vector2(.5f,1);hr.anchoredPosition=new Vector2(0,-65);hint.gameObject.SetActive(false);
  var frames=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/BowAnatomyStudy/BowDraw.png").OfType<Sprite>().OrderBy(s=>s.name).ToArray();if(frames.Length!=74)throw new Exception("Approved V4 bow atlas required");
  var preview=actor.gameObject.AddComponent<WeaponValidationPreview>();preview.Configure(animator,sword,actor.GetComponent<PlayerController>(),UnityEngine.Object.FindAnyObjectByType<ActionCombat>(),UnityEngine.Object.FindAnyObjectByType<ActionSliceHud>(),actor,blade,frames,hint);
  AddFraming(preview);
  var commands=UnityEngine.Object.FindAnyObjectByType<LocalSessionCommands>();page.gameObject.AddComponent<WeaponValidationMenu>().Configure(preview,commands,view,description,buttons);view.ConfigureWeaponValidation(page.gameObject,open);page.gameObject.SetActive(false);
  EditorUtility.SetDirty(view);EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return "R7 Esc menu: Espada, Arco frontal/lateral; scene authored through connected Editor. Official/legacy scenes unchanged.";
 }
 static void AddFraming(WeaponValidationPreview preview){var follow=Camera.main.GetComponent<CameraFollow>();var original=(Transform)new SerializedObject(follow).FindProperty("target").objectReferenceValue;var focus=new GameObject("BowValidationCameraFocus").transform;focus.SetParent(preview.transform,false);focus.localPosition=Vector3.up*1.5f;preview.ConfigureFraming(follow,original,focus);EditorUtility.SetDirty(preview);}
 public static string AddPreviewFraming(){var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(EditorApplication.isPlaying||scene.isDirty||scene.path!="Assets/Mmorpg/Scenes/HumanoidSwordR7.unity")throw new Exception("Clean stopped R7 scene required");var preview=UnityEngine.Object.FindAnyObjectByType<WeaponValidationPreview>();if(preview.transform.Find("BowValidationCameraFocus")!=null)throw new Exception("Framing already exists");AddFraming(preview);EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);return "Added reversible bow-only camera target; root and collision unchanged.";}
}
