using System.IO;
using UnityEngine;

namespace Mmorpg.Runtime
{
    [DefaultExecutionOrder(-10000)]
    public sealed class ValdoriaR9ProfileIsolation : MonoBehaviour
    {
        private string previous;
        private string assigned;
        [SerializeField] private string profileSubdirectory = "ValdoriaEnvironmentR9/IsolatedProfile";
        public void ConfigureTemporaryProfile(string subdirectory) => profileSubdirectory = subdirectory;

        private void Awake()
        {
            previous = LocalJourneyProfile.ValidationRootOverride;
            string temp = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "Temp")) + Path.DirectorySeparatorChar;
            assigned = Path.GetFullPath(Path.Combine(temp, profileSubdirectory));
            if (!assigned.StartsWith(temp, System.StringComparison.OrdinalIgnoreCase))
                throw new System.InvalidOperationException("Validation profiles must remain inside the project Temp directory.");
            Directory.CreateDirectory(assigned);
            LocalJourneyProfile.ValidationRootOverride = assigned;
        }

        private void OnDestroy()
        {
            if (LocalJourneyProfile.ValidationRootOverride == assigned)
                LocalJourneyProfile.ValidationRootOverride = previous;
        }
    }
}
