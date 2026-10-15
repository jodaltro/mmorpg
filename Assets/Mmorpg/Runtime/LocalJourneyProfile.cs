using System;
using System.IO;
using System.Linq;
using UnityEngine;
namespace Mmorpg.Runtime
{
    // Strict ownership allowlist. Never enumerate persistentDataPath for deletion.
    public static class LocalJourneyProfile
    {
        public static string ValidationRootOverride;
        private static readonly string[] owned={"journey.json","journey.json.bak","journey.json.tmp","marco06b1-exploration.json","marco06b1-exploration.json.bak","marco06b1-exploration.json.tmp","profile.json","decision-cache.json"};
        public static string Root=>Path.GetFullPath(ValidationRootOverride??Path.Combine(Application.persistentDataPath,"DevelopmentJourneys","marco06b4"));
        [Serializable] private sealed class Identity {public string id;public long epoch;}
        public static string IdentityId {get;private set;}
        public static void Open()
        {
            Directory.CreateDirectory(Root);string file=Path.Combine(Root,"profile.json");
            var identity=File.Exists(file)?JsonUtility.FromJson<Identity>(File.ReadAllText(file)):null;
            if(identity==null||!Guid.TryParseExact(identity.id,"N",out _))throwIfExisting(file);
            if(identity==null)identity=new Identity{id=Guid.NewGuid().ToString("N"),epoch=SessionEpoch.Current};
            IdentityId=identity.id;if(!File.Exists(file))File.WriteAllText(file,JsonUtility.ToJson(identity,true));
        }
        private static void throwIfExisting(string file){if(File.Exists(file))throw new InvalidDataException("Identidade local inválida; arquivo preservado.");}
        public static string BackupAndReset()
        {
            string root=Root,backup=Path.Combine(root,"Backups",DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff")+"-"+Guid.NewGuid().ToString("N").Substring(0,8));
            Directory.CreateDirectory(backup);
            var present=owned.Where(name=>File.Exists(Path.Combine(root,name))).ToArray();
            // Complete and byte-verify the backup before removing a single owned file.
            foreach(string name in present)
            {
                string from=Path.Combine(root,name),to=Path.Combine(backup,name);File.Copy(from,to,false);
                if(!File.ReadAllBytes(from).SequenceEqual(File.ReadAllBytes(to)))throw new IOException("Backup não verificado: "+name);
            }
            try{foreach(string name in present)File.Delete(Path.Combine(root,name));Open();}
            catch {foreach(string name in present)File.Copy(Path.Combine(backup,name),Path.Combine(root,name),true);throw;}
            return backup;
        }
    }
}
