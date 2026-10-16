using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
public static class ExportHumanoidSwordR7Metadata
{
 public static string Inspect(){var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/ValdoriaSwordR7.asset");File.WriteAllText("ArtSource/Labs/Humanoid2026/R7/character-manifest.json",JsonConvert.SerializeObject(new{set.characterId,set.eightDirectionPresentation,set.pixelsPerUnit,set.referenceSpeed,physicalPolicy="PlanarSweepOrigin",clips=set.clips.Select(c=>new{c.action,c.direction,c.loop,c.status,frames=c.frames.Select(f=>new{sprite=f.sprite.name,asset=AssetDatabase.GetAssetPath(f.sprite),rect=new[]{f.sprite.rect.x,f.sprite.rect.y,f.sprite.rect.width,f.sprite.rect.height},hand=new[]{f.hand.x,f.hand.y},f.holdAngle,f.depth,f.seconds,f.source})})},Formatting.Indented));return "Exported R7 metadata; references immutable R6 sprites.";}
}
