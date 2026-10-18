using System;
using System.IO;
using UnityEditor;
using Newtonsoft.Json;
public static class BuildNature10
{
 public static object Main()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped Editor required");if(File.Exists(NatureReference10Importer.Scene)||Directory.Exists(NatureReference10Importer.Art))throw new IOException("Refuse existing nature outputs");
  EditorApplication.update+=BuildOnce;return "Queued real Editor import; read Temp/Nature10-build.json";
 }
 static void BuildOnce(){EditorApplication.update-=BuildOnce;try{File.WriteAllText("Temp/Nature10-build.json",JsonConvert.SerializeObject(new{success=true,result=NatureReference10Importer.Build()},Formatting.Indented));}catch(Exception e){File.WriteAllText("Temp/Nature10-build.json",JsonConvert.SerializeObject(new{success=false,error=e.ToString()},Formatting.Indented));}}
}
