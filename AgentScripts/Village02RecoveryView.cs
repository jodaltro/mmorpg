using System;
using System.Reflection;
using UnityEditor;
using UnityEngine;
public static class Village02RecoveryView
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new Exception("Stopped recovery required");const BindingFlags flags=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
  var assembly=typeof(Editor).Assembly;var gt=assembly.GetType("UnityEditor.GameViewSizes",true);var sizes=gt.GetProperty("instance",BindingFlags.Public|BindingFlags.Static|BindingFlags.FlattenHierarchy).GetValue(null);var type=assembly.GetType("UnityEditor.GameViewSizeGroupType",true);var group=gt.GetMethod("GetGroup").Invoke(sizes,new[]{Enum.Parse(type,"Standalone")});var count=(int)group.GetType().GetMethod("GetTotalCount").Invoke(group,null);
  // Pre-restart receipt: previous=0, total-before=8, our custom index=8.
  var labels=(string[])group.GetType().GetMethod("GetDisplayTexts").Invoke(group,null);var vt=assembly.GetType("UnityEditor.GameView",true);var view=EditorWindow.GetWindow(vt);vt.GetProperty("selectedSizeIndex",flags).SetValue(view,0);int removed=0;for(int i=count-1;i>=0;i--)if(labels[i].Contains("ValdoriaVillage02-Native-QA")){group.GetType().GetMethod("RemoveCustomSize").Invoke(group,new object[]{i});removed++;}view.Repaint();SessionState.SetBool("Village02.FixedView",false);
  return new{restoredIndex=0,removedPersistedOwnedSizes=removed,previousInventory=labels,playMode=EditorApplication.isPlaying,targetFrameRate=Application.targetFrameRate,timeScale=Time.timeScale};
 }
}
