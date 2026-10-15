using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using Mmorpg.Domain;
using Newtonsoft.Json;

namespace Mmorpg.Runtime
{
    // Offline storage only: checksum detects accidental corruption, not cheating.
    public sealed class JsonJourneyPersistence : IJourneyPersistence
    {
        [Serializable] private sealed class Envelope { public int version=1; public string json, checksum; }
        private readonly string path;
        public string RecoveryMessage { get; private set; }
        public JsonJourneyPersistence(string path) { this.path=Path.GetFullPath(path); }
        private static string Hash(string text) { using(var sha=SHA256.Create()) return Convert.ToBase64String(sha.ComputeHash(Encoding.UTF8.GetBytes(text))); }
        public void Save(JourneySnapshot state)
        {
            JourneyEngine.Restore(state); // reject inconsistent caches before touching disk
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string json=JsonConvert.SerializeObject(state);
            byte[] bytes=Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(new Envelope{json=json,checksum=Hash(json)},Formatting.Indented));
            using(var stream=new FileStream(path+".tmp",FileMode.Create,FileAccess.Write,FileShare.None)) { stream.Write(bytes,0,bytes.Length); stream.Flush(true); }
            Read(path+".tmp");
            if(File.Exists(path))
            {
                // Preserve only a verified previous generation as the recovery backup.
                bool valid=true; try { Read(path); } catch(Exception ex) when(IsStorageFailure(ex)) { valid=false; }
                File.Replace(path+".tmp",path,valid?path+".bak":null);
            }
            else File.Move(path+".tmp",path);
        }
        public JourneySnapshot Load()
        {
            RecoveryMessage=null;
            bool any=false;
            foreach(string candidate in new[]{path,path+".bak",path+".tmp"})
            {
                if(!File.Exists(candidate)) continue;
                any=true;
                try { var result=Read(candidate); if(candidate!=path) RecoveryMessage="Save recuperado de "+Path.GetFileName(candidate); return result; }
                catch(Exception ex) when(IsStorageFailure(ex)) { RecoveryMessage="Save inválido: "+ex.Message; }
            }
            if(any) throw new InvalidDataException("Nenhuma geração íntegra do save foi encontrada.");
            return null;
        }
        private JourneySnapshot Read(string candidate)
        {
            var envelope=JsonConvert.DeserializeObject<Envelope>(File.ReadAllText(candidate,Encoding.UTF8));
            if(envelope==null||envelope.version!=1||envelope.json==null||Hash(envelope.json)!=envelope.checksum) throw new InvalidDataException("Envelope/version/checksum inválido");
            var saved=JsonConvert.DeserializeObject<JourneySnapshot>(envelope.json);
            return JourneyEngine.Restore(saved).Snapshot();
        }
        private static bool IsStorageFailure(Exception ex) => ex is IOException||ex is UnauthorizedAccessException||ex is ArgumentException||ex is JsonException||ex is NullReferenceException||ex is InvalidOperationException;
    }
    public sealed class MemoryJourneyPersistence : IJourneyPersistence
    {
        private JourneySnapshot saved;
        public void Save(JourneySnapshot state) => saved=JourneyEngine.Restore(state).Snapshot();
        public JourneySnapshot Load() => saved==null?null:JourneyEngine.Restore(saved).Snapshot();
    }
}
