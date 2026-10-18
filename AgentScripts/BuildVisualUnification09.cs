using System;
using System.IO;
using UnityEditor;
using Newtonsoft.Json;
public static class BuildVisualUnification09
{
 // Queue outside the CLI request's 5s main-thread budget. Import can take longer.
 public static object Main()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Requires clean stopped Editor");
  if(Directory.Exists(VisualUnification09Importer.Art)||Array.Exists(VisualUnification09Importer.Scenes,File.Exists))throw new IOException("Refuse existing Direction09 outputs");
  string output="Temp/WorldGen/BuildVisualUnification09.json";if(File.Exists(output))throw new IOException("Refuse existing build receipt");Directory.CreateDirectory("Temp/WorldGen");
  EditorApplication.delayCall+=()=>{try{var result=VisualUnification09Importer.Build();File.WriteAllText(output,JsonConvert.SerializeObject(new{success=true,result},Formatting.Indented));}catch(Exception e){File.WriteAllText(output,JsonConvert.SerializeObject(new{success=false,error=e.ToString()},Formatting.Indented));}};
  return new{queued=true,receipt=output};
 }
}
