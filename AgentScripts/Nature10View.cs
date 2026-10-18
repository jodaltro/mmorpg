using System;
using System.Reflection;
using UnityEditor;
using UnityEngine;
public static class Nature10View
{
    const BindingFlags Instance=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static Type Type(string name)=>typeof(Editor).Assembly.GetType("UnityEditor."+name,true);
    static object Group()
    {
        var t=Type("GameViewSizes");var sizes=t.GetProperty("instance",BindingFlags.Public|BindingFlags.Static|BindingFlags.FlattenHierarchy).GetValue(null);
        var group=Enum.Parse(Type("GameViewSizeGroupType"),"Standalone");return t.GetMethod("GetGroup").Invoke(sizes,new[]{group});
    }
    public static object Begin()
    {
        if(EditorApplication.isPlaying)throw new Exception("Set fixed view outside Play");
        if(SessionState.GetBool("Nature10.FixedView",false))throw new Exception("QA resolution already assigned");
        var view=EditorWindow.GetWindow(Type("GameView"));var property=Type("GameView").GetProperty("selectedSizeIndex",Instance);
        int previous=(int)property.GetValue(view);var group=Group();var gt=group.GetType();
        int total=(int)gt.GetMethod("GetTotalCount").Invoke(group,null);int built=(int)gt.GetMethod("GetBuiltinCount").Invoke(group,null);
        var kind=Enum.Parse(Type("GameViewSizeType"),"FixedResolution");
        var size=Activator.CreateInstance(Type("GameViewSize"),Instance,null,new object[]{kind,1600,900,"ValdoriaNature10-Native-QA"},null);
        gt.GetMethod("AddCustomSize").Invoke(group,new[]{size});property.SetValue(view,total);view.Repaint();
        SessionState.SetInt("Nature10.PreviousSize",previous);SessionState.SetInt("Nature10.CustomSize",total);SessionState.SetBool("Nature10.FixedView",true);
        return new{previous,fixedIndex=total,resolution="1600x900"};
    }
    public static object End()
    {
        if(EditorApplication.isPlaying)throw new Exception("Stop Play before restoring view");
        if(!SessionState.GetBool("Nature10.FixedView",false))return "No override";
        var view=EditorWindow.GetWindow(Type("GameView"));var property=Type("GameView").GetProperty("selectedSizeIndex",Instance);var group=Group();
        property.SetValue(view,SessionState.GetInt("Nature10.PreviousSize",0));
        int added=SessionState.GetInt("Nature10.CustomSize",-1);int built=(int)group.GetType().GetMethod("GetBuiltinCount").Invoke(group,null);int total=(int)group.GetType().GetMethod("GetTotalCount").Invoke(group,null);
        if(added<built||added>=total)throw new InvalidOperationException("Temporary Game View index is no longer valid");
        group.GetType().GetMethod("RemoveCustomSize").Invoke(group,new object[]{added});view.Repaint();
        SessionState.SetBool("Nature10.FixedView",false);return "Original Game View selection restored; temporary fixed size removed";
    }
}
